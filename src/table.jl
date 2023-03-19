# Tables.jl interface methods
Tables.istable(::Type{<:AbstractFeatureCollection}) = true
Tables.rowaccess(::Type{<:AbstractFeatureCollection}) = true
Tables.rows(fc::AbstractFeatureCollection) = fc
Tables.schema(::LazyFeatureCollection) = nothing
Tables.schema(fc::FeatureCollection) = Tables.Schema(collect(keys(getfield(fc, :types))), values(getfield(fc, :types)))


# Adapted from JSONTables.jl jsontable method
# We cannot simply use their method as we have concrete types and need the key/value pairs
# of the properties field, rather than the main object
# TODO: Is `missT` required?
# TODO: The `getfield` is probably required once
function property_schema(features)
    # Otherwise find the shared names
    names = Set{Symbol}()
    types = Dict{Symbol,Type}()
    for feature in features
        props = properties(feature)
        isnothing(props) && continue
        if isempty(names)
            for k in keys(props)
                k === :geometry && continue
                push!(names, k)
                types[k] = missT(typeof(props[k]))
            end
            push!(names, :geometry)
            types[:geometry] = missT(typeof(geometry(feature)))
        else
            for nm in names
                T = types[nm]
                if haskey(props, nm)
                    v = props[nm]
                    if !(missT(typeof(v)) <: T)
                        types[nm] = Union{T,missT(typeof(v))}
                    end
                elseif hasfield(typeof(feature), nm)
                    v = getfield(feature, nm)
                    if !(missT(typeof(v)) <: T)
                        types[nm] = Union{T,missT(typeof(v))}
                    end
                elseif !(T isa Union && T.a === Missing)
                    types[nm] = Union{Missing,types[nm]}
                end
            end
            for (k, v) in pairs(props)
                k === :geometry && continue
                if !(k in names)
                    push!(names, k)
                    types[k] = Union{Missing,missT(typeof(v))}
                end
            end
        end
    end
    return collect(names), types
end
