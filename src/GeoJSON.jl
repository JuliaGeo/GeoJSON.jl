module GeoJSON

@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    Base.read(path, String)
end GeoJSON

import Extents, GeoFormatTypes, GeoInterfaceRecipes, JSON3, Tables, StructTypes
import GeoInterface as GI
using ComputedFieldTypes: @computed

include("geojson_types.jl")
include("geointerface.jl")
include("io.jl")
include("table.jl")

end # module
