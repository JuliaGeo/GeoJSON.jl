"""
    LazyFeatureCollection{D,T,G,P,B} <: AbstractFeatureCollection{D,T}

A FeatureCollection that keeps the document bytes and a byte offset per feature; `bbox` and
foreign members parse at read time, features parse at access time. Built by
`read(src; lazy=true)` or `read(src, LazyFeatureCollection{D,T,G,P})`.

| access | cost | yields |
|---|---|---|
| `fc[i]`, iteration, `collect`, `Tables.rows` | one feature parse per element | `Feature{D,T,G,P}` |
| `lazyfeature(fc, i)`, `lazyfeatures(fc)`, `foreach(f, fc)` | none | [`LazyFeature`](@ref) |
| `features(fc)` | every feature | `Vector{Feature{D,T,G,P}}` |
| `Tables.schema(fc)`, `fc.column` | one pass over properties and geometry `"type"` | `Tables.Schema`, `Vector` |

Every lazy value borrows `buf`: mutating the buffer, or unmapping a memory-mapped one,
invalidates the collection and everything derived from it.
"""
struct LazyFeatureCollection{D,T,G,P,B<:AbstractVector{UInt8}} <: AbstractFeatureCollection{D,T}
    buf::B
    offsets::Vector{Int}
    bbox::Union{Nothing,Vector{T}}
    extras::Extras
end

"""
    LazyFeature{D,T,G,P,B} <: GeoJSONT{D,T}

One feature addressed by its byte offset. Each accessor (`geometry`, `properties`, `id`,
`bbox`, `extras`, `f["key"]`, `f.key`) walks the feature object once and parses only the
member it needs; [`materialize`](@ref) parses the whole feature into a `Feature{D,T,G,P}`.
"""
struct LazyFeature{D,T,G,P,B<:AbstractVector{UInt8}} <: GeoJSONT{D,T}
    buf::B
    pos::Int
end

"""
    LazyGeometry{D,T,B} <: GeoJSONT{D,T}

A geometry addressed by its byte offset: `GeoInterface.geomtrait` and `typestring` read the
`"type"` member, `GeoInterface.ncoord` is `D`, and [`materialize`](@ref) parses it.
"""
struct LazyGeometry{D,T,B<:AbstractVector{UInt8}} <: GeoJSONT{D,T}
    buf::B
    pos::Int
end

"""
    LazyStream{D,T,G,P,B}
    LazyStream(src; ndim=nothing, numbertype=Float64, geometries=nothing, properties=true, mmap=false)

A FeatureCollection walked once by `foreach(f, stream)`, which hands `f` a [`LazyFeature`](@ref)
per feature with no offset table. `read(src, LazyStream{D,T,G,P})` names the schema directly.
"""
struct LazyStream{D,T,G,P,B<:AbstractVector{UInt8}}
    buf::B
end

const LAZY_OPTS = JSON.LazyOptions()

_buf(x) = getfield(x, :buf)
_pos(x) = getfield(x, :pos)
_offsets(fc::LazyFeatureCollection) = getfield(fc, :offsets)

# The one place a `LazyValue` is built from a byte offset; `isroot=false` skips the
# end-of-input check.
@inline lazyat(buf, pos::Int) = JSON._lazy(buf, pos, getlength(buf), getbyte(buf, pos), LAZY_OPTS, false)
@inline lazyat(x::Union{LazyFeature,LazyGeometry}) = lazyat(_buf(x), _pos(x))

@inline _isnull(buf, pos::Int) = getbyte(buf, pos) == UInt8('n')

struct KeyPos
    key::String
end
@inline (s::KeyPos)(k::PtrString, v::LazyValues) = k == s.key ? EarlyReturn(getpos(v)) : 0

# Offset of `key`'s value in the object at `pos`, or 0 when absent; an `Int` return stays unboxed.
@inline function memberpos(buf, pos::Int, key::String)
    r = applyobject(KeyPos(key), lazyat(buf, pos))
    return r isa EarlyReturn ? r.value : 0
