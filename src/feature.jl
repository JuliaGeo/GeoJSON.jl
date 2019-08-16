
# https://tools.ietf.org/html/rfc7946#section-3.1
const SingleGeometry = Union{SVector, LineString, Polygon}
const MultiGeometry = Union{Vector{SVector}, Vector{LineString}, Vector{Polygon}}
const RegularGeometry = Union{SingleGeometry, MultiGeometry}

struct GeometryCollection <: AbstractVector{RegularGeometry}
    geometries::Vector{RegularGeometry}
end

GeometryCollection(g::RegularGeometry) = GeometryCollection([g])

Base.size(gcol::GeometryCollection) = size(gcol.geometries)
Base.IndexStyle(::GeometryCollection) = IndexLinear()
Base.getindex(gcol::GeometryCollection, i::Int) = gcol.geometries[i]
Base.setindex!(gcol::GeometryCollection, v, i::Int) = setindex!(gcol.geometries, v, i)

const Geometry = Union{RegularGeometry, GeometryCollection}

# https://tools.ietf.org/html/rfc7946#section-3.2
struct Feature{G<:Geometry}
    geometry::G
    properties::Union{JSON3.Object, Nothing}
    id::Union{String, Float64, Nothing}
end

Feature(g::Geometry) = Feature(g, nothing, nothing)

function Base.:(==)(f1::Feature{N}, f2::Feature{N}) where N
    return f1.geometry == f2.geometry &&
        f1.properties == f2.properties &&
        f1.id == f2.id
end

function Base.isequal(f1::Feature{N}, f2::Feature{N}) where N
    return isequal(f1.geometry, f2.geometry) &&
        isequal(f1.properties, f2.properties) &&
        isequal(f1.id, f2.id)
end

function Base.hash(f::Feature, h::UInt)
    hash(f.id, hash(f.properties, (hash(f.geometry,
        hash(UInt === UInt64 ? 0x9687d49697a61d91 : 0x7996a789, h)))))
end

struct FeatureCollection <: AbstractVector{Feature}
    features::Vector{Feature}
end

FeatureCollection(f::Feature) = FeatureCollection([f])

Base.size(fcol::FeatureCollection) = size(fcol.features)
Base.IndexStyle(::FeatureCollection) = IndexLinear()
Base.getindex(fcol::FeatureCollection, i::Int) = fcol.features[i]
Base.setindex!(fcol::FeatureCollection, v, i::Int) = setindex!(fcol.features, v, i)
