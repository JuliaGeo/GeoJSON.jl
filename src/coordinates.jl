# JSON does not expose a public String-buffer size hint. This owned adapter
# delegates all member emission and touches the optional internal hint only
# behind a feature guard. The unwrapped public writer is always callable.
struct SizedGeoJSON{G<:GeoJSONT}
    object::G
    capacity::Int
end
StructUtils.applyeach(st::JSON.JSONStyle, f, x::SizedGeoJSON) =
    StructUtils.applyeach(st, f, getfield(x, :object))
const WRITE_HINT_AVAILABLE = isdefined(JSON, :sizeguess)
@static if WRITE_HINT_AVAILABLE
    JSON.sizeguess(x::SizedGeoJSON) = getfield(x, :capacity)
end

# Hints need only be approximate: JSON still grows its buffer as necessary.
# Count positions without scanning numbers or invoking custom property lowering.
coordinatehint(::Nothing) = 4
coordinatehint(c::Tuple) = 3 + 10 * length(c)
coordinatehint(c::Vector{C}) where {C<:Tuple} = 2 + length(c) * (3 + 10 * fieldcount(C))
coordinatehint(c::Vector) = 2 + sum(x -> coordinatehint(x) + 1, c; init=0)
geometryhint(::Nothing) = 4
@inline function geometryhint(g::AbstractGeometry{D,T}) where {D,T}
    g isa Point{D,T} && return 96 + coordinatehint(getfield(g, :coordinates))
    g isa LineString{D,T} && return 96 + coordinatehint(getfield(g, :coordinates))
    g isa Polygon{D,T} && return 96 + coordinatehint(getfield(g, :coordinates))
    g isa MultiPoint{D,T} && return 96 + coordinatehint(getfield(g, :coordinates))
    g isa MultiLineString{D,T} && return 96 + coordinatehint(getfield(g, :coordinates))
    g isa MultiPolygon{D,T} && return 96 + coordinatehint(getfield(g, :coordinates))
    g isa GeometryCollection{D,T} && return collectionhint(g)
    512
end
# Keep collection recursion in a separate method. The trim verifier can resolve
# this single-method call; JET may still report the recursive dispatch.
function collectionhint(g::GeometryCollection)
    size = 96
    for child in getfield(g, :geometries); size += geometryhint(child); end
    size
end
function writehint(fc::FeatureCollection)
    size = 64
    for feature in getfield(fc, :features)
        props = getfield(feature, :properties)
        size += 64 + (props === nothing ? 4 : 32 * length(props)) + geometryhint(getfield(feature, :geometry))
    end
    min(size, 4 * 1024^2)
end

# CoordinateWriteStyle is used only by GeoJSON.write, whose format is fixed.
# Direct JSON.json calls keep JSON's option-aware coordinate writer (pretty,
# float_style, float_precision, custom styles and allownan).
struct CoordinateWriteStyle <: JSON.JSONStyle end
"""
    GeoJSON.StrictStyle()

Opt-in closed write style for `GeoJSON.write(x; style=GeoJSON.StrictStyle())`
and trimmed applications. Values in `Any` containers must have JSON's parsed
value types (including nested arrays/dictionaries and big numbers), or `missing`.
Other values throw `ArgumentError`; ordinary `write` retains custom lowering.
This style uses a fixed compact format. When JSON's writer options layout is
available, nondefault options (such as `pretty=true` or `allownan=true`) are
rejected for GeometryCollection children. Otherwise, that check is skipped.
"""
struct StrictStyle <: JSON.JSONStyle end
JSON.applyany(::StrictStyle, f, k, @nospecialize(v)) =
    throw(ArgumentError("unsupported value for key $(repr(k)) of type $(typeof(v)) in GeoJSON.StrictStyle"))
coordinateoutput(st, c) = c
# A Point already fits JSON's small tuple writer; a raw-text buffer costs more
# than it saves. Coordinate arrays amortize that allocation over many positions.
coordinateoutput(::Union{CoordinateWriteStyle,StrictStyle}, c::Tuple) = c
coordinateoutput(::Union{CoordinateWriteStyle,StrictStyle}, c::Vector{C}) where {C} = coordinateoutput(C, c)
coordinateoutput(::Type, c) = c
coordinateoutput(::Type{C}, c) where {C<:Tuple} =
    eltype(C) <: Union{Float32,Float64} ? JSON.JSONText(coordtext(c)) : c
coordinateoutput(::Type{Vector{C}}, c) where {C} = coordinateoutput(C, c)

