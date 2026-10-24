_omitoptional(x) = x === nothing || x === missing
_omitoptional(x::Union{AbstractString,AbstractArray,AbstractDict}) = isempty(x)

# Estimate from the numeric payload; JSON grows the buffer if more space is needed.
_coordinatesize(::Nothing) = 4
function _coordinatesize(x::Vector{C}) where {C<:Tuple}
    D = fieldcount(C)
    width = D == 0 ? 0 : D * (2 * sizeof(eltype(C)) + 1)
    2 + length(x) * (3 + width)
end
_coordinatesize(x::Vector) = 2 + length(x) + sum(_coordinatesize, x; init = 0)

function JSON.sizeguess(
    x::Union{
        LineString{D,T},
        MultiPoint{D,T},
        MultiLineString{D,T},
        Polygon{D,T},
        MultiPolygon{D,T},
    },
) where {D,T<:Union{Float32,Float64}}
    box = getfield(x, :bbox)
    64 +
    _coordinatesize(coordinates(x)) +
    (box === nothing ? 0 : length(box) * (2 * sizeof(T) + 1))
end

macro emit(key, value)
    esc(quote
        result = f($key, $value)
        result isa StructUtils.EarlyReturn && return result
    end)
end

function StructUtils.applyeach(style::JSON.JSONStyle, f, x::CoordinateGeometry)
    @emit "type" typestring(typeof(x))
    bb = bbox(x)
    bb === nothing || isempty(bb) || @emit "bbox" bb
    c = coordinates(x)
    if c === nothing
        @emit "coordinates" nothing
    else
        @emit "coordinates" c
    end
    nothing
end
function StructUtils.applyeach(style::JSON.JSONStyle, f, x::GeometryCollection)
    @emit "type" "GeometryCollection"
    bb = bbox(x)
    bb === nothing || isempty(bb) || @emit "bbox" bb
    @emit "geometries" geometry(x)
    nothing
end

function _emitgeometry(f, key, g)
    g === nothing && return f(key, nothing)
    g isa Point && return f(key, g)
    g isa LineString && return f(key, g)
    g isa Polygon && return f(key, g)
    g isa MultiPoint && return f(key, g)
    g isa MultiLineString && return f(key, g)
    g isa MultiPolygon && return f(key, g)
    g isa GeometryCollection && return f(key, g)
    f(key, g)
end
function StructUtils.applyeach(style::JSON.JSONStyle, f, x::Feature)
    @emit "type" "Feature"
    result = _emitid(style, f, id(x))
    result isa StructUtils.EarlyReturn && return result
    bb = bbox(x)
    bb === nothing || isempty(bb) || @emit "bbox" bb
    result = _emitgeometry(f, "geometry", geometry(x))
    result isa StructUtils.EarlyReturn && return result
    @emit "properties" getfield(x, :properties)
    nothing
end
function StructUtils.applyeach(style::JSON.JSONStyle, f, x::Union{FeatureCollection,LazyFeatureCollection})
    @emit "type" "FeatureCollection"
    bb = bbox(x)
    bb === nothing || isempty(bb) || @emit "bbox" bb
    @emit "features" getfield(x, :features)
    crs = getfield(x, :crs)
    crs === nothing || @emit "crs" crs
    nothing
end

StructUtils.lower(::JSON.JSONStyle, x::LazyFeature{D,T}) where {D,T} =
    _parse(codeunits(x), Feature{D,T})

missT(::Type{Nothing}) = Missing
missT(::Type{T}) where {T} = T

# Only schema writes close the Any-valued CRS/id fallback; ordinary writes retain
# JSON.jl's support for custom property values.
struct SchemaStyle <: JSON.JSONStyle end
JSON.applyany(::SchemaStyle, f, key, @nospecialize(value)) =
    throw(ArgumentError("unsupported value in schema-typed GeoJSON write"))
_writestyle(x) = JSON.JSONWriteStyle()
_writestyle(::Union{Feature{D,T,P},FeatureCollection{D,T,P}}) where {D,T,P} =
    P === DefaultProperties ? JSON.JSONWriteStyle() : SchemaStyle()

function _emitid(style, f, id)
    (id === nothing || id === missing) && return nothing
    id isa String && return isempty(id) ? nothing : f("id", id)
    id isa Int64 && return f("id", id)
    id isa Float64 && return f("id", id)
    _emitotherid(style, f, id)
end
_emitotherid(style, f, id) = _omitoptional(id) ? nothing : f("id", id)
_emitotherid(::SchemaStyle, f, @nospecialize(id)) = throw(ArgumentError("unsupported schema id"))

JSON.sizeguess(::Point) = 96
_propbytes(::Nothing) = 4
_propbytes(p::Union{AbstractDict,NamedTuple}) = 2 + 24 * length(p)
_propbytes(p) = 512
JSON.sizeguess(f::Feature) = 96 + JSON.sizeguess(geometry(f)) + _propbytes(getfield(f, :properties))
JSON.sizeguess(fc::FeatureCollection) = 64 + sum(JSON.sizeguess, features(fc); init=0)
