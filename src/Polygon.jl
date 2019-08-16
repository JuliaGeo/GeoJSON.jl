# This file is copied from RoamesGeometry.jl by Andy Ferris, Copyright (c) 2017 Fugro Roames, licensed under the MIT license.
# https://github.com/FugroRoames/RoamesGeometry.jl/blob/af52a35c951bb8e71b363704ed624e117738c850/src/Polygon.jl

struct Polygon{N, T <: Real, L <: LineString{N, T}, V <: AbstractVector{L}}
    exterior::L
    interiors::V
end

function Polygon{N}(exterior::L, interiors::AbstractVector{L}) where {N, T, L <: LineString{N, T}}
    Polygon{N, T, L, typeof(interiors)}(exterior, interiors)
end
function Polygon{N,T}(exterior::L, interiors::AbstractVector{L}) where {N, T, L <: LineString{N, T}}
    Polygon{N, T, L, typeof(interiors)}(exterior, interiors)
end

Polygon(points::StaticVector{N,T}...) where {N, T<:Real} = Polygon(collect(points))
Polygon(points::AbstractVector{<:StaticVector{N,T}}) where {N,T<:Real} = Polygon{N}(LineString{N}(points))
Polygon{N}(points::AbstractVector{T}...) where {N, T<:Real} = Polygon{N}(collect(points))
Polygon{N}(points::AbstractVector{<:AbstractVector{T}}) where {N, T<:Real} = Polygon{N,T}(LineString{N,T}(points))
Polygon{N,T}(points::AbstractVector{<:Real}...) where {N, T<:Real} = Polygon{N,T}(collect(points))
Polygon{N,T}(points::AbstractVector{<:AbstractVector{<:Real}}) where {N, T<:Real} = Polygon{N,T}(LineString{N,T}(points))

Polygon(ls::LineString) = Polygon(ls, Vector{typeof(ls)}())
Polygon{N}(ls::LineString{N}) where {N} = Polygon{N}(ls, Vector{typeof(ls)}())
Polygon{N,T}(ls::LineString{N,T}) where {N,T<:Real} = Polygon{N,T}(ls, Vector{typeof(ls)}())

# Note: This doesn't compare the ordering of points
function Base.:(==)(p1::Polygon{N}, p2::Polygon{N}) where N
    p1.exterior == p2.exterior && p1.interiors == p2.interiors
end

function Base.isequal(p1::Polygon{N}, p2::Polygon{N}) where N
    isequal(p1.exterior, p2.exterior) && isequal(p1.interiors, p2.interiors)
end

function Base.hash(p::Polygon, h::UInt)
    hash(p.exterior, hash(p.interiors, hash(UInt === UInt64 ? 0xde95b490c51c55a5 : 0x0f7345a4, h)))
end

function Base.show(io::IO, polygon::Polygon{N}) where N
    print(io, "Polygon{$N}([")
    for i in 1:length(polygon.exterior.points)
        print(io, polygon.exterior.points[i])
        if i < length(polygon.exterior.points)
            print(io, ", ")
        end
    end
    print(io, "]")
    for ls in polygon.interiors
    	print(io, ", [")
    	for i in 1:length(ls.points)
	        print(io, ls.points[i])
	        if i < length(ls.points)
	            print(io, ", ")
	        end
	    end
    	print(io, "]")
    end
    print(io, ")")
end
