using Test
using GeoJSON
using GeoInterface
using Extents
using Tables
using DataAPI
import GeoFormatTypes
import GeoInterface as GI

@testset "GeoInterface" begin
    ring2 = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0), (0.0, 0.0)]
    hole2 = [(0.2, 0.2), (0.4, 0.2), (0.4, 0.4), (0.2, 0.4), (0.2, 0.2)]
    ring3 = [(0.0, 0.0, 5.0), (1.0, 0.0, 5.0), (1.0, 1.0, 5.0), (0.0, 1.0, 5.0), (0.0, 0.0, 5.0)]
    hole3 = [(0.2, 0.2, 5.0), (0.4, 0.2, 5.0), (0.4, 0.4, 5.0), (0.2, 0.4, 5.0), (0.2, 0.2, 5.0)]

    point2 = GeoJSON.Point{2,Float64}(nothing, (1.0, 2.0))
    point3 = GeoJSON.Point{3,Float64}(nothing, (1.0, 2.0, 3.0))
    line2 = GeoJSON.LineString{2,Float64}(nothing, [(0.0, 0.0), (1.0, 1.0), (2.0, 0.0)])
    line3 = GeoJSON.LineString{3,Float64}(nothing, [(0.0, 0.0, 1.0), (1.0, 1.0, 2.0), (2.0, 0.0, 3.0)])
    multipoint2 = GeoJSON.MultiPoint{2,Float64}(nothing, [(0.0, 0.0), (1.0, 1.0)])
    multipoint3 = GeoJSON.MultiPoint{3,Float64}(nothing, [(0.0, 0.0, 1.0), (1.0, 1.0, 2.0)])
    polygon2 = GeoJSON.Polygon{2,Float64}(nothing, [ring2, hole2])
    polygon3 = GeoJSON.Polygon{3,Float64}(nothing, [ring3, hole3])
    multiline2 = GeoJSON.MultiLineString{2,Float64}(nothing, [ring2, hole2])
    multiline3 = GeoJSON.MultiLineString{3,Float64}(nothing, [ring3, hole3])
    multipolygon2 = GeoJSON.MultiPolygon{2,Float64}(nothing, [[ring2, hole2], [ring2]])
    multipolygon3 = GeoJSON.MultiPolygon{3,Float64}(nothing, [[ring3, hole3], [ring3]])
    collection2 = GeoJSON.GeometryCollection{2,Float64}(
        nothing, GeoJSON.AnyGeometry{2,Float64}[point2, line2, polygon2])
    collection3 = GeoJSON.GeometryCollection{3,Float64}(
        nothing, GeoJSON.AnyGeometry{3,Float64}[point3, line3, polygon3])
    nested2 = GeoJSON.GeometryCollection{2,Float64}(
        nothing, GeoJSON.AnyGeometry{2,Float64}[point2, collection2])

    geometries2 = (point2, line2, multipoint2, polygon2, multiline2, multipolygon2, collection2, nested2)
    geometries3 = (point3, line3, multipoint3, polygon3, multiline3, multipolygon3, collection3)

    properties2 = GeoJSON.Properties("name" => "somewhere", "n" => 1)
    feature2 = GeoJSON.Feature{2,Float64}(; geometry=polygon2, properties=properties2)
    feature3 = GeoJSON.Feature{3,Float64}(; geometry=polygon3, properties=properties2)
    nogeom = GeoJSON.Feature{2,Float64}(; geometry=nothing, properties=properties2)
    fc2 = GeoJSON.FeatureCollection{2,Float64}(; features=[feature2, nogeom])
    fc3 = GeoJSON.FeatureCollection{3,Float64}(; features=[feature3])

    @testset "testgeometry" begin
        for g in geometries2
            @test GI.isgeometry(g)
            @test GI.testgeometry(g)
        end
        for g in geometries3
            @test GI.isgeometry(g)
            @test GI.testgeometry(g)
        end
    end

    @testset "testfeature and testfeaturecollection" begin
        @test GI.isfeature(feature2)
        @test GI.testfeature(feature2)
        @test GI.testfeature(feature3)
        @test GI.testfeature(nogeom)
        @test GI.isfeaturecollection(fc2)
        @test GI.testfeaturecollection(fc2)
        @test GI.testfeaturecollection(fc3)
    end

    @testset "geomtrait" begin
        @test GI.geomtrait(point2) === GI.PointTrait()
        @test GI.geomtrait(line2) === GI.LineStringTrait()
        @test GI.geomtrait(multipoint2) === GI.MultiPointTrait()
        @test GI.geomtrait(polygon2) === GI.PolygonTrait()
        @test GI.geomtrait(multiline2) === GI.MultiLineStringTrait()
        @test GI.geomtrait(multipolygon2) === GI.MultiPolygonTrait()
        @test GI.geomtrait(collection2) === GI.GeometryCollectionTrait()
        @test GI.trait(feature2) === GI.FeatureTrait()
        @test GI.trait(fc2) === GI.FeatureCollectionTrait()
    end

    @testset "coordinates" begin
        @test GI.coordinates(point2) === (1.0, 2.0)
        @test GI.coordinates(point3) === (1.0, 2.0, 3.0)
        for g in (line2, multipoint2, polygon2, multiline2, multipolygon2, line3, polygon3)
            @test GI.coordinates(g) === GeoJSON.coordinates(g)
        end
        @test GI.coordinates(polygon2) isa Vector{Vector{Tuple{Float64,Float64}}}
        @test GI.coordinates(multipolygon3) isa Vector{Vector{Vector{Tuple{Float64,Float64,Float64}}}}
        @test GI.coordinates(multipolygon2)[1][1] == ring2
        @test GeoJSON.coordinates(collection2) == [(1.0, 2.0), GeoJSON.coordinates(line2), [ring2, hole2]]
        @test GeoJSON.coordinates(feature2) == GeoJSON.coordinates(polygon2)
    end

    @testset "ncoord and is3d" begin
        for g in geometries2
            @test GI.ncoord(g) == 2
            @test !GI.is3d(g)
        end
        for g in geometries3
            @test GI.ncoord(g) == 3
            @test GI.is3d(g)
        end
        @test GI.is3d(GI.geometry(feature3))
        @test !GI.is3d(GI.geometry(feature2))
        @test GI.ncoord(GeoJSON.Polygon{2,Float64}(nothing, Vector{NTuple{2,Float64}}[])) == 2
        @test GI.ncoord(GeoJSON.Polygon{3,Float64}(nothing, nothing)) == 3
    end

    @testset "ngeom and getgeom" begin
        @test GI.ngeom(line2) == 3
        @test GI.getgeom(line2, 2) === (1.0, 1.0)
        @test GI.ngeom(multipoint2) == 2
        @test GI.getgeom(multipoint2, 1) === (0.0, 0.0)
        @test GI.ngeom(polygon2) == 2
        @test GI.getgeom(polygon2, 1) == GeoJSON.LineString{2,Float64}(nothing, ring2)
        @test GI.getgeom(polygon2, 2) == GeoJSON.LineString{2,Float64}(nothing, hole2)
        @test GI.ngeom(multiline2) == 2
        @test GI.getgeom(multiline2, 2) == GeoJSON.LineString{2,Float64}(nothing, hole2)
        @test GI.ngeom(multipolygon2) == 2
        @test GI.getgeom(multipolygon2, 1) == GeoJSON.Polygon{2,Float64}(nothing, [ring2, hole2])
        @test GI.ngeom(collection2) == 3
        @test GI.getgeom(collection2, 1) === point2
        @test GI.getgeom(collection2, 2) === line2
        @test GI.getgeom(collection2, 3) === polygon2
        @test GI.getgeom(nested2, 2) === collection2
        @test GI.ngeom(GeoJSON.Polygon{2,Float64}(nothing, nothing)) == 0
        @test length(collect(GI.getgeom(polygon2))) == 2
    end

    @testset "getpoint" begin
        @test GI.npoint(line2) == 3
        @test GI.getpoint(line2, 1) === (0.0, 0.0)
        @test GI.getpoint(line2, 3) === (2.0, 0.0)
        @test collect(GI.getpoint(line2)) == GeoJSON.coordinates(line2)
        @test collect(GI.getpoint(multipoint3)) == GeoJSON.coordinates(multipoint3)
        @test GI.npoint(polygon2) == length(ring2) + length(hole2)
        @test first(GI.getpoint(polygon2)) === (0.0, 0.0)
        @test collect(GI.getpoint(polygon2)) == vcat(ring2, hole2)
        @test GI.x(GI.getpoint(line3, 2)) === 1.0
        @test GI.y(GI.getpoint(line3, 2)) === 1.0
        @test GI.z(GI.getpoint(line3, 2)) === 2.0
    end

    @testset "getcoord" begin
        @test GI.getcoord(point3, 1) === 1.0
        @test GI.getcoord(point3, 3) === 3.0
        @test GI.x(point2) === 1.0
        @test GI.y(point2) === 2.0
        @test GI.z(point3) === 3.0
    end

    @testset "getexterior, nhole and gethole" begin
        @test GI.getexterior(polygon2) == GeoJSON.LineString{2,Float64}(nothing, ring2)
        @test GI.getexterior(polygon3) == GeoJSON.LineString{3,Float64}(nothing, ring3)
        @test GI.nhole(polygon2) == 1
        @test GI.gethole(polygon2, 1) == GeoJSON.LineString{2,Float64}(nothing, hole2)
        @test collect(GI.gethole(polygon2)) == [GeoJSON.LineString{2,Float64}(nothing, hole2)]
        @test GI.nhole(GeoJSON.Polygon{2,Float64}(nothing, [ring2])) == 0
        @test GI.nhole(GeoJSON.Polygon{2,Float64}(nothing, Vector{NTuple{2,Float64}}[])) == 0
        @test GI.nhole(GeoJSON.Polygon{2,Float64}(nothing, nothing)) == 0
    end

    @testset "empty geometries" begin
        empties = (
            GeoJSON.LineString{2,Float64}(nothing, NTuple{2,Float64}[]),
            GeoJSON.MultiPoint{2,Float64}(nothing, NTuple{2,Float64}[]),
            GeoJSON.Polygon{2,Float64}(nothing, Vector{NTuple{2,Float64}}[]),
            GeoJSON.MultiLineString{2,Float64}(nothing, Vector{NTuple{2,Float64}}[]),
            GeoJSON.MultiPolygon{2,Float64}(nothing, Vector{Vector{NTuple{2,Float64}}}[]),
            GeoJSON.GeometryCollection{2,Float64}(nothing, GeoJSON.AnyGeometry{2,Float64}[]),
        )
        for g in empties
            @test GI.testgeometry(g)
            @test GI.ngeom(g) == 0
            @test GI.ncoord(g) == 2
            @test Extents.extent(g) === nothing
        end
    end

    @testset "isclosed" begin
        @test GI.isclosed(GeoJSON.LineString{2,Float64}(nothing, ring2))
        @test GI.isclosed(GeoJSON.LineString{3,Float64}(nothing, ring3))
        @test !GI.isclosed(line2)
        @test !GI.isclosed(line3)
    end

    @testset "extent" begin
        boxed2 = GeoJSON.Point{2,Float64}([-1.0, -2.0, 3.0, 4.0], (1.0, 2.0))
        boxed3 = GeoJSON.Point{3,Float64}([-1.0, -2.0, -3.0, 4.0, 5.0, 6.0], (1.0, 2.0, 3.0))
        @test Extents.extent(boxed2) == Extent(X=(-1.0, 3.0), Y=(-2.0, 4.0))
        @test Extents.extent(boxed3) == Extent(X=(-1.0, 4.0), Y=(-2.0, 5.0), Z=(-3.0, 6.0))
        @test GI.extent(boxed2) == Extent(X=(-1.0, 3.0), Y=(-2.0, 4.0))

        for g in geometries2
            @test Extents.extent(g) === nothing
            @test GI.extent(g; fallback=false) === nothing
        end
        @test Extents.extent(feature2) === nothing
        @test Extents.extent(fc2) === nothing
        @test GI.extent(feature2; fallback=false) === nothing
        @test GI.extent(fc2; fallback=false) === nothing

        @test GI.extent(line2) == Extent(X=(0.0, 2.0), Y=(0.0, 1.0))
        @test GI.extent(polygon2) == mapreduce(GI.extent, Extents.union, GI.getpoint(polygon2))

        boxedfeature = GeoJSON.Feature{2,Float64}(;
            bbox=[-1.0, -2.0, 3.0, 4.0], geometry=polygon2, properties=properties2)
        boxedfc = GeoJSON.FeatureCollection{2,Float64}(;
            bbox=[-1.0, -2.0, 3.0, 4.0], features=[boxedfeature])
        @test Extents.extent(boxedfeature) == Extent(X=(-1.0, 3.0), Y=(-2.0, 4.0))
        @test Extents.extent(boxedfc) == Extent(X=(-1.0, 3.0), Y=(-2.0, 4.0))
        @test GI.extent(boxedfc; fallback=false) == Extent(X=(-1.0, 3.0), Y=(-2.0, 4.0))
    end

    @testset "crs" begin
        @test GI.crs(point2) == GeoFormatTypes.EPSG(4326)
        @test GI.crs(collection3) == GeoFormatTypes.EPSG(4326)
        @test GI.crs(feature2) == GeoFormatTypes.EPSG(4326)
        @test GI.crs(fc2) == GeoFormatTypes.EPSG(4326)
    end

    @testset "feature and feature collection traits" begin
        @test GI.geometry(feature2) === polygon2
        @test GI.geometry(nogeom) === nothing
        @test GI.properties(feature2) === properties2
        @test GI.properties(feature2)["name"] == "somewhere"
        @test GI.nfeature(fc2) == 2
        @test GI.getfeature(fc2, 1) == feature2
        @test collect(GI.getfeature(fc2)) == [feature2, nogeom]
        @test GI.geometry(GI.getfeature(fc2, 2)) === nothing
    end

    @testset "DataAPI metadata" begin
        @test DataAPI.metadatasupport(typeof(fc2)) == (; read=true, write=false)
        @test DataAPI.metadatakeys(fc2) == ("GEOINTERFACE:geometrycolumns", "GEOINTERFACE:crs")
        @test DataAPI.metadatakeys(fc2) ==
              (GI.GEOINTERFACE_GEOMETRYCOLUMNS_KEY, GI.GEOINTERFACE_CRS_KEY)
        @test DataAPI.metadata(fc2, "GEOINTERFACE:geometrycolumns") == (:geometry,)
        @test DataAPI.metadata(fc2, "GEOINTERFACE:crs") == GI.crs(fc2)
        @test DataAPI.metadata(fc2, "GEOINTERFACE:crs"; style=true) == (GI.crs(fc2), :note)
        @test DataAPI.metadata(fc2, "GEOINTERFACE:geometrycolumns"; style=true) == ((:geometry,), :note)
        @test DataAPI.metadata(fc2, "not_a_key", :fallback) === :fallback
        @test DataAPI.metadata(fc2, "not_a_key", :fallback; style=true) === (:fallback, :default)
        @test_throws KeyError DataAPI.metadata(fc2, "not_a_key")
    end

    @testset "type stability" begin
        @test only(Base.return_types(GI.getpoint, Tuple{typeof(line2),Int})) == Tuple{Float64,Float64}
        @test only(Base.return_types(GI.getpoint, Tuple{typeof(line3),Int})) == Tuple{Float64,Float64,Float64}
        @test @inferred(GI.getpoint(line2, 1)) === (0.0, 0.0)
        @test @inferred(GI.ncoord(line2)) == 2
        @test only(Base.return_types(GI.getexterior, Tuple{typeof(polygon2)})) ==
              GeoJSON.LineString{2,Float64}
        @test only(Base.return_types(GI.getgeom, Tuple{typeof(multipolygon2),Int})) ==
              GeoJSON.Polygon{2,Float64}
    end

    @testset "allocations" begin
        sumx(g) = sum(GI.x(p) for p in GI.getpoint(g))
        @test sumx(line2) == 3.0
        sumx(line2)
        @test @allocated(sumx(line2)) == 0
        sumx(polygon2)
        @test @allocated(sumx(polygon2)) == 0
    end
end
