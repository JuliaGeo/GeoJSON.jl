# JSON's lazy parser passes an end position back from each materialization callback.
# Keep span access and the strict coordinate adapter in this file.
struct CoordinateStyle <: JSON.JSONStyle end
struct GeometryReadStyle <: StructUtils.StructStyle end

struct CoordinateDimensionError <: Exception
    expected::Int
end
Base.showerror(io::IO, e::CoordinateDimensionError) =
    print(io, "expected ", e.expected, " coordinate components")

mutable struct PositionState{D,T,S}
    values::NTuple{D,T}
    count::Int
    style::S
end

@inline function StructUtils.make(
    ::JSON.JSONReadStyle{O,N,GeometryReadStyle},
    ::Type{T},
    source::JSON.LazyValue,
) where {O,N,T<:Number}
    JSON.gettype(source) == JSON.JSONTypes.NUMBER ||
        throw(ArgumentError("geometry numbers must be numeric JSON values"))
    if T === Float32 || T === Float64
        buf = JSON.getbuf(source)
        return _coordinate(T, buf, JSON.getpos(source), JSON.getlength(buf))
    end
    style = JSON.JSONReadStyle{Dict{String,Any}}(nothing)
    value, pos = StructUtils.make(style, T, source)
    if T <: AbstractFloat &&
       iszero(value) &&
       JSON.getbyte(JSON.getbuf(source), JSON.getpos(source)) == UInt8('-')
        value = -zero(T)
    end
    value, pos
end

function StructUtils.make(
    ::JSON.JSONReadStyle{O,N,GeometryReadStyle},
    ::Type{Dict{Symbol,Any}},
    source::JSON.LazyValue,
) where {O,N}
    style = JSON.JSONReadStyle{Dict{String,Any}}(nothing)
    StructUtils.make(style, Dict{Symbol,Any}, source)
end

@inline function (state::PositionState{D,T})(i, source) where {D,T}
    i <= D || throw(CoordinateDimensionError(D))
    JSON.gettype(source) == JSON.JSONTypes.NUMBER ||
        throw(ArgumentError("coordinates must be numbers"))
    value, pos = StructUtils.make(state.style, T, source)
    if T <: AbstractFloat &&
       iszero(value) &&
       JSON.getbyte(JSON.getbuf(source), JSON.getpos(source)) == UInt8('-')
        value = -zero(T)
    end
    state.values = Base.setindex(state.values, value, i)
    state.count = i
    pos
end

@inline function StructUtils.make(
    ::CoordinateStyle,
    ::Type{C},
    source::JSON.LazyValue,
) where {C<:Tuple}
    D, T = fieldcount(C), eltype(C)
    D > 0 || throw(ArgumentError("coordinates require a positive dimension"))
    if T === Float32 || T === Float64
        return _position(C, source)
    end
    style = JSON.JSONReadStyle{Dict{String,Any}}(nothing)
    state = PositionState{D,T,typeof(style)}(ntuple(_ -> zero(T), Val(D)), 0, style)
    # Inlining the loop keeps the mutable accumulator off the heap.
    pos = @inline JSON.applyarray(state, source)
    state.count == D || throw(CoordinateDimensionError(D))
    state.values, pos
end

@inline function _nextcoordinate(buf, pos, len)
    while pos <= len
        b = JSON.getbyte(buf, pos)
        b in (0x20, 0x09, 0x0a, 0x0d) || return pos, b
        pos += 1
    end
    throw(ArgumentError("unexpected end of coordinates"))
end

