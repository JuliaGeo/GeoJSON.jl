module GeoJSON

import JSON3, Tables, GeoFormatTypes, Extents
import GeoInterface as GI

include("geometries.jl")
include("features.jl")
include("geointerface.jl")
include("json.jl")

end # module
