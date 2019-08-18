using GeoJSONTables
using JSON3
using Tables
using Test

# copied from the GeoJSON.jl test suite
include("geojson_samples.jl")
featurecollections = [g, multipolygon, realmultipolygon, polyline, point, pointnull,
    poly, polyhole, collection, osm_buildings]

@testset "GeoJSONTables.jl" begin
    # only FeatureCollection supported for now
    @test_throws ArgumentError GeoJSONTables.read(a)
    @test_throws ArgumentError GeoJSONTables.read(b)
    @test_throws ArgumentError GeoJSONTables.read(c)
    @test_throws ArgumentError GeoJSONTables.read(d)
    @test_throws ArgumentError GeoJSONTables.read(e)
    @test_throws ArgumentError GeoJSONTables.read(f)
    @test_throws ArgumentError GeoJSONTables.read(h)

    # check if reading doesn't error
    for featurecollection in featurecollections
        GeoJSONTables.read(featurecollection)
    end

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
end
