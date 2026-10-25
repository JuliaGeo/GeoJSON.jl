# JSON's ordinary tuple reader truncates extra components. Count positions strictly
# so read can retry a 2D document as 3D without losing coordinates.
struct DimensionError <: Exception
    n::Int
    ndim::Int
end
dimensionerror(n, ndim) = ArgumentError("position has $n components; ndim=$ndim")
mutable struct PositionSink{C,S}
    values::C
    n::Int
    style::S
end
@inline function (s::PositionSink{C})(_, v) where {C}
    s.n += 1
    s.n > fieldcount(C) && return nothing
    x, pos = coordinatecomponent(s.style, eltype(C), v)
    s.values = Base.setindex(s.values, x, s.n)
    pos
end
@inline function coordinatecomponent(st, ::Type{T}, v) where {T}
    # Numeric conversions accept Bool; this measured kind check rejects it.
    JSON.gettype(v) == JSON.JSONTypes.NUMBER || throw(ArgumentError("coordinate components must be numbers"))
    if T <: Integer
        try
            return nonfinitestyle(st) ? readscalar(st, T, v) : StructUtils.make(st, T, v)
        catch e
            e isa Union{InexactError,OverflowError} || rethrow()
            throw(ArgumentError("coordinate cannot be represented as $T"))
        end
    end
    nonfinitestyle(st) ? readscalar(st, T, v) : StructUtils.make(st, T, v)
end
@noinline function readcoordinates_public(st, ::Type{C}, src) where {C<:Tuple}
    StructUtils.arraylike(st, src) || throw(ArgumentError("a position must be an array"))
    s = PositionSink(ntuple(_ -> zero(eltype(C)), Val(fieldcount(C))), 0, st)
    pos = StructUtils.applyeach(st, s, src)
    s.n > fieldcount(C) && throw(DimensionError(s.n, fieldcount(C)))
    s.n == fieldcount(C) || throw(dimensionerror(s.n, fieldcount(C)))
    s.values, pos
end

readcoordinates_public(st, ::Type{T}, src) where {T<:Number} = coordinatecomponent(st, T, src)
readbbox(st, ::Type{T}, src) where {T} = StructUtils.nulllike(st, src) ?
    StructUtils.make(st, Nothing, src) : readcoordinates(st, Vector{T}, src)

struct CoordinateSink{C,S}
    values::Vector{C}
    style::S
end
@inline function (s::CoordinateSink{C})(_, v) where {C}
    x, pos = readcoordinates(s.style, C, v)
    push!(s.values, x)
    pos
end
@noinline function readcoordinates_public(st, ::Type{Vector{C}}, src) where {C}
    StructUtils.arraylike(st, src) || throw(ArgumentError("coordinates must be arrays"))
    values = C[]
    pos = StructUtils.applyeach(st, CoordinateSink(values, st), src)
    values, pos
end

const CoordinateGeometry{D,T} = Union{Point{D,T},LineString{D,T},Polygon{D,T},MultiPoint{D,T},MultiLineString{D,T},MultiPolygon{D,T}}
# Explicit sink constructors suppress inferred outer constructors whose nullable
# fields leave type parameters unbound (checked by Aqua).
mutable struct GeometrySink{C,T,S}
    bbox::Union{Nothing,Vector{T}}
    coordinates::Union{Nothing,C}
    style::S
    GeometrySink{C,T,S}(bbox, coordinates, style) where {C,T,S} = new{C,T,S}(bbox, coordinates, style)
end
function (s::GeometrySink{C,T})(k, v) where {C,T}
    if k == "coordinates"
        if StructUtils.nulllike(s.style, v)
            s.coordinates, pos = StructUtils.make(s.style, Nothing, v)
        else
            s.coordinates, pos = readcoordinates(s.style, C, v)
        end
        return pos
    elseif k == "bbox"
        s.bbox, pos = readbbox(s.style, T, v)
        return pos
    end
    nothing # skip type and foreign members
end
function StructUtils.make(st::StructUtils.StructStyle, ::Type{G}, src) where {D,T,G<:CoordinateGeometry{D,T}}
    C = Base.nonnothingtype(fieldtype(G, :coordinates))
    s = GeometrySink{C,T,typeof(st)}(nothing, nothing, st)
    pos = StructUtils.applyeach(st, s, src)
    G(s.bbox, s.coordinates), pos
end
struct ArraySink{E,S}
    values::Vector{E}
    style::S
end
function (s::ArraySink{E})(_, v) where {E}
    x, pos = StructUtils.make(s.style, E, v)
    push!(s.values, x)
    pos
