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
    Point{D}(coordinates::Union{Nothing,NTuple{D,Float32}})

A Point geometry with `D` dimensions.
"""
Base.@kwdef struct Point{D} <: AbstractGeometry{D}
    bbox::Union{Nothing,Vector{Float32}} = nothing
    coordinates::Union{Nothing,NTuple{D,Float32}} = nothing
end
Base.show(io::IO, ::Point{D}) where {D} = print(io, "$(D)D Point")
Base.eltype(::Type{Point}) = Float32

"""
    LineString{D}(coordinates::Union{Nothing,Vector{NTuple{D,Float32}}})

A LineString geometry with `D` dimensions.
"""
Base.@kwdef struct LineString{D} <: AbstractGeometry{D}
    bbox::Union{Nothing,Vector{Float32}} = nothing
    coordinates::Union{Nothing,Vector{NTuple{D,Float32}}} = nothing
end
Base.eltype(::Type{LineString{D}}) where {D} = NTuple{D,Float32}

"""
    Polygon{D}(coordinates::Union{Nothing,Vector{Vector{NTuple{D,Float32}}}})

A Polygon geometry with `D` dimensions.
"""
Base.@kwdef struct Polygon{D} <: AbstractGeometry{D}
    bbox::Union{Nothing,Vector{Float32}} = nothing
    coordinates::Union{Nothing,Vector{Vector{NTuple{D,Float32}}}} = nothing
end
Base.eltype(::Type{Polygon{D}}) where {D} = Vector{NTuple{D,Float32}}

"""
    MultiPoint{D}(coordinates::Union{Nothing,Vector{NTuple{D,Float32}}})

A MultiPoint geometry with `D` dimensions.
"""
Base.@kwdef struct MultiPoint{D} <: AbstractGeometry{D}
    bbox::Union{Nothing,Vector{Float32}} = nothing
    coordinates::Union{Nothing,Vector{NTuple{D,Float32}}} = nothing
end
Base.eltype(::Type{MultiPoint{D}}) where {D} = Vector{NTuple{D,Float32}}

"""
    MultiLineString{D}(coordinates::Union{Nothing,Vector{Vector{NTuple{D,Float32}}}})

A MultiLineString geometry with `D` dimensions.
"""
Base.@kwdef struct MultiLineString{D} <: AbstractGeometry{D}
    bbox::Union{Nothing,Vector{Float32}} = nothing
    coordinates::Union{Nothing,Vector{Vector{NTuple{D,Float32}}}} = nothing
end
Base.eltype(::Type{MultiLineString{D}}) where {D} = Vector{NTuple{D,Float32}}

"""
    MultiPolygon{D}(coordinates::Union{Nothing,Vector{Vector{Vector{NTuple{D,Float32}}}}})

A MultiPolygon geometry with `D` dimensions.
"""
Base.@kwdef struct MultiPolygon{D} <: AbstractGeometry{D}
    bbox::Union{Nothing,Vector{Float32}} = nothing
    coordinates::Union{Nothing,Vector{Vector{Vector{NTuple{D,Float32}}}}} = nothing
end
Base.eltype(::Type{MultiPolygon{D}}) where {D} = Vector{Vector{NTuple{D,Float32}}}
coordinates(g::AbstractGeometry) = getfield(g, :coordinates)

Base.show(io::IO, x::T) where {D,T<:AbstractGeometry{D}} = print(io, "$(D)D $(typestring(T)) $(get(io, :compact, false) ? "" : "with $(length(x.coordinates)) sub-geometries")")
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
    GeometryCollection{D}(geometries::Vector{AbstractGeometry{D}})

A GeometryCollection geometry with `D` dimensions.
"""
Base.@kwdef struct GeometryCollection{D} <: AbstractGeometry{D}
    bbox::Union{Nothing,Vector{Float32}} = nothing
    geometries::Vector{AbstractGeometry{D}} = AbstractGeometry{D}[]  # not that efficient
end

coordinates(g::GeometryCollection) = coordinates.(geometry(g))
geometry(g::GeometryCollection) = getfield(g, :geometries)

Base.show(io::IO, x::GeometryCollection{D}) where {D} = print(io, "GeometryCollection with $(length(x.geometries)) $(D)D geometries")
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
    Feature{D}(id::Union{String,Nothing}, bbox::Union{Nothing,Vector{Float32}}, geometry::Union{Nothing,AbstractGeometry{D}}, properties::Union{Nothing,Dict{String,Any}})

A Feature with `D` dimensional geometry.
"""
Base.@kwdef struct Feature{D} <: GeoJSONT{D}
    id::Union{Nothing,String,Int} = nothing
    bbox::Union{Nothing,Vector{Float32}} = nothing
    geometry::Union{Nothing,AbstractGeometry{D}} = nothing
    properties::Dict{Symbol,Any} = Dict{Symbol,Any}()
end
id(f::Feature) = getfield(f, :id)
geometry(f::Feature) = getfield(f, :geometry)
properties(f::Feature) = getfield(f, :properties)
coordinates(f::Feature) = coordinates(geometry(f))
Base.show(io::IO, x::Feature{D}) where {D} = print(io, "Feature with $(D)D $(typestring(typeof(geometry(x)))) geometry and $(length(properties(x))+1) properties: $(propertynames(x))")
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
struct LazyFeature{D} <: GeoJSONT{D}
    bytes::Any
    pos::Int
    len::Int
end
@inline StructTypes.construct(::Type{LazyFeature{D}}, x::JSON3.RawValue) where {D} = LazyFeature{D}(x.bytes, x.pos, x.len)
@inline Base.codeunits(x::LazyFeature) = unsafe_string(pointer(x.bytes, x.pos), x.len)
@inline JSON3.rawbytes(x::LazyFeature) = codeunits(x)


"""
    FeatureCollection{D}(bbox::Union{Nothing,Vector{Float32}}, features::Vector{Feature{D}}, crs::Union{Nothing,CRS})

