# Fields kept only as an internal cache on FeatureCollection; never serialized.
const COMPUTED_FIELDS = (:names, :types)
# Optional members dropped when absent, matching the GeoJSON spec (a null bbox/id/crs
# is not valid). Mirrors the old StructTypes `omitempties` list.
const OMITEMPTY_FIELDS = (:id, :bbox, :crs)

# Custom lowering to add the "type" field to GeoJSON types during serialization.
# This is required by the GeoJSON spec - all objects must have a "type" field.
@inline function StructUtils.lower(::JSON.JSONStyle, x::T) where {T<:GeoJSONT}
    kept = filter(fieldnames(T)) do f
        f in COMPUTED_FIELDS && return false
        f in OMITEMPTY_FIELDS && getfield(x, f) === nothing && return false
        return true
    end
    values = map(f -> getfield(x, f), kept)
    return merge((type = typestring(T),), NamedTuple{kept}(values))
end

missT(::Type{Nothing}) = Missing
missT(::Type{T}) where {T} = T
