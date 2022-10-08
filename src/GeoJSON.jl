module GeoJSON

@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    Base.read(path, String)
end GeoJSON

import Extents, GeoFormatTypes, GeoInterfaceRecipes, JSON3, JSONTables, Tables 
import GeoInterface as GI

include("geometries.jl")
include("features.jl")
include("geointerface.jl")
include("json.jl")

end # module
