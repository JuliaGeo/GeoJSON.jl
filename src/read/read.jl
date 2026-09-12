import Mmap

"""
    read(src; ndim=nothing, numbertype=Float64, geometries=nothing, properties=true, lazy=false, mmap=false)
    read(src, ::Type{FeatureCollection{D,T,G,P}})
    read(src, ::Type{Feature{D,T,G,P}})
    read(src, ::Type{<:AbstractGeometry{D,T}})

Read GeoJSON into a [`FeatureCollection`](@ref), [`Feature`](@ref), or geometry, chosen by the
root `"type"`. The typed form parses straight into the given type and errors when the root
`"type"` disagrees; the keyword form builds that type from its keywords.

`src` is a file path, a JSON string, an `IO`, or a byte vector. A `String` naming an existing
file is read as a path.

| keyword | effect |
|---|---|
| `ndim` | coordinate dimension `D`: `2`, `3`, `4`, or `Val(N)` for an inferable return type. Discovered from the first coordinate when `nothing` |
| `numbertype` | coordinate number type `T` |
| `geometries` | geometry type(s) admitted, e.g. `(Point, Polygon)`; `nothing` admits all seven |
| `properties` | `true` for [`Properties`](@ref), `false` to skip the member, or a `NamedTuple`/struct schema |
| `lazy` | `true` defers feature parsing to access time |
| `mmap` | memory-map a path instead of reading it |

Every coordinate position must hold exactly `D` values; a [`DimMismatch`](@ref) names the
offending feature.

The typed form is the inferable entry: `read(src, FeatureCollection{2,Float64,Point{2,Float64},Properties})`
infers exactly that type. The keyword form resolves the root kind, `properties` and `lazy` at run
time, so its return type is a union over the seven geometries, `Feature`, `FeatureCollection` and
`LazyFeatureCollection`; `ndim=Val(N)` pins `D` on every member of that union.
"""
function read(src; ndim=nothing, numbertype::Type=Float64, geometries=nothing, properties=true,
              lazy::Bool=false, mmap::Bool=false, lazyfc::Bool=false)
    lazyfc && (Base.depwarn("`lazyfc=true` is deprecated; use `lazy=true`", :read; force=true); lazy = true)
    lazy && return read_lazy(src; ndim, numbertype, geometries, properties, mmap)
    bytes = _bytes(src, mmap)
    return _readkw(bytes, _ndim(ndim, bytes), numbertype, geometries, _proptype(properties))
end

read(src, ::Type{X}; mmap::Bool=false) where {X<:GeoJSONT} = _readtyped(_bytes(src, mmap), X)

read(src::GeoFormatTypes.GeoJSON; kw...) = read(GeoFormatTypes.val(src); kw...)
read(src::GeoFormatTypes.GeoJSON{<:AbstractDict}; kw...) = read(JSON.json(GeoFormatTypes.val(src)); kw...)
read(src::GeoFormatTypes.GeoJSON, ::Type{X}; kw...) where {X<:GeoJSONT} =
    read(GeoFormatTypes.val(src), X; kw...)
read(src::GeoFormatTypes.GeoJSON{<:AbstractDict}, ::Type{X}; kw...) where {X<:GeoJSONT} =
    read(JSON.json(GeoFormatTypes.val(src)), X; kw...)

function read_lazy(src; ndim, numbertype::Type, geometries, properties, mmap::Bool)
    bytes = _bytes(src, mmap)
    return _readlazy(bytes, _ndim(ndim, bytes), numbertype, geometries, _proptype(properties),
                     LazyFeatureCollection)
end

_bytes(src::AbstractVector{UInt8}, mmap::Bool) = src
_bytes(io::IO, mmap::Bool) = Base.read(io)
# A document opens with '{' or '[' and a path never does; `stat` on a document would throw
# ENAMETOOLONG for any 256-byte line.
function _bytes(src::AbstractString, mmap::Bool)
    _looksjson(src) && return Vector{UInt8}(codeunits(src))
    return mmap ? Mmap.mmap(src) : Base.read(src)