end
function readarray(st, ::Type{E}, src) where {E}
    StructUtils.arraylike(st, src) || throw(ArgumentError("expected a GeoJSON array"))
    values = E[]
    pos = StructUtils.applyeach(st, ArraySink(values, st), src)
    values, pos
end
mutable struct CollectionSink{E,T,S}
    bbox::Union{Nothing,Vector{T}}
    children::Vector{E}
    crs::Union{Nothing,CRS}
    key::String
    style::S
    CollectionSink{E,T,S}(bbox, children, crs, key, style) where {E,T,S} = new{E,T,S}(bbox, children, crs, key, style)
end
function (s::CollectionSink{E,T})(k, v) where {E,T}
    if k == s.key
        s.children, pos = readarray(s.style, E, v)
        return pos
    elseif k == "bbox"
        s.bbox, pos = readbbox(s.style, T, v)
        return pos
    elseif k == "crs" && s.key == "features"
        if nonfinitestyle(s.style)
            value, pos = readnonfinite(s.style, v)
            if value === nothing
                s.crs = nothing
            else
                (value isa Dict{String,Any} && get(value, "type", nothing) isa String &&
                    get(value, "properties", nothing) isa Dict{String,Any}) ||
                    throw(ArgumentError("CRS must be an object with string type and object properties, or null"))
                crs = value::Dict{String,Any}
                s.crs = CRS(crs["type"]::String, crs["properties"]::Dict{String,Any})
            end
        else
            s.crs, pos = StructUtils.make(s.style, Union{Nothing,CRS}, v)
        end
        return pos
    end
    nothing
end
function StructUtils.make(st::StructUtils.StructStyle, ::Type{G}, src) where {D,T,G<:Union{GeometryCollection{D,T},FeatureCollection{D,T},LazyFeatureCollection{D,T}}}
    if G <: LazyFeatureCollection && geometrykind(st, src) != "FeatureCollection"
        throw(ArgumentError("lazyfc requires a FeatureCollection"))
    end
    E = eltype(fieldtype(G, G <: GeometryCollection ? :geometries : :features))
    key = G <: GeometryCollection ? "geometries" : "features"
    s = CollectionSink{E,T,typeof(st)}(nothing, E[], nothing, key, st)
    pos = StructUtils.applyeach(st, s, src)
    (G <: GeometryCollection ? G(s.bbox, s.children) : G(s.bbox, s.children, s.crs)), pos
end
struct TypeKey{S}
    style::S
end
function (t::TypeKey)(k, v)
    k == "type" || return nothing
    JSON.gettype(v) == JSON.JSONTypes.STRING || throw(ArgumentError("GeoJSON type must be a string"))
    value, _ = StructUtils.make(t.style, String, v)
    StructUtils.EarlyReturn(value)
end
function geometrykind(st, src)
    r = StructUtils.applyeach(st, TypeKey(st), src)
    r isa StructUtils.EarlyReturn || throw(ArgumentError("GeoJSON object is missing its type"))
    r.value::String
end
function StructUtils.make(st::StructUtils.StructStyle, ::Type{AbstractGeometry{D,T}}, src) where {D,T}
    k = geometrykind(st, src)
    k == "Point" && return StructUtils.make(st, Point{D,T}, src)
    k == "LineString" && return StructUtils.make(st, LineString{D,T}, src)
    k == "Polygon" && return StructUtils.make(st, Polygon{D,T}, src)
    k == "MultiPoint" && return StructUtils.make(st, MultiPoint{D,T}, src)
    k == "MultiLineString" && return StructUtils.make(st, MultiLineString{D,T}, src)
    k == "MultiPolygon" && return StructUtils.make(st, MultiPolygon{D,T}, src)
    k == "GeometryCollection" && return StructUtils.make(st, GeometryCollection{D,T}, src)
    throw(ArgumentError("unknown GeoJSON geometry type $k"))
end
function StructUtils.make(st::StructUtils.StructStyle, ::Type{GeoJSONT{D,T}}, src) where {D,T}
    k = geometrykind(st, src)
    k == "Feature" && return StructUtils.make(st, Feature{D,T}, src)
    k == "FeatureCollection" && return StructUtils.make(st, FeatureCollection{D,T}, src)
    StructUtils.make(st, AbstractGeometry{D,T}, src)
