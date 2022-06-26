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
# Useful for constructing geometries yourself rather than
# reading a JSON string, which gives JSON3.Object.
Point(; kwargs...) = Point(merge((type = "Point",), kwargs))
LineString(; kwargs...) = LineString(merge((type = "LineString",), kwargs))
Polygon(; kwargs...) = Polygon(merge((type = "Polygon",), kwargs))
MultiPoint(; kwargs...) = MultiPoint(merge((type = "MultiPoint",), kwargs))
MultiLineString(; kwargs...) = MultiLineString(merge((type = "MultiLineString",), kwargs))
MultiPolygon(; kwargs...) = MultiPolygon(merge((type = "MultiPolygon",), kwargs))
GeometryCollection(; kwargs...) =
    GeometryCollection(merge((type = "GeometryCollection",), kwargs))

# if the only argument is an AbstractVector it can be interpreted as the coordinates
Point(c::AbstractVector; kwargs...) =
    Point(merge((type = "Point", coordinates = c), kwargs))
LineString(c::AbstractVector; kwargs...) =
    LineString(merge((type = "LineString", coordinates = c), kwargs))
Polygon(c::AbstractVector; kwargs...) =
    Polygon(merge((type = "Polygon", coordinates = c), kwargs))
MultiPoint(c::AbstractVector; kwargs...) =
    MultiPoint(merge((type = "MultiPoint", coordinates = c), kwargs))
MultiLineString(c::AbstractVector; kwargs...) =
    MultiLineString(merge((type = "MultiLineString", coordinates = c), kwargs))
MultiPolygon(c::AbstractVector; kwargs...) =
    MultiPolygon(merge((type = "MultiPolygon", coordinates = c), kwargs))
GeometryCollection(g::AbstractVector; kwargs...) =
    GeometryCollection(merge((type = "GeometryCollection", geometries = c), kwargs))

coordinates(g::Geometry) = object(g).coordinates
coordinates(g::GeometryCollection) = geometries(g)
geometries(g::GeometryCollection) = object(g).geometries

# read only partial array interface like JSON3.Array
Base.size(g::Geometry) = size(coordinates(g))
Base.getindex(g::Geometry, i::Int) = getindex(coordinates(g), i::Int)
Base.IndexStyle(::Type{<:Geometry}) = Base.IndexLinear()
Base.iterate(g::Geometry, st = (1, 3)) = iterate(coordinates(g), st)
Base.length(g::Geometry) = length(coordinates(g))

Base.show(io::IO, g::Geometry) = print(io, type(g))
