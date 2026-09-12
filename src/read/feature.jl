# Each value materializes in place through JSON.jl's `applyvalue`; StructUtils' per-value `make(style, Any, v)` is the slow path.
struct DictSink{P}
    dict::P
end
(s::DictSink)(k::PtrString, v::LazyValues) =
    applyvalue(val -> _addkeyval!(s.dict, convert(String, k), val), v, nothing)

# Appending skips the linear duplicate-key scan in `setindex!(::Properties, ...)`.
_addkeyval!(p::Properties, k::String, v) = push!(p.pairs, Pair{String,Any}(k, v))
_addkeyval!(d::AbstractDict{String,Any}, k::String, v) = setindex!(d, v, k)

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
@noinline _nokey(name::String) =
    throw(ArgumentError("\"properties\" has no \"$name\" member and the schema field admits no missing"))

# One slot per NamedTuple schema field, `missing` until its key arrives.
struct SchemaSlots{P,S}
    st::S
    vals::Vector{Any}
end
_slots(::Type{P}) where {P} = fill!(Vector{Any}(undef, fieldcount(P)), missing)

@inline function fillslot!(s::SchemaSlots, i::Int, ::Type{FT}, v::LazyValues) where {FT}
    val, pos = StructUtils.make(s.st, FT, v)
    @inbounds s.vals[i] = val
    return pos::Int
end

# Field names are spliced as string literals, so a key compares by bytes with no Symbol interning.
@generated function (s::SchemaSlots{P})(k::PtrString, v::LazyValues) where {P}
    ex = Expr(:block)
    for i in 1:fieldcount(P)
        name = String(fieldname(P, i))
        push!(ex.args, :(StructUtils.keyeq(k, $name) && return fillslot!(s, $i, $(fieldtype(P, i)), v)))
    end
    push!(ex.args, :(return 0))
    return ex
end

@inline slotvalue(v, ::Type{FT}, name::String) where {FT} = v isa FT ? v : _nokey(name)
@generated function schematuple(::Type{P}, vals::Vector{Any}) where {P<:NamedTuple}
    args = [:(slotvalue(@inbounds(vals[$i]), $(fieldtype(P, i)), $(String(fieldname(P, i)))))
            for i in 1:fieldcount(P)]
    return :(P(($(args...),)))
end

function readprops(st, ::Type{P}, v::LazyValues) where {P<:NamedTuple}
    gettype(v) == OBJECT || _notobject("\"properties\"")
    s = SchemaSlots{P,typeof(st)}(st, _slots(P))
    pos = applyobject(s, v)::Int
    return schematuple(P, s.vals), pos
end
function readprops(st, ::Type{P}, v::LazyValues) where {P<:AbstractDict{String,Any}}
    gettype(v) == OBJECT || _notobject("\"properties\"")
    d = P()
    pos = applyobject(DictSink(d), v)
    return d, pos::Int
end
readprops(st, ::Type{P}, v::LazyValues) where {P} = StructUtils.make(st, P, v)

emptyprops(::Type{P}) where {P<:AbstractDict{String,Any}} = P()
emptyprops(::Type{Nothing}) = nothing
emptyprops(::Type{P}) where {P<:NamedTuple} = schematuple(P, _slots(P))
emptyprops(::Type{P}) where {P} = _noprops(P)

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
    ex, pos = _extra!(f.extras, k, v)
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

function readfeatures(st, ::Type{F}, v::LazyValues) where {F}
    gettype(v) == ARRAY || throw(ArgumentError("\"features\" must be an array"))
    out = F[]
    pos = applyarray(FeatureArraySink{F,typeof(st)}(st, out), v)
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
    ex, pos = _extra!(f.extras, k, v)
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
