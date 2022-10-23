"""
    Feature

A feature wrapping the JSON object.
"""
struct Feature{T}
    object::T
end

Feature{T}(f::Feature{T}) where {T} = f
Feature(f::Feature) = f
Feature(; geometry::Geometry, kwargs...) =
    Feature(merge((type = "Feature", geometry), kwargs))
Feature(geometry::Geometry; kwargs...) =
    Feature(merge((type = "Feature", geometry), kwargs))

"""
    properties(f::Union{Feature,FeatureCollection})

Access the properties JSON object of a Feature
"""
properties(obj::JSON3.Object) = obj.properties
properties(f::Feature{<:JSON3.Object}) = object(f).properties
properties(f::Feature{<:NamedTuple}) =
    haskey(object(f), :properties) ? object(f).properties : nothing

"""
    geometry(f::Feature)

Access the JSON object that represents the Feature's geometry
"""
geometry(f::Feature) = geometry(object(f).geometry)

coordinates(f::Feature) = coordinates(geometry(object(f).geometry))

# Base methods

# the keys in properties are added here for direct access
function Base.propertynames(f::Feature)
    propnames = keys(properties(f))
    # properties named "geometry" are shadowed by the geometry
    return (:geometry, filter(!=(:geometry), propnames)...)
end

function Base.getproperty(f::Feature, nm::Symbol)
    x = if nm == :geometry
        geometry(f)
    else
        props = properties(f)
        getproperty(props, nm)
    end
    return ifelse(x === nothing, missing, x)
end

Base.:(==)(f1::Feature, f2::Feature) = object(f1) == object(f2)



"""
    FeatureCollection <: AbstractVector{Feature}

A feature collection wrapping a JSON object.

Follows the julia `AbstractArray` interface as a lazy vector of `Feature`,
and similarly the GeoInterface.jl interface.
"""
struct FeatureCollection{T,O,A} <: AbstractVector{T}
    object::O
    features::A
    names::Vector{Symbol}
    types::Dict{Symbol,Type}
end
function FeatureCollection(object::O) where {O}
    features = object.features
    if isempty(features) 
        T = Feature{Any} 
        names = Symbol[:geometry]
        types = Dict{Symbol,Type}(:geometry => Union{Missing,Geometry})
    else
        T = typeof(Feature(first(features)))
        names, types = property_schema(features)
        insert!(names, 1, :geometry)
        types[:geometry] = Union{Missing,Geometry}
    end
    return FeatureCollection{T,O,typeof(features)}(object, features, names, types)
end

function FeatureCollection(; features::AbstractVector{T}, kwargs...) where {T}
    object = merge((type = "FeatureCollection", features), kwargs)
    return FeatureCollection(object)
end
FeatureCollection(features::AbstractVector; kwargs...) =
    FeatureCollection(; features, kwargs...)

"""
    features(fc::FeatureCollection)

Access the vector of features in the FeatureCollection
"""
features(fc::FeatureCollection) = getfield(fc, :features)

# Base methods

Base.propertynames(fc::FeatureCollection) = getfield(fc, :names)
Base.getproperty(fc::FeatureCollection, nm::Symbol) = getproperty.(fc, nm)

Base.IteratorSize(::Type{<:FeatureCollection}) = Base.HasLength()
Base.length(fc::FeatureCollection) = length(features(fc))
Base.IteratorEltype(::Type{<:FeatureCollection}) = Base.HasEltype()

# read only AbstractVector
Base.size(fc::FeatureCollection) = size(features(fc))
Base.eltype(::FeatureCollection{T}) where {T<:Feature} = T
Base.getindex(fc::FeatureCollection{T}, i) where {T<:Feature} = T(features(fc)[i])
Base.IndexStyle(::Type{<:FeatureCollection}) = IndexLinear()

function Base.iterate(fc::FeatureCollection{T}) where {T<:Feature}
    x = iterate(features(fc))
    x === nothing && return nothing
    val, state = x
    return T(val), state
end

function Base.iterate(fc::FeatureCollection{T}, state) where {T<:Feature}
    x = iterate(features(fc), state)
    x === nothing && return nothing
    val, state = x
    return T(val), state
end

Base.show(io::IO, fc::FeatureCollection) =
    println(io, "FeatureCollection with $(length(fc)) Features")

function Base.show(io::IO, f::Feature)
    geom = geometry(f)
    propnames = propertynames(f)
    n = length(propnames)
    if geom === nothing
        print(io, "Feature with null geometry")
    else
        print(io, "Feature with a ", type(geom))
    end
    print(io, " and $n properties: ", propnames)
end

# Tables.jl interface methods
Tables.istable(::Type{<:FeatureCollection}) = true
Tables.rowaccess(::Type{<:FeatureCollection}) = true
Tables.rows(fc::FeatureCollection) = fc
Tables.schema(fc::FeatureCollection) =
    Tables.Schema(getfield(fc, :names), [getfield(fc, :types)[nm] for nm in getfield(fc, :names)])

# methods that apply to all GeoJSON Objects
const GeoJSONObject = Union{Geometry,Feature,FeatureCollection}

"""
    object(x::GeoJSONObject)

Access the object underlying the GeoJSONObject. This can be any object that meets the
GeoJSON specification. When reading a file it will generally be a JSON3.Object. When
constructed in code that can also be a NamedTuple for instance. Either will serialize
correctly back to GeoJSON strings.
"""
object(x::GeoJSONObject) = getfield(x, :object)

type(x::GeoJSONObject) = String(object(x).type)
type(x) = String(x.type)
bbox(x::GeoJSONObject) = get(object(x), :bbox, nothing)

Base.show(io::IO, ::MIME"text/plain", x::GeoJSONObject) = show(io, x)

# Adapted from JSONTables.jl jsontable method
# We can simply use their method as we need the key/valu pairs
# of the properties field, rather than the main object
function property_schema(features)
    names = Symbol[]
    seen = Set{Symbol}()
    types = Dict{Symbol, Type}()
    for feature in features
        props = properties(feature)
        isnothing(props) && continue
        if isempty(names)
            for k in propertynames(props)
                k === :geometry && continue
                push!(names, k)
                types[k] = missT(typeof(props[k]))
            end
            seen = Set(names)
        else
            for nm in names
                if hasproperty(props, nm)
                    T = types[nm]
                    v = props[nm]
                    if !(missT(typeof(v)) <: T)
                        types[nm] = Union{T, missT(typeof(v))}
                    end
                else
                    types[nm] = Union{Missing, types[nm]}
                end
            end
            for k in propertynames(props)
                k === :geometry && continue
                if !(k in seen)
                    push!(seen, k)
                    push!(names, k)
                    types[k] = Union{Missing, missT(typeof(v))}
                end
            end
        end
    end
    return names, types
end

# Handle JSON where the properties are always in .properties

missT(::Type{Nothing}) = Missing
missT(::Type{T}) where {T} = T
