using GeoJSONTables
import GeoInterface
import GeoFormatTypes
using Extents
using JSON3
using Tables
using Test

# copied from the GeoJSON.jl test suite
include("geojson_samples.jl")
featurecollections = [g, multipolygon, realmultipolygon, polyline, point, pointnull,
    poly, polyhole, collection, osm_buildings]

@testset "Features" begin
    samples = (a, b, c, d, e, f, h)
    geometries = (
        nothing,
        [[-155.52, 19.61], [-156.22, 20.74], [-157.97, 21.46]],
        nothing,
        [[[3.75, 9.25], [-130.95, 1.52]], [[23.15, -34.25], [-1.35, -4.65], [3.45, 77.95]]],
        [53, -4],
        nothing,
        [[[3.75, 9.25], [-130.95, 1.52]], [[23.15, -34.25], [-1.35, -4.65], [3.45, 77.95]]],
    )
    properties = (
        [:Ã => "Ã"],
        [:type => "é"],
        [:type => "meow"],
        [:title => "Dict 1"],
        [:link => "http://example.org/features/1", :summary => "The first feature", :title => "Feature 1"],
        [:foo => "bar"],
        [:title => "Dict 1", :bbox => [-180.0, -90.0, 180.0, 90.0]],
    )
    foreach(samples, properties) do s, p
        @test collect(GeoJSONTables.properties(GeoJSONTables.read(s))) == p
    end
    foreach(samples, geometries) do s, g
        @test GeoJSONTables.geometry(GeoJSONTables.read(s)) == g
    end
end

@testset "Geometries" begin
    @test GeoJSONTables.read(multi) isa GeoJSONTables.MultiPolygon
    @test GeoJSONTables.read(multi) == [[[[180.0, 40.0], [180.0, 50.0], [170.0, 50.0], [170.0, 40.0], [180.0, 40.0]]],
                                       [[[-170.0, 40.0], [-170.0, 50.0], [-180.0, 50.0], [-180.0, 40.0], [-170.0, 40.0]]]]
end

@testset "extent" begin
    @test GeoInterface.extent(GeoJSONTables.read(d)) == Extent(X=(-180.0, 180.0), Y=(-90.0, 90.0))
    @test GeoInterface.extent(GeoJSONTables.read(e)) == nothing
    @test GeoInterface.extent(GeoJSONTables.read(g)) == Extent(X=(100.0, 105.0), Y=(0.0, 1.0))
end

@testset "crs" begin
    @test GeoInterface.crs(GeoJSONTables.read(a)) == GeoFormatTypes.EPSG(4326)
    @test GeoInterface.crs(GeoJSONTables.read(g)) == GeoFormatTypes.EPSG(4326)
    @test GeoInterface.crs(GeoJSONTables.read(multi)) == GeoFormatTypes.EPSG(4326)
end

@testset "read not crash" begin
    for featurecollection in featurecollections
        GeoJSONTables.read(featurecollection)
    end
end

@testset "write" begin
    # Round trip read/write and compare prettified output to prettified original
    foreach((a, b, c, d, e, f, h)) do json
        f = GeoJSONTables.read(json) 
        f1 = GeoJSONTables.read(GeoJSONTables.write(f))
        @test GeoJSONTables.geometry(f) == GeoJSONTables.geometry(f1)
        @test GeoJSONTables.properties(f) == GeoJSONTables.properties(f1)
        @test GeoInterface.extent(f) == GeoInterface.extent(f1)
    end

    foreach(featurecollections) do json
        json = featurecollections[1]
        fc = GeoJSONTables.read(json) 
        f1c = GeoJSONTables.read(GeoJSONTables.write(fc))
        foreach(fc, f1c) do f, f1
            @test GeoJSONTables.geometry(f) == GeoJSONTables.geometry(f1)
            @test GeoJSONTables.properties(f) == GeoJSONTables.properties(f1)
            @test GeoInterface.extent(f) == GeoInterface.extent(f1)
        end
    end
end

