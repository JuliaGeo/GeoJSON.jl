abstract type GeoJSONT{D,T} end
abstract type AbstractGeometry{D,T} <: GeoJSONT{D,T} end
abstract type AbstractFeatureCollection{D,T} <: GeoJSONT{D,T} end

const Dims = (2, 3, 4)
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
LineString(; bbox=nothing, coordinates::Vector{NTuple{2,T}}) where {T} = LineString{2,T}(bbox, coordinates)
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

function Base.show(io::IO, G::AbstractGeometry{D,T}) where {D,T}
    print(io, D, "D ", typestring(typeof(G)))
    if !get(io, :compact, false)
        print(io, "with ", length(G.coordinates), " sub-geometries")
    end
end

Base.length(g::AbstractGeometry) = length(coordinates(g))
Base.lastindex(g::AbstractGeometry) = length(coordinates(g))
Base.size(g::AbstractGeometry) = size(coordinates(g))
Base.axes(g::AbstractGeometry) = axes(coordinates(g))
Base.getindex(g::AbstractGeometry, i::Int) = getindex(coordinates(g), i::Int)
Base.IndexStyle(::Type{<:AbstractGeometry}) = Base.IndexLinear()

function Base.:(==)(g1::AbstractGeometry, g2::AbstractGeometry)
    (typeof(g1) === typeof(g2)) && (coordinates(g1) == coordinates(g2))
end

function Base.iterate(g::AbstractGeometry, state=1)
    x = iterate(coordinates(g), state)
    x === nothing && return nothing
    val, state = x
    return val, state
end

"""
    GeometryCollection{D,T}(geometries::Vector{Geometry{D,T}})

A GeometryCollection geometry with `D` dimensions.
"""
struct GeometryCollection{D,T} <: AbstractGeometry{D,T}
    bbox::Union{Nothing,Vector{T}}
    geometries::Vector{Union{Point{D,T},MultiPoint{D,T},LineString{D,T},
                             MultiLineString{D,T},Polygon{D,T},MultiPolygon{D,T},
                             GeometryCollection{D,T}}}
    GeometryCollection{D,T}(bbox, geometries) where {D,T} = new{D,T}(bbox, geometries)
    GeometryCollection{D,T}(; bbox=nothing, geometries=Geometry{D,T}[]) where {D,T} = GeometryCollection{D,T}(bbox, geometries)
end
"""
    Geometry{D,T}

The seven GeoJSON geometry kinds for dimension `D` and coordinate type `T`.
"""
const Geometry{D,T} = Union{Point{D,T},MultiPoint{D,T},LineString{D,T},
                            MultiLineString{D,T},Polygon{D,T},MultiPolygon{D,T},
                            GeometryCollection{D,T}}

GeometryCollection(; bbox=nothing, geometries::Vector{<:AbstractGeometry{D,T}}) where {D,T} = GeometryCollection{D,T}(bbox, geometries)

coordinates(g::GeometryCollection) = coordinates.(geometry(g))
geometry(g::GeometryCollection) = getfield(g, :geometries)

Base.show(io::IO, x::GeometryCollection{D,T}) where {D,T} = print(io, "GeometryCollection with $(length(x.geometries)) $(D)D geometries")
Base.eltype(::Type{GeometryCollection{D,T}}) where {D,T} = Geometry{D,T}
Base.length(g::GeometryCollection) = length(geometry(g))
Base.lastindex(g::GeometryCollection) = length(geometry(g))
Base.size(g::GeometryCollection) = size(geometry(g))
Base.axes(g::GeometryCollection) = axes(geometry(g))
Base.getindex(g::GeometryCollection, i::Int) = getindex(geometry(g), i::Int)
Base.IndexStyle(::Type{<:GeometryCollection}) = Base.IndexLinear()

function Base.iterate(g::GeometryCollection, state=1)
    x = iterate(geometry(g), state)
    x === nothing && return nothing
    val, state = x
    return val, state
end

"""
    Feature{D,T}(id::Union{String,Nothing}, bbox::Union{Nothing,Vector{T}}, geometry::Union{Nothing,Geometry{D,T}}, properties::Union{Nothing,Dict{Symbol,Any}})

A Feature with `D` dimensional geometry.
"""
struct Feature{D,T,P} <: GeoJSONT{D,T}
    id::Any
    bbox::Union{Nothing,Vector{T}}
    geometry::Union{Nothing,Geometry{D,T}}
    properties::P
    Feature{D,T,P}(id, bbox, geometry, properties) where {D,T,P} =
        new{D,T,P}(id, bbox, geometry, properties)
end
Feature(id, bbox, geometry::Geometry{D,T}, properties::P) where {D,T,P} =
    Feature{D,T,P}(id, bbox, geometry, properties)
const DefaultProperties = Union{Nothing,Dict{Symbol,Any}}
Feature{D,T}(id, bbox, geometry, properties) where {D,T} =
    Feature{D,T,DefaultProperties}(id, bbox, geometry, properties)