end
mutable struct FeatureSink{D,T,S}
    id::Any
    bbox::Union{Nothing,Vector{T}}
    geometry::Union{Nothing,AbstractGeometry{D,T}}
    properties::Union{Nothing,Dict{Symbol,Any}}
    style::S
    FeatureSink{D,T,S}(id, bbox, geometry, properties, style) where {D,T,S} = new{D,T,S}(id, bbox, geometry, properties, style)
end
function (s::FeatureSink{D,T})(k, v) where {D,T}
    if k == "geometry"
        s.geometry, pos = StructUtils.make(s.style, Union{Nothing,AbstractGeometry{D,T}}, v)
    elseif k == "properties"
        (StructUtils.structlike(s.style, v) || StructUtils.nulllike(s.style, v)) ||
            throw(ArgumentError("Feature properties must be an object or null"))
        value, pos = nonfinitestyle(s.style) ? readnonfinite(s.style, v, Symbol) :
            StructUtils.make(s.style, Union{Nothing,Dict{Symbol,Any}}, v)
        s.properties = value::Union{Nothing,Dict{Symbol,Any}}
    elseif k == "id"
        value, pos = nonfinitestyle(s.style) ? readnonfinite(s.style, v) : StructUtils.make(s.style, Any, v)
        # Keep Int64 IDs exact; oversized integer/float IDs retain 0.8.4 normalization.
        value isa Union{BigInt,BigFloat} && (value = Float64(value))
        if value isa Float64 && isinteger(value) && typemin(Int64) <= value <= typemax(Int64)
            value = Int64(value)
        end
        s.id = value
    elseif k == "bbox"
        s.bbox, pos = readbbox(s.style, T, v)
    else
        return nothing
    end
    pos
end
function StructUtils.make(st::StructUtils.StructStyle, ::Type{Feature{D,T}}, src) where {D,T}
    s = FeatureSink{D,T,typeof(st)}(nothing, nothing, nothing, nothing, st)
    pos = StructUtils.applyeach(st, s, src)
    Feature{D,T}(s.id, s.bbox, s.geometry, s.properties), pos
end
function StructUtils.make(st::StructUtils.StructStyle, ::Type{LazyFeature{D,T}}, src) where {D,T}
    text, pos = StructUtils.make(st, JSON.JSONText, src)
    bytes = codeunits(text.value)
    LazyFeature{D,T}(bytes, 1, length(bytes)), pos
end
# allownan=true also changes ordinary untyped numbers to Float64 and loosens
# numeric syntax. Restrict that option to the exceptional path, validating every
# scalar (including ignored members) and retaining its normal JSON number kind.
struct NonFiniteStyle <: StructUtils.StructStyle end
nonfinitestyle(st) = StructUtils.parentstyle(st) isa NonFiniteStyle
function readscalar(st, ::Type{T}, src) where {T}
    text, pos = StructUtils.make(st, JSON.JSONText, src)
    token = text.value
    value = token == "NaN" ? NaN : token in ("Inf", "Infinity") ? Inf :
        token in ("-Inf", "-Infinity") ? -Inf : parsegeojson(token, T)
    convert(T, value), pos
end
struct NonFiniteObjectSink{K,S}
    values::Dict{K,Any}
    style::S
end
function (s::NonFiniteObjectSink{K})(k, v) where {K}
    value, pos = readnonfinite(s.style, v)
    s.values[K(String(k))] = value
    pos
end
struct NonFiniteArraySink{S}
    values::Vector{Any}
    style::S
end
function (s::NonFiniteArraySink)(_, v)
    value, pos = readnonfinite(s.style, v)
    push!(s.values, value)
    pos
end
function readnonfinite(st, src, ::Type{K}=String)::Tuple{Any,Int} where {K}
    if StructUtils.structlike(st, src)
        out = Dict{K,Any}()
        pos = StructUtils.applyeach(st, NonFiniteObjectSink(out, st), src)
    elseif StructUtils.arraylike(st, src)
        out = Any[]
        pos = StructUtils.applyeach(st, NonFiniteArraySink(out, st), src)
    else
        return readscalar(st, Any, src)
    end
    out, pos
end
function StructUtils.make(st::StructUtils.StructStyle, ::Type{NonFiniteStyle}, src)
    _, pos = readnonfinite(st, src)
    NonFiniteStyle(), pos
