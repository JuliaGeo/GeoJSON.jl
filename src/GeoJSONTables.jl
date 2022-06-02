module GeoJSONTables

import JSON3, Tables, GeoFormatTypes, GeoInterface, Extents

const GI = GeoInterface

include("geometries.jl")
include("features.jl")
include("geointerface.jl")
include("json.jl")

end # module
