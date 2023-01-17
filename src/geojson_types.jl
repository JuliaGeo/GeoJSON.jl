abstract type GeoJSONT{D} end
abstract type AbstractGeometry{D} <: GeoJSONT{D} end
abstract type AbstractFeatureCollection{D} <: GeoJSONT{D} end

struct Point{D} <: AbstractGeometry{D}
    type::String
    coordinates::Union{Nothing,NTuple{D,Float64}}
end
Base.show(io::IO, ::Point{D}) where {D} = print(io, "$(D)D Point")
Base.eltype(::Type{Point}) = Float64

struct LineString{D} <: AbstractGeometry{D}
    type::String
    coordinates::Union{Nothing,Vector{NTuple{D,Float64}}}
end
Base.eltype(::Type{LineString{D}}) where {D} = NTuple{D,Float64}

struct Polygon{D} <: AbstractGeometry{D}
    type::String
    coordinates::Union{Nothing,Vector{Vector{NTuple{D,Float64}}}}
end
Base.eltype(::Type{Polygon{D}}) where {D} = Vector{NTuple{D,Float64}}

struct MultiPoint{D} <: AbstractGeometry{D}
    type::String
    coordinates::Union{Nothing,Vector{NTuple{D,Float64}}}
end
Base.eltype(::Type{MultiPoint{D}}) where {D} = Vector{NTuple{D,Float64}}

struct MultiLineString{D} <: AbstractGeometry{D}
    type::String
    coordinates::Union{Nothing,Vector{Vector{NTuple{D,Float64}}}}
end
Base.eltype(::Type{MultiLineString{D}}) where {D} = Vector{NTuple{D,Float64}}

struct MultiPolygon{D} <: AbstractGeometry{D}
    type::String
    coordinates::Union{Nothing,Vector{Vector{Vector{NTuple{D,Float64}}}}}
end
Base.eltype(::Type{MultiPolygon{D}}) where {D} = Vector{Vector{NTuple{D,Float64}}}

coordinates(g::AbstractGeometry) = g.coordinates
bbox(g::AbstractGeometry) = nothing

Base.show(io::IO, x::AbstractGeometry{D}) where {D} = print(io, "$(D)D $(x.type) with $(length(x.coordinates)) sub-geometries")
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

struct GeometryCollection{D} <: AbstractGeometry{D}
    type::String
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

@computed mutable struct Feature{D} <: GeoJSONT{D}
    type::String
    bbox::Union{Nothing,NTuple{D * 2,Float64}}
    geometry::Union{Nothing,AbstractGeometry{D}}
    properties::Union{Nothing,Dict{String,Any}}
    Feature{D}() where {D} = new()
end
bbox(f::Feature) = f.bbox
geometry(f::Feature) = f.geometry
properties(f::Feature) = f.properties
coordinates(f::Feature) = coordinates(geometry(f))
Base.show(io::IO, x::Feature{D}) where {D} = print(io, "Feature with $(D)D $(x.geometry.type) geometry and $(length(x.properties)) properties")

struct LazyFeature{D} <: GeoJSONT{D}
    bytes::Any
    pos::Int
    len::Int
end
StructTypes.construct(::Type{LazyFeature{D}}, x::JSON3.RawValue) where {D} = LazyFeature{D}(x.bytes, x.pos, x.len)
Base.codeunits(x::LazyFeature) = unsafe_string(pointer(x.bytes, x.pos), x.len)
JSON3.rawbytes(x::LazyFeature) = codeunits(x)

@computed mutable struct FeatureCollection{D} <: AbstractFeatureCollection{D}
    type::String
    bbox::Union{Nothing,NTuple{D * 2,Float64}}
    features::Vector{Feature{D}}
    FeatureCollection{D}() where {D} = new()
end
# FeatureCollection{D}() where {D} = FeatureCollection{D}("FeatureCollection", nothing, Feature{D}[])
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

@computed mutable struct LazyFeatureCollection{D} <: AbstractFeatureCollection{D}
    type::String
    bbox::Union{Nothing,NTuple{D * 2,Float64}}
    features::Vector{LazyFeature{D}}
    # TODO Use features::JSON3.Array directly once we can parse the tape to find the
    # feature offsets in the buffer?
    LazyFeatureCollection{D}() where {D} = new()
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

StructTypes.StructType(::Type{<:Feature}) = StructTypes.Mutable()
StructTypes.omitempties(::Type{<:Feature}) = (:bbox,)
StructTypes.StructType(::Type{<:LazyFeature}) = JSON3.RawType()
StructTypes.StructType(::Type{<:FeatureCollection}) = StructTypes.Mutable()
StructTypes.StructType(::Type{<:LazyFeatureCollection}) = StructTypes.Mutable()
StructTypes.omitempties(::Type{<:AbstractFeatureCollection}) = (:bbox,)
