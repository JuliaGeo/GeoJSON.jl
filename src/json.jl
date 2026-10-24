# JSON's lazy parser passes an end position back from each materialization callback.
# Keep span access and the strict coordinate adapter in this file.
struct CoordinateStyle <: JSON.JSONStyle end
struct GeometryReadStyle <: StructUtils.StructStyle
    geometrymask::UInt8
end
GeometryReadStyle() = GeometryReadStyle(0x7f)

_geometrymask(::Nothing) = 0x7f
function _geometrymask(geometrytype)
    geometrytype isa Type || throw(ArgumentError(
        "geometrytype must be nothing, AbstractGeometry (with optional parameters), or a built-in GeoJSON geometry kind or union of these types"))
    _geometrymasktype(geometrytype)
end

Base.@assume_effects :foldable Base.@nospecializeinfer function _geometrymasktype(@nospecialize(selector))
    arm = Base.unwrap_unionall(selector)
    arm isa Union && return _geometrymasktype(arm.a) | _geometrymasktype(arm.b)
    arm isa DataType && arm.name === Base.unwrap_unionall(AbstractGeometry).name && return 0x7f
    kinds = (Point, MultiPoint, LineString, MultiLineString, Polygon, MultiPolygon, GeometryCollection)
    for i in eachindex(kinds)
        arm !== Union{} && arm <: kinds[i] && return UInt8(1 << (i - 1))
    end
    throw(ArgumentError("unsupported geometrytype selector: expected AbstractGeometry or built-in GeoJSON geometry kinds (with optional parameters)"))
end

_checkgeometry(style, index, kind) = nothing
_checkgeometry(style::JSON.JSONReadStyle{O,N,GeometryReadStyle}, index, kind) where {O,N} =
    _checkgeometry(StructUtils.parentstyle(style), index, kind)
function _checkgeometry(style::GeometryReadStyle, index, kind)
    style.geometrymask & UInt8(1 << (index - 1)) != 0 ||
        throw(ArgumentError("GeoJSON geometry kind $kind is excluded by geometrytype"))
    nothing
end

struct CoordinateDimensionError <: Exception
    expected::Int
end
Base.showerror(io::IO, e::CoordinateDimensionError) =
    print(io, "expected ", e.expected, " coordinate components")

mutable struct PositionState{D,T,S}
    values::NTuple{D,T}
    count::Int
    style::S

    function PositionState{D,T}(style::S) where {D,T,S}
        new{D,T,S}(ntuple(_ -> zero(T), Val(D)), 0, style)
    end
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

_readprops(::Type{P}, source) where {P} =
    StructUtils.make(JSON.JSONReadStyle{Dict{String,Any}}(nothing), P, source)

function _readprops(::Type{Dict{Symbol,Any}}, source)
    props = Dict{Symbol,Any}()
    style = JSON.JSONReadStyle{Dict{String,Any}}(nothing)
    pos = JSON.applyobject(source) do key, value
        name = Symbol(String(key))
        JSON.applyvalue(v -> (props[name] = v), value, style)
    end
    props, pos
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
    state = PositionState{D,T}(style)
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

    function GeometryState{C,T}(style::S) where {C,T,S}
        new{C,T,S}(nothing, nothing, style)
    end
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

function _readgeometry(style, ::Type{G}, source) where {D,T,G<:CoordinateGeometry{D,T}}
    C = Base.nonnothingtype(fieldtype(G, :coordinates))
    state = GeometryState{C,T}(style)
    pos = JSON.applyobject(state, source)
    G(state.bbox, state.coordinates), pos
end

function _readgeometry(style, ::Type{GeometryCollection{D,T}}, source) where {D,T}
    fields = NamedTuple{(:bbox, :geometries),Tuple{Union{Nothing,Vector{T}},Vector{Geometry{D,T}}}}
    values, pos = StructUtils.make(style, fields, source)
    GeometryCollection{D,T}(values.bbox, values.geometries), pos
end

function _typekey(key, value)
    key == "type" || return nothing
    JSON.gettype(value) == JSON.JSONTypes.STRING || throw(ArgumentError("GeoJSON type must be a string"))
    StructUtils.EarlyReturn(first(JSON.parsestring(value)))
end
function _kind(source)
    result = JSON.applyobject(_typekey, source)
    result isa StructUtils.EarlyReturn || throw(ArgumentError("GeoJSON object is missing its type"))
    result.value
end

# Each branch names a concrete type, including when G is a schema union.
function StructUtils.make(style::StructUtils.StructStyle, ::Type{G}, source) where {D,T,G<:AbstractGeometry{D,T}}
    kind = _kind(source)
    Base.@nexprs 7 i -> begin
        GT = (Point{D,T}, MultiPoint{D,T}, LineString{D,T}, MultiLineString{D,T},
              Polygon{D,T}, MultiPolygon{D,T}, GeometryCollection{D,T})[i]
        if kind == typestring(GT)
            GT <: G || throw(ArgumentError("geometry type is not in the schema"))
            _checkgeometry(style, i, typestring(GT))
            return _readgeometry(style, GT, source)
        end
    end
    throw(ArgumentError("Unknown GeoJSON geometry type"))
end
StructUtils.make(style::StructUtils.StructStyle, type::Type{G}, source, tags) where {G<:AbstractGeometry} =
    StructUtils.make(style, type, source)

