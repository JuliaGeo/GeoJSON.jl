abstract type Geometry <: AbstractVector{Any} end

struct Point{T} <: Geometry
    object::T
end

struct LineString{T} <: Geometry
    object::T
end

struct Polygon{T} <: Geometry
    object::T
end

struct MultiPoint{T} <: Geometry
    object::T
end

struct MultiLineString{T} <: Geometry
    object::T
end

struct MultiPolygon{T} <: Geometry
    object::T
end

struct GeometryCollection{T} <: Geometry
    object::T
end

# Construct using keywords that become a NamedTuple object.
Point(; coordinates, kwargs...) = Point(merge((type = "Point", coordinates), kwargs))
LineString(; coordinates, kwargs...) =
    LineString(merge((type = "LineString", coordinates), kwargs))
Polygon(; coordinates, kwargs...) = Polygon(merge((type = "Polygon", coordinates), kwargs))
MultiPoint(; coordinates, kwargs...) =
    MultiPoint(merge((type = "MultiPoint", coordinates), kwargs))
MultiLineString(; coordinates, kwargs...) =
    MultiLineString(merge((type = "MultiLineString", coordinates), kwargs))
MultiPolygon(; coordinates, kwargs...) =
    MultiPolygon(merge((type = "MultiPolygon", coordinates), kwargs))
GeometryCollection(; geometries, kwargs...) =
    GeometryCollection(merge((type = "GeometryCollection", geometries), kwargs))

coordinates(g::Geometry) = object(g).coordinates
coordinates(g::GeometryCollection) = geometries(g)
geometries(g::GeometryCollection) = object(g).geometries
Base.propertynames(g::Geometry) = propertynames(object(g))
Base.getproperty(g::Geometry, nm::Symbol) = getproperty(object(g), nm)

function Base.iterate(g::Geometry)
    x = iterate(coordinates(g))
    x === nothing && return nothing
    val, state = x
    return val, state
end

function Base.iterate(g::Geometry, state)
    x = iterate(coordinates(g), state)
    x === nothing && return nothing
    val, state = x
    return val, state
end

# read only partial array interface like JSON3.Array
Base.size(g::Geometry) = size(coordinates(g))
Base.getindex(g::Geometry, i::Int) = getindex(coordinates(g), i::Int)
Base.IndexStyle(::Type{<:Geometry}) = Base.IndexLinear()
Base.length(g::Geometry) = length(coordinates(g))

Base.show(io::IO, g::Geometry) = print(io, type(g))
Base.show(io::IO, g::Point) = print(io, type(g), '(', coordinates(g), ')')
