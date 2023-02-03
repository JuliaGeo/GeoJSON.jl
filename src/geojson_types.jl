abstract type GeoJSONT{D,T} end
abstract type AbstractGeometry{D,T} <: GeoJSONT{D,T} end
abstract type AbstractFeatureCollection{D,T} <: GeoJSONT{D,T} end

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
    Point{D,T}(coordinates::Union{Nothing,NTuple{D,T}})

A Point geometry with `D` dimensions.
"""
struct Point{D,T} <: AbstractGeometry{D,T}
    bbox::Union{Nothing,Vector{T}}
    coordinates::Union{Nothing,NTuple{D,T}}
    Point{D,T}(bbox, coordinates) where {D,T} = new{D,T}(bbox, coordinates)
    Point{D,T}(; bbox=nothing, coordinates=nothing) where {D,T} = Point{D,T}(bbox, coordinates)
end
Point(; bbox=nothing, coordinates::NTuple{2,T}) where {T} = Point{2,T}(bbox, coordinates)
Base.show(io::IO, ::Point{D,T}) where {D,T} = print(io, "$(D)D Point")
Base.eltype(::Type{Point{D,T}}) where {D,T} = T

"""
    LineString{D,T}(coordinates::Union{Nothing,Vector{NTuple{D,T}}})

A LineString geometry with `D` dimensions.
"""
struct LineString{D,T} <: AbstractGeometry{D,T}
    bbox::Union{Nothing,Vector{T}}
    coordinates::Union{Nothing,Vector{NTuple{D,T}}}
    LineString{D,T}(bbox, coordinates) where {D,T} = new{D,T}(bbox, coordinates)
    LineString{D,T}(; bbox=nothing, coordinates=nothing) where {D,T} = LineString{D,T}(bbox, coordinates)
end
LineString(; bbox=nothing, coordinates::Vector{NTuple{2,T}}) where {T} = LineString{2,T}(D, T, bbox, coordinates)
Base.eltype(::Type{LineString{D,T}}) where {D,T} = NTuple{D,T}

"""
    Polygon{D,T}(coordinates::Union{Nothing,Vector{Vector{NTuple{D,T}}}})

A Polygon geometry with `D` dimensions.
"""
struct Polygon{D,T} <: AbstractGeometry{D,T}
    bbox::Union{Nothing,Vector{T}}
    coordinates::Union{Nothing,Vector{Vector{NTuple{D,T}}}}
    Polygon{D,T}(bbox, coordinates) where {D,T} = new{D,T}(bbox, coordinates)
    Polygon{D,T}(; bbox=nothing, coordinates=nothing) where {D,T} = Polygon{D,T}(bbox, coordinates)
end
Polygon(; bbox=nothing, coordinates::Vector{Vector{NTuple{2,T}}}) where {T} = Polygon{2,T}(bbox, coordinates)
Base.eltype(::Type{Polygon{D,T}}) where {D,T} = Vector{NTuple{D,T}}

"""
    MultiPoint{D,T}(coordinates::Union{Nothing,Vector{NTuple{D,T}}})

A MultiPoint geometry with `D` dimensions.
"""
struct MultiPoint{D,T} <: AbstractGeometry{D,T}
    bbox::Union{Nothing,Vector{T}}
    coordinates::Union{Nothing,Vector{NTuple{D,T}}}
    MultiPoint{D,T}(bbox, coordinates) where {D,T} = new{D,T}(bbox, coordinates)
    MultiPoint{D,T}(; bbox=nothing, coordinates=nothing) where {D,T} = MultiPoint{D,T}(bbox, coordinates)
end
MultiPoint(; bbox=nothing, coordinates::Vector{NTuple{2,T}}) where {T} = MultiPoint{2,T}(bbox, coordinates)
Base.eltype(::Type{MultiPoint{D,T}}) where {D,T} = Vector{NTuple{D,T}}

"""
    MultiLineString{D,T}(coordinates::Union{Nothing,Vector{Vector{NTuple{D,T}}}})

