"""
    Feature

A feature wrapping the JSON object.
"""
struct Feature{T}
    object::T
end

# these features always have type="Feature", so exclude that
# the keys in properties are added here for direct access
Base.propertynames(f::Feature) = keys(properties(f))

"Access the properties JSON3.Object of a Feature"
properties(f::Feature) = object(f).properties

"Access the JSON3.Object that represents the Feature's geometry"
geometry(f::Feature) = geometry(object(f).geometry)

coordinates(f::Feature) = coordinates(geometry(object(f).geometry))


# Base methods
Base.:(==)(f1::Feature, f2::Feature) = object(f1) == object(f2)

"""
    FeatureCollection <: AbstractVector{Feature}

A feature collection wrapping, wrapping the JSON object.

Follows the julia `AbstractArray` interface as a lazy vector of `Feature`, and similarly
the GeoInterface.jl interface.
"""
struct FeatureCollection{T} <: AbstractVector{Feature}
    object::T
end

"Access the JSON3.Array of Features in the FeatureCollection"
features(f::FeatureCollection) = object(f).features


# Base methods

Base.IteratorSize(::Type{<:FeatureCollection}) = Base.HasLength()
Base.length(fc::FeatureCollection) = length(features(fc))
Base.IteratorEltype(::Type{<:FeatureCollection}) = Base.HasEltype()

# read only AbstractVector
Base.size(fc::FeatureCollection) = size(features(fc))
Base.getindex(fc::FeatureCollection, i) = Feature(features(fc)[i])
Base.IndexStyle(::Type{<:FeatureCollection}) = IndexLinear()

"""
Get a specific property of the Feature

Returns missing for null/nothing or not present, to work nicely with
properties that are not defined for every feature. If it is a table,
it should in some sense be defined.
"""
function Base.getproperty(f::Feature, nm::Symbol)
    props = properties(f)
    val = get(props, nm, missing)
    miss(val)
end

@inline function Base.iterate(fc::FeatureCollection)
    st = iterate(features(fc))
    st === nothing && return nothing
    val, state = st
    return Feature(val), state
end

@inline function Base.iterate(fc::FeatureCollection, st)
    st = iterate(features(fc), st)
    st === nothing && return nothing
    val, state = st
    return Feature(val), state
end

Base.show(io::IO, fc::FeatureCollection) =
    println(io, "FeatureCollection with $(length(fc)) Features")

function Base.show(io::IO, f::Feature)
    geom = geometry(f)
    propnames = propertynames(f)
    n = length(propnames)
    if isnothing(geom)
        print(io, "Feature with null geometry")
    else
        print(io, "Feature with a ", type(geom))
    end
    print(io, " and $n properties: ", propnames)
end

# Tables.jl interface methods
Tables.istable(::Type{<:FeatureCollection}) = true
Tables.rowaccess(::Type{<:FeatureCollection}) = true
Tables.rows(fc::FeatureCollection) = fc

# methods that apply to all GeoJSON Objects
const GeoJSONObject = Union{Geometry,Feature,FeatureCollection}

"""
    object(x::GeoJSONObject)

Access the object underlying the GeoJSONObject. This can be any object that meets the
GeoJSON specification. When reading a file it will generally be a JSON3.Object. When
constructed in code that can also be a NamedTuple for instance. Either will serialize
correctly back to GeoJSON strings.
"""
object(x::GeoJSONObject) = getfield(x, :object)

type(x::GeoJSONObject) = object(x).type
bbox(x::GeoJSONObject) = get(object(x), :bbox, nothing)

Base.show(io::IO, ::MIME"text/plain", x::GeoJSONObject) = show(io, x)
