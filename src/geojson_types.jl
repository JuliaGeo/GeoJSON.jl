abstract type GeoJSONT{D} end
abstract type AbstractGeometry{D} <: GeoJSONT{D} end
abstract type AbstractFeatureCollection{D} <: GeoJSONT{D} end

"""
    CRS(type::String, properties::Dict{String,Any})

A Coordinate Reference System for compatibility.
Should not be used, as it is not part of the GeoJSON specification.
The CRS of a GeoJSON object is always WGS84.
"""
struct CRS
    type::String
    properties::Dict{String,Any}
end

"""
    Point{D}(coordinates::Union{Nothing,NTuple{D,Float64}})

A Point geometry with `D` dimensions.
"""
struct Point{D} <: AbstractGeometry{D}
    coordinates::Union{Nothing,NTuple{D,Float64}}
end
Base.show(io::IO, ::Point{D}) where {D} = print(io, "$(D)D Point")
Base.eltype(::Type{Point}) = Float64

"""
    LineString{D}(coordinates::Union{Nothing,Vector{NTuple{D,Float64}}})

A LineString geometry with `D` dimensions.
"""
struct LineString{D} <: AbstractGeometry{D}
    coordinates::Union{Nothing,Vector{NTuple{D,Float64}}}
end
Base.eltype(::Type{LineString{D}}) where {D} = NTuple{D,Float64}

"""
    Polygon{D}(coordinates::Union{Nothing,Vector{Vector{NTuple{D,Float64}}}})

A Polygon geometry with `D` dimensions.
"""
struct Polygon{D} <: AbstractGeometry{D}
    coordinates::Union{Nothing,Vector{Vector{NTuple{D,Float64}}}}
end
Base.eltype(::Type{Polygon{D}}) where {D} = Vector{NTuple{D,Float64}}

"""
    MultiPoint{D}(coordinates::Union{Nothing,Vector{NTuple{D,Float64}}})

A MultiPoint geometry with `D` dimensions.
"""
struct MultiPoint{D} <: AbstractGeometry{D}
    coordinates::Union{Nothing,Vector{NTuple{D,Float64}}}
end
Base.eltype(::Type{MultiPoint{D}}) where {D} = Vector{NTuple{D,Float64}}

"""
    MultiLineString{D}(coordinates::Union{Nothing,Vector{Vector{NTuple{D,Float64}}}})

A MultiLineString geometry with `D` dimensions.
"""
struct MultiLineString{D} <: AbstractGeometry{D}
    coordinates::Union{Nothing,Vector{Vector{NTuple{D,Float64}}}}
end
Base.eltype(::Type{MultiLineString{D}}) where {D} = Vector{NTuple{D,Float64}}

"""
    MultiPolygon{D}(coordinates::Union{Nothing,Vector{Vector{Vector{NTuple{D,Float64}}}}})

A MultiPolygon geometry with `D` dimensions.
"""
struct MultiPolygon{D} <: AbstractGeometry{D}
    coordinates::Union{Nothing,Vector{Vector{Vector{NTuple{D,Float64}}}}}
end
Base.eltype(::Type{MultiPolygon{D}}) where {D} = Vector{Vector{NTuple{D,Float64}}}

coordinates(g::AbstractGeometry) = g.coordinates
bbox(g::AbstractGeometry) = nothing

Base.show(io::IO, x::T) where {D,T<:AbstractGeometry{D}} = print(io, "$(D)D $(type(T)) with $(length(x.coordinates)) sub-geometries")
Base.length(g::AbstractGeometry) = length(coordinates(g))
Base.size(g::AbstractGeometry) = size(coordinates(g))
Base.getindex(g::AbstractGeometry, i::Int) = getindex(coordinates(g), i::Int)
Base.IndexStyle(::Type{<:AbstractGeometry}) = Base.IndexLinear()

function Base.iterate(g::AbstractGeometry, state=1)
    x = iterate(coordinates(g), state)
    x === nothing && return nothing
    val, state = x
    return val, state
end

"""
    GeometryCollection{D}(geometries::Vector{AbstractGeometry{D}})

A GeometryCollection geometry with `D` dimensions.
"""
struct GeometryCollection{D} <: AbstractGeometry{D}
    geometries::Vector{AbstractGeometry{D}}
