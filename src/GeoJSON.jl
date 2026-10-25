module GeoJSON

@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    Base.read(path, String)
end GeoJSON

import Extents, GeoFormatTypes, JSON, Parsers, Tables, StructUtils
import GeoInterface as GI

include("geojson_types.jl")
include("geointerface.jl")
include("coordinates.jl")
include("json.jl")
include("io.jl")
include("table.jl")
include("utils.jl")
include("precompile.jl")

end # module
