using GeoJSON
import GeoInterface as GI
import GeoFormatTypes
import Aqua
import JSON3
using Extents
using JSON3
using Tables
using Test
using Plots
using DataFrames

include("geojson_samples.jl")

@testset "GeoJSON" begin

    @testset "Features" begin
        geometries = [
            nothing,
            [(-155.52f0, 19.61f0), (-156.22f0, 20.74f0), (-157.97f0, 21.46f0)],
            nothing,
            [
                [(3.75f0, 9.25f0), (-130.95f0, 1.52f0)],
                [(23.15f0, -34.25f0), (-1.35f0, -4.65f0), (3.45f0, 77.95f0)],
            ],
            (53.0f0, -4.0f0),
            nothing,
            [
                [(3.75f0, 9.25f0), (-130.95f0, 1.52f0)],
                [(23.15f0, -34.25f0), (-1.35f0, -4.65f0), (3.45f0, 77.95f0)],
            ],
        ]
        properties = [
            [:Ã => "Ã"],
            [:type => "é"],
            [:type => "meow"],
            [:title => "Dict 1"],
            [
                :link => "http://example.org/features/1",
                :title => "Feature 1",
                :summary => "The first feature",
            ],
            [:foo => "bar"],
            [:title => "Dict 1", :bbox => [-180.0f0, -90.0f0, 180.0f0, 90.0f0]],
        ]
        foreach(Samples.features, geometries, properties) do s, g, p
            @test collect(pairs(GeoJSON.properties(GeoJSON.read(s)))) == p
            geom = GeoJSON.geometry(GeoJSON.read(s))
            if !isnothing(geom)
                @test GeoJSON.coordinates(geom) == g
                plot(geom)
            end
        end
    end

    @testset "Geometries" begin
        geom = GeoJSON.read(Samples.multi)
        @test geom isa GeoJSON.MultiPolygon
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
        plot(geom)
        @test geom isa GeoJSON.LineString
        @test GI.crs(geom) == GeoFormatTypes.EPSG(4326)
        @test GeoJSON.coordinates(geom) == [(-35.1f0, -6.6f0), (8.1f0, 3.8f0)]
        @test GeoJSON.bbox(geom) == [-35.1f0, -6.6f0, 8.1f0, 3.8f0]
        @test GI.extent(geom) == Extent(X=(-35.1f0, 8.1f0), Y=(-6.6f0, 3.8f0))

        geom = GeoJSON.read(Samples.bbox_z, ndim=3)
        @test geom isa GeoJSON.LineString
        @test GeoJSON.coordinates(geom) == [(-35.1f0, -6.6f0, 5.5f0), (8.1f0, 3.8f0, 6.5f0)]
        @test GeoJSON.bbox(geom) == [-35.1f0, -6.6f0, 5.5f0, 8.1f0, 3.8f0, 6.5f0]
        @test GI.extent(geom) == Extent(X=(-35.1f0, 8.1f0), Y=(-6.6f0, 3.8f0), Z=(5.5f0, 6.5f0))
    end

    @testset "Construct from NamedTuple" begin
        # Geometry
        p = GeoJSON.Point(coordinates=(1.1f0, 2.2f0))
        @test propertynames(p) === (:bbox, :coordinates)
        @test GeoJSON.typestring(typeof(p)) === "Point"
        @test p.coordinates === GeoJSON.coordinates(p) == (1.1f0, 2.2f0)

        # Feature
        # properties named "geometry" are *not* shadowed by the geometry
        f = GeoJSON.Feature(geometry=p, properties=pairs((a=1, geometry="g", b=2)))
        @test GeoJSON.coordinates(f) == (1.1f0, 2.2f0)
        @test propertynames(f) === (:geometry, :a, :b)
        @test GeoJSON.geometry(f) === p

        @test GeoJSON.properties(f)[:a] === 1
        @test GeoJSON.properties(f)[:b] === 2
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
        @test iterate(p) === (1.1f0, 2)
        @test iterate(p, 2) === (2.2f0, 3)
        @test iterate(p, 3) === nothing

        # other constructors
        GeoJSON.Feature(geometry=p, properties=pairs((a=1, geometry="g", b=2)))
        GeoJSON.FeatureCollection(features=[f])

        # Mixed name vector
        f2 = GeoJSON.Feature(geometry=p, properties=pairs((a=1, geometry="g", b=2, c=3)))
        GeoJSON.FeatureCollection(features=[f, f2])
    end

    @testset "extent" begin
        @test GI.extent(GeoJSON.read(Samples.d)) ==
              Extent(X=(-180.0f0, 180.0f0), Y=(-90.0f0, 90.0f0))
        @test GI.extent(GeoJSON.read(Samples.e), fallback=false) === nothing
        @test GI.extent(GeoJSON.read(Samples.g, ndim=2)) ==
              Extent(X=(100.0f0, 105.0f0), Y=(0.0f0, 1.0f0))
    end

    @testset "crs" begin
        @test GI.crs(GeoJSON.read(Samples.a)) == GeoFormatTypes.EPSG(4326)
        @test GI.crs(GeoJSON.read(Samples.collection)) == GeoFormatTypes.EPSG(4326)
        @test GI.crs(GeoJSON.read(Samples.multi)) == GeoFormatTypes.EPSG(4326)
    end

    @testset "read not crash" begin
        for str in vcat(Samples.featurecollections, Samples.features, Samples.geometries)
            GeoJSON.read(str)
        end
    end

    @testset "write" begin
        # Round trip read/write and compare prettified output to prettified original
        foreach(Samples.features) do json
            f = GeoJSON.read(json)
            f1 = GeoJSON.read(GeoJSON.write(f))
            @test GeoJSON.geometry(f) == GeoJSON.geometry(f1)
            @test GeoJSON.properties(f) == GeoJSON.properties(f1)
            @test GI.extent(f) == GI.extent(f1)
        end

        # Writing using _lower
        foreach(Samples.features) do json
            f = GeoJSON.read(json)
            f1 = GeoJSON.read(JSON3.write(GeoJSON._lower(f)))
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
    end

    @testset "FeatureCollection of one MultiPolygon" begin
        t = GeoJSON.read(Samples.g)
        @test Tables.istable(t)
        @test Tables.rows(t) === t
        @test Tables.columns(t) isa Tables.CopiedColumns
        @test t isa GeoJSON.FeatureCollection{2}
        @test sort(propertynames(t)) == [:addr1, :addr2, :cartodb_id, :geometry, :park,]
        @test Tables.rowtable(t) isa Vector{<:NamedTuple}
        @test Tables.columntable(t) isa NamedTuple
        @inferred first(t)
        f1, _ = iterate(t)
        @test f1 isa GeoJSON.Feature{2}
        @test propertynames(f1) === (:geometry, :park, :cartodb_id, :addr1, :addr2)
        @test all(propertynames(f1)) do pn
            getproperty(f1, pn) == getproperty(GI.getfeature(t, 1), pn)
        end
        @inferred t[1]
        @test f1 == t[1]
        geom = GeoJSON.geometry(f1)
        @test geom isa GeoJSON.MultiPolygon{2}
        @test geom isa GeoJSON.AbstractGeometry{2}
        @test GeoJSON.coordinates(geom) isa Vector{Vector{Vector{Tuple{Float32,Float32}}}}
        @test GI.coordinates(geom) isa Vector{Vector{Vector{Tuple{Float32,Float32}}}}
        @test GeoJSON.coordinates(geom)[1][1] == geom[1][1]
        @test length(geom[1][1]) == 4
        @test geom[1][1][1] == (-117.913883f0, 33.96657f0)
        @test geom[1][1][2] == (-117.907767f0, 33.967747f0)
        @test geom[1][1][3] == (-117.912919f0, 33.96445f0)
        @test geom[1][1][4] == (-117.913883f0, 33.96657f0)

        @testset "With NamedTuple feature" begin
            nt_feature = GeoJSON.Feature(
                geometry=t[1].geometry,
                properties=pairs((cartodb_id=t[1].cartodb_id, addr1=t[1].addr1, addr2=t[1].addr2, park=t[1].park))
            )
            fc = GeoJSON.FeatureCollection(features=[nt_feature])
            @test fc isa GeoJSON.FeatureCollection
            @test occursin("(:geometry,", sprint(show, MIME"text/plain"(), fc[1]))
            @test occursin(":park", sprint(show, MIME"text/plain"(), fc[1]))
        end

        @testset "write to disk" begin
            fc = t
            GeoJSON.write("Samples.json", fc)
            fc1 = GeoJSON.read(read("Samples.json", String))
            @test GI.extent(fc) == GI.extent(fc1) == Extent(X=(100.0f0, 105.0f0), Y=(0.0f0, 1.0f0))
            f = GI.getfeature(fc, 1)
            f1 = GI.getfeature(fc1, 1)
            @test GI.geometry(f) == GI.geometry(f1)
            @test GI.properties(f) == GI.properties(f1)
            rm("Samples.json")
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

    @testset "Tables with missings" begin
        t = GeoJSON.read(Samples.tablenull)
        @test t[1] isa GeoJSON.Feature
        @test occursin("(:geometry, :a, :b)", sprint(show, MIME"text/plain"(), t[1]))
        @test ismissing(t[1].geometry)
        GeoJSON.geometry(t[1])
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
        @testset "With NamedTuple feature" begin
            nt_props = [
                (a=t[1].a, b=t[1].b, c=t[1].c),
                (a=t[2].a, b=t[2].b, d=t[2].d),
                (a=t[3].a, b=t[3].b),
            ]
            features = map(t.geometry, nt_props) do geometry, properties
                # Setting 2 here is required because of the missing geometry
                GeoJSON.Feature{2,Float32}(geometry=ismissing(geometry) ? nothing : geometry, properties=pairs(properties))
            end
            fc = GeoJSON.FeatureCollection(features=features)
            @test fc isa GeoJSON.FeatureCollection
            @test occursin("(:geometry, :a, :b, :c)", sprint(show, MIME"text/plain"(), fc[1]))
        end
    end

    @testset "FeatureCollection of one GeometryCollection" begin
        fc = GeoJSON.read(Samples.collection)
        gc = GeoJSON.geometry(GI.getfeature(fc, 1))
        @test GI.geomtrait(gc) isa GI.GeometryCollectionTrait

        @testset "Mixed geometry types are returned" begin
            @test GI.getgeom(gc, 1) isa GeoJSON.Polygon
            @test GI.getgeom(gc, 2) isa GeoJSON.Polygon
            @test GI.getgeom(gc, 3) isa GeoJSON.Point
        end
    end

    @testset "GeoInterface tests" begin
        @test all(GI.testgeometry, GeoJSON.read.(Samples.geometries))
        @test all(GI.testfeature, GeoJSON.read.(Samples.features))
        @test all(GI.testfeaturecollection, GeoJSON.read.(Samples.featurecollections))
    end

    @testset "GeoFormatTypes" begin
        gft_str = GeoFormatTypes.GeoJSON(Samples.b)
        f = GeoJSON.read(gft_str)
        @test f isa GeoJSON.Feature

        dict = Dict{String,Any}("type" => "Point", "coordinates" => [-105.0, 39.5])
        gft_dict = GeoFormatTypes.GeoJSON(dict)
        p = GeoJSON.read(gft_dict)
        @test p isa GeoJSON.Point
    end

    @testset "numbertype" begin
        # all numbers are Float32 since we use numbertype=Float32
        p = GeoJSON.read(Samples.point_int)
        @test p isa GeoJSON.Point
        coords = GeoJSON.coordinates(p)
        @test eltype(coords) == Float32
        @test coords == (1.0, 2.0)
        @test collect(coords) isa Vector{Float32}
    end

    @testset "equality" begin
        p = GeoJSON.read(Samples.point_int)
        @test p == p
        @test GeoJSON.Point(coordinates=(1, 2)) != GeoJSON.Point(coordinates=(2, 3))
        @test GeoJSON.LineString(coordinates=[(1, 2)]) != GeoJSON.MultiPoint(coordinates=[(1, 2)])
    end

    @testset "regression" begin
        GeoJSON.read(Samples.null_prop_feat)
    end

    @testset "NamedTuple point order doesn't matter as long as it's known" begin
        @test GeoJSON.write((X=1.0, Y=2.0)) == 
              GeoJSON.write((Y=2.0, X=1.0)) == 
              "{\"type\":\"Point\",\"coordinates\":[1.0,2.0]}"
        @test GeoJSON.write((Z=3, X=1.0, Y=2.0)) == 
              GeoJSON.write((Y=2.0, X=1.0, Z=3)) == 
              GeoJSON.write((Y=2.0, Z=3, X=1.0)) == 
              GeoJSON.write((X=1.0, Z=3, Y=2.0)) == 
              "{\"type\":\"Point\",\"coordinates\":[1.0,2.0,3]}"
        # M is not in the spec
        @test GeoJSON.write((Z=3, X=1.0, Y=2.0, M=4)) == 
              GeoJSON.write((Y=2.0, X=1.0, M=4, Z=3)) == 
              GeoJSON.write((M=4, Y=2.0, Z=3, X=1.0)) == 
              GeoJSON.write((X=1.0, Z=3, M=4, Y=2.0)) == 
              "{\"type\":\"Point\",\"coordinates\":[1.0,2.0,3]}"
    end

    Aqua.test_all(GeoJSON)

end  # testset "GeoJSON"