end

coordinates(g::GeometryCollection) = geometries(g)
geometry(g::GeometryCollection) = g.geometries

Base.show(io::IO, x::GeometryCollection{D}) where {D} = print(io, "GeometryCollection with $(length(x.geometries)) $(D)D geometries")
Base.length(g::GeometryCollection) = length(geometry(g))
Base.size(g::GeometryCollection) = size(geometry(g))
Base.getindex(g::GeometryCollection, i::Int) = getindex(geometry(g), i::Int)
Base.IndexStyle(::Type{<:GeometryCollection}) = Base.IndexLinear()

function Base.iterate(g::GeometryCollection, state=1)
    x = iterate(geometries(g), state)
    x === nothing && return nothing
    val, state = x
    return val, state
end

"""
    Feature{D}(id::Union{String,Nothing}, bbox::Union{Nothing,Vector{Float64}}, geometry::Union{Nothing,AbstractGeometry{D}}, properties::Union{Nothing,Dict{String,Any}})

A Feature with `D` dimensional geometry.
"""
struct Feature{D} <: GeoJSONT{D}
    id::Union{Nothing,String,Int}
    bbox::Union{Nothing,Vector{Float64}}
    geometry::Union{Nothing,AbstractGeometry{D}}
    properties::Union{Nothing,Dict{String,Any}}
end
bbox(f::Feature) = f.bbox
geometry(f::Feature) = f.geometry
properties(f::Feature) = f.properties
coordinates(f::Feature) = coordinates(geometry(f))
Base.show(io::IO, x::Feature{D}) where {D} = print(io, "Feature with $(D)D $(type(typeof(x.geometry))) geometry and $(length(x.properties)) properties")

# This is a non-public type used to lazily construct a Feature from a JSON3.RawValue
# It can be written again as String, which can also be used to parsed to a Feature
struct LazyFeature{D} <: GeoJSONT{D}
    bytes::Any
    pos::Int
    len::Int
end
StructTypes.construct(::Type{LazyFeature{D}}, x::JSON3.RawValue) where {D} = LazyFeature{D}(x.bytes, x.pos, x.len)
Base.codeunits(x::LazyFeature) = unsafe_string(pointer(x.bytes, x.pos), x.len)
JSON3.rawbytes(x::LazyFeature) = codeunits(x)


"""
    FeatureCollection{D}(bbox::Union{Nothing,Vector{Float64}}, features::Vector{Feature{D}}, crs::Union{Nothing,CRS})

A FeatureCollection with `D` dimensional geometry in its features.
"""
struct FeatureCollection{D} <: AbstractFeatureCollection{D}
    bbox::Union{Nothing,Vector{Float64}}
    features::Vector{Feature{D}}
    crs::Union{Nothing,CRS}
end
features(fc::FeatureCollection) = fc.features

function Base.iterate(fc::AbstractFeatureCollection{D}, state=1) where {D}
    (1 <= state <= length(fc)) || return nothing
    val = fc[state]::Feature{D}
    return val, state + 1
end

Base.show(io::IO, x::FeatureCollection) = print(io, "FeatureCollection with $(length(x.features)) features")
Base.eltype(::Type{<:AbstractFeatureCollection{D}}) where {D} = Feature{D}
Base.length(x::AbstractFeatureCollection) = length(x.features)
Base.size(x::AbstractFeatureCollection) = size(x.features)
Base.getindex(x::AbstractFeatureCollection, i::Int) = x.features[i]
Base.IndexStyle(::AbstractFeatureCollection) = IndexLinear()

bbox(fc::AbstractFeatureCollection) = fc.bbox

"""
    LazyFeatureCollection{D}(bbox::Union{Nothing,Vector{Float64}}, features::Vector{LazyFeature{D}}, crs::Union{Nothing,String})

A FeatureCollection with `D` dimensional geometry in its features, but it's features are
lazily parsed from the GeoJSON string. Indexing into the collection will parse the feature.
This can be more efficient when interested in only a few features from a large collection,
or parsing a very large collection iteratively without loading it all into memory.
"""
struct LazyFeatureCollection{D} <: AbstractFeatureCollection{D}
    bbox::Union{Nothing,Vector{Float64}}
    features::Vector{LazyFeature{D}}
    crs::Union{Nothing,CRS}
    # TODO Use features::JSON3.Array directly once we can parse the tape to find the
    # feature offsets in the buffer?
