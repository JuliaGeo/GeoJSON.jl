"""
    GeoJSONStyle <: JSON.JSONStyle

Read style shared by every GeoJSON `StructUtils.make` method. `JSON.parse` wraps it in a
`JSON.JSONReadStyle`, so the methods dispatch on the abstract `JSON.JSONStyle`.
"""
struct GeoJSONStyle <: JSON.JSONStyle end

using JSON: LazyValue, LazyValues, PtrString, JSONTypes,
            getbuf, getpos, gettype, getopts, getlength, getbyte,
            applyobject, applyarray, applyvalue, parsestring, parsenumber
using StructUtils: EarlyReturn

const OBJECT = JSONTypes.OBJECT
const ARRAY = JSONTypes.ARRAY
const NULL = JSONTypes.NULL
const STRING = JSONTypes.STRING
const NUMBER = JSONTypes.NUMBER

@noinline _notobject(what::String) = throw(ArgumentError("expected a JSON object for $what"))
@noinline _notype(what::String) = throw(ArgumentError("$what has no \"type\" member"))
@noinline _wrongtype(expected::String, got::PtrString) =
    throw(ArgumentError("expected \"type\": \"$expected\", got \"$(convert(String, got))\""))

# Materializes one foreign member the way untyped `JSON.parse` would, returning the end
# position so the enclosing `applyobject` never walks the value twice.
mutable struct ValueBox
    value::Any
    ValueBox() = new()
end
(b::ValueBox)(v) = setfield!(b, :value, v)

function _extra!(extras::Extras, k::PtrString, v::LazyValues)
    box = ValueBox()
    pos = applyvalue(box, v, nothing)
    out = extras === nothing ? Pair{String,Any}[] : extras
    push!(out, Pair{String,Any}(convert(String, k), box.value))
    return out, pos
end
