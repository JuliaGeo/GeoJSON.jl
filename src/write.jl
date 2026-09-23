"""
    write(obj; pretty=false, inline_limit=3) -> String
    write(io::IO, obj; pretty=false, inline_limit=3)
    write(path::AbstractString, obj; pretty=false, inline_limit=3)

Write `obj` as GeoJSON text to a `String`, an `IO`, or a file at `path` (streamed).

`obj` is one of:

| input | written as |
|---|---|
| a GeoJSON geometry, `Feature`, or `FeatureCollection` | itself: `"type"` first, `bbox`/`id` only when present, `geometry`/`properties` as `null` when `nothing`, foreign members flat |
| a GeoInterface geometry, feature, or feature collection | the matching GeoJSON type; `bbox` from `GeoInterface.extent`; `Z` selects 3-D and `M` is dropped |
| a Tables.jl table | a `FeatureCollection` with one feature per row; `geometrycolumn` names the geometry column (default `first(GeoInterface.geometrycolumns(obj))`) and every other column is a property |

`pretty` is `true`, `false`, or an indent width. When pretty printing, arrays shorter than
`inline_limit` stay on one line, so the default keeps 2-D positions as `[x, y]`.

A properties or foreign member value of a GeoJSON object must be one of the types `read`
stores (see [`GeoJSONStyle`](@ref)); GeoInterface and Tables inputs convert theirs on the way in.
"""
write(obj; pretty=false, inline_limit=3, geometrycolumn=nothing) =
    JSON.json(_lower(obj, geometrycolumn); pretty, inline_limit, sort_keys=false, style=GeoJSONStyle())
write(io::IO, obj; pretty=false, inline_limit=3, geometrycolumn=nothing) =
    JSON.json(io, _lower(obj, geometrycolumn); pretty, inline_limit, sort_keys=false, style=GeoJSONStyle())
write(path::AbstractString, obj; pretty=false, inline_limit=3, geometrycolumn=nothing) =
    JSON.json(path, _lower(obj, geometrycolumn); pretty, inline_limit, sort_keys=false, style=GeoJSONStyle())

"""
    GeoJSONStyle <: JSON.JSONStyle

Write style of [`write`](@ref). A value in an `Any` container (a properties dict, a foreign
member) must be one of the types [`read`](@ref) stores: `nothing`, `missing`, `Bool`, `Int64`,
`Float64`, `BigInt`, `BigFloat`, `String`, `Vector{Any}`, `JSON.Object{String,Any}` or
`Dict{String,Any}`. Closing that set keeps every write statically resolvable under `--trim`.
"""
struct GeoJSONStyle <: JSON.JSONStyle end

@noinline _badvalue() = throw(ArgumentError(
    "a properties or foreign member value must be null, missing, Bool, Int64, Float64, BigInt, BigFloat, String, Vector{Any}, JSON.Object{String,Any} or Dict{String,Any}, as `read` stores them"))
JSON.applyany(::GeoJSONStyle, f, key, @nospecialize(value)) = _badvalue()

"""
    @emit key value

Emit one member from inside an `applyeach` method, returning early when the writer asks to.
"""
macro emit(k, v)
    esc(quote
        ret = f($k, $v)
        ret isa StructUtils.EarlyReturn && return ret
    end)
end

# `G` of a `Feature` may be a union of up to seven geometries, past what inference splits;
# each branch hands `f` one of them.
function _emitgeometry(f, k, g)
    g === nothing && return f(k, nothing)
    g isa Point && return f(k, g)
    g isa LineString && return f(k, g)
    g isa Polygon && return f(k, g)
    g isa MultiPoint && return f(k, g)
    g isa MultiLineString && return f(k, g)
    g isa MultiPolygon && return f(k, g)
    g isa GeometryCollection && return f(k, g)
    return f(k, g)
end

# Foreign members write flat into the enclosing object.
_emitextras(st, f, extras) =
    extras === nothing ? StructUtils.defaultstate(st) : StructUtils.applyeach(st, f, extras)

function StructUtils.applyeach(st::JSON.JSONStyle, f,
                               x::Union{Point,LineString,Polygon,MultiPoint,MultiLineString,MultiPolygon})
    @emit "type" typestring(x)
    bb = bbox(x)
    bb === nothing || @emit "bbox" bb
    c = coordinates(x)
    if c === nothing
        @emit "coordinates" nothing
    else
        @emit "coordinates" c
    end
    return _emitextras(st, f, extras(x))