end

struct TypeKind end
@inline (::TypeKind)(k::PtrString, v::LazyValues) =
    k == "type" ? EarlyReturn(geomkind(first(parsestring(v)))) : 0

function geomkindat(v::LazyValues)
    r = applyobject(TypeKind(), v)
    return r isa EarlyReturn ? r.value : KUNKNOWN
end

# --- the scan ------------------------------------------------------------------

struct OffsetSink
    offsets::Vector{Int}
end
@inline function (s::OffsetSink)(_, v::LazyValues)
    push!(s.offsets, getpos(v))
    return 0
end

struct LazyCollectionSink{C<:CollectionSink}
    eager::C
    offsets::Vector{Int}
end

function (s::LazyCollectionSink)(k::PtrString, v::LazyValues)
    k == "features" || return s.eager(k, v)
    gettype(v) == ARRAY || throw(ArgumentError("\"features\" must be an array"))
    return applyarray(OffsetSink(s.offsets), v)
end

function StructUtils.make(st::JSON.JSONStyle, ::Type{LazyFeatureCollection{D,T,G,P}}, src::LazyValues) where {D,T,G,P}
    gettype(src) == OBJECT || _notobject("a FeatureCollection")
    eager = CollectionSink{D,T,G,P,typeof(st)}(st, nothing, Feature{D,T,G,P}[], nothing, false)
    offsets = Int[]
    pos = applyobject(LazyCollectionSink(eager, offsets), src)::Int
    eager.typed || _notype("FeatureCollection")
    buf = getbuf(src)
    return LazyFeatureCollection{D,T,G,P,typeof(buf)}(buf, offsets, eager.bbox, eager.extras), pos
end
StructUtils.make(st::JSON.JSONStyle, ::Type{LazyFeatureCollection{D,T,G,P}}, src::LazyValues, tags) where {D,T,G,P} =
    StructUtils.make(st, LazyFeatureCollection{D,T,G,P}, src)

# --- entry points ------------------------------------------------------------

function _readlazy(bytes, D::Int, ::Type{T}, geometries, ::Type{P}, ::Type{L}) where {T,P,L}
    if D == 2
        return _readlazy(bytes, Val(2), T, geometries, P, L)
    elseif D == 3
        return _readlazy(bytes, Val(3), T, geometries, P, L)
    elseif D == 4
        return _readlazy(bytes, Val(4), T, geometries, P, L)
    end
    _badndim(D)
end
_readlazy(bytes, ::Val{D}, ::Type{T}, geometries, ::Type{P}, ::Type{L}) where {D,T,P,L} =
    _readlazy(bytes, L{D,T,_geomtype(geometries, Val(D), T),P})

_readlazy(bytes::AbstractVector{UInt8}, ::Type{LazyStream{D,T,G,P}}) where {D,T,G,P} =
    LazyStream{D,T,G,P,typeof(bytes)}(bytes)

# A root that is a bare Feature or geometry is small, so it reads eagerly.
function _readlazy(bytes::AbstractVector{UInt8}, ::Type{LazyFeatureCollection{D,T,G,P}}) where {D,T,G,P}
    x = JSON.lazy(bytes)
    rootkind(x) == ROOT_COLLECTION || return _read(bytes, Val(D), T, G, P)
    return _parse(bytes, x, LazyFeatureCollection{D,T,G,P}, Val(D))
end

function LazyStream(src; ndim=nothing, numbertype::Type=Float64, geometries=nothing,
                    properties=true, mmap::Bool=false)
    bytes = _bytes(src, mmap)
    return _readlazy(bytes, _ndim(ndim, bytes), numbertype, geometries, _proptype(properties), LazyStream)
end
read(src, ::Type{LazyStream{D,T,G,P}}; mmap::Bool=false) where {D,T,G,P} =
    _readlazy(_bytes(src, mmap), LazyStream{D,T,G,P})

# --- collection: indexing, iteration, materialization ----------------------------

