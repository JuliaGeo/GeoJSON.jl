abstract type GeoJSONT{D,T} end
abstract type AbstractGeometry{D,T} <: GeoJSONT{D,T} end
abstract type AbstractFeatureCollection{D,T} <: GeoJSONT{D,T} end

"""
    Extras

Foreign members of a GeoJSON object in document order; `nothing` when the object has none.
"""
const Extras = Union{Nothing,Vector{Pair{String,Any}}}

for (name, C, K) in (
    (:Point, :(NTuple{D,T}), :E),
    (:LineString, :(Vector{NTuple{D,T}}), :(Vector{E})),
    (:MultiPoint, :(Vector{NTuple{D,T}}), :(Vector{E})),
    (:Polygon, :(Vector{Vector{NTuple{D,T}}}), :(Vector{Vector{E}})),
    (:MultiLineString, :(Vector{Vector{NTuple{D,T}}}), :(Vector{Vector{E}})),
    (:MultiPolygon, :(Vector{Vector{Vector{NTuple{D,T}}}}), :(Vector{Vector{Vector{E}}})),
)
    @eval begin
        """
            $($name){D,T}(bbox, coordinates[, extras])
            $($name){D,T}(; bbox=nothing, coordinates=nothing, extras=nothing)
            $($name)(; coordinates, bbox=nothing, extras=nothing)

        A $($name) geometry with `D` dimensions and coordinate type `T`; `coordinates` is `$($(string(C)))`.
        The bare constructor infers `D` and `T` from `coordinates`.
        """
        struct $name{D,T} <: AbstractGeometry{D,T}
            bbox::Union{Nothing,Vector{T}}
            coordinates::Union{Nothing,$C}
            extras::Extras
            $name{D,T}(bbox, coordinates, extras=nothing) where {D,T} = new{D,T}(bbox, coordinates, extras)
        end
        $name{D,T}(; bbox=nothing, coordinates=nothing, extras=nothing) where {D,T} =
            $name{D,T}(bbox, coordinates, extras)
        $name(; coordinates::$K, bbox=nothing, extras=nothing) where {E<:Tuple} =
            $name{fieldcount(E),eltype(E)}(bbox, coordinates, extras)
        typestring(::Type{<:$name}) = $(String(name))
    end
end

Base.eltype(::Type{Point{D,T}}) where {D,T} = T
Base.eltype(::Type{LineString{D,T}}) where {D,T} = NTuple{D,T}
Base.eltype(::Type{MultiPoint{D,T}}) where {D,T} = NTuple{D,T}
Base.eltype(::Type{Polygon{D,T}}) where {D,T} = Vector{NTuple{D,T}}
Base.eltype(::Type{MultiLineString{D,T}}) where {D,T} = Vector{NTuple{D,T}}
Base.eltype(::Type{MultiPolygon{D,T}}) where {D,T} = Vector{Vector{NTuple{D,T}}}

"""
    GeometryCollection{D,T}(bbox, geometries[, extras])
    GeometryCollection{D,T}(; bbox=nothing, geometries=AnyGeometry{D,T}[], extras=nothing)
    GeometryCollection(; geometries, bbox=nothing, extras=nothing)

A GeometryCollection holding any of the seven GeoJSON geometries with `D` dimensions.
"""
struct GeometryCollection{D,T} <: AbstractGeometry{D,T}
    bbox::Union{Nothing,Vector{T}}
    geometries::Vector{Union{Point{D,T},LineString{D,T},Polygon{D,T},MultiPoint{D,T},
                             MultiLineString{D,T},MultiPolygon{D,T},GeometryCollection{D,T}}}
    extras::Extras
    GeometryCollection{D,T}(bbox, geometries, extras=nothing) where {D,T} = new{D,T}(bbox, geometries, extras)
end
const AnyGeometry{D,T} = Union{Point{D,T},LineString{D,T},Polygon{D,T},MultiPoint{D,T},
                               MultiLineString{D,T},MultiPolygon{D,T},GeometryCollection{D,T}}
GeometryCollection{D,T}(; bbox=nothing, geometries=AnyGeometry{D,T}[], extras=nothing) where {D,T} =
    GeometryCollection{D,T}(bbox, geometries, extras)
GeometryCollection(; geometries::AbstractVector{<:AbstractGeometry{D,T}}, bbox=nothing, extras=nothing) where {D,T} =
    GeometryCollection{D,T}(bbox, geometries, extras)
