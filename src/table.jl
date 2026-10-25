# Tables.jl interface methods
Tables.istable(::Type{<:AbstractFeatureCollection}) = true
Tables.rowaccess(::Type{<:AbstractFeatureCollection}) = true
Tables.rows(fc::AbstractFeatureCollection) = fc
Tables.schema(::LazyFeatureCollection) = nothing
Tables.schema(fc::FeatureCollection) = Tables.Schema(collect(keys(getfield(fc, :types))), values(getfield(fc, :types)))


# Collect distinct types by identity and form each column's Union once. Counts
# account for absent properties without revisiting every column on every row.
mutable struct ColumnTypes
    values::Vector{DataType}
    count::Int
end
@inline function addtype!(column::ColumnTypes, T::DataType)
    column.count += 1
    @inbounds for i in eachindex(column.values)
        column.values[i] === T && return nothing
    end
    push!(column.values, T)
    nothing
end
# Observed value types are always concrete DataTypes (including the types of
# property values that are themselves type objects). Keep that fact in storage
# and use a closed null check instead of dynamic dispatch on Type{T}.
@inline schematype(v) = v === nothing ? Missing : typeof(v)
function property_schema(features)
    names = Set{Symbol}()
    types = Dict{Symbol,Type}()
    columns = Dict{Symbol,ColumnTypes}()
    geometrycolumn = ColumnTypes(DataType[], 0)
    for (row, feature) in enumerate(features)
        props = properties(feature)
        for (k, v) in props
            k === :geometry && continue
            column = get(columns, k, nothing)
            if column === nothing
                push!(names, k)
                types[k] = Union{} # retain A's Dict insertion/hash order
                column = ColumnTypes(row == 1 ? DataType[] : DataType[Missing], 0)
                columns[k] = column
            end
            addtype!(column, schematype(v))
        end
        if row == 1
            push!(names, :geometry)
            types[:geometry] = Union{}
            columns[:geometry] = geometrycolumn
        end
        # As in A, a property named geometry overrides the geometry field after
        # the first row. Other field-named columns use fields when absent.
        g = row > 1 && haskey(props, :geometry) ? props[:geometry] : geometry(feature)
        addtype!(geometrycolumn, schematype(g))
        for k in (:id, :bbox, :properties)
            if haskey(columns, k) && !haskey(props, k)
                addtype!(columns[k], schematype(getfield(feature, k)))
            end
        end
    end
    for (k, column) in columns
        column.count < length(features) && addtype!(column, Missing)
        types[k] = Union{column.values...}
    end
    collect(names), types
end
