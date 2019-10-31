abstract type Geometry{T} <: AbstractVector{T} end

struct Point{T, S, TT} <: Geometry{T}
    json::JSON3.Array{T, S, TT}
end

struct LineString{T, S, TT} <: Geometry{T}
    json::JSON3.Array{T, S, TT}
end

struct Polygon{T, S, TT} <: Geometry{T}
    json::JSON3.Array{T, S, TT}
end

struct MultiPoint{T, S, TT} <: Geometry{T}
    json::JSON3.Array{T, S, TT}
end

struct MultiLineString{T, S, TT} <: Geometry{T}
    json::JSON3.Array{T, S, TT}
end

struct MultiPolygon{T, S, TT} <: Geometry{T}
    json::JSON3.Array{T, S, TT}
end

struct GeometryCollection{T, S, TT} <: Geometry{T}
    json::JSON3.Array{T, S, TT}
end

# read only partial array interface like JSON3.Array
Base.size(g::Geometry) = size(g.json)
Base.getindex(g::Geometry, i::Int) = getindex(g.json, i::Int)
Base.IndexStyle(::Type{<:Geometry}) = Base.IndexLinear()
Base.iterate(g::Geometry, st=(1, 3)) = iterate(g.json, st)
Base.length(g::Geometry) = length(g.json)
