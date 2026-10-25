# CoordinateWriteStyle is used only by GeoJSON.write, whose format is fixed.
# Direct JSON.json calls keep JSON's option-aware coordinate writer (pretty,
# float_style, float_precision, custom styles and allownan).
struct CoordinateWriteStyle <: JSON.JSONStyle end
coordinateoutput(st, c) = c
coordinateoutput(::CoordinateWriteStyle, c::C) where {C<:Tuple} = coordinateoutput(C, c)
coordinateoutput(::CoordinateWriteStyle, c::Vector{C}) where {C} = coordinateoutput(C, c)
coordinateoutput(::Type, c) = c
coordinateoutput(::Type{C}, c) where {C<:Tuple} =
    eltype(C) <: Union{Float32,Float64} ? JSON.JSONText(coordtext(c)) : c
coordinateoutput(::Type{Vector{C}}, c) where {C} = coordinateoutput(C, c)

# Upper bounds include brackets, separators and Ryu's maximum number length.
coordcapacity(::Type{C}) where {C<:Tuple} = 2 + fieldcount(C) * (Base.Ryu.neededdigits(eltype(C)) + 1)
coordcapacity(c::Tuple) = coordcapacity(typeof(c))
coordcapacity(c::Vector{C}) where {C<:Tuple} = 2 + length(c) * (coordcapacity(C) + 1)
coordcapacity(c::Vector) = 2 + sum(x -> coordcapacity(x) + 1, c; init=0)
function coordtext(c)
    buf = Vector{UInt8}(undef, coordcapacity(c))
    pos = writecoordinates!(buf, 1, c)
    resize!(buf, pos - 1)
    String(buf)
end
function writecoordinates!(buf, pos, c::Union{Tuple,Vector})
    @inbounds buf[pos] = UInt8('[')
    pos += 1
    for (i, x) in enumerate(c)
        if i > 1
            @inbounds buf[pos] = UInt8(',')
            pos += 1
        end
        pos = writecoordinates!(buf, pos, x)
    end
    @inbounds buf[pos] = UInt8(']')
    pos + 1
end
@inline function writecoordinates!(buf, pos, x::Union{Float32,Float64})
    isfinite(x) || throw(ArgumentError("NaN and Inf are not allowed in JSON coordinates"))
    Base.Ryu.writeshortest(buf, pos, x)
end

# Testable public-API fallback, also used for non-native coordinate types and
# A's exceptional NaN/Inf retry. No mutable global switch in the read hot path.
struct PublicCoordinateStyle <: StructUtils.StructStyle end
readcoordinates(st, ::Type{C}, src) where {C} = readcoordinates_public(st, C, src)
coordinatetype(::Type{T}) where {T<:Number} = T
coordinatetype(::Type{C}) where {C<:Tuple} = eltype(C)
coordinatetype(::Type{Vector{C}}) where {C} = coordinatetype(C)

# JSON's byte-span accessors are internal. Keep all use within this guard and
# fall back to StructUtils.applyeach if JSON changes the interface. Check the
# options layout too: bypassing JSON's array reader must retain its depth limit.
const COORDINATE_SCANNER_AVAILABLE = all(n -> isdefined(JSON, n),
    (:LazyValue, :getbuf, :getpos, :getdepth, :getopts, :LazyOptions)) &&
    hasfield(JSON.LazyOptions, :maxdepth)
@static if COORDINATE_SCANNER_AVAILABLE
    function readcoordinates(st, ::Type{C}, src::JSON.LazyValue) where {C}
        if coordinatetype(C) <: Union{Float32,Float64} &&
                !(StructUtils.parentstyle(st) isa PublicCoordinateStyle) && !nonfinitestyle(st)
            buf = JSON.getbuf(src)
            bytes = buf isa AbstractString ? codeunits(buf) : buf
            return scancoordinates(C, bytes, JSON.getpos(src), length(bytes),
                Int(JSON.getdepth(src)), Int(JSON.getopts(src).maxdepth))
        end
        readcoordinates_public(st, C, src)
    end
end

@noinline badcoordinates() = throw(ArgumentError("invalid JSON coordinates"))
@inline digit(b::UInt8) = UInt8('0') <= b <= UInt8('9')
@inline scanbyte(bytes, pos, len) = pos <= len ? @inbounds(bytes[pos]) : 0x00
@inline function coordinatews(bytes, pos, len)
    while scanbyte(bytes, pos, len) in (0x20, 0x09, 0x0a, 0x0d)
        pos += 1
    end
    pos
