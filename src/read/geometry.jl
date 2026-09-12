const KUNKNOWN = 0x00
const KPOINT = 0x01
const KLINESTRING = 0x02
const KPOLYGON = 0x03
const KMULTIPOINT = 0x04
const KMULTILINESTRING = 0x05
const KMULTIPOLYGON = 0x06
const KGEOMETRYCOLLECTION = 0x07

const KIND_NAMES = ("Point", "LineString", "Polygon", "MultiPoint",
                    "MultiLineString", "MultiPolygon", "GeometryCollection")
kindname(k::UInt8) = k == KUNKNOWN ? "unknown" : KIND_NAMES[k]

# Coordinate nesting depth of each kind; 0 for GeometryCollection, which has none.
kinddepth(k::UInt8) =
    k == KPOINT ? 1 :
    (k == KLINESTRING || k == KMULTIPOINT) ? 2 :
    (k == KPOLYGON || k == KMULTILINESTRING) ? 3 :
    k == KMULTIPOLYGON ? 4 : 0

@noinline function _kindslow(s::PtrString)
    str = convert(String, s)
    for (i, name) in enumerate(KIND_NAMES)
        str == name && return UInt8(i)
    end
    return KUNKNOWN
end

# Byte length separates six of the seven names; only LineString and MultiPoint collide.
@inline function geomkind(s::PtrString)
    s.escaped && return _kindslow(s)
    n = s.len
    if n == 7
        return s == "Polygon" ? KPOLYGON : KUNKNOWN
    elseif n == 12
        return s == "MultiPolygon" ? KMULTIPOLYGON : KUNKNOWN
    elseif n == 5
        return s == "Point" ? KPOINT : KUNKNOWN
    elseif n == 10
        return s == "LineString" ? KLINESTRING : (s == "MultiPoint" ? KMULTIPOINT : KUNKNOWN)
    elseif n == 15
        return s == "MultiLineString" ? KMULTILINESTRING : KUNKNOWN
    elseif n == 18
        return s == "GeometryCollection" ? KGEOMETRYCOLLECTION : KUNKNOWN
    end
    return KUNKNOWN
end

@noinline _badkind(s::PtrString) =
    throw(ArgumentError("\"$(convert(String, s))\" is not a GeoJSON geometry type"))
@noinline _baddepth(d::Int) =
    throw(ArgumentError("\"coordinates\" nested $d deep; GeoJSON geometries nest 1 to 4 deep"))
@noinline _depthmismatch(k::UInt8, d::UInt8) =
    throw(ArgumentError("\"coordinates\" nested $(Int(d)) deep on a $(kindname(k)), which needs depth $(kinddepth(k))"))
@noinline _coordsoncollection() =
    throw(ArgumentError("a GeometryCollection holds \"geometries\", not \"coordinates\""))
# Names the schema by its member kinds: every `<:` folds at inference, so the message is
# built from string literals and needs no type printing (a trim hazard).
@noinline function _badschema(k::UInt8, ::Type{G}) where {D,T,G<:AbstractGeometry{D,T}}
    names = String[]
    Point{D,T} <: G && push!(names, "Point")
    LineString{D,T} <: G && push!(names, "LineString")
    Polygon{D,T} <: G && push!(names, "Polygon")
    MultiPoint{D,T} <: G && push!(names, "MultiPoint")
    MultiLineString{D,T} <: G && push!(names, "MultiLineString")
    MultiPolygon{D,T} <: G && push!(names, "MultiPolygon")
    GeometryCollection{D,T} <: G && push!(names, "GeometryCollection")
    throw(ArgumentError(string("geometry type ", kindname(k), " is not in the schema (",
                               join(names, ", "), ")")))
end

# One slot per coordinate nesting depth; only the slot the parsed depth names is ever filled.
mutable struct GeomSink{D,T,S}
    st::S
    kind::UInt8
    depth::UInt8
    bbox::Union{Nothing,Vector{T}}
    point::Union{Nothing,NTuple{D,T}}
    ring::Union{Nothing,Ring{D,T}}
    surface::Union{Nothing,Surface{D,T}}
    solid::Union{Nothing,Solid{D,T}}
    geoms::Union{Nothing,Vector{AnyGeometry{D,T}}}
    extras::Extras
    deferpos::Int
    defertype::JSONTypes.T
end

GeomSink{D,T}(st::S) where {D,T,S} =
    GeomSink{D,T,S}(st, KUNKNOWN, 0x00, nothing, nothing, nothing, nothing, nothing, nothing,
                    nothing, 0, NULL)

# Coordinate nesting depth names the shape up to one binary choice that "type" resolves
# whenever it arrives, so a "type"-last document parses its payload on first sight. An empty
# array stays ambiguous (0).
@inline function arraydepth(v::LazyValues)
    buf = getbuf(v)
    pos = getpos(v)
    len = getlength(buf)
    d = 0
    while pos <= len
        b = getbyte(buf, pos)
        if b == UInt8('[')
            d += 1
        elseif !(b == UInt8(' ') || b == UInt8('\t') || b == UInt8('\n') || b == UInt8('\r'))
            return b == UInt8(']') ? 0 : d
        end
        pos += 1
    end
    return 0
end

