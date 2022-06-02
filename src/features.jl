"""
    Feature

A feature wrapping a lazy JSON object.

Follows the julia `AbstractArray` interface as a lazy vector of `Feature`, and similarly 
the GeoInterface.jl interface.
"""
struct Feature{T}
    object::T
end

# these features always have type="Feature", so exclude that
# the keys in properties are added here for direct access
Base.propertynames(f::Feature) = keys(properties(f))

"Access the properties JSON3.Object of a Feature"
properties(f::Feature) = object(f).properties

"Access the JSON3.Object that represents the Feature"
object(f::Feature) = getfield(f, :object)

"Access the JSON3.Object that represents the Feature's geometry"
geometry(f::Feature) = geometry(object(f).geometry)

function bbox(f::Feature)
    bbox = get(object(f), :bbox, nothing)
    isnothing(bbox) ? get(properties(f), :bbox, nothing) : bbox
end
function crs(f::Feature)
    crs = get(object(f), :crs, nothing)
    isnothing(crs) ? get(properties(f), :crs, nothing) : crs
end

# Base methods
Base.show(io::IO, ::MIME"text/plain", f::Feature) = show(io, f)


"""
    FeatureCollection <: AbstractVector

A feature collection wrapping both a lazy JSON object and an array of features.

Follows the julia `AbstractArray` interface as a lazy vector of `Feature`, and similarly 
the GeoInterface.jl interface.
"""
struct FeatureCollection{O,A} <: AbstractVector{eltype(A)}
    object::O
    array::A
end

"Access the JSON3.Object that represents the FeatureCollection"
object(f::FeatureCollection) = f.object

"Access the JSON3.Array that represents the FeatureCollection"
array(f::FeatureCollection) = f.array

bbox(f::FeatureCollection) = get(object(f), :bbox, nothing)
crs(f::FeatureCollection) = get(object(f), :crs, nothing)

# Base methods

Base.IteratorSize(::Type{<:FeatureCollection}) = Base.HasLength()
Base.length(fc::FeatureCollection) = length(array(fc))
Base.IteratorEltype(::Type{<:FeatureCollection}) = Base.HasEltype()

# read only AbstractVector
Base.size(fc::FeatureCollection) = size(array(fc))
Base.getindex(fc::FeatureCollection, i) = array(fc)[i]
Base.IndexStyle(::Type{<:FeatureCollection}) = IndexLinear()

"""
Get a specific property of the Feature

Returns missing for null/nothing or not present, to work nicely with
properties that are not defined for every feature. If it is a table,
it should in some sense be defined.
"""
function Base.getproperty(f::Feature, nm::Symbol)
    props = properties(f)
    val = get(props, nm, missing)
    miss(val)
end

@inline function Base.iterate(fc::FeatureCollection)
    st = iterate(array(fc))
    st === nothing && return nothing
    val, state = st
    return Feature(val), state
end

@inline function Base.iterate(fc::FeatureCollection, st)
    st = iterate(array(fc), st)
    st === nothing && return nothing
    val, state = st
    return Feature(val), state
end

Base.show(io::IO, fc::FeatureCollection) = println(io, "FeatureCollection with $(length(fc)) Features")
function Base.show(io::IO, f::Feature)
    geom = geometry(f)
    if isnothing(geom)
        print(io, "Feature without geometry")
    else
        print(io, "Feature with geometry type $(geometry(f))")
    end
    print(io, ", and properties: $(propertynames(f))")
end
Base.show(io::IO, ::MIME"text/plain", fc::FeatureCollection) = show(io, fc)

# Tables.jl interface methods
Tables.istable(::Type{<:FeatureCollection}) = true
Tables.rowaccess(::Type{<:FeatureCollection}) = true
Tables.rows(fc::FeatureCollection) = fc
