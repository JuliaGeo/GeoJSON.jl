using GeoJSONTables
import GeoInterface as GI
import GeoFormatTypes
import Aqua
using Extents
using JSON3
using Tables
using Test

# samples and collections thereof defined under module T
include("geojson_samples.jl")

@testset "GeoJSONTables" begin

    @testset "Features" begin
        geometries = [
            nothing,
            [[-155.52, 19.61], [-156.22, 20.74], [-157.97, 21.46]],
            nothing,
            [
                [[3.75, 9.25], [-130.95, 1.52]],
                [[23.15, -34.25], [-1.35, -4.65], [3.45, 77.95]],
            ],
            [53, -4],
            nothing,
            [
                [[3.75, 9.25], [-130.95, 1.52]],
                [[23.15, -34.25], [-1.35, -4.65], [3.45, 77.95]],
            ],
        ]
        properties = [
            [:Ã => "Ã"],
            [:type => "é"],
            [:type => "meow"],
            [:title => "Dict 1"],
            [
                :link => "http://example.org/features/1",
                :summary => "The first feature",
                :title => "Feature 1",
            ],
            [:foo => "bar"],
            [:title => "Dict 1", :bbox => [-180.0, -90.0, 180.0, 90.0]],
        ]
        foreach(T.features, geometries, properties) do s, g, p
            @test collect(GeoJSONTables.properties(GeoJSONTables.read(s))) == p
            @test GeoJSONTables.geometry(GeoJSONTables.read(s)) == g
        end
    end

    @testset "Geometries" begin
        geom = GeoJSONTables.read(T.multi)
        @test geom isa GeoJSONTables.MultiPolygon
        @test geom == [
            [[[180.0, 40.0], [180.0, 50.0], [170.0, 50.0], [170.0, 40.0], [180.0, 40.0]]],
            [[
                [-170.0, 40.0],
                [-170.0, 50.0],
                [-180.0, 50.0],
                [-180.0, 40.0],
                [-170.0, 40.0],
            ]],
        ]

        geom = GeoJSONTables.read(T.bbox)
        @test geom isa GeoJSONTables.LineString
        @test geom == [[-35.1, -6.6], [8.1, 3.8]]
        @test GI.crs(geom) == GeoFormatTypes.EPSG(4326)
        @test GeoJSONTables.bbox(geom) == [-35.1, -6.6, 8.1, 3.8]
        @test GI.extent(geom) == Extent(X = (-35.1, 8.1), Y = (-6.6, 3.8))

        geom = GeoJSONTables.read(T.bbox_z)
        @test geom isa GeoJSONTables.LineString
        @test geom == [[-35.1, -6.6, 5.5], [8.1, 3.8, 6.5]]
        @test GeoJSONTables.bbox(geom) == [-35.1, -6.6, 5.5, 8.1, 3.8, 6.5]
        @test GI.extent(geom) == Extent(X = (-35.1, 8.1), Y = (-6.6, 3.8), Z = (5.5, 6.5))
    end

    @testset "Construct from NamedTuple" begin
        # Geometry
        p = GeoJSONTables.Point(coordinates = [1.1, 2.2])
        @test propertynames(p) === (:type, :coordinates)
        @test p.type === GeoJSONTables.type(p) === "Point"
        @test p.coordinates === GeoJSONTables.coordinates(p) == [1.1, 2.2]

        # Feature
        # properties named "geometry" are shadowed by the geometry
        f = GeoJSONTables.Feature(p; properties = (a = 1, geometry = "g", b = 2))
        @test GeoJSONTables.coordinates(f) == [1.1, 2.2]
        @test propertynames(f) === (:geometry, :a, :b)
        @test GeoJSONTables.geometry(f) === f.geometry === p
        @test f.a === 1
        @test f.b === 2
        @test_throws ErrorException f.not_a_col
        @test_throws MethodError iterate(f)
        @test_throws MethodError f[1]
        # but can still be retrieved from the properties directly
        @test GeoJSONTables.properties(f).geometry === "g"
        @test GeoJSONTables.object(f) isa NamedTuple{
            (:type, :geometry, :properties),
            Tuple{
                String,
                GeoJSONTables.Point{
                    NamedTuple{(:type, :coordinates),Tuple{String,Vector{Float64}}},
                },
                NamedTuple{(:a, :geometry, :b),Tuple{Int64,String,Int64}},
            },
        }

        # FeatureCollection
        features = [f]
        fc = GeoJSONTables.FeatureCollection(features)
        @test GeoJSONTables.features(fc) === features
        @test propertynames(fc) === Tables.columnnames(fc) === (:geometry, :a, :b)
        @test GeoJSONTables.geometry.(fc) == [p]
        @test iterate(p) === (1.1, 2)
        @test iterate(p, 2) === (2.2, 3)
        @test iterate(p, 3) === nothing

        # other constructors
        GeoJSONTables.Feature(geometry = p, properties = (a = 1, geometry = "g", b = 2))
        GeoJSONTables.Feature((geometry = p, properties = (a = 1, geometry = "g", b = 2)))
        GeoJSONTables.FeatureCollection(; features)
        GeoJSONTables.FeatureCollection((type = "FeatureCollection", features = [f]))
    end

    @testset "extent" begin
        @test GI.extent(GeoJSONTables.read(T.d)) ==
              Extent(X = (-180.0, 180.0), Y = (-90.0, 90.0))
        @test GI.extent(GeoJSONTables.read(T.e)) === nothing
        @test GI.extent(GeoJSONTables.read(T.g)) ==
              Extent(X = (100.0, 105.0), Y = (0.0, 1.0))
    end

    @testset "crs" begin
        @test GI.crs(GeoJSONTables.read(T.a)) == GeoFormatTypes.EPSG(4326)
        @test GI.crs(GeoJSONTables.read(T.collection)) == GeoFormatTypes.EPSG(4326)
        @test GI.crs(GeoJSONTables.read(T.multi)) == GeoFormatTypes.EPSG(4326)
    end

    @testset "read not crash" begin
        for str in vcat(T.featurecollections, T.features, T.geometries)
            GeoJSONTables.read(str)
        end
    end

    @testset "write" begin
        # Round trip read/write and compare prettified output to prettified original
        foreach(T.features) do json
            f = GeoJSONTables.read(json)
            f1 = GeoJSONTables.read(GeoJSONTables.write(f))
            @test GeoJSONTables.geometry(f) == GeoJSONTables.geometry(f1)
            @test GeoJSONTables.properties(f) == GeoJSONTables.properties(f1)
            @test GI.extent(f) == GI.extent(f1)
        end

        foreach(T.featurecollections) do json
            fc = GeoJSONTables.read(json)
            f1c = GeoJSONTables.read(GeoJSONTables.write(fc))
            foreach(fc, f1c) do f, f1
                @test GeoJSONTables.geometry(f) == GeoJSONTables.geometry(f1)
                @test GeoJSONTables.properties(f) == GeoJSONTables.properties(f1)
                @test GI.extent(f) == GI.extent(f1)
            end
        end
    end

    @testset "FeatureCollection of one MultiPolygon" begin
        t = GeoJSONTables.read(T.g)
        @test Tables.istable(t)
        @test Tables.rows(t) === t
        @test Tables.columns(t) isa Tables.CopiedColumns
        @test t isa GeoJSONTables.FeatureCollection{
            <:GeoJSONTables.Feature,
            <:JSON3.Object,
            <:JSON3.Array,
        }
        @test propertynames(t) == (:geometry, :park, :cartodb_id, :addr1, :addr2)
        @test Tables.rowtable(t) isa Vector{<:NamedTuple}
        @test Tables.columntable(t) isa NamedTuple
        @inferred first(t)
        f1, _ = iterate(t)
        @test f1 isa GeoJSONTables.Feature{<:JSON3.Object}
        @test propertynames(f1) === (:geometry, :park, :cartodb_id, :addr1, :addr2)
        @test all(propertynames(f1)) do pn
            getproperty(f1, pn) == getproperty(GI.getfeature(t, 1), pn)
        end
        @inferred t[1]
        @test f1 == t[1]
        geom = GeoJSONTables.geometry(f1)
        @test geom isa GeoJSONTables.MultiPolygon{<:JSON3.Object}
        @test geom isa GeoJSONTables.Geometry
        @test geom isa AbstractVector
        @test GeoJSONTables.object(geom) isa JSON3.Object
        @test GeoJSONTables.coordinates(geom) isa JSON3.Array
        @test GI.coordinates(geom) isa Vector
        @test GeoJSONTables.coordinates(geom)[1][1] == geom[1][1]
        @test length(geom[1][1]) == 4
        @test geom[1][1][1] == [-117.913883, 33.96657]
        @test geom[1][1][2] == [-117.907767, 33.967747]
        @test geom[1][1][3] == [-117.912919, 33.96445]
        @test geom[1][1][4] == [-117.913883, 33.96657]

        @testset "write to disk" begin
            fc = t
            GeoJSONTables.write("test.json", fc)
            fc1 = GeoJSONTables.read(read("test.json", String))
            @test GI.extent(fc) == GI.extent(fc1) == Extent(X = (100, 105), Y = (0, 1))
            f = GI.getfeature(fc, 1)
            f1 = GI.getfeature(fc1, 1)
            @test GI.geometry(f) == GI.geometry(f1)
            @test GI.properties(f) == GI.properties(f1)
            rm("test.json")
        end

        @testset "GeoInterface" begin
            @test GI.trait(t) == GI.FeatureCollectionTrait()
            geom = GeoJSONTables.geometry(f1)
            @test GI.trait(f1) === GI.FeatureTrait()
            @test GI.geomtrait(geom) === GI.MultiPolygonTrait()
            properties = GeoJSONTables.properties(f1)
            @test properties isa JSON3.Object
            @test properties["addr2"] === "Rowland Heights"
            @test !GI.isclosed(GeoJSONTables.read(T.bbox))
            @test GI.isclosed(GeoJSONTables.read(T.bermuda_triangle))
        end
    end

    @testset "Tables with missings" begin
        t = GeoJSONTables.read(T.tablenull)
        @test t[1] isa GeoJSONTables.Feature
        @test t.geometry isa Vector{Union{T,Missing}} where {T<:GeoJSONTables.Point}
        @test ismissing(t.geometry[3])
        @test t.a isa Vector{Union{Int,Missing}}
        @test isequal(t.a, [1, missing, 3])
        @test t.b isa Vector{Missing}
        @test Tables.columntable(t) isa NamedTuple

        t = GeoJSONTables.read(T.table_not_present)
        @test propertynames(t) === propertynames(t[1]) === (:geometry, :a, :b, :c)
        @test propertynames(t[2]) === (:geometry, :a, :b)
        # "c" is only present in the properyies of the first row
        # We don't support automatically setting these to missing in the tables interface.
        # They have to be explicitly set to null.
        # We could support it by having getproperty(f::Feature, :not_present) return missing
        # if needed, but then you always get missing instead of KeyError.
        @test_throws KeyError t.c
        @test_throws KeyError Tables.columntable(t)
    end

    @testset "FeatureCollection of one GeometryCollection" begin
        fc = GeoJSONTables.read(T.collection)
        gc = GeoJSONTables.geometry(GI.getfeature(fc, 1))
        @test GI.geomtrait(gc) isa GI.GeometryCollectionTrait

        @testset "Mixed geometry types are returned" begin
            @test GI.getgeom(gc, 1) isa GeoJSONTables.Polygon
            @test GI.getgeom(gc, 2) isa GeoJSONTables.Polygon
            @test GI.getgeom(gc, 3) isa GeoJSONTables.Point
        end
    end

    @testset "GeoInterface tests" begin
        @test all(GI.testgeometry, GeoJSONTables.read.(T.geometries))
        @test all(GI.testfeature, GeoJSONTables.read.(T.features))
        @test all(GI.testfeaturecollection, GeoJSONTables.read.(T.featurecollections))
    end

    @testset "GeoFormatTypes" begin
        gft_str = GeoFormatTypes.GeoJSON(T.b)
        f = GeoJSONTables.read(gft_str)
        @test f isa GeoJSONTables.Feature

        dict = Dict{String,Any}("type" => "Point", "coordinates" => [-105.0, 39.5])
        gft_dict = GeoFormatTypes.GeoJSON(dict)
        p = GeoJSONTables.read(gft_dict)
        @test p isa GeoJSONTables.Point
    end

    Aqua.test_all(GeoJSONTables)

end  # testset "GeoJSONTables"