Base.length(fc::LazyFeatureCollection) = length(_offsets(fc))
Base.eachindex(fc::LazyFeatureCollection) = Base.OneTo(length(fc))
Base.eltype(::Type{<:LazyFeatureCollection{D,T,G,P}}) where {D,T,G,P} = Feature{D,T,G,P}

function _feature(buf, pos::Int, ::Type{F}, i::Int) where {F<:Feature}
    try
        return JSON.parse(lazyat(buf, pos), F; style=GeoJSONStyle())
    catch e
        (e isa DimMismatch && e.feature == 0) && throw(DimMismatch(e.expected, e.got, i))
        rethrow()
    end
end

@inline function Base.getindex(fc::LazyFeatureCollection{D,T,G,P}, i::Int) where {D,T,G,P}
    @boundscheck checkbounds(_offsets(fc), i)
    return _feature(_buf(fc), @inbounds(_offsets(fc)[i]), Feature{D,T,G,P}, i)
end
Base.getindex(fc::LazyFeatureCollection{D,T,G,P}, r::Union{UnitRange,Vector}) where {D,T,G,P} =
    Feature{D,T,G,P}[fc[i] for i in r]

"""
    features(fc::LazyFeatureCollection) -> Vector{Feature}

Materializes every feature.
"""
features(fc::LazyFeatureCollection) = collect(fc)

"""
    lazyfeature(fc, i) -> LazyFeature
    lazyfeatures(fc) -> AbstractVector{LazyFeature}

The features of a [`LazyFeatureCollection`](@ref) as unparsed [`LazyFeature`](@ref) views.
"""
@inline function lazyfeature(fc::LazyFeatureCollection{D,T,G,P,B}, i::Int) where {D,T,G,P,B}
    @boundscheck checkbounds(_offsets(fc), i)
    return LazyFeature{D,T,G,P,B}(_buf(fc), @inbounds(_offsets(fc)[i]))
end

struct LazyFeatures{D,T,G,P,B} <: AbstractVector{LazyFeature{D,T,G,P,B}}
    fc::LazyFeatureCollection{D,T,G,P,B}
end
lazyfeatures(fc::LazyFeatureCollection) = LazyFeatures(fc)
Base.size(v::LazyFeatures) = (length(v.fc),)
@inline function Base.getindex(v::LazyFeatures, i::Int)
    @boundscheck checkbounds(v, i)
    return @inbounds lazyfeature(v.fc, i)
end

"""
    foreach(f, fc::LazyFeatureCollection)

Calls `f` on each feature as a [`LazyFeature`](@ref), parsing nothing up front.
"""
function Base.foreach(f, fc::LazyFeatureCollection)
    for i in 1:length(fc)
        f(@inbounds lazyfeature(fc, i))
    end
    return nothing
end

Base.:(==)(a::LazyFeatureCollection, b::AbstractFeatureCollection) = _fceq(a, b)
Base.:(==)(a::AbstractFeatureCollection, b::LazyFeatureCollection) = _fceq(a, b)
Base.:(==)(a::LazyFeatureCollection, b::LazyFeatureCollection) = _fceq(a, b)
_fceq(a, b) = bbox(a) == bbox(b) && isequal(extras(a), extras(b)) && length(a) == length(b) &&
              all(a[i] == b[i] for i in 1:length(a))

Base.show(io::IO, fc::LazyFeatureCollection) = print(io, "LazyFeatureCollection with ", length(fc), " Features")

# --- streaming: one walk, no offsets --------------------------------------------

struct StreamSink{D,T,G,P,B,F}
    f::F
    buf::B
end
@inline function (s::StreamSink{D,T,G,P,B})(_, v::LazyValues) where {D,T,G,P,B}
    s.f(LazyFeature{D,T,G,P,B}(s.buf, getpos(v)))
    return 0
end

struct StreamRoot{S}
    sink::S
end
(r::StreamRoot)(k::PtrString, v::LazyValues) = k == "features" ? applyarray(r.sink, v) : 0

