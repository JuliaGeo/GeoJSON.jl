"""
    DimMismatch(expected, got, feature)

A coordinate position held `got` values in an `expected`-dimensional read. `feature` is the
1-based index of the offending feature, or 0 when the document is a bare geometry.
"""
struct DimMismatch <: Exception
    expected::Int
    got::Int
    feature::Int
end

function Base.showerror(io::IO, e::DimMismatch)
    print(io, "coordinate with ", e.got, " values in a ", e.expected, "-D read")
    e.feature > 0 && print(io, " (feature ", e.feature, ")")
    2 <= e.got <= 4 && print(io, "; pass `ndim=", e.got, "`")
end

@noinline _nested() = throw(ArgumentError("a coordinate position must be a flat array of numbers"))

# Element count of the flat array at buf[pos] and the position past its ']'; (-1, 0) when the
# array nests, (0, pos) when it is empty. Byte arithmetic only, so no number is parsed twice.
@inline function flatcount(buf, pos::Int, len::Int)
    pos += 1
    n = 0
    @inbounds while pos <= len
        b = getbyte(buf, pos)
        if b == UInt8(']')
            return n, pos + 1
        elseif b == UInt8(',')
            n += 1
        elseif b == UInt8('[') || b == UInt8('{')
            return -1, 0
        elseif n == 0 && !(b == UInt8(' ') || b == UInt8('\n') || b == UInt8('\t') || b == UInt8('\r'))
            n = 1
        end
        pos += 1
    end
    return -1, 0
end

# JSON.jl's `maketuple` silently drops elements past `D` and throws a generic parse error on
# fewer, so the element count is checked on bytes first.
@inline function positioncount(x::LazyValues)
    gettype(x) == ARRAY || _nested()
    buf = getbuf(x)
    n, pos = flatcount(buf, getpos(x), getlength(buf))
    n < 0 && _nested()
    return n, pos
end

@inline function readpoint(st, ::Val{D}, ::Type{T}, x::LazyValues) where {D,T}
    n, _ = positioncount(x)
    n == D || throw(DimMismatch(D, n, 0))
    return StructUtils.maketuple(st, NTuple{D,T}, x)
end

# A Point's own position may be empty: the unlocated point that `"coordinates": null` also gives.
@inline function readposition(st, ::Val{D}, ::Type{T}, x::LazyValues) where {D,T}
    n, pos = positioncount(x)
    val::Union{Nothing,NTuple{D,T}} = nothing
    if n != 0
        n == D || throw(DimMismatch(D, n, 0))
        val, pos = StructUtils.maketuple(st, NTuple{D,T}, x)
    end
    return val, pos
end

struct CoordSink{E,S}
    st::S
    out::Vector{E}
end

@inline function (s::CoordSink{E})(_, v::LazyValues) where {E}
    val, pos = readcoords(s.st, E, v)
    push!(s.out, val)
    return pos
end

readcoords(st, ::Type{E}, x::LazyValues) where {E<:Tuple} = readpoint(st, Val(fieldcount(E)), eltype(E), x)
function readcoords(st, ::Type{Vector{E}}, x::LazyValues) where {E}
    gettype(x) == ARRAY || _nested()
    out = E[]
    pos = applyarray(CoordSink{E,typeof(st)}(st, out), x)
    return out, pos::Int
end

const Ring{D,T} = Vector{NTuple{D,T}}
const Surface{D,T} = Vector{Vector{NTuple{D,T}}}
const Solid{D,T} = Vector{Vector{Vector{NTuple{D,T}}}}

# Inference barriers: each nesting depth is its own parse tower, and inlining all four into
# one geometry method costs seconds of first-call inference.
@noinline readring(st, ::Val{D}, ::Type{T}, x::LazyValues) where {D,T} = readcoords(st, Ring{D,T}, x)
@noinline readsurface(st, ::Val{D}, ::Type{T}, x::LazyValues) where {D,T} = readcoords(st, Surface{D,T}, x)
@noinline readsolid(st, ::Val{D}, ::Type{T}, x::LazyValues) where {D,T} = readcoords(st, Solid{D,T}, x)
