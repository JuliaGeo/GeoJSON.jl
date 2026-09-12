const Found = EarlyReturn{Int}

"""
    discover_dim(bytes) -> Int

Dimension of the first coordinate position reachable through `features → geometry →
coordinates` (or `geometries`), descending only through those keys so `properties` and
`bbox` are never entered. Returns 0 when the document holds no coordinate.
"""
discover_dim(bytes) = discover_dim(JSON.lazy(bytes))
function discover_dim(x::LazyValue)
    r = _dim(x)
    return r isa Found ? r.value : 0
end

# Either the position past `x` (nothing found; parsing resumes there) or `Found(D)`.
function _dim(x::LazyValue)::Union{Int,Found}
    gettype(x) == OBJECT || return 0
    return applyobject(x) do k, v
        if k == "features" || k == "geometries"
            gettype(v) == ARRAY || return 0
            return applyarray((_, e) -> _dim(e), v)
        elseif k == "geometry"
            return _dim(v)
        elseif k == "coordinates"
            return _coord_dim(v)
        end
        return 0
    end
end

function _coord_dim(x::LazyValue)::Union{Int,Found}
    gettype(x) == ARRAY || return 0
    n = Ref(0)
    r = applyarray(x) do i, e
        t = gettype(e)
        t == ARRAY && return _coord_dim(e)
        t == NUMBER && (n[] = i)
        return 0
    end
    r isa Found && return r
    return n[] > 0 ? Found(n[]) : r
end

mutable struct DimScan
    minD::Int
    maxD::Int
    npoints::Int
    feature::Int
    badfeature::Int
    expect::Int
end

"""
    scan_dims(bytes; expect=0) -> DimScan

Count the elements of every coordinate position by byte scanning. Records the min and max
dimension, the point count, and the first feature index whose dimension differs from
`expect` (or from the first position seen when `expect` is 0). Runs only on the error path,
to name the feature in a [`DimMismatch`](@ref).
"""
scan_dims(bytes; expect::Int=0) = scan_dims(JSON.lazy(bytes); expect)
function scan_dims(x::LazyValue; expect::Int=0)
    s = DimScan(typemax(Int), 0, 0, 0, 0, expect)
    _scan(x, s)
    s.npoints == 0 && (s.minD = 0)
    return s
end

function _scan(x::LazyValue, s::DimScan)::Int
    gettype(x) == OBJECT || return 0
    return applyobject(x) do k, v
        if k == "features"
            gettype(v) == ARRAY || return 0
            return applyarray(v) do i, e
                s.feature = i
                _scan(e, s)
            end
        elseif k == "geometries"
            gettype(v) == ARRAY || return 0
            return applyarray((_, e) -> _scan(e, s), v)
        elseif k == "geometry"
            return _scan(v, s)
        elseif k == "coordinates"
            return _scan_coords(v, s)
        end
        return 0
    end
end

function _scan_coords(x::LazyValue, s::DimScan)::Int
    gettype(x) == ARRAY || return 0
    buf = getbuf(x)
    n, endpos = flatcount(buf, getpos(x), getlength(buf))
    n < 0 && return applyarray((_, e) -> _scan_coords(e, s), x)
    n == 0 && return endpos
    s.npoints += 1
    s.minD = min(s.minD, n)
    s.maxD = max(s.maxD, n)
    s.expect == 0 && (s.expect = n)
    n != s.expect && s.badfeature == 0 && (s.badfeature = s.feature)
    return endpos
end