A FeatureCollection with `D` dimensional geometry in its features.
"""
Base.@kwdef struct FeatureCollection{D} <: AbstractFeatureCollection{D}
    bbox::Union{Nothing,Vector{Float32}} = nothing
    features::Vector{Feature{D}} = Feature{D}[]
    crs::Union{Nothing,CRS} = nothing
    names::Vector{Symbol}
    types::Dict{Symbol,Type}
    function FeatureCollection{D}(bbox, features, crs, n, t) where {D}
        names, types = property_schema(isnothing(features) ? Feature{D}[] : features)
        return new{D}(bbox, features, crs, names, types)
    end
end
function FeatureCollection(; bbox=nothing, features::Vector{Feature{D}}, crs=nothing) where {D}
    names, types = property_schema(isnothing(features) ? Feature{D}[] : features)
    FeatureCollection{D}(bbox, features, crs, names, types)
end


features(fc::FeatureCollection) = getfield(fc, :features)
Base.propertynames(fc::FeatureCollection) = getfield(fc, :names)
Base.getproperty(fc::FeatureCollection, nm::Symbol) = getproperty.(fc, nm)

function Base.getproperty(fc::FeatureCollection, name::Symbol)
    if hasfield(typeof(fc), name)
        getfield(fc, name)
    else
        getproperty.(fc, name)
    end
end

function Base.iterate(fc::AbstractFeatureCollection{D}, state=1) where {D}
    (1 <= state <= length(fc)) || return nothing
    val = fc[state]::Feature{D}
    return val, state + 1
end

Base.show(io::IO, fc::FeatureCollection) = print(io, "FeatureCollection with $(length(fc)) Features")
Base.eltype(::Type{<:AbstractFeatureCollection{D}}) where {D} = Feature{D}
Base.IteratorEltype(::Type{<:AbstractFeatureCollection}) = Base.HasEltype()
Base.length(fc::AbstractFeatureCollection) = length(features(fc))
Base.lastindex(fc::AbstractFeatureCollection) = length(features(fc))
Base.IteratorSize(::Type{<:AbstractFeatureCollection}) = Base.HasLength()
Base.size(fc::AbstractFeatureCollection) = size(features(fc))
Base.getindex(fc::AbstractFeatureCollection, i::Int) = features(fc)[i]
Base.IndexStyle(::AbstractFeatureCollection) = IndexLinear()

bbox(x::GeoJSONT) = getfield(x, :bbox)

"""
    LazyFeatureCollection{D}(bbox::Union{Nothing,Vector{Float32}}, features::Vector{LazyFeature{D}}, crs::Union{Nothing,String})

A FeatureCollection with `D` dimensional geometry in its features, but it's features are
lazily parsed from the GeoJSON string. Indexing into the collection will parse the feature.
This can be more efficient when interested in only a few features from a large collection,
or parsing a very large collection iteratively without loading it all into memory.
"""
struct LazyFeatureCollection{D} <: AbstractFeatureCollection{D}
    bbox::Union{Nothing,Vector{Float32}}
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
@inline StructTypes.StructType(::Type{<:GeoJSONWrapper}) = StructTypes.CustomStruct()
@inline StructTypes.lower(x::GeoJSONWrapper) = x.obj
@inline StructTypes.lowertype(::Type{<:GeoJSONWrapper{D}}) where {D} = GeoJSONT{D}

const point = "Point"
@inline typestring(::Type{<:Point}) = point
const multipoint = "MultiPoint"
@inline typestring(::Type{<:MultiPoint}) = multipoint
const linestring = "LineString"
@inline typestring(::Type{<:LineString}) = linestring
const multilinestring = "MultiLineString"
@inline typestring(::Type{<:MultiLineString}) = multilinestring
const polygon = "Polygon"
@inline typestring(::Type{<:Polygon}) = polygon
const multipolygon = "MultiPolygon"
@inline typestring(::Type{<:MultiPolygon}) = multipolygon
const geometrycollection = "GeometryCollection"
@inline typestring(::Type{<:GeometryCollection}) = geometrycollection
const feature = "Feature"
@inline typestring(::Type{<:Feature}) = feature
const featurecollection = "FeatureCollection"
@inline typestring(::Type{<:FeatureCollection}) = featurecollection
const null = "null"
@inline typestring(::Type{Nothing}) = null
@inline typestring(::Type{Missing}) = null

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
@inline StructTypes.subtypes(::Type{<:AbstractGeometry{D}}) where {D} = geom_mapping(D)
@inline StructTypes.subtypekey(::Type{<:GeoJSONT}) = :type
@inline StructTypes.subtypes(::Type{<:GeoJSONT{D}}) where {D} = merge(geom_mapping(D), obj_mapping(D))

@inline StructTypes.StructType(::Type{<:Feature}) = StructTypes.Struct()
@inline StructTypes.StructType(::Type{<:LazyFeature}) = JSON3.RawType()
@inline StructTypes.StructType(::Type{<:FeatureCollection}) = StructTypes.Struct()
@inline StructTypes.excludes(::Type{<:FeatureCollection}) = (:names, :types,)
@inline StructTypes.StructType(::Type{<:LazyFeatureCollection}) = StructTypes.Struct()
@inline StructTypes.StructType(::Type{CRS}) = StructTypes.Struct()

@inline StructTypes.omitempties(::Type{<:GeoJSONT}) = (:id, :crs, :bbox,)
