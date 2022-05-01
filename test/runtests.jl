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

@testset "GeoJSONTables.jl" begin

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

    @testset "Read not crash" begin
        for featurecollection in featurecollections
            GeoJSONTables.read(featurecollection)
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
            getproperty(f1, pn) == getproperty(t[1], pn)
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

        @testset "GeoInterface" begin
            # Feature and FeatureCollection are not part of the GeoInterface
            @test GeoInterface.geomtype(t) == nothing
            geom = GeoJSONTables.geometry(f1)
            @test GeoInterface.geomtype(f1) === GeoInterface.MultiPolygonTrait()
            @test GeoInterface.geomtype(geom) === GeoInterface.MultiPolygonTrait()
            properties = GeoJSONTables.properties(f1)
            @test properties isa JSON3.Object
            @test properties["addr2"] === "Rowland Heights"
        end
    end
end
