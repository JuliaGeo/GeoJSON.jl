using GeoJSON
import GeoInterface as GI
import GeoFormatTypes
import Aqua
using Extents
using JSON
using Tables
using Test
using Plots
using Makie
using DataFrames

include("geojson_samples.jl")
include("json.jl")
include("schema.jl")
include("small_union.jl")
include("collection_iteration.jl")

@testset "GeoJSON" begin
    @testset "Aqua.jl" begin
        Aqua.test_all(GeoJSON)
    end

    @testset "Polygon rings, bbox and 3D extents survive parsing" begin
        geom = GeoJSON.read(Samples.multi)
        @test GI.coordinates(geom) == [
            [[(180.0f0, 40.0f0), (180.0f0, 50.0f0), (170.0f0, 50.0f0), (170.0f0, 40.0f0), (180.0f0, 40.0f0)]],
            [[
                (-170.0f0, 40.0f0),
                (-170.0f0, 50.0f0),
                (-180.0f0, 50.0f0),
                (-180.0f0, 40.0f0),
                (-170.0f0, 40.0f0),
            ]],
        ]

        geom = GeoJSON.read(Samples.bbox)
        @test GI.crs(geom) == GeoFormatTypes.EPSG(4326)
        @test GeoJSON.coordinates(geom) == [(-35.1f0, -6.6f0), (8.1f0, 3.8f0)]
        @test GeoJSON.bbox(geom) == [-35.1f0, -6.6f0, 8.1f0, 3.8f0]
        @test GI.extent(geom) == Extent(X=(-35.1f0, 8.1f0), Y=(-6.6f0, 3.8f0))

        geom = GeoJSON.read(Samples.bbox_z, ndim=3)
        @test GeoJSON.coordinates(geom) == [(-35.1f0, -6.6f0, 5.5f0), (8.1f0, 3.8f0, 6.5f0)]
        @test GeoJSON.bbox(geom) == [-35.1f0, -6.6f0, 5.5f0, 8.1f0, 3.8f0, 6.5f0]
        @test GI.extent(geom) == Extent(X=(-35.1f0, 8.1f0), Y=(-6.6f0, 3.8f0), Z=(5.5f0, 6.5f0))
    end

    @testset "Constructors preserve properties and geometry name collisions" begin
        # Geometry
        p = GeoJSON.Point(coordinates=(1.1f0, 2.2f0))
        @test p.coordinates === GeoJSON.coordinates(p) == (1.1f0, 2.2f0)

        # Feature
        # properties named "geometry" are *not* shadowed by the geometry
        f = GeoJSON.Feature(geometry=p, properties=pairs((a=1, geometry="g", b=2)))
        @test GeoJSON.coordinates(f) == (1.1f0, 2.2f0)
        @test propertynames(f) === (:geometry, :a, :b)
        @test GeoJSON.geometry(f) === p

        @test GeoJSON.properties(f) == Dict(:a=>1, :geometry=>"g", :b=>2)
        @test ismissing(f.not_a_col)
        @test iterate(f) isa Tuple
        @test_throws MethodError f[1]
        # but can still be retrieved from the properties directly
        @test GeoJSON.properties(f)[:geometry] === "g"

        # FeatureCollection
        features = [f]
        fc = GeoJSON.FeatureCollection(features=features)
        @test GeoJSON.features(fc) == features
        @test propertynames(fc) == Tables.columnnames(fc) == [:a, :b, :geometry]
        @test GeoJSON.geometry.(fc) == [p]
        @test collect(p) == [1.1f0, 2.2f0]
    end

    @testset "Extent fallback respects explicit bounds" begin
        @test GI.extent(GeoJSON.read(Samples.d)) ==
              Extent(X=(-180.0f0, 180.0f0), Y=(-90.0f0, 90.0f0))
        @test GI.extent(GeoJSON.read(Samples.e), fallback=false) === nothing
        @test GI.extent(GeoJSON.read(Samples.g, ndim=2)) ==
              Extent(X=(100.0f0, 105.0f0), Y=(0.0f0, 1.0f0))
    end

    @testset "Spec samples roundtrip geometry, properties and extents" begin
        # Spec examples retain values and extents through a round trip.
        foreach(Samples.features) do json
            f = GeoJSON.read(json)
            f1 = GeoJSON.read(GeoJSON.write(f))
            @test GeoJSON.geometry(f) == GeoJSON.geometry(f1)
            @test GeoJSON.properties(f) == GeoJSON.properties(f1)
            @test GI.extent(f) == GI.extent(f1)
        end

        foreach(Samples.featurecollections) do json
            fc = GeoJSON.read(json)
            f1c = GeoJSON.read(GeoJSON.write(fc))
            foreach(fc, f1c) do f, f1
                @test GeoJSON.geometry(f) == GeoJSON.geometry(f1)
                @test GeoJSON.properties(f) == GeoJSON.properties(f1)
                @test GI.extent(f) == GI.extent(f1)
            end
        end

        # GeoInterface support
        foreach(Samples.featuresgeom) do json
            geom = GeoJSON.geometry(GeoJSON.read(json))
            geom1 = GeoJSON.read(GeoJSON.write(GI.convert(GI, geom)))
            @test geom == geom1
            @test GI.extent(geom) == GI.extent(geom1)
        end
    end

    @testset "Collections expose Tables rows and inferred indexing" begin
        t = GeoJSON.read(Samples.g)
        @test Tables.istable(t)
        @test Tables.rows(t) === t
        @test Tables.columns(t) isa Tables.CopiedColumns
        @test sort(propertynames(t)) == [:addr1, :addr2, :cartodb_id, :geometry, :park,]
        @test Tables.rowtable(t) isa Vector{<:NamedTuple}
        @test Tables.columntable(t) isa NamedTuple
        @inferred first(t)
        f1, _ = iterate(t)
        @test propertynames(f1) === (:geometry, :park, :cartodb_id, :addr1, :addr2)
        @test GI.getfeature(t, 1) === f1
        @inferred t[1]
        @test f1 == t[1]
        geom = GeoJSON.geometry(f1)
        @test geom isa GeoJSON.MultiPolygon{2}
        @test GI.coordinates(geom) isa Vector{Vector{Vector{Tuple{Float32,Float32}}}}
        @test GeoJSON.coordinates(geom)[1][1] == geom[1][1]
        @test first(geom[1][1]) == last(geom[1][1]) == (-117.913883f0, 33.96657f0)

        @testset "Paths, bytes and IO preserve feature values" begin
            mktemp() do path, io
                GeoJSON.write(io, t)
                close(io)
                bytes = read(path)
                for source in (path, bytes, IOBuffer(bytes))
                    @test GeoJSON.read(source)[1] == t[1]
                end
                GeoJSON.write(path, t)
                @test read(path) == bytes
            end
        end

        @testset "GeoInterface" begin
            @test GI.trait(t) == GI.FeatureCollectionTrait()
            geom = GeoJSON.geometry(f1)
            @test GI.trait(f1) === GI.FeatureTrait()
            @test GI.geomtrait(geom) === GI.MultiPolygonTrait()
            properties = GeoJSON.properties(f1)
            @test properties isa Dict{Symbol,Any}
            @test properties[:addr2] === "Rowland Heights"
            @test !GI.isclosed(GeoJSON.read(Samples.bbox))
            @test GI.isclosed(GeoJSON.read(Samples.bermuda_triangle))
        end
    end

    @testset "Tables distinguish nulls and absent columns" begin
        t = GeoJSON.read(Samples.tablenull)
        @test occursin("(:geometry, :a, :b)", sprint(show, MIME"text/plain"(), t[1]))
        @test ismissing(t[1].geometry)
        @test t.geometry isa Vector{Union{T,Missing}} where {T<:GeoJSON.Point}
        @test ismissing(t.geometry[3])
        @test t.a isa Vector{Union{Int64,Missing}}
        @test isequal(t.a, [1, missing, 3])
        @test t.b isa Vector{Missing}
        @test Tables.columntable(t) isa NamedTuple

        t = GeoJSON.read(Samples.table_not_present)
        @test occursin("(:geometry, :a, :b, :c)", sprint(show, MIME"text/plain"(), t[1]))
        @test sort(propertynames(t)) == sort([:a, :b, :c, :geometry, :d])
        @test propertynames(t[1]) == (:geometry, :a, :b, :c)
        @test propertynames(t[2]) == (:geometry, :a, :b, :d)
        # "c" and "d" are only present in the properties of a single row
        @test all(t.c .=== ["only-here", missing, missing])
        @test all(t.d .=== [missing, "appears-later", missing])
        # The partial constructor accepts missing geometries and pairs of properties.
        f = GeoJSON.Feature{2,Float32}(properties=pairs((a=1, b=missing)))
        @test isequal(GeoJSON.properties(f), Dict(:a=>1, :b=>missing))
    end

    @testset "Computed extents agree with point bounds" begin
        # First, test that `Extents.extent` returns nothing for a geometry with no bbox
        feature = GeoJSON.read(Samples.b)
        @test isnothing(GI.Extents.extent(feature))
        # Next, test that `GI.extent` returns the correct extent for a geometry with a bbox
        @test GI.extent(feature) == mapreduce(GI.extent, GI.Extents.union, GI.getpoint(feature.geometry))
    end

    @testset "Every geometry trait conforms to GeoInterface" begin
        @test all(GI.testgeometry, GeoJSON.read.(Samples.geometries))
        @test all(GI.testfeature, GeoJSON.read.(Samples.features))
        @test all(GI.testfeaturecollection, GeoJSON.read.(Samples.featurecollections))
    end

    @testset "GeoFormatTypes accepts string and dictionary inputs" begin
        gft_str = GeoFormatTypes.GeoJSON(Samples.b)
        f = GeoJSON.read(gft_str)
        @test f isa GeoJSON.Feature

        dict = Dict{String,Any}("type" => "Point", "coordinates" => [-105.0, 39.5])
        gft_dict = GeoFormatTypes.GeoJSON(dict)
        p = GeoJSON.read(gft_dict)
        @test p isa GeoJSON.Point
    end

    @testset "Equality distinguishes coordinates and geometry kinds" begin
        p = GeoJSON.read(Samples.point_int)
        @test p == p
        @test GeoJSON.Point(coordinates=(1, 2)) != GeoJSON.Point(coordinates=(2, 3))
        @test GeoJSON.LineString(coordinates=[(1, 2)]) != GeoJSON.MultiPoint(coordinates=[(1, 2)])
    end

    @testset "Point writes order XYZ and ignore M" begin
        @test GeoJSON.write((X=1.0, Y=2.0)) ==
              GeoJSON.write((Y=2.0, X=1.0)) ==
              "{\"type\":\"Point\",\"coordinates\":[1.0,2.0]}"
        @test GeoJSON.write((Z=3, X=1.0, Y=2.0)) ==
              GeoJSON.write((Y=2.0, X=1.0, Z=3)) ==
              "{\"type\":\"Point\",\"coordinates\":[1.0,2.0,3]}"
        # M is not in the spec
        @test GeoJSON.write((Z=3, X=1.0, Y=2.0, M=4)) ==
              GeoJSON.write((X=1.0, Z=3, M=4, Y=2.0)) ==
              "{\"type\":\"Point\",\"coordinates\":[1.0,2.0,3]}"
    end

    @testset "Table writes select the requested geometry column" begin
        # try a namedtuple table
        t1 = map(tuple.(1:10, 1:10), rand(10), ["abc" for i in 1:10]) do geometry, prop1, prop2
            (; geometry, prop1, prop2)
        end
        t1_geojson_str = GeoJSON.write(t1)
        t1_geojson = GeoJSON.read(t1_geojson_str)
        @test map(x -> (GI.x(x), GI.y(x)), t1_geojson.geometry) == getproperty.(t1, :geometry)
        @test t1_geojson.prop1 == getproperty.(t1, :prop1)

        t2 = map(tuple.(1:10, 1:10), rand(10), ["abc" for i in 1:10]) do somethingelse, prop1, prop2
            (; somethingelse, prop1, prop2)
        end
        t2_geojson_str = GeoJSON.write(t2; geometrycolumn = :somethingelse)
        t2_geojson = GeoJSON.read(t2_geojson_str)
        @test map(x -> (GI.x(x), GI.y(x)), t2_geojson.geometry) == getproperty.(t2, :somethingelse)
        @test t2_geojson.prop1 == getproperty.(t2, :prop1)

        @testset "Metadata" begin
            @test GI.DataAPI.metadatasupport(typeof(t2_geojson)) == (; read = true, write = false)
            @test GI.DataAPI.metadatakeys(t2_geojson) == ("GEOINTERFACE:geometrycolumns", "GEOINTERFACE:crs")
            @test GI.DataAPI.metadata(t2_geojson, "GEOINTERFACE:geometrycolumns") == (:geometry,)
            @test GI.DataAPI.metadata(t2_geojson, "GEOINTERFACE:crs") == GI.crs(t2_geojson)
            @test_throws KeyError GI.DataAPI.metadata(t2_geojson, "not_a_key")

            df = DataFrames.DataFrame(t2_geojson)
            m = DataFrames.metadata(df)
            @test isempty(setdiff(keys(m), (GI.GEOINTERFACE_CRS_KEY, GI.GEOINTERFACE_GEOMETRYCOLUMNS_KEY)))
            @test m[GI.GEOINTERFACE_CRS_KEY] == GI.crs(t2_geojson)
            @test m[GI.GEOINTERFACE_GEOMETRYCOLUMNS_KEY] == (:geometry,)
        end
    end
end  # testset "GeoJSON"

@testset "Plot extensions accept a polygon geometry" begin
    geom = GeoJSON.read(Samples.multi)
    @test Plots.plot(geom) isa Plots.Plot
    @test Makie.plot(geom) isa Makie.FigureAxisPlot
end