function Base.foreach(f, s::LazyStream{D,T,G,P,B}) where {D,T,G,P,B}
    x = JSON.lazy(s.buf)
    gettype(x) == OBJECT || _notobject("a FeatureCollection")
    applyobject(StreamRoot(StreamSink{D,T,G,P,B,typeof(f)}(f, s.buf)), x)
    return nothing
end

# --- one feature ----------------------------------------------------------------

"""
    materialize(x::LazyFeature) -> Feature
    materialize(x::LazyGeometry) -> geometry

Parse the whole value.
"""
materialize(f::LazyFeature{D,T,G,P}) where {D,T,G,P} = _feature(_buf(f), _pos(f), Feature{D,T,G,P}, 0)
materialize(g::LazyGeometry{D,T}) where {D,T} = JSON.parse(lazyat(g), AnyGeometry{D,T}; style=GeoJSONStyle())

@inline memberpos(f::Union{LazyFeature,LazyGeometry}, key::String) = memberpos(_buf(f), _pos(f), key)

function id(f::LazyFeature)
    pos = memberpos(f, "id")
    pos == 0 && return nothing
    return first(readid(lazyat(_buf(f), pos)))
end

function _bboxat(buf, pos::Int, ::Type{T}) where {T}
    (pos == 0 || _isnull(buf, pos)) && return nothing
    return JSON.parse(lazyat(buf, pos), Vector{T})
end
bbox(f::LazyFeature{D,T}) where {D,T} = _bboxat(_buf(f), memberpos(f, "bbox"), T)
bbox(g::LazyGeometry{D,T}) where {D,T} = _bboxat(_buf(g), memberpos(g, "bbox"), T)

function geometry(f::LazyFeature{D,T,G}) where {D,T,G}
    buf = _buf(f)
    pos = memberpos(f, "geometry")
    (pos == 0 || _isnull(buf, pos)) && return nothing
    return JSON.parse(lazyat(buf, pos), G; style=GeoJSONStyle())
end

"""
    lazygeometry(f::LazyFeature) -> Union{Nothing,LazyGeometry}
"""
function lazygeometry(f::LazyFeature{D,T,G,P,B}) where {D,T,G,P,B}
    buf = _buf(f)
    pos = memberpos(f, "geometry")
    (pos == 0 || _isnull(buf, pos)) && return nothing
    return LazyGeometry{D,T,B}(buf, pos)
end

# The style `JSON.parse` hands `make`, for parsing a properties object on its own.
const READ_STYLE = JSON.JSONReadStyle{JSON.DEFAULT_OBJECT_TYPE}(nothing, GeoJSONStyle(), true)

properties(f::LazyFeature{D,T,G,Nothing}) where {D,T,G} = nothing
function properties(f::LazyFeature{D,T,G,P}) where {D,T,G,P}
    buf = _buf(f)
    pos = memberpos(f, "properties")
    (pos == 0 || _isnull(buf, pos)) && return emptyprops(P)
    return first(readprops(READ_STYLE, P, lazyat(buf, pos)))
end

mutable struct ExtrasSink
    extras::Extras
end
function (s::ExtrasSink)(k::PtrString, v::LazyValues)
    (k == "type" || k == "id" || k == "bbox" || k == "geometry" || k == "properties") && return 0
    ex, pos = _extra!(s.extras, k, v)
    s.extras = ex
    return pos
end
function extras(f::LazyFeature)
    s = ExtrasSink(nothing)
    applyobject(s, lazyat(f))
    return s.extras
end

# Offset of property `key`, or 0 when the schema or the document lacks it.
_proppos(f::LazyFeature{D,T,G,Nothing}, key::String) where {D,T,G} = 0
function _proppos(f::LazyFeature{D,T,G,P}, key::String) where {D,T,G,P}
    P <: AbstractDict || hasfield(P, Symbol(key)) || return 0
    pos = memberpos(f, "properties")
    (pos == 0 || _isnull(_buf(f), pos)) && return 0
    return memberpos(_buf(f), pos, key)