A MultiLineString geometry with `D` dimensions.
"""
struct MultiLineString{D,T} <: AbstractGeometry{D,T}
    bbox::Union{Nothing,Vector{T}}
    coordinates::Union{Nothing,Vector{Vector{NTuple{D,T}}}}
    MultiLineString{D,T}(bbox, coordinates) where {D,T} = new{D,T}(bbox, coordinates)
    MultiLineString{D,T}(; bbox=nothing, coordinates=nothing) where {D,T} = MultiLineString{D,T}(bbox, coordinates)
end
MultiLineString(; bbox=nothing, coordinates::Vector{Vector{NTuple{2,T}}}) where {T} = MultiLineString{2,T}(bbox, coordinates)
Base.eltype(::Type{MultiLineString{D,T}}) where {D,T} = Vector{NTuple{D,T}}

"""
    MultiPolygon{D,T}(coordinates::Union{Nothing,Vector{Vector{Vector{NTuple{D,T}}}}})

A MultiPolygon geometry with `D` dimensions.
"""
struct MultiPolygon{D,T} <: AbstractGeometry{D,T}
    bbox::Union{Nothing,Vector{T}}
    coordinates::Union{Nothing,Vector{Vector{Vector{NTuple{D,T}}}}}
    MultiPolygon{D,T}(bbox, coordinates) where {D,T} = new{D,T}(bbox, coordinates)
    MultiPolygon{D,T}(; bbox=nothing, coordinates=nothing) where {D,T} = MultiPolygon{D,T}(bbox, coordinates)
end
MultiPolygon(; bbox=nothing, coordinates::Vector{Vector{Vector{NTuple{2,T}}}}) where {T} = MultiPolygon{2,T}(bbox, coordinates)
Base.eltype(::Type{MultiPolygon{D,T}}) where {D,T} = Vector{Vector{NTuple{D,T}}}
coordinates(g::AbstractGeometry) = getfield(g, :coordinates)

Base.show(io::IO, G::AbstractGeometry{D,T}) where {D,T} = print(io, "$(D)D $(typestring(typeof(G))) $(get(io, :compact, false) ? "" : "with $(length(G.coordinates)) sub-geometries")")
Base.length(g::AbstractGeometry) = length(coordinates(g))
Base.lastindex(g::AbstractGeometry) = length(coordinates(g))
Base.size(g::AbstractGeometry) = size(coordinates(g))
Base.axes(g::AbstractGeometry) = axes(coordinates(g))
Base.getindex(g::AbstractGeometry, i::Int) = getindex(coordinates(g), i::Int)
Base.IndexStyle(::Type{<:AbstractGeometry}) = Base.IndexLinear()

Base.:(==)(g1::AbstractGeometry, g2::AbstractGeometry) = coordinates(g1) == coordinates(g2)

function Base.iterate(g::AbstractGeometry, state=1)
    x = iterate(coordinates(g), state)
    x === nothing && return nothing
    val, state = x
    return val, state
end

"""
    GeometryCollection{D,T}(geometries::Vector{AbstractGeometry{D,T}})

