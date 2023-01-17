"""
    Feature

A feature wrapping the JSON object.
"""
struct Feature{T}
    object::T
    parent_properties::Vector{Symbol}
end

Feature(f::Feature) = f
Feature(f::Feature, names::Vector{Symbol}) = Feature(object(f), names)
Feature{T}(f::Feature, names::Vector{Symbol}) where {T} = Feature(object(f), names)
Feature{T}(f::Feature) where {T} = f
Feature(object) = Feature(object, Symbol[])
Feature(; geometry::Union{Geometry,Missing,Nothing}, kwargs...) =
    Feature(merge((type="Feature", geometry), kwargs))
Feature(geometry::Union{Geometry,Missing,Nothing}; kwargs...) =
    Feature(merge((type="Feature", geometry), kwargs))

"""
    properties(f::Union{Feature,FeatureCollection})

Access the properties JSON object of a Feature
"""
properties(obj::JSON3.Object) = obj.properties
properties(f::Feature) = object(f).properties

"""
    geometry(f::Feature)

Access the JSON object that represents the Feature's geometry
"""
function geometry(f::Feature{<:JSON3.Object})
    geom = geometry(object(f).geometry)
    return ismissing(geom) ? nothing : geom
end
function geometry(f::Feature{<:NamedTuple})
    geom = object(f).geometry
    return ismissing(geom) ? nothing : geom
end

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
        if hasproperty(props, nm)
            getproperty(props, nm)
        else
            if nm in getfield(f, :parent_properties)
                missing
            else
                error("property `$nm` is not part of Feature or parent FeatureCollection")
            end
        end
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
        names = Symbol[:geometry]
        types = Dict{Symbol,Type}(:geometry => Union{Missing,Geometry})
        T = Feature{Any}
    else
        names, types = property_schema(features)
        insert!(names, 1, :geometry)
        types[:geometry] = Union{Missing,Geometry}
        f1 = first(features)
        T = if f1 isa JSON3.Object
            typeof(Feature(f1, names))
        elseif f1 isa NamedTuple && isconcretetype(eltype(features))
            typeof(Feature(f1, names))
        else
            T = Feature{Any}
        end
    end
    return FeatureCollection{T,O,typeof(features)}(object, features, names, types)
end
function FeatureCollection(; features::AbstractVector{T}, kwargs...) where {T}
    object = merge((type="FeatureCollection", features), kwargs)
    return FeatureCollection(object)
end
FeatureCollection(features::AbstractVector; kwargs...) =
    FeatureCollection(; features, kwargs...)

names(fc::FeatureCollection) = getfield(fc, :names)
types(fc::FeatureCollection) = getfield(fc, :types)

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
Base.IndexStyle(::Type{<:FeatureCollection}) = IndexLinear()
function Base.getindex(fc::FeatureCollection{T}, i) where {T<:Feature}
    f = features(fc)[i]
    if f isa Feature
        return f
    else
        return T(f, names(fc))
    end
end

function Base.iterate(fc::FeatureCollection{T}) where {T<:Feature}
    x = iterate(features(fc))
    x === nothing && return nothing
    val, state = x
    return T(val, names(fc)), state
end

function Base.iterate(fc::FeatureCollection{T}, state) where {T<:Feature}
    x = iterate(features(fc), state)
    x === nothing && return nothing
    val, state = x
    return T(val, names(fc)), state
end

Base.show(io::IO, ::MIME"text/plain", fc::FeatureCollection) =
    println(io, "FeatureCollection with $(length(fc)) Features")

function Base.show(io::IO, ::MIME"text/plain", f::Feature)
    geom = geometry(f)
    propnames = propertynames(f)
    n = length(propnames)
    if ismissing(geom) || isnothing(geom)
        print(io, "Feature with null geometry")
    else
        print(io, "Feature with a ", type(geom))
    end
    print(io, " and $n properties: ", propnames)
end

# Adapted from JSONTables.jl jsontable method
# We cannot simply use their method as we need the key/value pairs
# of the properties field, rather than the main object
function property_schema(features)
    # Short cut for concrete eltypes of NamedTuple
    if features isa AbstractArray{<:NamedTuple} && isconcretetype(eltype(features))
        f1 = first(features)
        props = properties(f1)
        names = [keys(props)...]
        types = Dict{Symbol,Type}(map((k, v) -> k => typeof(v), keys(props), props)...)
        return names, types
    end
    # Otherwise find the shared names
    names = Symbol[]
    seen = Set{Symbol}()
    types = Dict{Symbol,Type}()
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
                        types[nm] = Union{T,missT(typeof(v))}
                    end
                else
                    types[nm] = Union{Missing,types[nm]}
                end
            end
            for (k, v) in pairs(props)
                k === :geometry && continue
                if !(k in seen)
                    push!(seen, k)
                    push!(names, k)
                    types[k] = Union{Missing,missT(typeof(v))}
                end
            end
        end
    end
    return names, types
end

missT(::Type{Nothing}) = Missing
missT(::Type{T}) where {T} = T