function readdepth!(f::GeomSink{D,T}, v::LazyValues, d::Int) where {D,T}
    st = f.st
    f.depth = d % UInt8
    if d == 1
        val, pos = readposition(st, Val(D), T, v)
        f.point = val
        return pos
    elseif d == 2
        val, pos = readring(st, Val(D), T, v)
        f.ring = val
        return pos
    elseif d == 3
        val, pos = readsurface(st, Val(D), T, v)
        f.surface = val
        return pos
    elseif d == 4
        val, pos = readsolid(st, Val(D), T, v)
        f.solid = val
        return pos
    end
    return _baddepth(d)
end

struct GeomArraySink{D,T,S}
    st::S
    out::Vector{AnyGeometry{D,T}}
end

function (s::GeomArraySink{D,T})(_, v::LazyValues) where {D,T}
    g, pos = StructUtils.make(s.st, AnyGeometry{D,T}, v)
    push!(s.out, g)
    return pos
end

@noinline function readgeoms(st, ::Val{D}, ::Type{T}, v::LazyValues) where {D,T}
    gettype(v) == ARRAY || throw(ArgumentError("\"geometries\" must be an array"))
    out = AnyGeometry{D,T}[]
    pos = applyarray(GeomArraySink{D,T,typeof(st)}(st, out), v)
    return out, pos::Int
end

function (f::GeomSink{D,T})(k::PtrString, v::LazyValues) where {D,T}
    if k == "coordinates"
        gettype(v) == NULL && return 0
        d = f.kind == KUNKNOWN ? arraydepth(v) : kinddepth(f.kind)
        if d == 0
            f.deferpos = getpos(v)
            f.defertype = gettype(v)
            return 0
        end
        return readdepth!(f, v, d)
    elseif k == "type"
        s, pos = parsestring(v)
        f.kind = geomkind(s)
        f.kind == KUNKNOWN && _badkind(s)
        return pos
    elseif k == "geometries"
        gettype(v) == NULL && return 0
        val, pos = readgeoms(f.st, Val(D), T, v)
        f.geoms = val
        return pos
    elseif k == "bbox"
        gettype(v) == NULL && return 0
        val, pos = StructUtils.make(f.st, Vector{T}, v)
        f.bbox = val
        return pos
    end
    ex, pos = _extra!(f.extras, k, v)
    f.extras = ex
    return pos
end

function scan!(f::GeomSink{D,T}, src::LazyValues) where {D,T}
    pos = applyobject(f, src)::Int
    if f.deferpos != 0
        f.kind == KUNKNOWN && _notype("geometry")
        d = kinddepth(f.kind)
        d == 0 && _coordsoncollection()
        readdepth!(f, LazyValue(getbuf(src), f.deferpos, f.defertype, getopts(src), false), d)
    end
    return pos
end

# `Point{D,T} <: G` folds at inference, so the return type is a union over exactly the kinds
# in `G` and the other branches compile to the schema error.
function build(f::GeomSink{D,T}, ::Type{G}) where {D,T,G}
    k = f.kind
    k == KUNKNOWN && _notype("geometry")
    d = f.depth
    d == 0x00 || d == kinddepth(k) % UInt8 || _depthmismatch(k, d)
    b = f.bbox
    e = f.extras
    if k == KPOLYGON
        Polygon{D,T} <: G || _badschema(k, G)
        return Polygon{D,T}(b, f.surface, e)
    elseif k == KMULTIPOLYGON
        MultiPolygon{D,T} <: G || _badschema(k, G)
        return MultiPolygon{D,T}(b, f.solid, e)
    elseif k == KPOINT
        Point{D,T} <: G || _badschema(k, G)
        return Point{D,T}(b, f.point, e)
    elseif k == KLINESTRING
        LineString{D,T} <: G || _badschema(k, G)
        return LineString{D,T}(b, f.ring, e)
    elseif k == KMULTIPOINT
        MultiPoint{D,T} <: G || _badschema(k, G)
        return MultiPoint{D,T}(b, f.ring, e)
    elseif k == KMULTILINESTRING
        MultiLineString{D,T} <: G || _badschema(k, G)
        return MultiLineString{D,T}(b, f.surface, e)
    end
    GeometryCollection{D,T} <: G || _badschema(k, G)
    gs = f.geoms
    return GeometryCollection{D,T}(b, gs === nothing ? AnyGeometry{D,T}[] : gs, e)
end

function StructUtils.make(st::JSON.JSONStyle, ::Type{G}, src::LazyValues) where {D,T,G<:AbstractGeometry{D,T}}
    gettype(src) == OBJECT || _notobject("a geometry")
    f = GeomSink{D,T}(st)
    pos = scan!(f, src)
    return build(f, G), pos
end
StructUtils.make(st::JSON.JSONStyle, ::Type{G}, src::LazyValues, tags) where {D,T,G<:AbstractGeometry{D,T}} =
    StructUtils.make(st, G, src)

@noinline _unparameterized(::Type{G}) where {G} =
    throw(ArgumentError("geometry type $G needs its dimension and number type, e.g. $(G){2,Float64}"))
StructUtils.make(::JSON.JSONStyle, ::Type{G}, ::LazyValues) where {G<:AbstractGeometry} = _unparameterized(G)
StructUtils.make(::JSON.JSONStyle, ::Type{G}, ::LazyValues, tags) where {G<:AbstractGeometry} = _unparameterized(G)