A GeometryCollection geometry with `D` dimensions.
"""
struct GeometryCollection{D,T} <: AbstractGeometry{D,T}
    bbox::Union{Nothing,Vector{T}}
    geometries::Vector{AbstractGeometry{D,T}}   # not that efficient
    GeometryCollection{D,T}(bbox, geometries) where {D,T} = new{D,T}(bbox, geometries)
    GeometryCollection{D,T}(; bbox=nothing, geometries=AbstractGeometry{D,T}[]) where {D,T} = GeometryCollection{D,T}(bbox, geometries)
end
GeometryCollection(; bbox=nothing, geometries::Vector{<:AbstractGeometry{D,T}}) where {D,T} = GeometryCollection{D,T}(bbox, geometries)

coordinates(g::GeometryCollection) = coordinates.(geometry(g))
geometry(g::GeometryCollection) = getfield(g, :geometries)

Base.show(io::IO, x::GeometryCollection{D,T}) where {D,T} = print(io, "GeometryCollection with $(length(x.geometries)) $(D)D geometries")
Base.length(g::GeometryCollection) = length(geometry(g))
Base.lastindex(g::GeometryCollection) = length(geometry(g))
Base.size(g::GeometryCollection) = size(geometry(g))
Base.axes(g::GeometryCollection) = axes(geometry(g))
Base.getindex(g::GeometryCollection, i::Int) = getindex(geometry(g), i::Int)
Base.IndexStyle(::Type{<:GeometryCollection}) = Base.IndexLinear()

function Base.iterate(g::GeometryCollection, state=1)
    x = iterate(geometries(g), state)
    x === nothing && return nothing
    val, state = x
    return val, state
end

"""
    Feature{D,T}(id::Union{String,Nothing}, bbox::Union{Nothing,Vector{T}}, geometry::Union{Nothing,AbstractGeometry{D,T}}, properties::Union{Nothing,Dict{String,Any}})

A Feature with `D` dimensional geometry.
"""
struct Feature{D,T} <: GeoJSONT{D,T}
    id::Union{Nothing,String,Int}
    bbox::Union{Nothing,Vector{T}}
    geometry::Union{Nothing,AbstractGeometry{D,T}}
    properties::NamedTuple
    Feature{D,T}(id, bbox, geometry, properties) where {D,T} = new{D,T}(id, bbox, geometry, properties)
    Feature{D,T}(; id=nothing, bbox=nothing, geometry=nothing, properties=NamedTuple()) where {D,T} = Feature{D,T}(id, bbox, geometry, properties)
end
Feature(; id=nothing, bbox=nothing, geometry::AbstractGeometry{D,T}, properties=NamedTuple()) where {D,T} = Feature{D,T}(id, bbox, geometry, properties)

id(f::Feature) = getfield(f, :id)
geometry(f::Feature) = getfield(f, :geometry)
properties(f::Feature) = getfield(f, :properties)
coordinates(f::Feature) = coordinates(geometry(f))
Base.show(io::IO, x::Feature{D,T}) where {D,T} = print(io, "Feature with $(D)D $(typestring(typeof(geometry(x)))) geometry and $(length(properties(x))+1) properties: $(propertynames(x))")
Base.:(==)(f1::Feature, f2::Feature) = id(f1) == id(f2) && bbox(f1) == bbox(f2) && geometry(f1) == geometry(f2) && properties(f1) == properties(f2)

# the keys in properties are added here for direct access
function Base.propertynames(f::Feature)
    (:geometry, filter(!=(:geometry), keys(properties(f)))...)
end

function Base.getproperty(f::Feature, name::Symbol)
    props = properties(f)
    v = if haskey(props, name)
        get(props, name, missing)
    elseif hasfield(typeof(f), name)
        getfield(f, name)
    else
        missing  # when called from a collection with some features having the property and some not
    end
    isnothing(v) ? missing : v
end

function Base.iterate(f::Feature, state=collect(propertynames(f)))
    isempty(state) && return nothing
    k = pop!(state)
    ((k, getproperty(f, k)), state)
end


# This is a non-public type used to lazily construct a Feature from a JSON3.RawValue
# It can be written again as String, which can also be used to parsed to a Feature
struct LazyFeature{D,T} <: GeoJSONT{D,T}
    bytes::Any
    pos::Int
    len::Int
end
@inline StructTypes.construct(::Type{LazyFeature{D,T}}, x::JSON3.RawValue) where {D,T} = LazyFeature{D,T}(x.bytes, x.pos, x.len)
@inline Base.codeunits(x::LazyFeature) = unsafe_string(pointer(x.bytes, x.pos), x.len)
@inline JSON3.rawbytes(x::LazyFeature) = codeunits(x)


"""
    FeatureCollection{D,T}(bbox::Union{Nothing,Vector{T}}, features::Vector{Feature{D,T}}, crs::Union{Nothing,CRS})

