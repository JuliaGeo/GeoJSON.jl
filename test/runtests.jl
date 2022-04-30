using GeoJSONTables
using JSON3
import GeoInterface
using Tables
using Test

# copied from the GeoJSON.jl test suite
include("geojson_samples.jl")
featurecollections = [g, multipolygon, realmultipolygon, polyline, point, pointnull,
    poly, polyhole, collection, osm_buildings]

@testset "GeoJSONTables.jl" begin
    # only FeatureCollection supported for now
    @testset "Not FeatureCollections" begin
        @test_throws ArgumentError GeoJSONTables.read(a)
        @test_throws ArgumentError GeoJSONTables.read(b)
        @test_throws ArgumentError GeoJSONTables.read(c)
        @test_throws ArgumentError GeoJSONTables.read(d)
        @test_throws ArgumentError GeoJSONTables.read(e)
        @test_throws ArgumentError GeoJSONTables.read(f)
        @test_throws ArgumentError GeoJSONTables.read(h)
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
        @test t isa GeoJSONTables.FeatureCollection{<:JSON3.Array{JSON3.Object}}
        @test Base.propertynames(t) == (:json,)  # override this?
        @test Tables.rowtable(t) isa Vector{<:NamedTuple}
        @test Tables.columntable(t) isa NamedTuple

        f1, _ = iterate(t)
        @test f1 isa GeoJSONTables.Feature{<:JSON3.Object}
        @test all(Base.propertynames(f1) .== [:cartodb_id, :addr1, :addr2, :park])
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
            @test_throws MethodError GeoJSONTables.bbox(t)
            @test GeoJSONTables.bbox(f1) === nothing
        end
    end
end
