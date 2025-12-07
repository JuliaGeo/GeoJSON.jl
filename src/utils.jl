# Custom lowering to add the "type" field to GeoJSON types during serialization
# This is required by the GeoJSON spec - all objects must have a "type" field
@inline function StructUtils.lower(style::JSON.JSONStyle, x::T) where {T<:GeoJSONT}
    # Get all field names and values
    fields = fieldnames(T)
    values = ntuple(i -> getfield(x, fields[i]), length(fields))

    # Create a NamedTuple with "type" first, then all the struct fields
    return merge((type = typestring(T),), NamedTuple{fields}(values))
end

missT(::Type{Nothing}) = Missing
missT(::Type{T}) where {T} = T