A FeatureCollection with `D` dimensional geometry in its features.
"""
struct FeatureCollection{D,T} <: AbstractFeatureCollection{D,T}
    bbox::Union{Nothing,Vector{T}}
    features::Vector{Feature{D,T}}
    crs::Union{Nothing,CRS}
    names::Vector{Symbol}
    types::Dict{Symbol,Type}
    function FeatureCollection{D,T}(bbox, features, crs, n=nothing, t=nothing) where {D,T}  # n, t = nothing required for StructTypes
        names, types = property_schema(features)
        return new{D,T}(bbox, features, crs, names, types)
    end
    FeatureCollection{D,T}(; bbox=nothing, features=Feature{D,T}[], crs=nothing) where {D,T} = FeatureCollection{D,T}(bbox, features, crs)
end
function FeatureCollection(; bbox=nothing, features::Vector{Feature{D,T}}, crs=nothing) where {D,T}
    FeatureCollection{D,T}(bbox, features, crs)
end


features(fc::FeatureCollection) = getfield(fc, :features)
Base.propertynames(fc::FeatureCollection) = getfield(fc, :names)

function Base.getproperty(fc::FeatureCollection, name::Symbol)
    if hasfield(typeof(fc), name)
        getfield(fc, name)
    else
        getproperty.(fc, name)
    end
end

function Base.iterate(fc::AbstractFeatureCollection{D,T}, state=1) where {D,T}
    (1 <= state <= length(fc)) || return nothing
    val = fc[state]::Feature{D,T}
    return val, state + 1
end

Base.show(io::IO, fc::FeatureCollection) = print(io, "FeatureCollection with $(length(fc)) Features")
Base.eltype(::Type{<:AbstractFeatureCollection{D,T}}) where {D,T} = Feature{D,T}
Base.IteratorEltype(::Type{<:AbstractFeatureCollection}) = Base.HasEltype()
Base.length(fc::AbstractFeatureCollection) = length(features(fc))
Base.lastindex(fc::AbstractFeatureCollection) = length(features(fc))
Base.IteratorSize(::Type{<:AbstractFeatureCollection}) = Base.HasLength()
Base.size(fc::AbstractFeatureCollection) = size(features(fc))
Base.getindex(fc::AbstractFeatureCollection, i::Int) = features(fc)[i]
Base.IndexStyle(::AbstractFeatureCollection) = IndexLinear()

bbox(x::GeoJSONT) = getfield(x, :bbox)

"""
    LazyFeatureCollection{D,T}(bbox::Union{Nothing,Vector{T}}, features::Vector{LazyFeature{D,T}}, crs::Union{Nothing,String})

