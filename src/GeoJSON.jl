module GeoJSON

@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    Base.read(path, String)
end GeoJSON

import Extents, GeoFormatTypes, GeoInterfaceRecipes, JSON3, Tables, StructTypes
import GeoInterface as GI

include("geojson_types.jl")
include("geojson_samples.jl")
include("geointerface.jl")
include("io.jl")
include("table.jl")
include("utils.jl")

using SnoopPrecompile

# TODO This doesn't seem to do anything at all
@precompile_all_calls begin
    # if ccall(:jl_generating_output, Cint, ()) == 1   # if we're precompiling the package
    for geom in Samples.geometries_2d
        g = GeoJSON.read(geom)
        g = GeoJSON.read(geom, numbertype=Float64)
        JSON3.read(geom, GeoJSONWrapper{2,Float32})
        GI.coordinates(g)
        GeoJSON.write(g)
    end
    for geom in Samples.geometries_3d
        g = GeoJSON.read(geom)
        g = GeoJSON.read(geom, numbertype=Float64)
        JSON3.read(geom, GeoJSONWrapper{3,Float32})
        GI.coordinates(g)
        GeoJSON.write(g)
    end
    for f in Samples.features
        g = GeoJSON.read(f)
        g = GeoJSON.read(f, numbertype=Float64)
        JSON3.read(f, GeoJSONWrapper{2,Float32})
        GeoJSON.write(g)
    end
    for fc in Samples.featurecollections
        g = GeoJSON.read(fc)
        g = GeoJSON.read(fc, lazyfc=true)
        g = GeoJSON.read(fc, numbertype=Float64)
        JSON3.read(fc, GeoJSONWrapper{2,Float32})
        Tables.rowtable(g)
        GeoJSON.write(g)
    end
end

end # module
