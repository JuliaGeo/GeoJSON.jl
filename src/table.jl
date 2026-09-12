Tables.istable(::Type{<:AbstractFeatureCollection}) = true
Tables.rowaccess(::Type{<:AbstractFeatureCollection}) = true
Tables.rows(fc::AbstractFeatureCollection) = fc
Tables.schema(fc::FeatureCollection) = Tables.Schema(_schema(fc)...)

# The geometry column is always the geometry field, even when a property is named "geometry".
Tables.getcolumn(f::Feature, k::Symbol) = k === :geometry ? something(geometry(f), missing) : getproperty(f, k)
Tables.getcolumn(f::Feature, i::Int) = Tables.getcolumn(f, propertynames(f)[i])

Base.propertynames(fc::FeatureCollection) = first(_schema(fc))
function Base.getproperty(fc::FeatureCollection, k::Symbol)
    hasfield(typeof(fc), k) && return getfield(fc, k)
    names, types = _schema(fc)
    i = findfirst(==(k), names)
    T = i === nothing ? Missing : types[i]
    return T[Tables.getcolumn(f, k) for f in features(fc)]
end

_columntype(::Type{T}) where {T} = Nothing <: T ? Union{Missing,Base.nonnothingtype(T)} : T
_widen(A, B) = B <: A ? A : Union{A,B}

function _schema(fc::FeatureCollection{D,T,G,P}) where {D,T,G,P}
    names, types = _propertyschema(fc, P)
    push!(names, :geometry)
    push!(types, _geometrytype(fc))
    return names, types
end

function _geometrytype(fc::FeatureCollection{D,T,G}) where {D,T,G}
    t = mapreduce(f -> _columntype(typeof(geometry(f))), _widen, features(fc); init=Union{})
    return t === Union{} ? G : t
end

_propertyschema(fc, ::Type{Nothing}) = (Symbol[], Type[])

function _propertyschema(fc, ::Type{P}) where {P}
    names = Symbol[]
    types = Type[]
    for (k, t) in zip(fieldnames(P), fieldtypes(P))
        k === :geometry && continue
        push!(names, k)
        push!(types, _columntype(t))
    end
    return names, types
end

function _propertyschema(fc, ::Type{P}) where {P<:AbstractDict}
    names = Symbol[]
    types = Type[]
    count = Int[]
    seen = Int[]  # last feature index holding each column; guards count against repeated keys in one feature
    index = Dict{Symbol,Int}()
    for (n, f) in enumerate(features(fc))
        for (k, v) in pairs(properties(f))
            s = Symbol(k)
            s === :geometry && continue
            vt = _columntype(typeof(v))
            i = get(index, s, 0)
            if i == 0
                push!(names, s)
                push!(types, vt)
                push!(count, 1)
                push!(seen, n)
                index[s] = length(names)
            else
                types[i] = _widen(types[i], vt)
                seen[i] == n || (count[i] += 1; seen[i] = n)
            end
        end
    end
    for i in eachindex(names)
        count[i] < length(fc) && (types[i] = Union{Missing,types[i]})
    end
    return names, types
end