end

function StructUtils.applyeach(st::JSON.JSONStyle, f, x::GeometryCollection)
    @emit "type" "GeometryCollection"
    bb = bbox(x)
    bb === nothing || @emit "bbox" bb
    @emit "geometries" geometry(x)
    return _emitextras(st, f, extras(x))
end

function StructUtils.applyeach(st::JSON.JSONStyle, f, x::Feature)
    @emit "type" "Feature"
    i = id(x)
    i === nothing || @emit "id" i
    bb = bbox(x)
    bb === nothing || @emit "bbox" bb
    ret = _emitgeometry(f, "geometry", geometry(x))
    ret isa StructUtils.EarlyReturn && return ret
    @emit "properties" properties(x)
    return _emitextras(st, f, extras(x))
end

_featureview(x::FeatureCollection) = features(x)
_featureview(x::LazyFeatureCollection) = lazyfeatures(x)

function StructUtils.applyeach(st::JSON.JSONStyle, f, x::Union{FeatureCollection,LazyFeatureCollection})
    @emit "type" "FeatureCollection"
    bb = bbox(x)
    bb === nothing || @emit "bbox" bb
    @emit "features" _featureview(x)
    return _emitextras(st, f, extras(x))
end

StructUtils.lower(::JSON.JSONStyle, x::LazyFeature) = materialize(x)

# --- Output size estimate ------------------------------------------------------

# `JSON.json` allocates its buffer at `sizeguess` bytes and grows it geometrically from 512 when a
# type has no estimate. This one leans high: `String` takes an oversized buffer without copying,
# and each shortfall copies everything written so far.
_coordbytes(::Type{Float32}) = 13
_coordbytes(::Type) = 20

_npoints(::Tuple) = 1
_npoints(c::Vector{<:Tuple}) = length(c)
_npoints(c::Vector) = sum(_npoints, c; init=0)

_bboxbytes(::Nothing) = 0
_bboxbytes(b::Vector) = 12 + 24 * length(b)
_propbytes(::Nothing) = 4
_propbytes(p::Union{AbstractDict,NamedTuple}) = 2 + 24 * length(p)
_propbytes(p) = 512
_extrasbytes(::Nothing) = 0
_extrasbytes(e::Vector) = 64 * length(e)

function JSON.sizeguess(g::AbstractGeometry{D,T}) where {D,T}
    c = coordinates(g)
    n = c === nothing ? 0 : _npoints(c)
    return 40 + _bboxbytes(bbox(g)) + _extrasbytes(extras(g)) + n * (D * _coordbytes(T) + 4)
end
# A union-typed geometry reaches `sizeguess` as one concrete type. A GeometryCollection takes a flat
# guess: an estimate that re-enters its own methods with a second signature is widened to `Any`.
function _geombytes(g)
    g === nothing && return 4
    g isa Point && return JSON.sizeguess(g)
    g isa LineString && return JSON.sizeguess(g)
    g isa Polygon && return JSON.sizeguess(g)
    g isa MultiPoint && return JSON.sizeguess(g)
    g isa MultiLineString && return JSON.sizeguess(g)
    g isa MultiPolygon && return JSON.sizeguess(g)
    g isa GeometryCollection && return 48 + 512 * length(geometry(g))
    return 512
end
function JSON.sizeguess(g::GeometryCollection)
    n = 48 + _bboxbytes(bbox(g)) + _extrasbytes(extras(g))
    for m in geometry(g)
        n += _geombytes(m)
    end
    return n
end
JSON.sizeguess(x::Feature) =
    64 + _bboxbytes(bbox(x)) + _geombytes(geometry(x)) + _propbytes(properties(x)) + _extrasbytes(extras(x))
function JSON.sizeguess(x::FeatureCollection)
    n = 40 + _bboxbytes(bbox(x)) + _extrasbytes(extras(x))
    for f in features(x)
        n += JSON.sizeguess(f)
    end
    return n
end

# --- GeoInterface and Tables inputs lower into the GeoJSON types --------------

