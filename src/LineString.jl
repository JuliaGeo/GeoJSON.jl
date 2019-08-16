# This file is copied from RoamesGeometry.jl by Andy Ferris, Copyright (c) 2017 Fugro Roames, licensed under the MIT license.
# https://github.com/FugroRoames/RoamesGeometry.jl/blob/af52a35c951bb8e71b363704ed624e117738c850/src/LineString.jl

"""
    LineString(points)

Construct a `LineString` geometric object, which is a connected string of lines. The
`points` are expected to be a vector 2-vectors or 3-vectors.

Certain two-dimensional operations are provided for `LineString`. A `LineString`
`isclosed` if it is not empty and the first and last point is identical. A `LineString`
`issimple` if it `isclosed`, and no lines intersect (when projected to the X-Y plane).
"""
struct LineString{N, V <: AbstractVector{<:StaticVector{N, Float64}}} <: AbstractVector{Line{N}}
    points::V
end

LineString(points::StaticVector{N,T}...) where {N, T <: Real} = LineString(collect(points))
LineString{N}(points::AbstractVector{T}...) where {N, T <: Real} = LineString{N}(collect(points))
LineString{N}(points::AbstractVector{<:AbstractVector{T}}) where {N, T <: Real} = LineString{N}(points)
LineString{N}(points::AbstractVector{<:Real}...) where {N, T <: Real} = LineString{N}(collect(points))
LineString{N}(points::AbstractVector{<:AbstractVector{<:Real}}) where {N, T <: Real} = LineString{N}(convert.(SVector{N, Float64}, points))
LineString{N}(points::AbstractVector{<:StaticVector{N, T}}) where {N, T <: Real} = LineString{N, typeof(points)}(points)

# AbstractArray interface
Base.IndexStyle(ls::Type{<:LineString}) = IndexLinear()
Base.size(ls::LineString) = (max(1, length(ls.points)) - 1,)
# TODO support offset vectors
Base.@propagate_inbounds Base.getindex(ls::LineString, i::Int) = Line(ls.points[i], ls.points[i+1])

function Base.:(==)(ls1::LineString{N}, ls2::LineString{N}) where N
    return ls1.points == ls2.points
end

function Base.isequal(ls1::LineString{N}, ls2::LineString{N}) where N
    isequal(ls1.points, ls2.points)
end

function Base.hash(p::LineString, h::UInt)
    hash(p.points, hash(UInt === UInt64 ? 0x9f7771527ea46b4f : 0xb6701376, h))
end

function Base.show(io::IO, ls::LineString{N}) where N
    print(io, "LineString{$N}([")
    for i in 1:length(ls.points)
        print(io, ls.points[i])
        if i < length(ls.points)
            print(io, ", ")
        end
    end
    print(io, "])")
end

# Some geometry interfaces
isclosed(ls::LineString) = length(ls.points) > 1 && first(ls.points) == last(ls.points)

function winding_number(p::StaticVector{2, <:Real}, ls::LineString{2})
    # Calculate clockwise winding number.
    # See for example http://geomalgorithms.com/a03-_inclusion.html
    if isempty(ls.points)
        return 0
    end

    winding = 0

    # Shift origin to p, and test winding of all Line(p1, p2)
    p1 = ls.points[1] - p
    for i in 2:length(ls.points)
        p2 = ls.points[i] - p
        if p1[2] <= 0
            if p2[2] > 0 # crosses x-axis upwards
                if p1 × p2 > 0 # orign, p1, p2 form anticlockwise triangle if it passes to the right
                    winding -= 1
                end
            end
        else
            if p2[2] <= 0 # crosses x-axis downwards
                if p1 × p2 < 0 # orign, p1, p2 form clockwise triangle if it passes to the right
                    winding += 1
                end
            end
        end
        p1 = p2
    end
    return winding # clockwise sense
end