Feature{D,T}(; id=nothing, bbox=nothing, geometry=nothing, properties=NamedTuple()) where {D,T} =
    Feature{D,T}(id, bbox, geometry, properties)
Feature(; id=nothing, bbox=nothing, geometry::AbstractGeometry{D,T}, properties=NamedTuple()) where {D,T} = Feature{D,T}(id, bbox, geometry, properties)

Base.convert(::Type{F}, f::F) where {F<:Feature} = f
Base.convert(::Type{Feature{D,T,P}}, f::Feature{D,T}) where {D,T,P} =
    Feature{D,T,P}(id(f), bbox(f), geometry(f), getfield(f, :properties))

id(f::Feature) = getfield(f, :id)
geometry(f::Feature) = getfield(f, :geometry)
function properties(f::Feature)
    props = getfield(f, :properties)
    return isnothing(props) ? Dict{Symbol,Any}() : props
end

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


# A feature span retains its input buffer until it is materialized.
struct LazyFeature{D,T} <: GeoJSONT{D,T}
    bytes::Any
    pos::Int
    len::Int
end
@inline Base.codeunits(x::LazyFeature) = _featurebytes(x.bytes, x.pos, x.len)


"""
    FeatureCollection{D,T}(bbox::Union{Nothing,Vector{T}}, features::Vector{Feature{D,T}}, crs::Union{Nothing,CRS})

A FeatureCollection with `D` dimensional geometry in its features.
"""
struct FeatureCollection{D,T,P} <: AbstractFeatureCollection{D,T}
    bbox::Union{Nothing,Vector{T}}
    features::Vector{Feature{D,T,P}}
    crs::Union{Nothing,CRS}
    names::Vector{Symbol}
    types::Dict{Symbol,Type}
    schema_ready::Base.RefValue{Bool}
    function FeatureCollection{D,T,P}(bbox, features, crs) where {D,T,P}
        return new{D,T,P}(bbox, features, crs, Symbol[], Dict{Symbol,Type}(), Ref(false))
    end
end
FeatureCollection{D,T}(bbox, features::Vector{Feature{D,T,P}}, crs, n=nothing, t=nothing) where {D,T,P} =
    FeatureCollection{D,T,P}(bbox, features, crs)
FeatureCollection{D,T}(bbox, features, crs, n=nothing, t=nothing) where {D,T} =
    FeatureCollection{D,T,DefaultProperties}(bbox, features, crs)
FeatureCollection{D,T}(; bbox=nothing, features=Feature{D,T}[], crs=nothing) where {D,T} =
    FeatureCollection{D,T}(bbox, features, crs)
FeatureCollection(bbox, features::Vector{<:Feature{D,T}}, crs) where {D,T} =
    FeatureCollection{D,T}(bbox, features, crs)
FeatureCollection(; bbox=nothing, features::Vector{<:Feature{D,T}}, crs=nothing) where {D,T} =
    FeatureCollection{D,T}(bbox, features, crs)

Base.eltype(::Type{FeatureCollection{D,T,P}}) where {D,T,P} = Feature{D,T,P}


features(fc::FeatureCollection) = getfield(fc, :features)
Base.propertynames(fc::FeatureCollection) = first(_schema(fc))

function Base.getproperty(fc::FeatureCollection, name::Symbol)
    if name === :names
        first(_schema(fc))
    elseif name === :types
        last(_schema(fc))
    elseif name in (:bbox, :features, :crs)
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
Base.getindex(fc::AbstractFeatureCollection, i::Union{Int,UnitRange,Vector}) = features(fc)[i]
Base.IndexStyle(::AbstractFeatureCollection) = IndexLinear()

bbox(x::GeoJSONT) = getfield(x, :bbox)

"""
    LazyFeatureCollection{D,T}(bbox::Union{Nothing,Vector{T}}, features::Vector{LazyFeature{D,T}}, crs::Union{Nothing,String})

A FeatureCollection with `D` dimensional geometry in its features, but its features are
lazily parsed from the GeoJSON string. Indexing into the collection will parse the feature.
This can be more efficient when interested in only a few features from a large collection,
or parsing a very large collection iteratively without loading it all into memory.
"""
struct LazyFeatureCollection{D,T} <: AbstractFeatureCollection{D,T}
    bbox::Union{Nothing,Vector{T}}
    features::Vector{LazyFeature{D,T}}
    crs::Union{Nothing,CRS}
end
features(fc::LazyFeatureCollection) = collect(fc.features)
Base.eltype(::Type{LazyFeatureCollection{D,T}}) where {D,T} = Feature{D,T,DefaultProperties}
Base.length(fc::LazyFeatureCollection) = length(getfield(fc, :features))
Base.size(fc::LazyFeatureCollection) = size(getfield(fc, :features))

Base.show(io::IO, x::LazyFeatureCollection) = print(io, "LazyFeatureCollection with $(length(x.features)) features")
Base.getindex(x::LazyFeatureCollection{D,T}, i::Int) where {D,T} = _parse(codeunits(x.features[i]), Feature{D,T})::Feature{D,T}

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

typestring(::Type{<:LazyFeatureCollection}) = "FeatureCollection"
