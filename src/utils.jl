_omitoptional(x) = x === nothing || x === missing
_omitoptional(x::Union{AbstractString,AbstractArray,AbstractDict}) = isempty(x)

# Estimate from the numeric payload; JSON grows the buffer if more space is needed.
_coordinatesize(::Nothing) = 4
function _coordinatesize(x::Vector{C}) where {C<:Tuple}
    D = fieldcount(C)
    width = D == 0 ? 0 : D * (2 * sizeof(eltype(C)) + 1)
    2 + length(x) * (3 + width)
end
_coordinatesize(x::Vector) = 2 + length(x) + sum(_coordinatesize, x; init = 0)

function JSON.sizeguess(
    x::Union{
        LineString{D,T},
        MultiPoint{D,T},
        MultiLineString{D,T},
        Polygon{D,T},
        MultiPolygon{D,T},
    },
) where {D,T<:Union{Float32,Float64}}
    box = getfield(x, :bbox)
    64 +
    _coordinatesize(coordinates(x)) +
    (box === nothing ? 0 : length(box) * (2 * sizeof(T) + 1))
end

@generated function StructUtils.applyeach(
    style::JSON.JSONStyle,
    f,
    x::T,
) where {T<:GeoJSONT}
    body = Expr(:block, :(f("type", typestring(T))))
    for name in fieldnames(T)
        name in (:names, :types) && continue
        value = :(getfield(x, $(QuoteNode(name))))
        emit = :(f($(String(name)), StructUtils.lower(style, $value)))
        if name in (:id, :bbox, :crs)
            emit = :(_omitoptional($value) || $emit)
        end
        push!(body.args, emit)
    end
    push!(body.args, :(nothing))
    body
end

StructUtils.lower(::JSON.JSONStyle, x::LazyFeature{D,T}) where {D,T} =
    _parse(codeunits(x), Feature{D,T})

missT(::Type{Nothing}) = Missing
missT(::Type{T}) where {T} = T