end

# Strings, null and booleans parse in place, skipping the box JSON's untyped parse allocates per value.
function _parseany(v::LazyValue)
    t = gettype(v)
    if t == STRING
        buf = getbuf(v)
        GC.@preserve buf return convert(String, first(parsestring(v)))
    elseif t == NULL
        return nothing
    elseif t == JSONTypes.TRUE
        return true
    elseif t == JSONTypes.FALSE
        return false
    end
    return JSON.parse(v)
end

_propvalue(f::LazyFeature{D,T,G,P}, key::String, pos::Int) where {D,T,G,P<:AbstractDict} =
    _parseany(lazyat(_buf(f), pos))
_propvalue(f::LazyFeature{D,T,G,P}, key::String, pos::Int) where {D,T,G,P} =
    JSON.parse(lazyat(_buf(f), pos), fieldtype(P, Symbol(key)); style=GeoJSONStyle())

function Base.getindex(f::LazyFeature, key::Union{AbstractString,Symbol})
    k = String(key)
    pos = _proppos(f, k)
    pos == 0 && throw(KeyError(key))
    return _propvalue(f, k, pos)
end
function Base.get(f::LazyFeature, key::Union{AbstractString,Symbol}, default)
    k = String(key)
    pos = _proppos(f, k)
    return pos == 0 ? default : _propvalue(f, k, pos)
end
Base.haskey(f::LazyFeature, key::Union{AbstractString,Symbol}) = _proppos(f, String(key)) != 0

function _field(f::LazyFeature, k::Symbol)
    k === :geometry && return geometry(f)
    k === :properties && return properties(f)
    k === :id && return id(f)
    k === :bbox && return bbox(f)
    k === :extras && return extras(f)
    return missing
end

function Base.getproperty(f::LazyFeature, k::Symbol)
    key = String(k)
    pos = _proppos(f, key)
    v = pos == 0 ? _field(f, k) : _propvalue(f, key, pos)
    return v === nothing ? missing : v
end

struct NameSink
    names::Vector{Symbol}
end
function (s::NameSink)(k::PtrString, ::LazyValues)
    sym = Symbol(convert(String, k))
    sym === :geometry || push!(s.names, sym)
    return 0
end

_pushnames!(names::Vector{Symbol}, f::LazyFeature{D,T,G,Nothing}) where {D,T,G} = names
_pushnames!(names::Vector{Symbol}, f::LazyFeature{D,T,G,P}) where {D,T,G,P} = _pushnames!(names, fieldnames(P))
function _pushnames!(names::Vector{Symbol}, f::LazyFeature{D,T,G,P}) where {D,T,G,P<:AbstractDict}
    buf = _buf(f)
    pos = memberpos(f, "properties")
    (pos == 0 || _isnull(buf, pos)) && return names
    applyobject(NameSink(names), lazyat(buf, pos))
    return names
end
Base.propertynames(f::LazyFeature)::Tuple{Vararg{Symbol}} = Tuple(_pushnames!(Symbol[:geometry], f))

Base.:(==)(a::LazyFeature, b::Feature) = materialize(a) == b
Base.:(==)(a::Feature, b::LazyFeature) = a == materialize(b)
Base.:(==)(a::LazyFeature, b::LazyFeature) = materialize(a) == materialize(b)

function Base.show(io::IO, f::LazyFeature{D,T}) where {D,T}
    g = lazygeometry(f)
    print(io, "LazyFeature with ", D, "D ", g === nothing ? "null" : typestring(g), " geometry and ",
          length(propertynames(f)), " properties: ", propertynames(f))
end

# --- one geometry ----------------------------------------------------------------

const KIND_TYPES = (Point, LineString, Polygon, MultiPoint, MultiLineString, MultiPolygon, GeometryCollection)
const KIND_TRAITS = (GI.PointTrait(), GI.LineStringTrait(), GI.PolygonTrait(), GI.MultiPointTrait(),
                     GI.MultiLineStringTrait(), GI.MultiPolygonTrait(), GI.GeometryCollectionTrait())