function StructUtils.make(style::StructUtils.StructStyle, ::Type{GeoJSONT{D,T}}, source) where {D,T}
    kind = _kind(source)
    kind == "Feature" && return StructUtils.make(style, Feature{D,T}, source)
    kind == "FeatureCollection" && return StructUtils.make(style, FeatureCollection{D,T}, source)
    StructUtils.make(style, AbstractGeometry{D,T}, source)
end

StructUtils.make(style::StructUtils.StructStyle, ::Type{Feature{D,T}}, source) where {D,T} =
    StructUtils.make(style, Feature{D,T,DefaultProperties}, source)
StructUtils.make(style::StructUtils.StructStyle, ::Type{FeatureCollection{D,T}}, source) where {D,T} =
    StructUtils.make(style, FeatureCollection{D,T,DefaultProperties}, source)

mutable struct FeatureSink{D,T,P,S}
    style::S
    id::Any
    bbox::Union{Nothing,Vector{T}}
    geometry::Union{Nothing,Geometry{D,T}}
    properties::Union{Nothing,P}
    typed::Bool
    FeatureSink{D,T,P,S}(style) where {D,T,P,S} =
        new{D,T,P,S}(style, nothing, nothing, nothing, nothing, false)
end

function (f::FeatureSink{D,T,P})(key, value) where {D,T,P}
    if key == "geometry"
        if JSON.gettype(value) == JSON.JSONTypes.NULL
            f.geometry = nothing
            return nothing
        end
        f.geometry, pos = StructUtils.make(f.style, Geometry{D,T}, value)
        return pos
    elseif key == "properties"
        if JSON.gettype(value) == JSON.JSONTypes.NULL
            f.properties = nothing
            return nothing
        end
        f.properties, pos = _readprops(Base.nonnothingtype(P), value)
        return pos
    elseif key == "id"
        f.id, pos = StructUtils.make(JSON.JSONReadStyle{Dict{String,Any}}(nothing), Any, value)
        return pos
    elseif key == "bbox"
        f.bbox, pos = StructUtils.make(f.style, Union{Nothing,Vector{T}}, value)
        return pos
    elseif key == "type"
        JSON.gettype(value) == JSON.JSONTypes.STRING || throw(ArgumentError("GeoJSON type must be a string"))
        kind, pos = JSON.parsestring(value)
        kind == "Feature" || throw(ArgumentError("expected a Feature"))
        f.typed = true
        return pos
    end
    nothing
end

_emptyproperties(::Type{P}) where {P} = Nothing <: P ? nothing : throw(ArgumentError("properties requires schema fields"))
_emptyproperties(::Type{P}) where {P<:NamedTuple} =
    all(FT -> Missing <: FT, fieldtypes(P)) ? P(ntuple(_ -> missing, Val(fieldcount(P)))) :
    throw(ArgumentError("properties requires schema fields"))

function StructUtils.make(style::StructUtils.StructStyle, ::Type{Feature{D,T,P}}, source) where {D,T,P}
    sink = FeatureSink{D,T,P,typeof(style)}(style)
    pos = JSON.applyobject(sink, source)
    sink.typed || throw(ArgumentError("expected a Feature"))
    props = sink.properties
    props === nothing && (props = _emptyproperties(P))
    Feature{D,T,P}(sink.id, sink.bbox, sink.geometry, props), pos
end

struct ArraySink{E,S}
    style::S
    values::Vector{E}
end
function (sink::ArraySink{E})(_, value) where {E}
    item, pos = StructUtils.make(sink.style, E, value)
    push!(sink.values, item)
    pos
end
function _readarray(style, ::Type{E}, source) where {E}
    values = E[]
    pos = JSON.applyarray(ArraySink(style, values), source)
    values, pos::Int
end

mutable struct CollectionSink{D,T,P,S}
    style::S
    bbox::Union{Nothing,Vector{T}}
    features::Vector{Feature{D,T,P}}
    crs::Union{Nothing,CRS}
    typed::Bool
end

function (f::CollectionSink{D,T,P})(key, value) where {D,T,P}
    if key == "features"
        f.features, pos = _readarray(f.style, Feature{D,T,P}, value)
        return pos
    elseif key == "bbox"
        f.bbox, pos = StructUtils.make(f.style, Union{Nothing,Vector{T}}, value)
        return pos
    elseif key == "crs"
        f.crs, pos = StructUtils.make(JSON.JSONReadStyle{Dict{String,Any}}(nothing), Union{Nothing,CRS}, value)
        return pos
    elseif key == "type"
        JSON.gettype(value) == JSON.JSONTypes.STRING || throw(ArgumentError("GeoJSON type must be a string"))
        kind, pos = JSON.parsestring(value)
        kind == "FeatureCollection" || throw(ArgumentError("expected a FeatureCollection"))
        f.typed = true
        return pos
    end
    nothing
end

function StructUtils.make(style::StructUtils.StructStyle, ::Type{FeatureCollection{D,T,P}}, source) where {D,T,P}
    sink = CollectionSink{D,T,P,typeof(style)}(style, nothing, Feature{D,T,P}[], nothing, false)
    pos = JSON.applyobject(sink, source)
    sink.typed || throw(ArgumentError("expected a FeatureCollection"))
    FeatureCollection{D,T,P}(sink.bbox, sink.features, sink.crs), pos
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

_parsedimensioned(input, type, style=GeometryReadStyle()) =
    JSON.parse(input, type; style)

function _parse(input, type, style=GeometryReadStyle())
    try
        _parsedimensioned(input, type, style)
    catch e
        e isa CoordinateDimensionError || rethrow()
        throw(ArgumentError(sprint(showerror, e)))
    end
end