@inline function _coordinate(::Type{T}, buf, pos, len) where {T}
    first = pos
    b = JSON.getbyte(buf, pos)
    if b == UInt8('-')
        pos += 1
        pos <= len || throw(ArgumentError("invalid coordinate number"))
        b = JSON.getbyte(buf, pos)
    end
    if b == UInt8('0')
        pos += 1
        pos <= len &&
            UInt8('0') <= JSON.getbyte(buf, pos) <= UInt8('9') &&
            throw(ArgumentError("leading zeros are invalid in coordinate numbers"))
    elseif UInt8('1') <= b <= UInt8('9')
        while pos <= len && UInt8('0') <= JSON.getbyte(buf, pos) <= UInt8('9')
            pos += 1
        end
    else
        throw(ArgumentError("coordinates must be numbers"))
    end
    if pos <= len && JSON.getbyte(buf, pos) == UInt8('.')
        pos += 1
        pos <= len && UInt8('0') <= JSON.getbyte(buf, pos) <= UInt8('9') ||
            throw(ArgumentError("invalid coordinate fraction"))
        while pos <= len && UInt8('0') <= JSON.getbyte(buf, pos) <= UInt8('9')
            pos += 1
        end
    end
    if pos <= len && JSON.getbyte(buf, pos) in (UInt8('e'), UInt8('E'))
        pos += 1
        if pos <= len && JSON.getbyte(buf, pos) in (UInt8('+'), UInt8('-'))
            pos += 1
        end
        pos <= len && UInt8('0') <= JSON.getbyte(buf, pos) <= UInt8('9') ||
            throw(ArgumentError("invalid coordinate exponent"))
        while pos <= len && UInt8('0') <= JSON.getbyte(buf, pos) <= UInt8('9')
            pos += 1
        end
    end
    bytes = buf isa AbstractString ? codeunits(buf) : buf
    value, code = Parsers.parsefloat(T, bytes, first, pos - 1)
    code in (Parsers.RC_OK, Parsers.RC_OVERFLOW, Parsers.RC_UNDERFLOW) ||
        throw(ArgumentError("invalid coordinate number"))
    value, pos
end

# Consume fixed-size numeric positions without a LazyValue for every component.
@inline function _position(::Type{C}, source) where {C<:Tuple}
    buf = JSON.getbuf(source)
    len = JSON.getlength(buf)
    pos = JSON.getpos(source)
    _coordinatedepth(source, 1)
    _position(C, buf, pos, len)
end

@inline function _coordinatedepth(source, levels)
    @static if isdefined(JSON, :getdepth)
        opts = JSON.getopts(source)
        JSON.getdepth(source) + levels <= opts.maxdepth ||
            JSON.toodeep(JSON.getpos(source), opts.maxdepth)
    end
    nothing
end

@inline function _position(::Type{C}, buf, pos, len) where {C<:Tuple}
    D, T = fieldcount(C), eltype(C)
    JSON.getbyte(buf, pos) == UInt8('[') ||
        throw(ArgumentError("coordinates must be arrays"))
    pos, b = _nextcoordinate(buf, pos + 1, len)
    values = ntuple(_ -> zero(T), Val(D))
    for i = 1:D
        b == UInt8(']') && throw(CoordinateDimensionError(D))
        value, pos = _coordinate(T, buf, pos, len)
        values = Base.setindex(values, value, i)
        pos, b = _nextcoordinate(buf, pos, len)
        if i < D
            b == UInt8(']') && throw(CoordinateDimensionError(D))
            b == UInt8(',') || throw(ArgumentError("expected coordinate comma"))
            pos, b = _nextcoordinate(buf, pos + 1, len)
            b == UInt8(']') && throw(ArgumentError("trailing coordinate comma"))
        end
    end
    b == UInt8(',') && throw(CoordinateDimensionError(D))
    b == UInt8(']') || throw(ArgumentError("expected end of coordinates"))
    values, pos + 1
end

@inline function StructUtils.make(
    style::CoordinateStyle,
    ::Type{Vector{C}},
    source::JSON.LazyValue,
) where {C<:Tuple}
    coordinates = C[]
    T = eltype(C)
    if T === Float32 || T === Float64
        buf = JSON.getbuf(source)
        len = JSON.getlength(buf)
        pos = JSON.getpos(source)
        _coordinatedepth(source, 1)
        JSON.getbyte(buf, pos) == UInt8('[') ||
            throw(ArgumentError("coordinates must be arrays"))
        pos, b = _nextcoordinate(buf, pos + 1, len)
        b == UInt8(']') && return coordinates, pos + 1
        _coordinatedepth(source, 2)
        while true
            coordinate, pos = _position(C, buf, pos, len)
            push!(coordinates, coordinate)
            pos, b = _nextcoordinate(buf, pos, len)
            b == UInt8(']') && return coordinates, pos + 1
            b == UInt8(',') || throw(ArgumentError("expected coordinate comma"))
            pos, b = _nextcoordinate(buf, pos + 1, len)
        end
    end
    pos = @inline JSON.applyarray(source) do _, value
        coordinate, stop = StructUtils.make(style, C, value)
        push!(coordinates, coordinate)
        stop
    end
    coordinates, pos
