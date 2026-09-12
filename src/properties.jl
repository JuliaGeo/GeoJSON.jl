"""
    Properties(pairs...)
    Properties(itr)

Feature properties as an insertion-ordered `AbstractDict{String,Any}`. Keys are `String`s;
`Symbol` keys are accepted by every lookup and mutation method.
"""
struct Properties <: AbstractDict{String,Any}
    pairs::Vector{Pair{String,Any}}
    Properties(pairs::Vector{Pair{String,Any}}) = new(pairs)
end
Properties() = Properties(Pair{String,Any}[])
Properties(ps::Pair...) = Properties(ps)
Properties(itr) = Properties(Pair{String,Any}[_key(k) => v for (k, v) in itr])

_key(k::AbstractString) = String(k)
_key(k::Symbol) = String(k)

function _find(p::Properties, k::String)
    for (i, pair) in enumerate(p.pairs)
        first(pair) == k && return i
    end
    return 0
end

Base.length(p::Properties) = length(p.pairs)
Base.iterate(p::Properties, state...) = iterate(p.pairs, state...)
Base.haskey(p::Properties, k::Union{AbstractString,Symbol}) = _find(p, _key(k)) != 0
function Base.getindex(p::Properties, k::Union{AbstractString,Symbol})
    i = _find(p, _key(k))
    i == 0 && throw(KeyError(k))
    return last(p.pairs[i])
end
function Base.get(p::Properties, k::Union{AbstractString,Symbol}, default)
    i = _find(p, _key(k))
    return i == 0 ? default : last(p.pairs[i])
end
function Base.get(f::Base.Callable, p::Properties, k::Union{AbstractString,Symbol})
    i = _find(p, _key(k))
    return i == 0 ? f() : last(p.pairs[i])
end
function Base.setindex!(p::Properties, v, k::Union{AbstractString,Symbol})
    key = _key(k)
    i = _find(p, key)
    i == 0 ? push!(p.pairs, key => v) : (p.pairs[i] = key => v)
    return p
end
function Base.delete!(p::Properties, k::Union{AbstractString,Symbol})
    i = _find(p, _key(k))
    i == 0 || deleteat!(p.pairs, i)
    return p
end
Base.empty!(p::Properties) = (empty!(p.pairs); p)
Base.copy(p::Properties) = Properties(copy(p.pairs))
Base.sizehint!(p::Properties, n) = (sizehint!(p.pairs, n); p)
