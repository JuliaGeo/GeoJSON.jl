# Hack to get force the type field into the JSON
@inline function StructTypes.foreachfield(f, x::T) where {T<:GeoJSONT}
    N = fieldcount(T)
    nms = StructTypes.names(T)
    kwargs = StructTypes.keywordargs(T)
    emp = StructTypes.omitempties(T) === true ? fieldnames(T) : StructTypes.omitempties(T)
    f(0, :type, String, type(T))
    Base.@nexprs 8 i -> begin
        k_i = fieldname(T, i)
        if isdefined(x, i)
            v_i = Core.getfield(x, i)
            if !StructTypes.symbolin(emp, k_i) || !StructTypes.isempty(T, x, i)
                if haskey(kwargs, k_i)
                    f(i, StructTypes.serializationname(nms, k_i), fieldtype(T, i), v_i; kwargs[k_i]...)
                else
                    f(i, StructTypes.serializationname(nms, k_i), fieldtype(T, i), v_i)
                end
            end
        end
        N == i && @goto done
    end

    @label done
    return
end
