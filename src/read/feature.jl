# Properties: insertion-ordered pairs on JSON.jl's own `applyvalue` materializer.
struct PairSink
    pairs::Vector{Pair{String,Any}}
end
(s::PairSink)(k::PtrString, v::LazyValues) =
    applyvalue(val -> push!(s.pairs, Pair{String,Any}(convert(String, k), val)), v, nothing)

function StructUtils.make(::JSON.JSONStyle, ::Type{Properties}, x::LazyValues)
    gettype(x) == OBJECT || _notobject("\"properties\"")
    pairs = Pair{String,Any}[]
    pos = applyobject(PairSink(pairs), x)
    return Properties(pairs), pos::Int
end
StructUtils.make(st::JSON.JSONStyle, ::Type{Properties}, x::LazyValues, tags) =
    StructUtils.make(st, Properties, x)

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

# Typed columns keep isbits property values unboxed; one buffer serves every feature of a
# collection. `tags[i]` is 0 while slot `i` is missing.
struct SlotBuffer
    tags::Vector{UInt8}
    f64::Vector{Float64}
    i64::Vector{Int64}
    bools::Vector{Bool}
    strs::Vector{String}
    boxed::Vector{Any}
end
SlotBuffer(n::Int) = SlotBuffer(zeros(UInt8, n), Vector{Float64}(undef, n), Vector{Int64}(undef, n),
                                Vector{Bool}(undef, n), Vector{String}(undef, n), Vector{Any}(undef, n))
SlotBuffer(::Type{P}) where {P<:NamedTuple} = SlotBuffer(fieldcount(P))

slotbuffer(::Type{P}) where {P<:NamedTuple} = SlotBuffer(P)
slotbuffer(::Type) = nothing

# The non-missing part of a field type picks its column and tag at compile time.
column(b::SlotBuffer, ::Type{Float64}) = b.f64
column(b::SlotBuffer, ::Type{Int64}) = b.i64
column(b::SlotBuffer, ::Type{Bool}) = b.bools
column(b::SlotBuffer, ::Type{String}) = b.strs
column(b::SlotBuffer, ::Type) = b.boxed
slottag(::Type{Float64}) = 0x01
slottag(::Type{Int64}) = 0x02
slottag(::Type{Bool}) = 0x03
slottag(::Type{String}) = 0x04
slottag(::Type) = 0x05

@noinline function _badvalue(name::String, expected::String, t)
    t == NULL && throw(ArgumentError("\"properties\" member \"$name\" is null and the schema field admits no missing"))
    throw(ArgumentError("\"properties\" member \"$name\" must be $expected"))
end

function readslot(::Type{Float64}, st, name::String, v::LazyValues)
    t = gettype(v)
    t == NUMBER || _badvalue(name, "a number", t)
    num, pos = parsenumber(v, Float64)
    x = JSON.isint(num) ? Float64(num.int) :
        JSON.isfloat(num) ? num.float :
        JSON.isbigint(num) ? Float64(num.bigint) : Float64(num.bigfloat)
    return x, pos
end
function readslot(::Type{Int64}, st, name::String, v::LazyValues)
    t = gettype(v)
    t == NUMBER || _badvalue(name, "an integer", t)
    num, pos = parsenumber(v, Int64)
    JSON.isint(num) && return num.int, pos
    JSON.isfloat(num) && return Int64(num.float), pos
    _badvalue(name, "an integer within Int64", t)
end
function readslot(::Type{Bool}, st, name::String, v::LazyValues)
    t = gettype(v)
    t == JSONTypes.TRUE && return true, getpos(v) + 4
    t == JSONTypes.FALSE && return false, getpos(v) + 5
    _badvalue(name, "a boolean", t)
end
function readslot(::Type{String}, st, name::String, v::LazyValues)
    t = gettype(v)
    t == STRING || _badvalue(name, "a string", t)
    s, pos = parsestring(v)
    return convert(String, s), pos
end
readslot(::Type{NM}, st, name::String, v::LazyValues) where {NM} = StructUtils.make(st, NM, v)

struct SchemaSlots{P,S}
    st::S
    buf::SlotBuffer
end

@inline function fillslot!(s::SchemaSlots, i::Int, ::Type{FT}, ::Type{NM}, name::String, v::LazyValues) where {FT,NM}
    b = s.buf
    if Missing <: FT && gettype(v) == NULL
        @inbounds b.tags[i] = 0x00
        return getpos(v) + 4
    end
    x, pos = readslot(NM, s.st, name, v)
    @inbounds column(b, NM)[i] = x
    @inbounds b.tags[i] = slottag(NM)
    return pos::Int
end