end

const CoordinateGeometry{D,T} = Union{
    Point{D,T},
    MultiPoint{D,T},
    LineString{D,T},
    MultiLineString{D,T},
    Polygon{D,T},
    MultiPolygon{D,T},
}

mutable struct GeometryState{C,T,S}
    coordinates::Union{Nothing,C}
    bbox::Union{Nothing,Vector{T}}
    style::S
end

@inline function (state::GeometryState{C,T})(key, source) where {C,T}
    if key == "coordinates"
        if StructUtils.nulllike(state.style, source)
            state.coordinates, pos = StructUtils.make(state.style, Nothing, source)
        else
            state.coordinates, pos = StructUtils.make(CoordinateStyle(), C, source)
        end
        return pos
    elseif key == "bbox"
        state.bbox, pos = StructUtils.make(state.style, Union{Nothing,Vector{T}}, source)
        return pos
    end
    nothing
end

function StructUtils.make(
    style::StructUtils.StructStyle,
    ::Type{G},
    source,
) where {D,T,G<:CoordinateGeometry{D,T}}
    C = Base.nonnothingtype(fieldtype(G, :coordinates))
    state = GeometryState{C,T,typeof(style)}(nothing, nothing, style)
    pos = JSON.applyobject(state, source)
    G(state.bbox, state.coordinates), pos
end

function _choosetype(mapping, source)
    kind = get(source, :type, nothing)
    kind === nothing && throw(ArgumentError("GeoJSON object is missing its type"))
    name = kind[]
    name isa String || throw(ArgumentError("GeoJSON type must be a string"))
    type = get(mapping, Symbol(name), nothing)
    type === nothing && throw(ArgumentError("Unknown GeoJSON type: $name"))
    type
end

function StructUtils.make(
    style::StructUtils.StructStyle,
    ::Type{GeoJSONT{D,T}},
    source,
) where {D,T}
    type = _choosetype(merge(geom_mapping(D, T), obj_mapping(D, T)), source)
    StructUtils.make(style, type, source)
end

function StructUtils.make(
    style::StructUtils.StructStyle,
    ::Type{AbstractGeometry{D,T}},
    source,
) where {D,T}
    type = _choosetype(geom_mapping(D, T), source)
    StructUtils.make(style, type, source)
end

# Nullable struct fields use the tagged entry point even when no tags are set.
StructUtils.make(
    style::StructUtils.StructStyle,
    type::Type{AbstractGeometry{D,T}},
    source,
    tags,
) where {D,T} = StructUtils.make(style, type, source)

function StructUtils.make(
    style::StructUtils.StructStyle,
    ::Type{FeatureCollection{D,T}},
    source,
) where {D,T}
    fields = NamedTuple{
        (:bbox, :features, :crs),
        Tuple{Union{Nothing,Vector{T}},Vector{Feature{D,T}},Union{Nothing,CRS}},
    }
    values, pos = StructUtils.make(style, fields, source)
    FeatureCollection{D,T}(values.bbox, values.features, values.crs), pos
end

function StructUtils.make(
    ::StructUtils.StructStyle,
    ::Type{LazyFeature{D,T}},
    source,
) where {D,T}
    pos = JSON.getpos(source)
    stop = JSON.skip(source)
    LazyFeature{D,T}(JSON.getbuf(source), pos, stop - pos), stop
end

_featurebytes(bytes::AbstractString, pos, len) = SubString(bytes, pos, pos + len - 1)
_featurebytes(bytes::AbstractVector{UInt8}, pos, len) = view(bytes, pos:(pos+len-1))

_parsedimensioned(input, type) =
    JSON.parse(input, type; dicttype = Dict{String,Any}, style = GeometryReadStyle())

function _parse(input, type)
    try
        _parsedimensioned(input, type)
    catch e
        e isa CoordinateDimensionError || rethrow()
        throw(ArgumentError(sprint(showerror, e)))
    end
end
