abstract type Geometry end

struct Point{S, TT} <: Geometry
    json::JSON3.Object{S, TT}
end

struct LineString{S, TT} <: Geometry
    json::JSON3.Object{S, TT}
end

struct Polygon{S, TT} <: Geometry
    json::JSON3.Object{S, TT}
end

struct MultiPoint{S, TT} <: Geometry
    json::JSON3.Object{S, TT}
end

struct MultiLineString{S, TT} <: Geometry
    json::JSON3.Object{S, TT}
end

struct MultiPolygon{S, TT} <: Geometry
    json::JSON3.Object{S, TT}
end

struct GeometryCollection{S, TT} <: Geometry
    json::JSON3.Object{S, TT}
end

Base.getproperty(g::Geometry, nm::Symbol) = getproperty(getfield(g, :json), nm)
