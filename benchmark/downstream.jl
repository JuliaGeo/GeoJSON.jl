# Run in a task-local environment developing this checkout with NaturalEarth,
# GeoDataFrames, GeoIO, GeometryOps, their test dependencies and Test installed.
using Test, GeoJSON

module NaturalEarthSmoke
using Test, NaturalEarth
include(joinpath(pkgdir(NaturalEarth), "test", "runtests.jl"))
end

module GeoDataFramesSmoke
using Test, GeoJSON, GeoDataFrames, DataFrames
import GeoIO
import GeoInterface as GI
@testset "GeoDataFrames GeoJSON driver" begin
    mktempdir() do dir
        path = joinpath(dir, "polygons.geojson")
        # The GeoJSON fixture used by the upstream driver test is generated in
        # its test setup; use GeoIO's committed polygons for the same assertions.
        import_path = joinpath(pkgdir(GeoIO), "test", "data", "polygons.geojson")
        driver = GeoDataFrames.GeoJSONDriver()
        df = GeoDataFrames.read(driver, import_path)
        gdal = GeoDataFrames.read(GeoDataFrames.ArchGDALDriver(), import_path)
        @test names(df) == names(gdal)
        @test nrow(df) == nrow(gdal)
        @test GI.trait(df.geometry[1]) == GI.trait(gdal.geometry[1])
        @test all(isapprox.(collect.(GI.coordinates(df.geometry[1])[1]), GI.coordinates(gdal.geometry[1])[1]))
        @test !isnothing(GI.crs(df))
        @test GeoDataFrames.write(driver, path, df) == path
        again = GeoDataFrames.read(driver, path)
        @test names(again) == names(df)
        @test nrow(again) == nrow(df)
        @test GI.coordinates.(again.geometry) == GI.coordinates.(df.geometry)
        for lazyfc in (false, true)
            @test nrow(GeoDataFrames.read(driver, path; lazyfc, numbertype=Float64)) == nrow(df)
        end
    end
end
end

module GeoIOSmoke
using Test, GeoIO, Meshes, GeoTables, CoordRefSystems, Tables
const datadir = joinpath(pkgdir(GeoIO), "test", "data")
const savedir = mktempdir()
# The upstream GIS-issues file uses this helper for Shapefile roundtrips.
isequalshp(d1::Domain, d2::Domain) = all(isequalshp(g1, g2) for (g1,g2) in zip(d1,d2))
isequalshp(g1, g2) = g1 == g2
isequalshp(m1::Multi, m2::Multi) = m1 == m2
isequalshp(g, m::Multi) = isequalshp(m, g)
isequalshp(m::Multi, g) = length(parent(m)) == 1 && first(parent(m)) == g
include(joinpath(pkgdir(GeoIO), "test", "io", "geojson.jl"))
include(joinpath(pkgdir(GeoIO), "test", "gisissues.jl"))
end

module GeometryOpsSmoke
using Test, GeoJSON, NaturalEarth, GeometryOps
import GeoInterface as GI
const GO = GeometryOps
@testset "GeometryOps GeoJSON simplify cases" begin
    datadir = joinpath(pkgdir(GO), "test", "data")
    for file in ("simplify.geojson", "simplify2.geojson")
        fc = GeoJSON.read(joinpath(datadir, file))
        @test fc isa GeoJSON.FeatureCollection
        if file == "simplify.geojson"
            for T in (GO.RadialDistance, GO.VisvalingamWhyatt)
                @test length(collect(GO.flatten(GI.PointTrait, GO.simplify(T(number=10), fc)))) == 10
                @test length(collect(GO.flatten(GI.PointTrait, GO.simplify(T(ratio=0.5), fc)))) == 39
                @test_nowarn GO.simplify(T(tol=0.001), fc; threaded=true, calc_extent=true)
            end
        end
    end
end
# The full upstream file includes its NaturalEarth Russia/Fiji/Antarctica cases.
include(joinpath(pkgdir(GO), "test", "transformations", "antimeridian_split.jl"))
@test ne_ok # a missing download must fail this smoke, not silently skip
end