end
# Only failures pay for this byte scan. Skip quoted text (including escapes),
# and require a value prefix so property names/values such as "Information"
# do not invoke the cold non-finite reader.
function hasnonfinite(input)
    bytes = input isa AbstractString ? codeunits(input) : input
    quoted = false
    escaped = false
    previous = 0x00
    @inbounds for i in eachindex(bytes)
        b = bytes[i]
        if quoted
            if escaped
                escaped = false
            elseif b == 0x5c
                escaped = true
            elseif b == 0x22
                quoted = false
            end
        elseif b == 0x22
            quoted = true
            previous = b
        elseif !(b in (0x20, 0x09, 0x0a, 0x0d))
            if previous in (0x5b, 0x2c, 0x3a, 0x2d) && i <= lastindex(bytes) - 2
                ((b == 0x4e && bytes[i+1] == 0x61 && bytes[i+2] == 0x4e) ||
                 (b == 0x49 && bytes[i+1] == 0x6e && bytes[i+2] == 0x66)) && return true
            end
            previous = b
        end
    end
    false
end
# Keep the exceptional reader out of the ordinary call graph/package image.
# A first NaN/Inf read intentionally compiles this path on demand.
@noinline function parsenonfinite(input, ::Type{T}) where {T}
    style = JSON.parse(input, NonFiniteStyle; allownan=true)
    JSON.parse(input, T; dicttype=Dict{String,Any}, allownan=true, style)
end
function _parse(input, ::Type{T}) where {T}
    try
        parsegeojson(input, T)
    catch e
        e isa ArgumentError && hasnonfinite(input) || rethrow()
        text = input isa AbstractString ? String(input) : String(copy(input))
        Base.invokelatest(parsenonfinite, text, T)::T
    end
end

# JSON's public parse keyword wrapper does not always propagate dicttype into
# trimmed callers. Keep the concrete style visible, and isolate this optional
# internal adapter so an incompatible JSON release retains the public parser.
const CONCRETE_READ_AVAILABLE = all(n -> isdefined(JSON, n),
    (:JSONReadStyle, :checkendpos)) &&
    hasmethod(JSON.JSONReadStyle{Dict{String,Any}},
        Tuple{Nothing,StructUtils.DefaultStyle,Bool}) &&
    hasmethod(JSON.JSONReadStyle{Dict{String,Any}},
        Tuple{Nothing,NonFiniteStyle,Bool})
# Keep the public parser callable even when the adapter is available, so its
# results and diagnostics can be compared directly in tests.
parsegeojson(input, ::Type{T}) where {T} = parsegeojson(input, T, Val(CONCRETE_READ_AVAILABLE))
parsegeojson(input, ::Type{T}, ::Val{false}) where {T} =
    JSON.parse(input, T; dicttype=Dict{String,Any})
@static if CONCRETE_READ_AVAILABLE
    function parsegeojson(input, ::Type{T}, ::Val{true}) where {T}
        src = JSON.lazy(input)
        style = JSON.JSONReadStyle{Dict{String,Any}}(nothing, StructUtils.DefaultStyle(), true)
        value, pos = StructUtils.make(style, T, src)
        JSON.checkendpos(src, T, pos)
        value
    end
    # Lazy access also supports the ordinary reader's exceptional literals, but
    # never enters JSON.parse's keyword retry or an invokelatest call. Typed
    # reads accept standard JSON, so their retained features take the first path.
    function parselazynonfinite(input, ::Type{T}) where {T}
        src = JSON.lazy(input; allownan=true)
        style = JSON.JSONReadStyle{Dict{String,Any}}(nothing, NonFiniteStyle(), true)
        StructUtils.make(style, NonFiniteStyle, src) # validate ignored members too
        value, pos = StructUtils.make(style, T, src)
        JSON.checkendpos(src, T, pos)
        value
    end
else
    parselazynonfinite(input, ::Type{T}) where {T} = parsenonfinite(input, T)
end
function parselazyfeature(input, ::Type{T}) where {T}
    try
        parsegeojson(input, T)
    catch e
        e isa ArgumentError && hasnonfinite(input) || rethrow()
        parselazynonfinite(input, T)::T
    end
end

# Emit only spec members, in the same order as 0.8.4. Dict ordering is selected
# explicitly at the entrypoints, since JSON.json otherwise sorts Dict keys.
macro emit(k, v)
    esc(:(r = f($k, $v); r isa StructUtils.EarlyReturn && return r))
end
function StructUtils.applyeach(st::JSON.JSONStyle, f, g::G) where {G<:CoordinateGeometry}
    @emit "type" typestring(G)
    b = getfield(g, :bbox); b === nothing || @emit "bbox" b
    c = getfield(g, :coordinates)
    if c === nothing; @emit "coordinates" nothing; else; @emit "coordinates" coordinateoutput(st, c); end
    nothing
