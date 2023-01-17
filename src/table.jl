# Tables.jl interface methods
Tables.istable(::Type{<:FeatureCollection}) = true
Tables.rowaccess(::Type{<:FeatureCollection}) = true
Tables.rows(fc::FeatureCollection) = fc
Tables.schema(fc::FeatureCollection) =
    Tables.Schema(Tuple(keys(first(fc).properties)), (typeof(v) for v in values(first(fc).properties)))