kindtype(k::UInt8, ::Val{D}, ::Type{T}) where {D,T} = KIND_TYPES[k]{D,T}

function kind(g::LazyGeometry)
    k = geomkindat(lazyat(g))
    k == KUNKNOWN && _notype("geometry")
    return k
end
typestring(g::LazyGeometry) = kindname(kind(g))
Base.show(io::IO, g::LazyGeometry{D}) where {D} = print(io, "Lazy ", D, "D ", typestring(g))

GI.isgeometry(::Type{<:LazyGeometry}) = true
GI.geomtrait(g::LazyGeometry) = KIND_TRAITS[kind(g)]
GI.ncoord(::GI.AbstractTrait, ::LazyGeometry{D}) where {D} = D

# --- GeoInterface and Tables ------------------------------------------------------

GI.isfeature(::Type{<:LazyFeature}) = true
GI.trait(::LazyFeature) = GI.FeatureTrait()
GI.geometry(f::LazyFeature) = geometry(f)
GI.properties(f::LazyFeature) = properties(f)

Tables.getcolumn(f::LazyFeature, k::Symbol) = k === :geometry ? something(geometry(f), missing) : getproperty(f, k)
Tables.getcolumn(f::LazyFeature, i::Int) = Tables.getcolumn(f, propertynames(f)[i])

_column(fc::LazyFeatureCollection{D,T,G,P}, k::Symbol) where {D,T,G,P} = _column(lazyfeatures(fc), G, P, k)
function _propertyvalue(f::LazyFeature, key::String)
    pos = _proppos(f, key)
    return pos == 0 ? Absent() : _propvalue(f, key, pos)
end

# One walk per feature: the geometry kind with coordinates skipped, plus the properties when
# their keys are the schema.
struct SchemaRow{P}
    properties::Union{Nothing,P}
    kind::UInt8
end

mutable struct SchemaSink{P,S}
    st::S
    properties::Union{Nothing,P}
    kind::UInt8
end

function (s::SchemaSink{P})(k::PtrString, v::LazyValues) where {P}
    if k == "properties"
        (!(P <: AbstractDict) || gettype(v) == NULL) && return 0
        val, pos = readprops(s.st, P, v)
        s.properties = val
        return pos
    elseif k == "geometry"
        gettype(v) == NULL || (s.kind = geomkindat(v))
    end
    return 0
end

function StructUtils.make(st::JSON.JSONStyle, ::Type{SchemaRow{P}}, src::LazyValues) where {P}
    s = SchemaSink{P,typeof(st)}(st, nothing, KUNKNOWN)
    pos = applyobject(s, src)::Int
    return SchemaRow{P}(s.properties, s.kind), pos
end
StructUtils.make(st::JSON.JSONStyle, ::Type{SchemaRow{P}}, src::LazyValues, tags) where {P} =
    StructUtils.make(st, SchemaRow{P}, src)

# Dict-keyed properties feed the same per-row schema step as an eager collection; a static `P`
# names its columns up front, so each row contributes only its geometry kind.
function _schema(fc::LazyFeatureCollection{D,T,G,P}) where {D,T,G,P}
    buf = _buf(fc)
    offsets = _offsets(fc)
    pass = P <: AbstractDict ? SchemaPass() : nothing
    gt = Union{}
    for (n, pos) in enumerate(offsets)
        row = JSON.parse(lazyat(buf, pos), SchemaRow{P}; style=GeoJSONStyle())
        pass === nothing || _schemarow!(pass, n, row.properties)
        gt = _widen(gt, row.kind == KUNKNOWN ? Missing : kindtype(row.kind, Val(D), T))
    end
    names, types = pass === nothing ? _propertyschema(offsets, P) : _finish(pass, length(offsets))
    push!(names, :geometry)
    push!(types, gt === Union{} ? G : gt)
    return names, types
end