end
@inline function arraystart(bytes, pos, len, depth, maxdepth)
    depth < maxdepth || throw(ArgumentError("JSON coordinates exceed maximum depth $maxdepth"))
    scanbyte(bytes, pos, len) == UInt8('[') || badcoordinates()
    coordinatews(bytes, pos + 1, len)
end
function scancoordinates(::Type{Vector{C}}, bytes, pos, len, depth, maxdepth) where {C}
    pos = arraystart(bytes, pos, len, depth, maxdepth)
    out = C[]
    scanbyte(bytes, pos, len) == UInt8(']') && return out, pos + 1
    while true
        x, pos = scancoordinates(C, bytes, pos, len, depth + 1, maxdepth)
        push!(out, x)
        pos = coordinatews(bytes, pos, len)
        b = scanbyte(bytes, pos, len)
        b == UInt8(']') && return out, pos + 1
        b == UInt8(',') || badcoordinates()
        pos = coordinatews(bytes, pos + 1, len)
    end
end
function scancoordinates(::Type{C}, bytes, pos, len, depth, maxdepth) where {C<:Tuple}
    pos = arraystart(bytes, pos, len, depth, maxdepth)
    D = fieldcount(C)
    values = ntuple(_ -> zero(eltype(C)), Val(fieldcount(C)))
    n = 0
    if scanbyte(bytes, pos, len) != UInt8(']')
        while true
            x, pos = scancoordinates(eltype(C), bytes, pos, len, depth + 1, maxdepth)
            n += 1
            n <= D && (values = Base.setindex(values, x, n))
            pos = coordinatews(bytes, pos, len)
            b = scanbyte(bytes, pos, len)
            b == UInt8(']') && break
            b == UInt8(',') || badcoordinates()
            pos = coordinatews(bytes, pos + 1, len)
        end
    end
    n > D && throw(DimensionError(n, D))
    n == D || throw(dimensionerror(n, D))
    values, pos + 1
end

# Strict JSON number grammar, independently of Parsers' more permissive syntax.
# Convert directly to T so long mantissas cannot double-round through Float64.
@inline function scancoordinates(::Type{T}, bytes, pos, len, depth, maxdepth) where {T<:Union{Float32,Float64}}
    first = pos
    b = scanbyte(bytes, pos, len)
    if b == UInt8('-')
        pos += 1
        b = scanbyte(bytes, pos, len)
    end
    if b == UInt8('0')
        pos += 1
        digit(scanbyte(bytes, pos, len)) && badcoordinates()
    else
        UInt8('1') <= b <= UInt8('9') || badcoordinates()
        pos += 1
        while digit(scanbyte(bytes, pos, len)); pos += 1; end
    end
    if scanbyte(bytes, pos, len) == UInt8('.')
        pos += 1
        digit(scanbyte(bytes, pos, len)) || badcoordinates()
        while digit(scanbyte(bytes, pos, len)); pos += 1; end
    end
    if scanbyte(bytes, pos, len) in (UInt8('e'), UInt8('E'))
        pos += 1
        scanbyte(bytes, pos, len) in (UInt8('+'), UInt8('-')) && (pos += 1)
        digit(scanbyte(bytes, pos, len)) || badcoordinates()
        while digit(scanbyte(bytes, pos, len)); pos += 1; end
    end
    # A treats the integer token -0 as Int64(0); decimal/exponent zeros
    # retain their sign. Keep that distinction byte-for-byte on re-serialization.
    x = pos == first + 2 && bytes[first] == UInt8('-') && bytes[first+1] == UInt8('0') ?
        zero(T) : coordinatefloat(T, bytes, first, pos - 1)
    x, pos
end
@static if pkgversion(Parsers) < v"3"
    @inline function coordinatefloat(::Type{T}, bytes, first, last) where {T}
        result = Parsers.xparse2(T, bytes, first, last)
        Parsers.invalid(result.code) && badcoordinates()
        result.val
    end
else
    @inline coordinatefloat(::Type{T}, bytes, first, last) where {T} =
        Parsers.parsefloat(T, bytes, first, last)[1]
end
