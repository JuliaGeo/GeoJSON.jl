# Tables.jl interface methods
Tables.istable(::Type{<:AbstractFeatureCollection}) = true
Tables.rowaccess(::Type{<:AbstractFeatureCollection}) = true
Tables.rows(fc::AbstractFeatureCollection) = fc
Tables.schema(::LazyFeatureCollection) = nothing
Tables.schema(fc::FeatureCollection) = Tables.Schema(collect(keys(getfield(fc, :types))), values(getfield(fc, :types)))


# Collect distinct types by identity and form each column's Union once. Counts
# account for absent properties without revisiting every column on every row.
mutable struct ColumnTypes
    values::Vector{Type}
    count::Int
end
function addtype!(column::ColumnTypes, T::Type)
    any(t -> t === T, column.values) || push!(column.values, T)
    column.count += 1
    nothing
end
function property_schema(features)
    names = Set{Symbol}()
    types = Dict{Symbol,Type}()
    columns = Dict{Symbol,ColumnTypes}()
    for (row, feature) in enumerate(features)
        props = properties(feature)
        for (k, v) in props
            k === :geometry && continue
            if !haskey(columns, k)
                push!(names, k)
                types[k] = Union{} # retain A's Dict insertion/hash order
                columns[k] = ColumnTypes(row == 1 ? Type[] : Type[Missing], 0)
            end
            addtype!(columns[k], missT(typeof(v)))
        end
        if row == 1
            push!(names, :geometry)
            types[:geometry] = Union{}
            columns[:geometry] = ColumnTypes(Type[], 0)
        end
        # As in A, a property named geometry overrides the geometry field after
        # the first row. Other field-named columns use fields when absent.
        g = row > 1 && haskey(props, :geometry) ? props[:geometry] : geometry(feature)
        addtype!(columns[:geometry], missT(typeof(g)))
        for k in (:id, :bbox, :properties)
            if haskey(columns, k) && !haskey(props, k)
                addtype!(columns[k], missT(typeof(getfield(feature, k))))
            end
        end
    end
    for (k, column) in columns
        column.count < length(features) && addtype!(column, Missing)
        types[k] = Union{column.values...}
    end
    collect(names), types
end