end
function _looksjson(s::AbstractString)
    for b in codeunits(s)
        (b == UInt8('{') || b == UInt8('[')) && return true
        (b == UInt8(' ') || b == UInt8('\n') || b == UInt8('\t') || b == UInt8('\r')) || return false
    end
    return false
end

_ndim(::Nothing, bytes) = max(discover_dim(bytes), 2)
_ndim(n::Integer, bytes) = Int(n)
_ndim(v::Val, bytes) = v

_proptype(keep::Bool) = keep ? Properties : Nothing
_proptype(::Type{P}) where {P} = P

_geomtype(::Nothing, ::Val{D}, ::Type{T}) where {D,T} = AnyGeometry{D,T}
_geomtype(g::Type, v::Val, ::Type{T}) where {T} = _geomtype((g,), v, T)
_geomtype(gs::Tuple, ::Val{D}, ::Type{T}) where {D,T} = Union{map(g -> _parameterize(g, D, T), gs)...}
_parameterize(g::UnionAll, D, T) = g{D,T}
_parameterize(g::DataType, D, T) = g

@noinline _badndim(D::Int) = throw(ArgumentError("ndim must be 2, 3, or 4; got $D"))

function _readkw(bytes, D::Int, ::Type{T}, geometries, ::Type{P}) where {T,P}
    if D == 2
        return _readkw(bytes, Val(2), T, geometries, P)
    elseif D == 3
        return _readkw(bytes, Val(3), T, geometries, P)
    elseif D == 4
        return _readkw(bytes, Val(4), T, geometries, P)
    end
    _badndim(D)
end
_readkw(bytes, ::Val{D}, ::Type{T}, geometries, ::Type{P}) where {D,T,P} =
    _read(bytes, Val(D), T, _geomtype(geometries, Val(D), T), P)

const ROOT_COLLECTION = 0x01
const ROOT_FEATURE = 0x02
const ROOT_GEOMETRY = 0x03

struct RootTypeGrab end
@inline function (::RootTypeGrab)(k::PtrString, v::LazyValues)
    k == "type" || return 0
    s, _ = parsestring(v)
    kind = s == "FeatureCollection" ? ROOT_COLLECTION : s == "Feature" ? ROOT_FEATURE : ROOT_GEOMETRY
    return EarlyReturn(kind)
end

function rootkind(x::LazyValue)
    gettype(x) == OBJECT || _notobject("a GeoJSON document")
    r = applyobject(RootTypeGrab(), x)
    r isa EarlyReturn || _notype("GeoJSON object")
    return r.value
end

function _read(bytes::AbstractVector{UInt8}, ::Val{D}, ::Type{T}, ::Type{G}, ::Type{P}) where {D,T,G,P}
    x = JSON.lazy(bytes)
    kind = rootkind(x)
    if kind == ROOT_COLLECTION
        return _parse(bytes, x, FeatureCollection{D,T,G,P}, Val(D))
    elseif kind == ROOT_FEATURE
        return _parse(bytes, x, Feature{D,T,G,P}, Val(D))
    end
    return _parse(bytes, x, G, Val(D))
end

_readtyped(bytes::AbstractVector{UInt8}, ::Type{X}) where {D,T,X<:GeoJSONT{D,T}} =
    _parse(bytes, JSON.lazy(bytes), X, Val(D))
@noinline _readtyped(bytes, ::Type{X}) where {X} =
    throw(ArgumentError("read(src, $X) needs the dimension and number type, e.g. FeatureCollection{2,Float64,AnyGeometry{2,Float64},Properties}"))

# The feature index costs a second scan, so it is computed only once a mismatch is known.
function _parse(bytes, x::LazyValue, ::Type{X}, ::Val{D}) where {X,D}
    err = try
        return JSON.parse(x, X; style=GeoJSONStyle())
    catch e
        (e isa DimMismatch && e.feature == 0) || rethrow()
        e::DimMismatch
    end
    throw(DimMismatch(err.expected, err.got, scan_dims(bytes; expect=D).badfeature))
end
