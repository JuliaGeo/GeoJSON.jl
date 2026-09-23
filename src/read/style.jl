using JSON: LazyValue, LazyValues, PtrString, JSONTypes,
            getbuf, getpos, gettype, getopts, getlength, getbyte,
            applyobject, applyarray, parsestring, parsenumber
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
function _extra!(st, extras::Extras, k::PtrString, v::LazyValues)
    val, pos = StructUtils.make(st, Any, v)
    out = extras === nothing ? Pair{String,Any}[] : extras
    push!(out, Pair{String,Any}(convert(String, k), val))
    return out, pos
end
