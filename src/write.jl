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
"""
write(obj; pretty=false, inline_limit=3, geometrycolumn=nothing) =
    JSON.json(_lower(obj, geometrycolumn); pretty, inline_limit)
write(io::IO, obj; pretty=false, inline_limit=3, geometrycolumn=nothing) =
    JSON.json(io, _lower(obj, geometrycolumn); pretty, inline_limit)
write(path::AbstractString, obj; pretty=false, inline_limit=3, geometrycolumn=nothing) =
    JSON.json(path, _lower(obj, geometrycolumn); pretty, inline_limit)

# --- applyeach on the default JSON style -------------------------------------

"""
    Elements(v)

Array view for the JSON writer: elements reach it keyed by their integer index, and nested
vectors and tuples are wrapped the same way, so a coordinate tree writes without per-element
key strings.
"""
struct Elements{V}
    v::V
end
StructUtils.arraylike(::Type{<:Elements}) = true
Base.length(e::Elements) = length(e.v)

_element(st, x::Real) = x
_element(st, x::Union{AbstractVector,Tuple}) = Elements(x)
_element(st, x) = StructUtils.lower(st, x)

function StructUtils.applyeach(st::JSON.JSONStyle, f, e::Elements)
    v = e.v
    for i in eachindex(v)
        ret = f(i, _element(st, @inbounds v[i]))
        ret isa StructUtils.EarlyReturn && return ret
    end
    return StructUtils.defaultstate(st)
end

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

_omit(::Nothing) = JSON.Omit()
_omit(x) = x
_bboxvalue(::Nothing) = JSON.Omit()
_bboxvalue(v::AbstractVector) = Elements(v)
_coordsvalue(::Nothing) = nothing
_coordsvalue(c) = Elements(c)

function _emitextras(st, f, extras)
    extras === nothing && return StructUtils.defaultstate(st)
    for (k, v) in extras
        ret = f(k, StructUtils.lower(st, v))
        ret isa StructUtils.EarlyReturn && return ret
    end
    return StructUtils.defaultstate(st)
end

for G in (:Point, :LineString, :Polygon, :MultiPoint, :MultiLineString, :MultiPolygon)
    @eval function StructUtils.applyeach(st::JSON.JSONStyle, f, x::$G)
        @emit "type" $(String(G))
        @emit "bbox" _bboxvalue(bbox(x))
        @emit "coordinates" _coordsvalue(coordinates(x))
        return _emitextras(st, f, extras(x))
    end
end

function StructUtils.applyeach(st::JSON.JSONStyle, f, x::GeometryCollection)
    @emit "type" "GeometryCollection"
    @emit "bbox" _bboxvalue(bbox(x))
    @emit "geometries" Elements(geometry(x))
    return _emitextras(st, f, extras(x))
end

function StructUtils.applyeach(st::JSON.JSONStyle, f, x::Feature)
    @emit "type" "Feature"
    @emit "id" _omit(id(x))
    @emit "bbox" _bboxvalue(bbox(x))
    @emit "geometry" geometry(x)
    @emit "properties" StructUtils.lower(st, properties(x))
    return _emitextras(st, f, extras(x))
end

function StructUtils.applyeach(st::JSON.JSONStyle, f, x::FeatureCollection)
    @emit "type" "FeatureCollection"
    @emit "bbox" _bboxvalue(bbox(x))
    @emit "features" Elements(features(x))
    return _emitextras(st, f, extras(x))
end

# --- GeoInterface and Tables inputs lower into the GeoJSON types --------------

_lower(x::GeoJSONT, geometrycolumn) = x
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

_properties(::Nothing) = Properties()
_properties(p::Properties) = p
_properties(p::AbstractDict) = Properties(p)
_properties(p) = Properties(k => getproperty(p, k) for k in propertynames(p))

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
    geoms = Any[]
    props = Properties[]
    for row in rows
        push!(geoms, Tables.getcolumn(row, geometrycolumn))
        push!(props, Properties(Pair{String,Any}[String(n) => Tables.getcolumn(row, n) for n in propnames]))
    end
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