# Field names are spliced as string literals, so a key compares by bytes with no Symbol interning.
@generated function (s::SchemaSlots{P})(k::PtrString, v::LazyValues) where {P}
    ex = Expr(:block)
    for i in 1:fieldcount(P)
        FT = fieldtype(P, i)
        name = String(fieldname(P, i))
        push!(ex.args, :(StructUtils.keyeq(k, $name) &&
                         return fillslot!(s, $i, $FT, $(Base.nonmissingtype(FT)), $name, v)))
    end
    push!(ex.args, :(return 0))
    return ex
end

@inline function slotvalue(b::SlotBuffer, i::Int, ::Type{FT}, ::Type{NM}, name::String) where {FT,NM}
    if @inbounds(b.tags[i]) == 0x00
        Missing <: FT || _nokey(name)
        return missing
    end
    return @inbounds(column(b, NM)[i])::NM
end
@generated function schematuple(::Type{P}, b::SlotBuffer) where {P<:NamedTuple}
    args = [:(slotvalue(b, $i, $(fieldtype(P, i)), $(Base.nonmissingtype(fieldtype(P, i))),
                        $(String(fieldname(P, i)))))
            for i in 1:fieldcount(P)]
    return :(P(($(args...),)))
end

function readprops(st, ::Type{P}, v::LazyValues, b::SlotBuffer) where {P<:NamedTuple}
    gettype(v) == OBJECT || _notobject("\"properties\"")
    fill!(b.tags, 0x00)
    pos = applyobject(SchemaSlots{P,typeof(st)}(st, b), v)::Int
    return schematuple(P, b), pos
end
readprops(st, ::Type{P}, v::LazyValues, ::Nothing) where {P} = StructUtils.make(st, P, v)
readprops(st, ::Type{P}, v::LazyValues) where {P} = readprops(st, P, v, slotbuffer(P))

emptyprops(::Type{Properties}) = Properties()
emptyprops(::Type{Nothing}) = nothing
emptyprops(::Type{P}) where {P<:NamedTuple} = schematuple(P, SlotBuffer(P))
emptyprops(::Type{P}) where {P} = _noprops(P)

mutable struct FeatureSink{D,T,G,P,S,B}
    st::S
    slots::B
    id::Union{Nothing,String,Int64,Float64}
    bbox::Union{Nothing,Vector{T}}
    geometry::Union{Nothing,G}
    properties::Union{Nothing,P}
    extras::Extras
    typed::Bool
end

FeatureSink{D,T,G,P}(st::S, slots::B) where {D,T,G,P,S,B} =
    FeatureSink{D,T,G,P,S,B}(st, slots, nothing, nothing, nothing, nothing, nothing, false)

readprops!(::FeatureSink{D,T,G,Nothing}, v::LazyValues) where {D,T,G} = JSON.skip(v)
function readprops!(f::FeatureSink{D,T,G,P}, v::LazyValues) where {D,T,G,P}
    gettype(v) == NULL && return 0
    val, pos = readprops(f.st, P, v, f.slots)
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

function makefeature(st, ::Type{Feature{D,T,G,P}}, src::LazyValues, slots) where {D,T,G,P}
    gettype(src) == OBJECT || _notobject("a Feature")
    f = FeatureSink{D,T,G,P}(st, slots)
    pos = applyobject(f, src)::Int
    f.typed || _notype("Feature")
    props = f.properties
    props === nothing && (props = emptyprops(P))
    return Feature{D,T,G,P}(f.id, f.bbox, f.geometry, props, f.extras), pos
end
StructUtils.make(st::JSON.JSONStyle, ::Type{Feature{D,T,G,P}}, src::LazyValues) where {D,T,G,P} =
    makefeature(st, Feature{D,T,G,P}, src, slotbuffer(P))
StructUtils.make(st::JSON.JSONStyle, ::Type{Feature{D,T,G,P}}, src::LazyValues, tags) where {D,T,G,P} =
    StructUtils.make(st, Feature{D,T,G,P}, src)

struct FeatureArraySink{F,S,B}
    st::S
    out::Vector{F}
    slots::B
end

function (s::FeatureArraySink{F})(_, v::LazyValues) where {F}
    val, pos = makefeature(s.st, F, v, s.slots)
    push!(s.out, val)
    return pos
end

function readfeatures(st, ::Type{Feature{D,T,G,P}}, v::LazyValues) where {D,T,G,P}
    gettype(v) == ARRAY || throw(ArgumentError("\"features\" must be an array"))
    out = Feature{D,T,G,P}[]
    pos = applyarray(FeatureArraySink(st, out, slotbuffer(P)), v)
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
