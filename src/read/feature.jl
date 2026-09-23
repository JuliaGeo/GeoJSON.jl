@noinline _badid() = throw(ArgumentError("\"id\" must be a string or a number"))

# Single exit: two returns would merge tuple types and widen the four-member id union to `Any`.
function readid(v::LazyValues)
    t = gettype(v)
    id::Union{Nothing,String,Int64,Float64} = nothing
    pos = 0
    if t == STRING
        s, pos = parsestring(v)
        id = convert(String, s)
    elseif t == NUMBER
        num, pos = parsenumber(v)
        id = JSON.isint(num) ? num.int : Float64(num.float)
    elseif t == NULL
        pos = getpos(v) + 4
    else
        _badid()
    end
    return id, pos
end

@noinline _noprops(::Type{P}) where {P} =
    throw(ArgumentError("\"properties\" is null or missing; the schema $P needs an object"))

# A null or absent "properties" member: an empty dict, or a schema whose every field defaults.
emptyprops(::Type{P}) where {P<:AbstractDict{String,Any}} = P()
emptyprops(::Type{Nothing}) = nothing
emptyprops(::Type{P}) where {P<:NamedTuple} =
    all(FT -> Missing <: FT, fieldtypes(P)) ? P(ntuple(_ -> missing, fieldcount(P))) : _noprops(P)
emptyprops(::Type{P}) where {P} = _noprops(P)

function readprops(st, ::Type{P}, v::LazyValues) where {P}
    gettype(v) == OBJECT || _notobject("\"properties\"")
    return StructUtils.make(st, P, v)
end

# Appending skips the duplicate-key scan in `setindex!(::Properties, ...)`.
StructUtils.addkeyval!(p::Properties, k::String, v) = push!(p.pairs, Pair{String,Any}(k, v))

mutable struct FeatureSink{D,T,G,P,S}
    st::S
    id::Union{Nothing,String,Int64,Float64}
    bbox::Union{Nothing,Vector{T}}
    geometry::Union{Nothing,G}
    properties::Union{Nothing,P}
    extras::Extras
    typed::Bool
end

FeatureSink{D,T,G,P}(st::S) where {D,T,G,P,S} =
    FeatureSink{D,T,G,P,S}(st, nothing, nothing, nothing, nothing, nothing, false)

readprops!(::FeatureSink{D,T,G,Nothing}, v::LazyValues) where {D,T,G} = JSON.skip(v)
function readprops!(f::FeatureSink{D,T,G,P}, v::LazyValues) where {D,T,G,P}
    gettype(v) == NULL && return 0
    val, pos = readprops(f.st, P, v)
    f.properties = val
    return pos
end

function (f::FeatureSink{D,T,G,P})(k::PtrString, v::LazyValues) where {D,T,G,P}
    if k == "geometry"
        gettype(v) == NULL && return 0
        val, pos = StructUtils.make(f.st, G, v)
        f.geometry = val
        return pos
    elseif k == "properties"
        return readprops!(f, v)
    elseif k == "type"
        s, pos = parsestring(v)
        s == "Feature" || _wrongtype("Feature", s)
        f.typed = true
        return pos
    elseif k == "id"
        val, pos = readid(v)
        f.id = val
        return pos
    elseif k == "bbox"
        gettype(v) == NULL && return 0
        val, pos = StructUtils.make(f.st, Vector{T}, v)
        f.bbox = val
        return pos
    end
    ex, pos = _extra!(f.st, f.extras, k, v)
    f.extras = ex
    return pos
end

function StructUtils.make(st::JSON.JSONStyle, ::Type{Feature{D,T,G,P}}, src::LazyValues) where {D,T,G,P}
    gettype(src) == OBJECT || _notobject("a Feature")
    f = FeatureSink{D,T,G,P}(st)
    pos = applyobject(f, src)::Int
    f.typed || _notype("Feature")
    props = f.properties
    props === nothing && (props = emptyprops(P))
    return Feature{D,T,G,P}(f.id, f.bbox, f.geometry, props, f.extras), pos
end
StructUtils.make(st::JSON.JSONStyle, ::Type{Feature{D,T,G,P}}, src::LazyValues, tags) where {D,T,G,P} =
    StructUtils.make(st, Feature{D,T,G,P}, src)

struct FeatureArraySink{F,S}
    st::S
    out::Vector{F}
end

function (s::FeatureArraySink{F})(_, v::LazyValues) where {F}
    val, pos = StructUtils.make(s.st, F, v)
    push!(s.out, val)
    return pos
end

function readfeatures(st, ::Type{Feature{D,T,G,P}}, v::LazyValues) where {D,T,G,P}
    gettype(v) == ARRAY || throw(ArgumentError("\"features\" must be an array"))
    out = Feature{D,T,G,P}[]
    pos = applyarray(FeatureArraySink(st, out), v)
    return out, pos::Int
end

mutable struct CollectionSink{D,T,G,P,S}
    st::S
    bbox::Union{Nothing,Vector{T}}
    features::Vector{Feature{D,T,G,P}}
    extras::Extras
    typed::Bool
end

function (f::CollectionSink{D,T,G,P})(k::PtrString, v::LazyValues) where {D,T,G,P}
    if k == "features"
        val, pos = readfeatures(f.st, Feature{D,T,G,P}, v)
        f.features = val
        return pos
    elseif k == "type"
        s, pos = parsestring(v)
        s == "FeatureCollection" || _wrongtype("FeatureCollection", s)
        f.typed = true
        return pos
    elseif k == "bbox"
        gettype(v) == NULL && return 0
        val, pos = StructUtils.make(f.st, Vector{T}, v)
        f.bbox = val
        return pos
    end
    ex, pos = _extra!(f.st, f.extras, k, v)
    f.extras = ex
    return pos
end

function StructUtils.make(st::JSON.JSONStyle, ::Type{FeatureCollection{D,T,G,P}}, src::LazyValues) where {D,T,G,P}
    gettype(src) == OBJECT || _notobject("a FeatureCollection")
    f = CollectionSink{D,T,G,P,typeof(st)}(st, nothing, Feature{D,T,G,P}[], nothing, false)
    pos = applyobject(f, src)::Int
    f.typed || _notype("FeatureCollection")
    return FeatureCollection{D,T,G,P}(f.bbox, f.features, f.extras), pos
end
StructUtils.make(st::JSON.JSONStyle, ::Type{FeatureCollection{D,T,G,P}}, src::LazyValues, tags) where {D,T,G,P} =
    StructUtils.make(st, FeatureCollection{D,T,G,P}, src)