end
@inline emitgeometry(f, key, ::Nothing) = f(key, nothing)
@inline function emitgeometry(f, key, g::AbstractGeometry{D,T}) where {D,T}
    g isa Point{D,T} && return f(key, g)
    g isa LineString{D,T} && return f(key, g)
    g isa Polygon{D,T} && return f(key, g)
    g isa MultiPoint{D,T} && return f(key, g)
    g isa MultiLineString{D,T} && return f(key, g)
    g isa MultiPolygon{D,T} && return f(key, g)
    g isa GeometryCollection{D,T} && return f(key, g)
    throw(ArgumentError("unsupported geometry type"))
end
function StructUtils.applyeach(st::JSON.JSONStyle, f, g::GeometryCollection)
    @emit "type" "GeometryCollection"
    b = getfield(g, :bbox); b === nothing || @emit "bbox" b
    # Let JSON carry all writer options (including pretty printing) to children.
    @emit "geometries" getfield(g, :geometries)
    nothing
end
# Start each child at the same JSON.json signature. Passing the parent's
# WriteClosure recursively through abstract geometry vectors makes inference
# widen the nested closure types, which the safe-trim verifier cannot resolve.
# The fixed-format StrictStyle can splice compact child text; ordinary JSON
# styles retain their option-aware traversal (pretty printing, float options).
stricttext(st::StrictStyle, g) = JSON.JSONText(JSON.json(g; sort_keys=false, style=st))
@inline function strictchild(st::StrictStyle, g::AbstractGeometry{D,T}) where {D,T}
    g isa Point{D,T} && return stricttext(st, g)
    g isa LineString{D,T} && return stricttext(st, g)
    g isa Polygon{D,T} && return stricttext(st, g)
    g isa MultiPoint{D,T} && return stricttext(st, g)
    g isa MultiLineString{D,T} && return stricttext(st, g)
    g isa MultiPolygon{D,T} && return stricttext(st, g)
    g isa GeometryCollection{D,T} && return stricttext(st, g)
    throw(ArgumentError("unsupported geometry type"))
end
# StrictStyle deliberately has a fixed format. Reject options that would be
# lost when splicing children, rather than silently changing their meaning.
function checkstrictoptions(f::JSON.WriteClosure)
    opts = f.opts
    (opts.pretty == 0 && !opts.allownan && !opts.jsonlines &&
        opts.omit_null === nothing && opts.omit_empty === nothing &&
        opts.inline_limit == 0 && opts.float_style === :shortest &&
        opts.float_precision == 1 && opts.ninf == "-Infinity" &&
        opts.inf == "Infinity" && opts.nan == "NaN") ||
        throw(ArgumentError("GeoJSON.StrictStyle GeometryCollections require default JSON writer options; pretty, allownan and other format options are unsupported"))
    nothing
end
checkstrictoptions(f) = nothing # non-writer StructUtils visitors
function StructUtils.applyeach(st::StrictStyle, f, g::GeometryCollection)
    checkstrictoptions(f)
    @emit "type" "GeometryCollection"
    b = getfield(g, :bbox); b === nothing || @emit "bbox" b
    children = JSON.JSONText[]
    for child in getfield(g, :geometries)
        push!(children, strictchild(st, child))
    end
    @emit "geometries" children
    nothing
end
function StructUtils.applyeach(st::JSON.JSONStyle, f, x::Feature)
    @emit "type" "Feature"
    id = getfield(x, :id)
    if id === nothing
    elseif id isa String; @emit "id" id
    elseif id isa Int64; @emit "id" id
    elseif id isa Float64; @emit "id" id
    else; r = JSON.applyany(st, f, "id", id); r isa StructUtils.EarlyReturn && return r
    end
    b = getfield(x, :bbox); b === nothing || @emit "bbox" b
    r = emitgeometry(f, "geometry", getfield(x, :geometry))
    r isa StructUtils.EarlyReturn && return r
    p = getfield(x, :properties)
    if p === nothing; @emit "properties" nothing; else; @emit "properties" p; end
    nothing
end
function StructUtils.applyeach(st::JSON.JSONStyle, f, x::Union{FeatureCollection,LazyFeatureCollection})
    @emit "type" "FeatureCollection"
    b = getfield(x, :bbox); b === nothing || @emit "bbox" b
    @emit "features" getfield(x, :features)
    c = getfield(x, :crs); c === nothing || @emit "crs" c
    nothing
end
# Lazy writes preserve the original feature text, including NaN/Inf literals;
# unlike materialized features, their numeric values are not checked by the writer.
JSON.lower(f::LazyFeature) = JSON.JSONText(codeunits(f))
