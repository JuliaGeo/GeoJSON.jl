module GeoJSONTables

import JSON3, Tables, GeoInterface

struct FeatureCollection{T} <: AbstractVector{eltype(T)}
    source::T
end

function read(source)
    fc = JSON3.read(source)
    features = get(fc, :features, nothing)
    if get(fc, :type, nothing) == "FeatureCollection" && features isa JSON3.Array
        FeatureCollection{typeof(features)}(features)
    else
        throw(ArgumentError("input source is not a GeoJSON FeatureCollection"))
    end
end

Tables.istable(::Type{<:FeatureCollection}) = true
Tables.rowaccess(::Type{<:FeatureCollection}) = true
Tables.rows(x::FeatureCollection) = x

Base.IteratorSize(::Type{<:FeatureCollection}) = Base.HasLength()
Base.length(x::FeatureCollection) = length(getfield(x, :source))
Base.IteratorEltype(::Type{<:FeatureCollection}) = Base.HasEltype()

# read only AbstractVector
Base.size(x::FeatureCollection) = size(getfield(x, :source))
Base.getindex(x::FeatureCollection, i) = Feature(getindex(getfield(x, :source), i))
Base.IndexStyle(::Type{<:FeatureCollection}) = IndexLinear()

miss(x) = ifelse(x === nothing, missing, x)

struct Feature{T}
    x::T
end

function Base.propertynames(x::Feature)
    # these features always have type="Feature", so exclude that
    # the keys in properties are added here for direct access
    feature = getfield(x, :x)
    vcat(:geometry, propertynames(feature.properties))
end

function Base.getproperty(x::Feature, nm::Symbol)
    feature = getfield(x, :x)
    if nm in propertynames(feature)
        miss(getproperty(feature, nm))
    elseif nm in propertynames(feature.properties)
        miss(getproperty(feature.properties, nm))
    else
        missing
    end
end

@inline function Base.iterate(x::FeatureCollection)
    st = iterate(getfield(x, :source))
    st === nothing && return nothing
    val, state = st
    return Feature(val), state
end

@inline function Base.iterate(x::FeatureCollection, st)
    st = iterate(getfield(x, :source), st)
    st === nothing && return nothing
    val, state = st
    return Feature(val), state
end

Base.show(io::IO, x::FeatureCollection) = println(io, "FeatureCollection with $(length(x)) Features")
function Base.show(io::IO, x::Feature)
    println(io, "Feature with geometry type $(x.geometry.type) and properties $(propertynames(x))")
end
Base.show(io::IO, ::MIME"text/plain", x::FeatureCollection) = show(io, x)
Base.show(io::IO, ::MIME"text/plain", x::Feature) = show(io, x)

include("geointerface.jl")

end # module
