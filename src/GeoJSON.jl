module GeoJSON

@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    Base.read(path, String)
end GeoJSON

import JSON3, Tables, GeoFormatTypes, Extents, GeoInterfaceRecipes
import GeoInterface as GI

include("geometries.jl")
include("features.jl")
include("geointerface.jl")
include("json.jl")

end # module
