Tables.istable(::Type{<:AbstractFeatureCollection}) = true
Tables.rowaccess(::Type{<:AbstractFeatureCollection}) = true
Tables.rows(fc::AbstractFeatureCollection) = fc
Tables.schema(fc::AbstractFeatureCollection) = Tables.Schema(_schema(fc)...)

# The geometry column is always the geometry field, even when a property is named "geometry".
Tables.getcolumn(f::Feature, k::Symbol) = k === :geometry ? something(geometry(f), missing) : getproperty(f, k)
function Tables.getcolumn(f::Feature, i::Int)
    i == 1 && return something(geometry(f), missing)
    v = _nthproperty(properties(f), i - 1)
    return v === nothing ? missing : v
end

Base.propertynames(fc::AbstractFeatureCollection) = first(_schema(fc))
function Base.getproperty(fc::AbstractFeatureCollection, k::Symbol)
    hasfield(typeof(fc), k) && return getfield(fc, k)
    return _column(fc, k)
end

_columntype(::Type{T}) where {T} = Nothing <: T ? Union{Missing,Base.nonnothingtype(T)} : T
_widen(A, B) = B <: A ? A : Union{A,B}

# --- columns -----------------------------------------------------------------------

# A property key absent from one row, as distinct from a null value.
struct Absent end

# `f(rows[i])` for every row into the narrowest `Vector`: the element type starts at `T` and
# widens as values arrive, the way `collect` does.
function _collectcolumn(f, rows::AbstractVector, ::Type{T}) where {T}
    return _collectcolumn!(f, rows, Vector{T}(undef, length(rows)), 1)
end
function _collectcolumn!(f, rows, out::Vector{T}, from::Int) where {T}
    for i in from:length(rows)
        v = f(@inbounds rows[i])
        if v isa T
            @inbounds out[i] = v
        else
            wider = Vector{_widen(T, typeof(v))}(undef, length(out))
            copyto!(wider, 1, out, 1, i - 1)
            @inbounds wider[i] = v
            return _collectcolumn!(f, rows, wider, i + 1)
        end
    end
    return out
end

_column(fc::FeatureCollection{D,T,G,P}, k::Symbol) where {D,T,G,P} = _column(features(fc), G, P, k)

function _column(rows, ::Type{G}, ::Type{P}, k::Symbol) where {G,P}
    k === :geometry && return _geometrycolumn(rows, G)
    P !== Nothing && hasfield(P, k) || throw(KeyError(k))
    return _collectcolumn(row -> _cell(Tables.getcolumn(row, k)), rows, _columntype(fieldtype(P, k)))
end

# A dict-keyed column is typed by its values; a key absent from every row throws.
function _column(rows, ::Type{G}, ::Type{P}, k::Symbol) where {G,P<:AbstractDict}
    k === :geometry && return _geometrycolumn(rows, G)
    key = String(k)
    found = Ref(false)
    col = _collectcolumn(rows, Union{}) do row
        v = _propertyvalue(row, key)
        v isa Absent && return missing
        found[] = true
        return _cell(v)
    end
    found[] || throw(KeyError(k))
    return col
end

_cell(v) = v === nothing ? missing : v
_propertyvalue(f::Feature, key::String) = get(properties(f), key, Absent())

function _geometrycolumn(rows, ::Type{G}) where {G}
    isempty(rows) && return G[]
    return _collectcolumn(row -> something(geometry(row), missing), rows, Union{})
end

# --- schema ------------------------------------------------------------------------

function _schema(fc::FeatureCollection{D,T,G,P}) where {D,T,G,P}
    names, types = _propertyschema(features(fc), P)
    push!(names, :geometry)
    push!(types, _geometrytype(fc))
    return names, types
end

function _geometrytype(fc::FeatureCollection{D,T,G}) where {D,T,G}
    t = mapreduce(f -> _columntype(typeof(geometry(f))), _widen, features(fc); init=Union{})
    return t === Union{} ? G : t
end

_propertyschema(rows, ::Type{Nothing}) = (Symbol[], Type[])

function _propertyschema(rows, ::Type{P}) where {P}
    names = Symbol[]
    types = Type[]
    for (k, t) in zip(fieldnames(P), fieldtypes(P))
        k === :geometry && continue
        push!(names, k)
        push!(types, _columntype(t))
    end
    return names, types
end

# Column names, types and row counts accumulated one dict-keyed properties object at a time.
struct SchemaPass
    names::Vector{Symbol}
    types::Vector{Type}
    count::Vector{Int}
    seen::Vector{Int}  # last row holding each column; guards count against repeated keys in one row
    index::Dict{Symbol,Int}
end
SchemaPass() = SchemaPass(Symbol[], Type[], Int[], Int[], Dict{Symbol,Int}())

_schemarow!(s::SchemaPass, n::Int, ::Nothing) = s
function _schemarow!(s::SchemaPass, n::Int, p::AbstractDict)
    for (k, v) in pairs(p)
        sym = Symbol(k)
        sym === :geometry && continue
        vt = _columntype(typeof(v))
        i = get(s.index, sym, 0)
        if i == 0
            push!(s.names, sym)
            push!(s.types, vt)
            push!(s.count, 1)
            push!(s.seen, n)
            s.index[sym] = length(s.names)
        else
            s.types[i] = _widen(s.types[i], vt)
            s.seen[i] == n || (s.count[i] += 1; s.seen[i] = n)
        end
    end
    return s
end

function _finish(s::SchemaPass, nrows::Int)
    for i in eachindex(s.names)
        s.count[i] < nrows && (s.types[i] = Union{Missing,s.types[i]})
    end
    return s.names, s.types
end

function _propertyschema(rows, ::Type{P}) where {P<:AbstractDict}
    s = SchemaPass()
    for (n, f) in enumerate(rows)
        _schemarow!(s, n, properties(f))
    end
    return _finish(s, length(rows))
end