# Ten bytes per number is a useful initial estimate for geographic positions.
# High precision/extreme values grow the same owned buffer before printing; do
# not pay a worst-case float bound for every ordinary coordinate.
coordcapacity(::Type{C}) where {C<:Tuple} = 2 + fieldcount(C) * 11
coordcapacity(c::Tuple) = coordcapacity(typeof(c))
coordcapacity(c::Vector{C}) where {C<:Tuple} = 2 + length(c) * (coordcapacity(C) + 1)
coordcapacity(c::Vector) = 2 + sum(x -> coordcapacity(x) + 1, c; init=0)
@inline function coordinatecapacity!(buf, pos, needed)
    if pos + needed - 1 > length(buf)
        resize!(buf, max(2 * length(buf), pos + needed))
    end
    nothing
end

# String-backed byte vectors let String take ownership after shrinking, avoiding
# a second coordinate-text allocation. This Base helper is internal; absence
# keeps the ordinary Vector path, which is also exercised explicitly in tests.
const STRING_VECTOR_AVAILABLE = isdefined(Base, :StringVector)
coordinatebuffer(n, ::Val{false}) = Vector{UInt8}(undef, n)
@static if STRING_VECTOR_AVAILABLE
    coordinatebuffer(n, ::Val{true}) = Base.StringVector(n)
end
coordtext(c) = coordtext(c, Val(STRING_VECTOR_AVAILABLE))
@noinline function coordtext(c, mode::Val)
    buf = coordinatebuffer(coordcapacity(c), mode)
    pos = writecoordinates!(buf, 1, c)
    resize!(buf, pos - 1)
    String(buf)
end
function writecoordinates!(buf, pos, c::Union{Tuple,Vector})
    coordinatecapacity!(buf, pos, 1)
    @inbounds buf[pos] = UInt8('[')
    pos += 1
    for (i, x) in enumerate(c)
        if i > 1
            coordinatecapacity!(buf, pos, 1)
            @inbounds buf[pos] = UInt8(',')
            pos += 1
        end
        pos = writecoordinates!(buf, pos, x)
    end
    coordinatecapacity!(buf, pos, 1)
    @inbounds buf[pos] = UInt8(']')
    pos + 1
end
@inline function writecoordinates!(buf, pos, x::Union{Float32,Float64})
    isfinite(x) || throw(ArgumentError("$(Float64(x)) not allowed to be written in JSON spec; pass `allownan=true` to allow anyway"))
    # 32 covers shortest Float32/Float64 output and Ryu's scratch space.
    coordinatecapacity!(buf, pos, 32)
    Base.Ryu.writeshortest(buf, pos, x)
end

# Testable public-API fallback, also used for non-native coordinate types and
# A's exceptional NaN/Inf retry. No mutable global switch in the read hot path.
struct PublicCoordinateStyle <: StructUtils.StructStyle end
struct CoordinateFallback <: Exception end
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
    @noinline function readcoordinates(st, ::Type{C}, src::JSON.LazyValue) where {C}
        if coordinatetype(C) <: Union{Float32,Float64} &&
                !(StructUtils.parentstyle(st) isa PublicCoordinateStyle) && !nonfinitestyle(st)
            buf = JSON.getbuf(src)
            bytes = buf isa AbstractString ? codeunits(buf) : buf
            try
                return scancoordinates(C, bytes, JSON.getpos(src), length(bytes),
                    Int(JSON.getdepth(src)), Int(JSON.getopts(src).maxdepth))
            catch e
                # Let A report malformed input, including counting/skipping
                # extra non-numeric components before its dimension retry.
                e isa Union{ArgumentError,CoordinateFallback} || rethrow()
            end
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
function scanposition(::Type{C}, bytes, pos, len, depth, maxdepth) where {C<:Tuple}
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

# Emit common arities directly into tuple slots, avoiding runtime tuple
# updates/counts. Other arities retain the general scanner; excess components
# use A's exact counting/retry.
@generated function scancoordinates(::Type{C}, bytes, pos, len, depth, maxdepth) where {C<:Tuple}
    D = fieldcount(C)
    D in (2, 3) || return :(scanposition(C, bytes, pos, len, depth, maxdepth))
    components = [gensym(:component) for _ in 1:D]
    steps = Any[:(pos = arraystart(bytes, pos, len, depth, maxdepth))]
    for i in 1:D
        push!(steps, quote
            $(components[i]), pos = scancoordinates(eltype(C), bytes, pos, len, depth + 1, maxdepth)
            pos = coordinatews(bytes, pos, len)
            b = scanbyte(bytes, pos, len)
        end)
        if i < D
            push!(steps, quote
                b == UInt8(']') && throw(dimensionerror($i, $D))
                b == UInt8(',') || badcoordinates()
                pos = coordinatews(bytes, pos + 1, len)
            end)
        end
    end
    push!(steps, :(b == UInt8(']') || throw(CoordinateFallback())))
    push!(steps, :(return ($(Expr(:tuple, components...)), pos + 1)))
    Expr(:block, steps...)
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