_lower(x::GeoJSONT, geometrycolumn) = x
_lower(x::Union{LazyFeature,LazyGeometry}, geometrycolumn) = materialize(x)
_lower(::Nothing, geometrycolumn) = nothing
function _lower(obj, geometrycolumn)
    # A column table with a `geometry` column is also a GeoInterface NamedTuple feature; tables win.
    if GI.isfeaturecollection(obj)
        v = _dims(obj)
        return _lowercollection(obj, v, _numtype(obj, v))
    elseif Tables.istable(obj)
        return _lowertable(obj, geometrycolumn)
    elseif GI.isfeature(obj)
        v = _dims(obj)
        return _lowerfeature(obj, v, _numtype(obj, v))
    elseif GI.isgeometry(obj)
        v = _dims(obj)
        return _lowergeom(obj, v, _numtype(obj, v))
    end
    throw(ArgumentError("cannot write a $(typeof(obj)) as GeoJSON; expected a GeoInterface geometry, feature or feature collection, or a Tables.jl table"))
end

_dims(obj) = Val(_is3d(obj) ? 3 : 2)
_is3d(::Union{Nothing,Missing}) = false
function _is3d(obj)
    GI.isfeaturecollection(obj) && return any(_is3d, GI.getfeature(obj))
    GI.isfeature(obj) && return _is3d(GI.geometry(obj))
    return GI.is3d(obj)
end

_xyz(p, ::Val{2}) = (GI.x(p), GI.y(p))
_xyz(p, ::Val{3}) = (GI.x(p), GI.y(p), GI.z(p))

# The promotion of every coordinate type in `obj`; `Union{}` when it has no positions.
_coordtype(::Union{Nothing,Missing}, v) = Union{}
function _coordtype(obj, v)
    GI.isfeaturecollection(obj) &&
        return mapreduce(f -> _coordtype(f, v), promote_type, GI.getfeature(obj); init=Union{})
    GI.isfeature(obj) && return _coordtype(GI.geometry(obj), v)
    GI.geomtrait(obj) isa GI.AbstractPointTrait && return promote_type(map(typeof, _xyz(obj, v))...)
    return mapreduce(g -> _coordtype(g, v), promote_type, GI.getgeom(obj); init=Union{})
end
function _numtype(obj, v)
    T = _coordtype(obj, v)
    return T === Union{} ? Float64 : T
end

_position(p, v::Val{D}, ::Type{T}) where {D,T} = convert(NTuple{D,T}, _xyz(p, v))
_positions(g, v::Val{D}, ::Type{T}) where {D,T} = NTuple{D,T}[_position(p, v, T) for p in GI.getgeom(g)]
_rings(g, v::Val{D}, ::Type{T}) where {D,T} = Vector{NTuple{D,T}}[_positions(r, v, T) for r in GI.getgeom(g)]
_polygons(g, v::Val{D}, ::Type{T}) where {D,T} = Vector{Vector{NTuple{D,T}}}[_rings(p, v, T) for p in GI.getgeom(g)]

_lowergeom(g, v, ::Type{T}) where {T} = _lowergeom(GI.geomtrait(g), g, v, T)
_lowergeom(::GI.AbstractPointTrait, g, v::Val{D}, ::Type{T}) where {D,T} = Point{D,T}(nothing, _position(g, v, T))
_lowergeom(::GI.AbstractLineStringTrait, g, v::Val{D}, ::Type{T}) where {D,T} = LineString{D,T}(nothing, _positions(g, v, T))
_lowergeom(::GI.AbstractPolygonTrait, g, v::Val{D}, ::Type{T}) where {D,T} = Polygon{D,T}(nothing, _rings(g, v, T))
_lowergeom(::GI.AbstractMultiPointTrait, g, v::Val{D}, ::Type{T}) where {D,T} = MultiPoint{D,T}(nothing, _positions(g, v, T))
_lowergeom(::GI.AbstractMultiLineStringTrait, g, v::Val{D}, ::Type{T}) where {D,T} = MultiLineString{D,T}(nothing, _rings(g, v, T))
_lowergeom(::GI.AbstractMultiPolygonTrait, g, v::Val{D}, ::Type{T}) where {D,T} = MultiPolygon{D,T}(nothing, _polygons(g, v, T))
_lowergeom(::GI.AbstractGeometryCollectionTrait, g, v::Val{D}, ::Type{T}) where {D,T} =
    GeometryCollection{D,T}(nothing, AnyGeometry{D,T}[_lowergeom(c, v, T) for c in GI.getgeom(g)])
