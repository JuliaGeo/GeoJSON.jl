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
        @test Base.propertynames(t) == (:source,)  # override this?
        @test Tables.rowtable(t) isa Vector{<:NamedTuple}
        @test Tables.columntable(t) isa NamedTuple

        f1, _ = iterate(t)
        @test f1 isa GeoJSONTables.Feature{<:JSON3.Object}
        @test Base.propertynames(t) == (:source,)
        @test Base.propertynames(f1) == [:geometry, :cartodb_id, :addr1, :addr2, :park]
        @test f1 == t[1]
        @test f1.geometry isa JSON3.Object
        @test f1.geometry.type === "MultiPolygon"
        @test f1.geometry.coordinates isa JSON3.Array
        @test length(f1.geometry.coordinates[1][1]) == 4
        @test f1.geometry.coordinates[1][1][1] == [-117.913883,33.96657]
        @test f1.geometry.coordinates[1][1][2] == [-117.907767,33.967747]
        @test f1.geometry.coordinates[1][1][3] == [-117.912919,33.96445]
        @test f1.geometry.coordinates[1][1][4] == [-117.913883,33.96657]

        @testset "GeoInterface" begin
            @test GeoInterface.geotype(t) === :FeatureCollection
            @test GeoInterface.geotype(f1) === :Feature
            gi_mp = GeoInterface.geometry(f1)
            @test gi_mp isa GeoInterface.MultiPolygon
            @test GeoInterface.geotype(gi_mp) === :MultiPolygon
            properties = GeoInterface.properties(f1)
            @test properties isa Dict{String, Any}
            @test properties["addr2"] === "Rowland Heights"
            @test_throws MethodError GeoInterface.bbox(t)
            @test GeoInterface.bbox(f1) === nothing
            coordinates = GeoInterface.coordinates(f1)
            @test coordinates == Vector{Vector{Vector{Float64}}}[[[
                [-117.913883, 33.96657],
                [-117.907767, 33.967747],
                [-117.912919, 33.96445],
                [-117.913883, 33.96657],
            ]]]
        end
    end
end