@testset "FeatureCollection of one MultiPolygon" begin
    t = GeoJSONTables.read(g)
    @test Tables.istable(t)
    @test Tables.rows(t) === t
    @test Tables.columns(t) isa Tables.CopiedColumns
    @test t isa GeoJSONTables.FeatureCollection{<:JSON3.Object,<:JSON3.Array{JSON3.Object}}
    @test Base.propertynames(t) == (:object, :array)  # override this?
    @test Tables.rowtable(t) isa Vector{<:NamedTuple}
    @test Tables.columntable(t) isa NamedTuple

    f1, _ = iterate(t)
    @test f1 isa GeoJSONTables.Feature{<:JSON3.Object}
    @test all(Base.propertynames(f1) .== [:cartodb_id, :addr1, :addr2, :park])
    @test all(propertynames(f1)) do pn
        getproperty(f1, pn) == getproperty(GeoInterface.getfeature(t, 1), pn)
    end
    @test_broken f1 == t[1]
    geom = GeoJSONTables.geometry(f1)
    @test geom isa GeoJSONTables.MultiPolygon
    @test geom isa GeoJSONTables.Geometry
    @test geom isa AbstractVector
    @test geom.json isa JSON3.Array
    @test length(geom.json[1][1]) == 4
    @test length(geom[1][1]) == 4
    @test geom[1][1][1] == [-117.913883,33.96657]
    @test geom[1][1][2] == [-117.907767,33.967747]
    @test geom[1][1][3] == [-117.912919,33.96445]
    @test geom[1][1][4] == [-117.913883,33.96657]

    @testset "write to disk" begin
        fc = t
        GeoJSONTables.write("test.json", fc)
        fc1 = GeoJSONTables.read(read("test.json", String))
        @test GeoInterface.extent(fc) == GeoInterface.extent(fc1) == Extent(X=(100, 105), Y=(0, 1))
        f = GeoInterface.getfeature(fc, 1) 
        f1 = GeoInterface.getfeature(fc1, 1) 
        @test GeoInterface.geometry(f) == GeoInterface.geometry(f1)
        @test GeoInterface.properties(f) == GeoInterface.properties(f1)
        rm("test.json")
    end

    @testset "GeoInterface" begin
        @test GeoInterface.geomtrait(t) == GeoInterface.FeatureCollectionTrait()
        geom = GeoJSONTables.geometry(f1)
        @test GeoInterface.geomtrait(f1) === GeoInterface.FeatureTrait()
        @test GeoInterface.geomtrait(geom) === GeoInterface.MultiPolygonTrait()
        properties = GeoJSONTables.properties(f1)
        @test properties isa JSON3.Object
        @test properties["addr2"] === "Rowland Heights"
    end
end

@testset "FeatureCollection of one GeometryCollection" begin
    fc = GeoJSONTables.read(collection)
    gc = GeoJSONTables.geometry(GeoInterface.getfeature(fc, 1))
    @test GeoInterface.geomtrait(gc) isa GeoInterface.GeometryCollectionTrait

    @testset "Mixed geometry types are returned" begin
        @test GeoInterface.getgeom(gc, 1) isa GeoJSONTables.Polygon
        @test GeoInterface.getgeom(gc, 2) isa GeoJSONTables.Polygon
        @test GeoInterface.getgeom(gc, 3) isa GeoJSONTables.Point
    end
end

@testset "GeoInterface tests" begin
    geoms = [multi]
    @test all(s -> GeoInterface.testgeometry(s), GeoJSONTables.read.(geoms))
    # @test GeoInterface.coordinates(GeoJSONTables.read.(geoms)[1])
    features = [a, b, c, d, e, f, h]
    @test all(s -> GeoInterface.testfeature(s), GeoJSONTables.read.(features))
    featurecollections = [g, multipolygon, realmultipolygon, polyline, point, pointnull, poly, polyhole, collection, osm_buildings]
    @test all(s -> GeoInterface.testfeaturecollection(s), GeoJSONTables.read.(featurecollections))
end
