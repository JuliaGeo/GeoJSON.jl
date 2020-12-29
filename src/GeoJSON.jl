module GeoJSON

using StaticArrays
import GeoInterface
import JSON3

# from RoamesGeometry.jl
include("Line.jl")
include("LineString.jl")
include("Polygon.jl")

include("feature.jl")
include("read.jl")
include("write.jl")
include("geointerface.jl")
include("deprecations.jl")

end  # module