end
features(fc::LazyFeatureCollection) = collect(fc.features)

Base.show(io::IO, x::LazyFeatureCollection) = print(io, "LazyFeatureCollection with $(length(x.features)) features")
Base.getindex(x::LazyFeatureCollection{D}, i::Int) where {D} = JSON3.read(codeunits(x.features[i]), Feature{D})::Feature{D}

struct GeoJSONWrapper{D,X<:GeoJSONT{D}}
    obj::X
end
GeoJSONWrapper{D}(obj::X) where {D,X<:GeoJSONT{D}} = GeoJSONWrapper{D,X}(obj)

# symbol (from json string type) to struct mapping
function geom_mapping(D)
    (;
        Point=Point{D},
        MultiPoint=MultiPoint{D},
        LineString=LineString{D},
        MultiLineString=MultiLineString{D},
        Polygon=Polygon{D},
        MultiPolygon=MultiPolygon{D},
        GeometryCollection=GeometryCollection{D}
    )
end
function obj_mapping(D)
    (;
        Feature=Feature{D},
        FeatureCollection=FeatureCollection{D}
    )
end
StructTypes.StructType(::Type{<:GeoJSONWrapper}) = StructTypes.CustomStruct()
StructTypes.lower(x::GeoJSONWrapper) = x.obj
StructTypes.lowertype(::Type{<:GeoJSONWrapper{D}}) where {D} = GeoJSONT{D}

const point = "Point"
type(::Type{<:Point}) = point
const multipoint = "MultiPoint"
type(::Type{<:MultiPoint}) = multipoint
const linestring = "LineString"
type(::Type{<:LineString}) = linestring
const multilinestring = "MultiLineString"
type(::Type{<:MultiLineString}) = multilinestring
const polygon = "Polygon"
type(::Type{<:Polygon}) = polygon
const multipolygon = "MultiPolygon"
type(::Type{<:MultiPolygon}) = multipolygon
const geometrycollection = "GeometryCollection"
type(::Type{<:GeometryCollection}) = geometrycollection
const feature = "Feature"
type(::Type{<:Feature}) = feature
const featurecollection = "FeatureCollection"
type(::Type{<:FeatureCollection}) = featurecollection
const null = "null"
type(::Type{Nothing}) = null

StructTypes.StructType(::Type{<:GeoJSONT}) = StructTypes.AbstractType()
StructTypes.StructType(::Type{<:AbstractGeometry}) = StructTypes.AbstractType()
StructTypes.StructType(::Type{<:Point}) = StructTypes.Struct()
StructTypes.StructType(::Type{<:LineString}) = StructTypes.Struct()
StructTypes.StructType(::Type{<:Polygon}) = StructTypes.Struct()
StructTypes.StructType(::Type{<:MultiPoint}) = StructTypes.Struct()
StructTypes.StructType(::Type{<:MultiLineString}) = StructTypes.Struct()
StructTypes.StructType(::Type{<:MultiPolygon}) = StructTypes.Struct()
StructTypes.StructType(::Type{<:GeometryCollection}) = StructTypes.Struct()
StructTypes.subtypekey(::Type{<:AbstractGeometry}) = :type
StructTypes.subtypes(::Type{<:AbstractGeometry{D}}) where {D} = geom_mapping(D)
StructTypes.subtypekey(::Type{<:GeoJSONT}) = :type
StructTypes.subtypes(::Type{<:GeoJSONT{D}}) where {D} = merge(geom_mapping(D), obj_mapping(D))

StructTypes.StructType(::Type{<:Feature}) = StructTypes.Struct()
StructTypes.StructType(::Type{<:LazyFeature}) = JSON3.RawType()
StructTypes.StructType(::Type{<:FeatureCollection}) = StructTypes.Struct()
StructTypes.StructType(::Type{<:LazyFeatureCollection}) = StructTypes.Struct()
StructTypes.StructType(::Type{CRS}) = StructTypes.Struct()

StructTypes.omitempties(::Type{<:GeoJSONT}) = (:id, :crs, :bbox,)