A FeatureCollection with `D` dimensional geometry in its features, but it's features are
lazily parsed from the GeoJSON string. Indexing into the collection will parse the feature.
This can be more efficient when interested in only a few features from a large collection,
or parsing a very large collection iteratively without loading it all into memory.
"""
struct LazyFeatureCollection{D,T} <: AbstractFeatureCollection{D,T}
    bbox::Union{Nothing,Vector{T}}
    features::Vector{LazyFeature{D,T}}
    crs::Union{Nothing,CRS}
    # TODO Use features::JSON3.Array directly once we can parse the tape to find the
    # feature offsets in the buffer?
end
features(fc::LazyFeatureCollection) = collect(fc.features)

Base.show(io::IO, x::LazyFeatureCollection) = print(io, "LazyFeatureCollection with $(length(x.features)) features")
Base.getindex(x::LazyFeatureCollection{D,T}, i::Int) where {D,T} = JSON3.read(codeunits(x.features[i]), Feature{D,T})::Feature{D,T}

struct GeoJSONWrapper{D,T,X<:GeoJSONT{D,T}}
    obj::X
end
GeoJSONWrapper{D,T}(obj::X) where {D,T,X<:GeoJSONT{D,T}} = GeoJSONWrapper{D,T,X}(obj)

# symbol (from json string type) to struct mapping
@inline function geom_mapping(D, T)
    (;
        Point=Point{D,T},
        MultiPoint=MultiPoint{D,T},
        LineString=LineString{D,T},
        MultiLineString=MultiLineString{D,T},
        Polygon=Polygon{D,T},
        MultiPolygon=MultiPolygon{D,T},
        GeometryCollection=GeometryCollection{D,T}
    )
end
@inline function obj_mapping(D, T)
    (;
        Feature=Feature{D,T},
        FeatureCollection=FeatureCollection{D,T}
    )
end
@inline StructTypes.StructType(::Type{<:GeoJSONWrapper}) = StructTypes.CustomStruct()
@inline StructTypes.lower(x::GeoJSONWrapper) = x.obj
@inline StructTypes.lowertype(::Type{<:GeoJSONWrapper{D,T}}) where {D,T} = GeoJSONT{D,T}

typestring(::Type{<:Point}) = "Point"
typestring(::Type{<:MultiPoint}) = "MultiPoint"
typestring(::Type{<:LineString}) = "LineString"
typestring(::Type{<:MultiLineString}) = "MultiLineString"
typestring(::Type{<:Polygon}) = "Polygon"
typestring(::Type{<:MultiPolygon}) = "MultiPolygon"
typestring(::Type{<:GeometryCollection}) = "GeometryCollection"
typestring(::Type{<:Feature}) = "Feature"
typestring(::Type{<:FeatureCollection}) = "FeatureCollection"
typestring(::Type{Nothing}) = "null"
typestring(::Type{Missing}) = "null"

@inline StructTypes.StructType(::Type{<:GeoJSONT}) = StructTypes.AbstractType()
@inline StructTypes.StructType(::Type{<:AbstractGeometry}) = StructTypes.AbstractType()
@inline StructTypes.StructType(::Type{<:Point}) = StructTypes.Struct()
@inline StructTypes.StructType(::Type{<:LineString}) = StructTypes.Struct()
@inline StructTypes.StructType(::Type{<:Polygon}) = StructTypes.Struct()
@inline StructTypes.StructType(::Type{<:MultiPoint}) = StructTypes.Struct()
@inline StructTypes.StructType(::Type{<:MultiLineString}) = StructTypes.Struct()
@inline StructTypes.StructType(::Type{<:MultiPolygon}) = StructTypes.Struct()
@inline StructTypes.StructType(::Type{<:GeometryCollection}) = StructTypes.Struct()
@inline StructTypes.subtypekey(::Type{<:AbstractGeometry}) = :type
@inline StructTypes.subtypes(::Type{<:AbstractGeometry{D,T}}) where {D,T} = geom_mapping(D, T)
@inline StructTypes.subtypekey(::Type{<:GeoJSONT}) = :type
@inline StructTypes.subtypes(::Type{<:GeoJSONT{D,T}}) where {D,T} = merge(geom_mapping(D, T), obj_mapping(D, T))

@inline StructTypes.StructType(::Type{<:Feature}) = StructTypes.Struct()
@inline StructTypes.StructType(::Type{<:LazyFeature}) = JSON3.RawType()
@inline StructTypes.StructType(::Type{<:FeatureCollection}) = StructTypes.Struct()
@inline StructTypes.excludes(::Type{<:FeatureCollection}) = (:names, :types,)
@inline StructTypes.StructType(::Type{<:LazyFeatureCollection}) = StructTypes.Struct()
@inline StructTypes.StructType(::Type{CRS}) = StructTypes.Struct()

@inline StructTypes.omitempties(::Type{<:GeoJSONT}) = (:id, :crs, :bbox,)