typestring(::Type{<:GeometryCollection}) = "GeometryCollection"
Base.eltype(::Type{GeometryCollection{D,T}}) where {D,T} = AnyGeometry{D,T}

"""
    Feature{D,T,G,P}(id, bbox, geometry, properties, extras)
    Feature{D,T}(; id=nothing, bbox=nothing, geometry=nothing, properties=Dict{String,Any}(), extras=nothing)
    Feature(; geometry::AbstractGeometry{D,T}, ...)

A GeoJSON Feature. `G` is the geometry type (`AnyGeometry{D,T}` by default) and `P` the properties
container: `Dict{String,Any}` by default, [`Properties`](@ref) for document order, `Nothing` for
skipped properties, a `NamedTuple`, or a user struct. The keyword constructors accept Symbol-keyed
`properties` (a `NamedTuple`, `pairs(nt)`) for a String-keyed `P`.
`f.name` returns property `name` when present, else the field `name`, else `missing`;
`f["name"]`, `get(f, "name", default)` and `haskey(f, "name")` reach the properties container.
"""
struct Feature{D,T,G,P} <: GeoJSONT{D,T}
    id::Union{Nothing,String,Int64,Float64}
    bbox::Union{Nothing,Vector{T}}
    geometry::Union{Nothing,G}
    properties::P
    extras::Extras
end
Feature{D,T,G,P}(; id=nothing, bbox=nothing, geometry=nothing, properties=emptyprops(P), extras=nothing) where {D,T,G,P} =
    Feature{D,T,G,P}(id, bbox, geometry, _asprops(P, properties), extras)
Feature{D,T}(; kw...) where {D,T} = Feature{D,T,AnyGeometry{D,T},Dict{String,Any}}(; kw...)
_asprops(::Type{P}, x) where {P} = x isa P ? x : _keyed(P, x)
_keyed(::Type{P}, x) where {P<:AbstractDict{String,Any}} = P(_key(k) => v for (k, v) in _pairs(x))
_keyed(::Type{P}, x) where {P} = x
_pairs(x::NamedTuple) = pairs(x)
_pairs(x) = x
Feature(; geometry::AbstractGeometry{D,T}, kw...) where {D,T} = Feature{D,T}(; geometry, kw...)
typestring(::Type{<:Feature}) = "Feature"

"""
    FeatureCollection{D,T,G,P}(bbox, features, extras)
    FeatureCollection{D,T}(; bbox=nothing, features=Feature{D,T}[], extras=nothing)
    FeatureCollection(; features::Vector{<:Feature{D,T}}, ...)

A GeoJSON FeatureCollection; indexes and iterates as a vector of `Feature{D,T,G,P}`.
"""
struct FeatureCollection{D,T,G,P} <: AbstractFeatureCollection{D,T}
    bbox::Union{Nothing,Vector{T}}
    features::Vector{Feature{D,T,G,P}}
    extras::Extras
end
FeatureCollection{D,T,G,P}(; bbox=nothing, features=Feature{D,T,G,P}[], extras=nothing) where {D,T,G,P} =
    FeatureCollection{D,T,G,P}(bbox, features, extras)
FeatureCollection{D,T}(; kw...) where {D,T} = FeatureCollection{D,T,AnyGeometry{D,T},Dict{String,Any}}(; kw...)
FeatureCollection(; features::AbstractVector{Feature{D,T,G,P}}, bbox=nothing, extras=nothing) where {D,T,G,P} =
    FeatureCollection{D,T,G,P}(bbox, features, extras)
typestring(::Type{<:FeatureCollection}) = "FeatureCollection"
typestring(::Type{Nothing}) = "null"
typestring(::Type{Missing}) = "null"
typestring(x) = typestring(typeof(x))

"""
    bbox(x) -> Union{Nothing,Vector{T}}

The `bbox` member of a geometry, `Feature`, or collection: `[minx, miny, maxx, maxy]` (six values in 3-D), or `nothing`.
"""
bbox(x::GeoJSONT) = getfield(x, :bbox)

"""
    extras(x) -> Extras

The foreign members of `x` in document order, or `nothing`.
"""
extras(x::GeoJSONT) = getfield(x, :extras)

"""
    coordinates(g) -> coordinate tree
    coordinates(f::Feature)

The `coordinates` of a geometry as nested vectors of `NTuple{D,T}` (`nothing` for an empty
geometry); for a `GeometryCollection`, one tree per member; for a `Feature`, those of its geometry.
"""
coordinates(g::AbstractGeometry) = getfield(g, :coordinates)
coordinates(g::GeometryCollection) = coordinates.(geometry(g))
coordinates(f::Feature) = coordinates(geometry(f))

