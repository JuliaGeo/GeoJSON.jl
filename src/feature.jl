# https://tools.ietf.org/html/rfc7946#section-5
# was <: StaticMatrix{N, 2, Float64} but gave too many ambiguities
struct BBox{N} <: AbstractMatrix{Float64}
    # west east
    # south north
    # [down] [up]
    bounds::SMatrix{N, 2, Float64}
end

Base.size(b::BBox) = size(b.bounds)
Base.IndexStyle(::BBox) = IndexLinear()
Base.getindex(b::BBox, i::Int) = b.bounds[i]
Base.setindex!(b::BBox, v, i::Int) = setindex!(b.bounds, v, i)

# https://tools.ietf.org/html/rfc7946#section-3.1
const SingleGeometry = Union{SVector, LineString, Polygon}
const MultiGeometry = Union{Vector{SVector}, Vector{LineString}, Vector{Polygon}}
const RegularGeometry = Union{SingleGeometry, MultiGeometry}

struct GeometryCollection <: AbstractVector{RegularGeometry}
    geometries::Vector{RegularGeometry}
    bbox::Union{BBox, Nothing}
end

GeometryCollection(g::RegularGeometry) = GeometryCollection([g], nothing)
GeometryCollection(g::AbstractVector) = GeometryCollection(g, nothing)

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
    bbox::Union{BBox, Nothing}
end

Feature(g::Geometry) = Feature(g, nothing, nothing, nothing)
Feature(f::Feature;
    properties::Union{JSON3.Object, Nothing}=f.properties,
    id::Union{String, Float64, Nothing}=f.id,
    bbox::Union{BBox, Nothing}=f.bbox) = Feature(f.geometry, properties, id, bbox)

function Base.:(==)(f1::Feature{N}, f2::Feature{N}) where N
    return f1.geometry == f2.geometry &&
        f1.properties == f2.properties &&
        f1.id == f2.id &&
        f1.bbox == f2.bbox
end

function Base.isequal(f1::Feature{N}, f2::Feature{N}) where N
    return isequal(f1.geometry, f2.geometry) &&
        isequal(f1.properties, f2.properties) &&
        isequal(f1.id, f2.id) &&
        isequal(f1.bbox, f2.bbox)
end

function Base.hash(f::Feature, h::UInt)
    hash(f.bbox, (hash(f.id, hash(f.properties, (hash(f.geometry,
        hash(UInt === UInt64 ? 0x9687d49697a61d91 : 0x7996a789, h)))))))
end

struct FeatureCollection <: AbstractVector{Feature}
    features::Vector{Feature}
    bbox::Union{BBox, Nothing}
end

FeatureCollection(f::Feature) = FeatureCollection([f], nothing)
FeatureCollection(f::AbstractVector{Feature}) = FeatureCollection(f, nothing)

Base.size(fcol::FeatureCollection) = size(fcol.features)
Base.IndexStyle(::FeatureCollection) = IndexLinear()
Base.getindex(fcol::FeatureCollection, i::Int) = fcol.features[i]
Base.setindex!(fcol::FeatureCollection, v, i::Int) = setindex!(fcol.features, v, i)
