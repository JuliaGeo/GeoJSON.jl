module GeoJSON

@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    Base.read(path, String)
end GeoJSON

import JSON, StructUtils, Extents, GeoFormatTypes, Tables
import GeoInterface as GI

include("types.jl")
include("properties.jl")
include("read/style.jl")
include("read/points.jl")
include("read/geometry.jl")
include("read/feature.jl")
include("read/discover.jl")
include("read/read.jl")
include("geointerface.jl")
include("table.jl")
include("lazy.jl")
include("write.jl")
include("precompile.jl")

end # module