"""
    geometry(f::Feature) -> Union{Nothing,G}
    geometry(gc::GeometryCollection) -> Vector

The geometry of a `Feature` (`nothing` when its `geometry` member is null), or the member
geometries of a `GeometryCollection`.
"""
geometry(g::GeometryCollection) = getfield(g, :geometries)
geometry(f::Feature) = getfield(f, :geometry)

"""
    id(f::Feature) -> Union{Nothing,String,Int64,Float64}

The `id` member of a feature, or `nothing`.
"""
id(f::Feature) = getfield(f, :id)

"""
    properties(f::Feature) -> P

The properties container of a feature: a `Dict{String,Any}` by default, a [`Properties`](@ref),
a `NamedTuple`, a user struct, or `nothing` when properties were skipped.
"""
properties(f::Feature) = getfield(f, :properties)

"""
    features(fc) -> Vector{Feature}

The features of a collection; a [`LazyFeatureCollection`](@ref) materializes every feature.
"""
features(fc::FeatureCollection) = getfield(fc, :features)

"""
    typestring(x) -> String

The GeoJSON `"type"` name of a value or type: `"Point"`, `"Feature"`, and so on; `"null"` for
`nothing` and `missing`.
"""
typestring

_items(g::AbstractGeometry) = coordinates(g)
_items(g::GeometryCollection) = geometry(g)
Base.length(g::AbstractGeometry) = length(_items(g))
Base.lastindex(g::AbstractGeometry) = length(_items(g))
Base.size(g::AbstractGeometry) = size(_items(g))
Base.axes(g::AbstractGeometry) = axes(_items(g))
Base.getindex(g::AbstractGeometry, i::Int) = getindex(_items(g), i)
Base.IndexStyle(::Type{<:AbstractGeometry}) = Base.IndexLinear()
Base.iterate(g::AbstractGeometry, state=1) = iterate(_items(g), state)

# Properties and extras hold `missing` and `Any`, so they compare with `isequal` and `==` stays a Bool.
Base.:(==)(a::AbstractGeometry, b::AbstractGeometry) =
    typeof(a) === typeof(b) && _items(a) == _items(b) && isequal(extras(a), extras(b))
Base.isequal(a::AbstractGeometry, b::AbstractGeometry) =
    typeof(a) === typeof(b) && isequal(_items(a), _items(b)) && isequal(extras(a), extras(b))
Base.hash(g::AbstractGeometry, h::UInt) = hash(_items(g), hash(extras(g), hash(typeof(g), h)))
Base.:(==)(a::Feature, b::Feature) =
    id(a) == id(b) && bbox(a) == bbox(b) && geometry(a) == geometry(b) &&
    isequal(properties(a), properties(b)) && isequal(extras(a), extras(b))
Base.isequal(a::Feature, b::Feature) =
    isequal(id(a), id(b)) && isequal(bbox(a), bbox(b)) && isequal(geometry(a), geometry(b)) &&
    isequal(properties(a), properties(b)) && isequal(extras(a), extras(b))
Base.hash(f::Feature, h::UInt) =
    hash(extras(f), hash(properties(f), hash(geometry(f), hash(bbox(f), hash(id(f), hash(Feature, h))))))
Base.:(==)(a::FeatureCollection, b::FeatureCollection) =
    bbox(a) == bbox(b) && features(a) == features(b) && isequal(extras(a), extras(b))
Base.isequal(a::FeatureCollection, b::FeatureCollection) =
    isequal(bbox(a), bbox(b)) && isequal(features(a), features(b)) && isequal(extras(a), extras(b))
Base.hash(fc::FeatureCollection, h::UInt) =
    hash(extras(fc), hash(features(fc), hash(bbox(fc), hash(FeatureCollection, h))))

Base.show(io::IO, ::Point{D,T}) where {D,T} = print(io, D, "D Point")
function Base.show(io::IO, g::AbstractGeometry{D,T}) where {D,T}
    print(io, D, "D ", typestring(g))
    c = coordinates(g)
    get(io, :compact, false) || c === nothing || print(io, " with ", length(c), " sub-geometries")
end
Base.show(io::IO, g::GeometryCollection{D,T}) where {D,T} =
    print(io, "GeometryCollection with ", length(g), " ", D, "D geometries")
