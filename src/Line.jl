# This file is copied from RoamesGeometry.jl by Andy Ferris, Copyright (c) 2017 Fugro Roames, licensed under the MIT license.
# https://github.com/FugroRoames/RoamesGeometry.jl/blob/af52a35c951bb8e71b363704ed624e117738c850/src/Line.jl

"""
    Line(p1, p2)

Construct a `Line` geometric object (representing a segment) with given beginning and end
points, which are generally 2-vectors or 3-vectors.
"""
struct Line{N, T <: Real}
    p1::SVector{N, T}
    p2::SVector{N, T}
end

function Line(p1::StaticVector{N, T}, p2::StaticVector{N, T}) where {N, T <: Real}
    Line{N, T}(p1, p2)
end

function Line{N}(p1::AbstractVector{T}, p2::AbstractVector{T}) where {N, T <: Real}
    Line{N, T}(p1, p2)
end

# Note: This doesn't compare the ordering of points
function Base.:(==)(l1::Line{N}, l2::Line{N}) where N
    return l1.p1 == l2.p1 && l1.p2 == l2.p2
end

function Base.isequal(l1::Line{N}, l2::Line{N}) where N
    isequal(l1.p1, l2.p1) && isequal(l1.p2, l2.p2)
end

function Base.hash(l::Line, h::UInt)
    hash(l.p1, hash(l.p2, hash(UInt === UInt64 ? 0x627c5acc5b1e3d3d : 0x94c690be, h)))
end

Base.eltype(::Line{N, T}) where {N, T} = SVector{N,T}
Base.eltype(::Type{Line{N, T}}) where {N, T} = SVector{N,T}

function Base.show(io::IO, l::Line{N}) where N
    print(io, "Line{$N}(")
    print(io, l.p1)
    print(io, ", ")
    print(io, l.p2)
    print(io, ")")
end