_lowergeom(trait, g, v, ::Type{T}) where {T} =
    throw(ArgumentError("GeoJSON has no geometry for a $(typeof(trait)); got a $(typeof(g))"))

# The keyword routes wrapper types through the interface method, which computes a missing extent.
_extent(::Union{Nothing,Missing}) = nothing
_extent(x) = GI.extent(x; fallback=true)

_bbox(::Nothing, ::Type{T}) where {T} = nothing
function _bbox(ext::Extents.Extent, ::Type{T}) where {T}
    haskey(ext, :Z) && return T[ext.X[1], ext.Y[1], ext.Z[1], ext.X[2], ext.Y[2], ext.Z[2]]
    return T[ext.X[1], ext.Y[1], ext.X[2], ext.Y[2]]
end

# A value outside the set `GeoJSONStyle` writes takes one trip through JSON text, which lowers
# it the way `JSON.json` would. The check is shallow: a `Vector{Any}` passes as it is.
_writable(v) = v isa Union{Nothing,Missing,Bool,Int64,Float64,BigInt,BigFloat,String,
                           Vector{Any},JSON.Object{String,Any},Dict{String,Any}}
_jsonvalue(v) = _writable(v) ? v : JSON.parse(JSON.json(v))

_properties(::Nothing) = Properties()
_properties(p::AbstractDict) = Properties(Pair{String,Any}[_key(k) => _jsonvalue(v) for (k, v) in p])
_properties(p) = Properties(Pair{String,Any}[String(k) => _jsonvalue(getproperty(p, k)) for k in propertynames(p)])

_feature(geom, props, ext, v::Val{D}, ::Type{T}) where {D,T} =
    Feature{D,T,AnyGeometry{D,T},Properties}(nothing, _bbox(ext, T), _lowergeom(geom, v, T), props, nothing)
_lowergeom(::Union{Nothing,Missing}, v, ::Type{T}) where {T} = nothing

_lowerfeature(obj, v, ::Type{T}) where {T} =
    _feature(GI.geometry(obj), _properties(GI.properties(obj)), _extent(obj), v, T)

function _lowercollection(obj, v::Val{D}, ::Type{T}) where {D,T}
    feats = Feature{D,T,AnyGeometry{D,T},Properties}[_lowerfeature(f, v, T) for f in GI.getfeature(obj)]
    return FeatureCollection{D,T,AnyGeometry{D,T},Properties}(_bbox(_extent(obj), T), feats, nothing)
end


function _lowertable(obj, geometrycolumn)
    geometrycolumn === nothing && (geometrycolumn = first(GI.geometrycolumns(obj)))
    geometrycolumn isa Symbol ||
        throw(ArgumentError("GeoJSON.write takes a single geometry column named by a `Symbol`; got `$geometrycolumn`"))
    rows = Tables.rows(obj)
    sch = Tables.schema(rows)
    names = sch === nothing ? Tables.columnnames(Tables.columns(obj)) : sch.names
    propnames = Tuple(n for n in names if n !== geometrycolumn)
    cells = [(Tables.getcolumn(row, geometrycolumn),
              Properties(Pair{String,Any}[String(n) => _jsonvalue(Tables.getcolumn(row, n)) for n in propnames])) for row in rows]
    geoms = map(first, cells)
    props = map(last, cells)
    v = Val(any(_is3d, geoms) ? 3 : 2)
    T = mapreduce(g -> _coordtype(g, v), promote_type, geoms; init=Union{})
    return _lowertable(geoms, props, v, T === Union{} ? Float64 : T)
end

function _lowertable(geoms, props, v::Val{D}, ::Type{T}) where {D,T}
    exts = map(_extent, geoms)
    feats = Feature{D,T,AnyGeometry{D,T},Properties}[_feature(g, p, e, v, T) for (g, p, e) in zip(geoms, props, exts)]
    ext = reduce(Extents.union, exts; init=nothing)
    return FeatureCollection{D,T,AnyGeometry{D,T},Properties}(_bbox(ext, T), feats, nothing)
end