Base.show(io::IO, f::Feature{D,T}) where {D,T} =
    print(io, "Feature with ", D, "D ", typestring(geometry(f)), " geometry and ",
          length(propertynames(f)), " properties: ", propertynames(f))
Base.show(io::IO, fc::FeatureCollection) = print(io, "FeatureCollection with ", length(fc), " Features")

# Property lookup for every supported container: a dict, a NamedTuple, nothing, or a user struct.
_haskey(::Nothing, k::Symbol) = false
_haskey(p::AbstractDict, k::Symbol) = haskey(p, k)
_haskey(p::AbstractDict{String}, k::Symbol) = haskey(p, String(k))
_haskey(p::NamedTuple, k::Symbol) = haskey(p, k)
_haskey(p, k::Symbol) = hasproperty(p, k)
_getkey(p::AbstractDict, k::Symbol) = p[k]
_getkey(p::AbstractDict{String}, k::Symbol) = p[String(k)]
_getkey(p, k::Symbol) = getproperty(p, k)
_pushnames!(names::Vector{Symbol}, ::Nothing) = names
_pushnames!(names::Vector{Symbol}, p::AbstractDict) = _pushnames!(names, keys(p))
_pushnames!(names::Vector{Symbol}, p) = _pushnames!(names, propertynames(p))
function _pushnames!(names::Vector{Symbol}, keys::Union{Base.KeySet,Tuple})
    for k in keys
        s = Symbol(k)
        s === :geometry || push!(names, s)
    end
    return names
end
# The n-th property after `geometry` is dropped, in the order `propertynames` lists them.
function _nthproperty(p::AbstractDict, n::Int)
    i = n
    for (k, v) in pairs(p)
        Symbol(k) === :geometry && continue
        i -= 1
        i == 0 && return v
    end
    throw(BoundsError(p, n))
end
function _nthproperty(p, n::Int)
    i = n
    for k in propertynames(p)
        k === :geometry && continue
        i -= 1
        i == 0 && return getproperty(p, k)
    end
    throw(BoundsError(p, n))
end

const FEATURE_FIELDS = (:id, :bbox, :geometry, :properties, :extras)

Base.propertynames(f::Feature)::Tuple{Vararg{Symbol}} = Tuple(_pushnames!(Symbol[:geometry], properties(f)))
function Base.getproperty(f::Feature, k::Symbol)
    p = properties(f)
    v = if _haskey(p, k)
        _getkey(p, k)
    elseif k in FEATURE_FIELDS
        getfield(f, k)
    else
        missing
    end
    v === nothing ? missing : v
end
Base.haskey(f::Feature, k::Union{AbstractString,Symbol}) = _haskey(properties(f), Symbol(k))
function Base.getindex(f::Feature, k::Union{AbstractString,Symbol})
    p = properties(f)
    s = Symbol(k)
    _haskey(p, s) || throw(KeyError(k))
    return _getkey(p, s)
end
function Base.get(f::Feature, k::Union{AbstractString,Symbol}, default)
    p = properties(f)
    s = Symbol(k)
    return _haskey(p, s) ? _getkey(p, s) : default
end
Base.IteratorSize(::Type{<:Feature}) = Base.SizeUnknown()
function Base.iterate(f::Feature, state=(propertynames(f), 1))
    names, i = state
    i > length(names) && return nothing
    k = @inbounds names[i]
    return (k => getproperty(f, k), (names, i + 1))
end

Base.eltype(::Type{FeatureCollection{D,T,G,P}}) where {D,T,G,P} = Feature{D,T,G,P}
Base.eltype(::Type{<:AbstractFeatureCollection{D,T}}) where {D,T} = Feature{D,T}
Base.IteratorEltype(::Type{<:AbstractFeatureCollection}) = Base.HasEltype()
Base.IteratorSize(::Type{<:AbstractFeatureCollection}) = Base.HasLength()
Base.length(fc::AbstractFeatureCollection) = length(features(fc))
Base.lastindex(fc::AbstractFeatureCollection) = length(fc)
Base.size(fc::AbstractFeatureCollection) = (length(fc),)
Base.IndexStyle(::Type{<:AbstractFeatureCollection}) = Base.IndexLinear()
Base.getindex(fc::FeatureCollection, i::Union{Int,UnitRange,Vector}) = features(fc)[i]
function Base.iterate(fc::AbstractFeatureCollection, state=1)
    (1 <= state <= length(fc)) || return nothing
    return fc[state], state + 1
end
