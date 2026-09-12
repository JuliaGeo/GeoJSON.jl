using Test
using GeoJSON
using JSON
import GeoFormatTypes

@testset "spec" begin

    # Type shorthands the assertions name repeatedly.
    Props = GeoJSON.Properties
    AG2 = GeoJSON.AnyGeometry{2,Float64}
    P2 = GeoJSON.Point{2,Float64}
    F2 = GeoJSON.Feature{2,Float64,AG2,Props}
    FC2 = GeoJSON.FeatureCollection{2,Float64,AG2,Props}

    # The exception `f` throws, or `nothing`.
    function thrown(f)
        try
            f()
        catch e
            return e
        end
        nothing
    end

    # Every valid document in this file, so the round-trip testset can replay all of them.
    docs = (
        point_typelast = """{"coordinates":[1,2],"type":"Point"}""",
        linestring_typelast = """{"coordinates":[[1,2],[3,4]],"type":"LineString"}""",
        multipoint_typelast = """{"coordinates":[[1,2],[3,4]],"type":"MultiPoint"}""",
        polygon_typelast = """{"coordinates":[[[0,0],[1,0],[1,1],[0,0]]],"type":"Polygon"}""",
        multilinestring_typelast = """{"coordinates":[[[1,2],[3,4]]],"type":"MultiLineString"}""",
        multipolygon_typelast = """{"coordinates":[[[[0,0],[1,0],[1,1],[0,0]]]],"type":"MultiPolygon"}""",
        collection_typelast = """{"geometries":[{"coordinates":[1,2],"type":"Point"}],"type":"GeometryCollection"}""",
        feature_typelast = """{"geometry":{"coordinates":[1,2],"type":"Point"},"properties":{"a":1},"type":"Feature"}""",
        collection_typelast_fc = """{"features":[{"geometry":null,"properties":{},"type":"Feature"}],"type":"FeatureCollection"}""",
        nested_collection = """{"type":"GeometryCollection","geometries":[{"type":"Point","coordinates":[1,2]},{"type":"GeometryCollection","geometries":[{"type":"LineString","coordinates":[[1,2],[3,4]]}]}]}""",
        empty_linestring = """{"type":"LineString","coordinates":[]}""",
        empty_multipoint = """{"type":"MultiPoint","coordinates":[]}""",
        empty_polygon = """{"type":"Polygon","coordinates":[]}""",
        empty_multilinestring = """{"type":"MultiLineString","coordinates":[]}""",
        empty_multipolygon = """{"type":"MultiPolygon","coordinates":[]}""",
        empty_collection = """{"type":"GeometryCollection","geometries":[]}""",
        null_coordinates = """{"type":"Point","coordinates":null}""",
        null_geometry = """{"type":"Feature","geometry":null,"properties":{"a":1}}""",
        null_properties = """{"type":"Feature","geometry":{"type":"Point","coordinates":[1,2]},"properties":null}""",
        no_properties = """{"type":"Feature","geometry":{"type":"Point","coordinates":[1,2]}}""",
        no_features = """{"type":"FeatureCollection"}""",
        id_string = """{"type":"Feature","id":"abc","geometry":null,"properties":{}}""",
        id_int = """{"type":"Feature","id":42,"geometry":null,"properties":{}}""",
        id_float = """{"type":"Feature","id":4.5,"geometry":null,"properties":{}}""",
        id_null = """{"type":"Feature","id":null,"geometry":null,"properties":{}}""",
        bbox_geometry = """{"type":"Point","bbox":[1,2,3,4],"coordinates":[1,2]}""",
        bbox_geometry_3d = """{"type":"Point","bbox":[1,2,3,4,5,6],"coordinates":[1,2,3]}""",
        bbox_feature = """{"type":"Feature","bbox":[1,2,3,4],"geometry":null,"properties":{}}""",
        bbox_collection = """{"type":"FeatureCollection","bbox":[1,2,3,4,5,6],"features":[]}""",
        extras_everywhere = """{"type":"FeatureCollection","name":"nm","crs":{"type":"name"},"features":[{"type":"Feature","fid":7,"geometry":{"type":"Point","coordinates":[1,2],"gext":[1,2]},"properties":{"a":1},"fext":"x"}],"tail":[1,2]}""",
        bare_point = """{"type":"Point","coordinates":[1,2]}""",
        bare_feature = """{"type":"Feature","geometry":{"type":"Point","coordinates":[1,2]},"properties":{}}""",
        dims_2d = """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":null,"properties":{}},{"type":"Feature","geometry":{"type":"LineString","coordinates":[]},"properties":{}},{"type":"Feature","geometry":{"type":"Point","coordinates":[1,2]},"properties":{}}]}""",
        dims_3d = """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":null,"properties":{}},{"type":"Feature","geometry":{"type":"MultiPoint","coordinates":[]},"properties":{}},{"type":"Feature","geometry":{"type":"Point","coordinates":[1,2,3]},"properties":{}}]}""",
        dims_4d = """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":null,"properties":{}},{"type":"Feature","geometry":{"type":"MultiPoint","coordinates":[]},"properties":{}},{"type":"Feature","geometry":{"type":"Point","coordinates":[1,2,3,4]},"properties":{}}]}""",
        numbers = """{"type":"Point","coordinates":[1e30,-2.5e-8]}""",
        property_types = """{"type":"Feature","geometry":null,"properties":{"i":1,"f":1.5,"s":"x","b":true,"n":null,"o":{"k":[1,2]},"a":[1,"two",null]}}""",
    )

    @testset "RFC 7946 shapes" begin
        @testset "\"type\" after \"coordinates\"" begin
            @test GeoJSON.read(docs.point_typelast) == P2(nothing, (1.0, 2.0))
            @test GeoJSON.read(docs.linestring_typelast) ==
                  GeoJSON.LineString{2,Float64}(nothing, [(1.0, 2.0), (3.0, 4.0)])
            @test GeoJSON.read(docs.multipoint_typelast) ==
                  GeoJSON.MultiPoint{2,Float64}(nothing, [(1.0, 2.0), (3.0, 4.0)])
            @test GeoJSON.read(docs.polygon_typelast) ==
                  GeoJSON.Polygon{2,Float64}(nothing, [[(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 0.0)]])
            @test GeoJSON.read(docs.multilinestring_typelast) ==
                  GeoJSON.MultiLineString{2,Float64}(nothing, [[(1.0, 2.0), (3.0, 4.0)]])
            @test GeoJSON.read(docs.multipolygon_typelast) ==
                  GeoJSON.MultiPolygon{2,Float64}(nothing, [[[(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 0.0)]]])
            gc = GeoJSON.read(docs.collection_typelast)
            @test gc isa GeoJSON.GeometryCollection{2,Float64}
            @test gc[1] == P2(nothing, (1.0, 2.0))
        end

        @testset "\"type\" after the other members" begin
            f = GeoJSON.read(docs.feature_typelast)
            @test f isa F2
            @test GeoJSON.geometry(f) == P2(nothing, (1.0, 2.0))
            @test f.a == 1
            @test GeoJSON.write(f) ==
                  """{"type":"Feature","geometry":{"type":"Point","coordinates":[1.0,2.0]},"properties":{"a":1}}"""

            fc = GeoJSON.read(docs.collection_typelast_fc)
            @test fc isa FC2
            @test length(fc) == 1
            @test GeoJSON.geometry(fc[1]) === nothing
            @test GeoJSON.write(fc) ==
                  """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":null,"properties":{}}]}"""
        end

        @testset "nested GeometryCollection" begin
            gc = GeoJSON.read(docs.nested_collection)
            @test gc isa GeoJSON.GeometryCollection{2,Float64}
            @test length(gc) == 2
            @test gc[1] == P2(nothing, (1.0, 2.0))
            @test gc[2] isa GeoJSON.GeometryCollection{2,Float64}
            @test gc[2][1] == GeoJSON.LineString{2,Float64}(nothing, [(1.0, 2.0), (3.0, 4.0)])
            @test GeoJSON.write(gc) ==
                  """{"type":"GeometryCollection","geometries":[{"type":"Point","coordinates":[1.0,2.0]},{"type":"GeometryCollection","geometries":[{"type":"LineString","coordinates":[[1.0,2.0],[3.0,4.0]]}]}]}"""
        end

        @testset "empty coordinates" begin
            @test GeoJSON.coordinates(GeoJSON.read(docs.empty_linestring)) == NTuple{2,Float64}[]
            @test GeoJSON.coordinates(GeoJSON.read(docs.empty_multipoint)) == NTuple{2,Float64}[]
            @test GeoJSON.coordinates(GeoJSON.read(docs.empty_polygon)) == Vector{NTuple{2,Float64}}[]
            @test GeoJSON.coordinates(GeoJSON.read(docs.empty_multilinestring)) == Vector{NTuple{2,Float64}}[]
            @test GeoJSON.coordinates(GeoJSON.read(docs.empty_multipolygon)) == Vector{Vector{NTuple{2,Float64}}}[]
            @test isempty(GeoJSON.geometry(GeoJSON.read(docs.empty_collection)))
            for k in (:empty_linestring, :empty_multipoint, :empty_polygon, :empty_multilinestring,
                      :empty_multipolygon, :empty_collection)
                @test GeoJSON.write(GeoJSON.read(docs[k])) == docs[k]
            end

            # A null coordinate member is the unlocated point the `Union{Nothing,NTuple}` field allows.
            p = GeoJSON.read(docs.null_coordinates)
            @test p isa P2
            @test GeoJSON.coordinates(p) === nothing
            @test GeoJSON.write(p) == docs.null_coordinates

            # An empty position is the same unlocated point.
            @test GeoJSON.read("""{"type":"Point","coordinates":[]}""") == P2(nothing, nothing)
            @test GeoJSON.coordinates(GeoJSON.read("""{"type":"Point","coordinates":[]}""")) === nothing
            @test GeoJSON.coordinates(GeoJSON.read("""{"coordinates":[],"type":"Point"}""")) === nothing
            # An empty position inside a ring is a mismatch no `ndim` could satisfy.
            e = thrown(() -> GeoJSON.read("""{"type":"LineString","coordinates":[[1,2],[]]}"""))
            @test e isa GeoJSON.DimMismatch
            @test (e::GeoJSON.DimMismatch).got == 0
            @test !occursin("ndim=", sprint(showerror, e))
        end

        @testset "null geometry and properties" begin
            f = GeoJSON.read(docs.null_geometry)
            @test GeoJSON.geometry(f) === nothing
            @test f.a == 1
            @test GeoJSON.write(f) == """{"type":"Feature","geometry":null,"properties":{"a":1}}"""

            for k in (:null_properties, :no_properties)
                f = GeoJSON.read(docs[k])
                @test GeoJSON.properties(f) == Props()
                @test isempty(GeoJSON.properties(f))
                @test GeoJSON.write(f) ==
                      """{"type":"Feature","geometry":{"type":"Point","coordinates":[1.0,2.0]},"properties":{}}"""
            end

            fc = GeoJSON.read(docs.no_features)
            @test fc isa FC2
            @test length(fc) == 0
            @test GeoJSON.write(fc) == """{"type":"FeatureCollection","features":[]}"""
        end

        @testset "id" begin
            @test GeoJSON.id(GeoJSON.read(docs.id_string)) === "abc"
            @test GeoJSON.id(GeoJSON.read(docs.id_int)) === Int64(42)
            @test GeoJSON.id(GeoJSON.read(docs.id_float)) === 4.5
            @test GeoJSON.id(GeoJSON.read(docs.id_null)) === nothing
            @test GeoJSON.id(GeoJSON.read(docs.null_geometry)) === nothing
            @test GeoJSON.write(GeoJSON.read(docs.id_string)) ==
                  """{"type":"Feature","id":"abc","geometry":null,"properties":{}}"""
            @test GeoJSON.write(GeoJSON.read(docs.id_int)) ==
                  """{"type":"Feature","id":42,"geometry":null,"properties":{}}"""
            @test GeoJSON.write(GeoJSON.read(docs.id_float)) ==
                  """{"type":"Feature","id":4.5,"geometry":null,"properties":{}}"""
            # A null id is dropped, like an absent one.
            @test GeoJSON.write(GeoJSON.read(docs.id_null)) ==
                  """{"type":"Feature","geometry":null,"properties":{}}"""
            @test thrown(() -> GeoJSON.read("""{"type":"Feature","id":[1],"geometry":null,"properties":{}}""")) isa ArgumentError
        end

        @testset "bbox" begin
            g = GeoJSON.read(docs.bbox_geometry)
            @test GeoJSON.bbox(g) == [1.0, 2.0, 3.0, 4.0]
            @test GeoJSON.bbox(g) isa Vector{Float64}
            @test GeoJSON.write(g) == """{"type":"Point","bbox":[1.0,2.0,3.0,4.0],"coordinates":[1.0,2.0]}"""

            g3 = GeoJSON.read(docs.bbox_geometry_3d)
            @test g3 isa GeoJSON.Point{3,Float64}
            @test GeoJSON.bbox(g3) == [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]

            f = GeoJSON.read(docs.bbox_feature)
            @test GeoJSON.bbox(f) == [1.0, 2.0, 3.0, 4.0]
            @test GeoJSON.write(f) == """{"type":"Feature","bbox":[1.0,2.0,3.0,4.0],"geometry":null,"properties":{}}"""

            fc = GeoJSON.read(docs.bbox_collection)
            @test GeoJSON.bbox(fc) == [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
            @test GeoJSON.write(fc) ==
                  """{"type":"FeatureCollection","bbox":[1.0,2.0,3.0,4.0,5.0,6.0],"features":[]}"""

            @test GeoJSON.bbox(GeoJSON.read(docs.bare_point)) === nothing
        end

        @testset "foreign members" begin
            fc = GeoJSON.read(docs.extras_everywhere)
            f = fc[1]
            g = GeoJSON.geometry(f)
            @test GeoJSON.extras(fc) == ["name" => "nm",
                                         "crs" => JSON.Object{String,Any}("type" => "name"),
                                         "tail" => Any[1, 2]]
            @test GeoJSON.extras(f) == ["fid" => 7, "fext" => "x"]
            @test GeoJSON.extras(g) == ["gext" => Any[1, 2]]
            # Foreign members follow the standard members of their own object, in document order.
            @test GeoJSON.write(fc) ==
                  """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[1.0,2.0],"gext":[1,2]},"properties":{"a":1},"fid":7,"fext":"x"}],"name":"nm","crs":{"type":"name"},"tail":[1,2]}"""
            @test GeoJSON.read(GeoJSON.write(fc)) == fc
        end

        @testset "bare geometry and bare Feature roots" begin
            @test GeoJSON.read(docs.bare_point) isa P2
            @test GeoJSON.read(docs.bare_feature) isa F2
            @test GeoJSON.read(docs.nested_collection) isa GeoJSON.GeometryCollection{2,Float64}
            @test thrown(() -> GeoJSON.read("""{"coordinates":[1,2]}""")) isa ArgumentError
            @test thrown(() -> GeoJSON.read("""[1,2]""")) isa ArgumentError
        end
    end

    @testset "dimensions" begin
        @testset "discovery" begin
            @test GeoJSON.read(docs.dims_2d) isa GeoJSON.FeatureCollection{2,Float64}
            @test GeoJSON.read(docs.dims_3d) isa GeoJSON.FeatureCollection{3,Float64}
            @test GeoJSON.read(docs.dims_4d) isa GeoJSON.FeatureCollection{4,Float64}
            # A document with no position at all falls back to 2.
            @test GeoJSON.read(docs.no_features) isa GeoJSON.FeatureCollection{2,Float64}
            @test GeoJSON.discover_dim(codeunits(docs.dims_4d)) == 4
            @test GeoJSON.discover_dim(codeunits(docs.no_features)) == 0
        end

        @testset "ndim" begin
            bytes = Vector{UInt8}(docs.dims_3d)
            @test GeoJSON.read(bytes; ndim=3) isa GeoJSON.FeatureCollection{3,Float64}
            @test GeoJSON.read(bytes; ndim=Val(3)) isa GeoJSON.FeatureCollection{3,Float64}

            readval3(b) = GeoJSON.read(b; ndim=Val(3))
            members = Base.uniontypes(only(Base.return_types(readval3, Tuple{Vector{UInt8}})))
            # `Val(3)` pins D on every member: seven geometries, `Feature`, `FeatureCollection`,
            # and the `LazyFeatureCollection` the `lazy::Bool` keyword keeps reachable.
            @test length(members) == 10
            @test all(m -> m <: GeoJSON.GeoJSONT{3,Float64}, members)
            # The seven geometries are concrete; the three feature containers keep `P` free,
            # because `properties` reaches `_proptype` as a runtime `Bool`.
            @test count(isconcretetype, members) == 7
            # The typed read is the inferable entry; `Val(3)` only pins `D` on the keyword form.
            FC3 = GeoJSON.FeatureCollection{3,Float64,GeoJSON.AnyGeometry{3,Float64},Props}
            @test (@inferred GeoJSON.read(bytes, FC3)) isa FC3

            @test thrown(() -> GeoJSON.read(docs.dims_4d; ndim=5)) isa ArgumentError
        end

        @testset "mismatch names the feature" begin
            src = """{"type":"FeatureCollection","features":[
                {"type":"Feature","geometry":{"type":"Point","coordinates":[1,2]},"properties":{}},
                {"type":"Feature","geometry":{"type":"Point","coordinates":[3,4]},"properties":{}},
                {"type":"Feature","geometry":{"type":"Point","coordinates":[5,6,7]},"properties":{}},
                {"type":"Feature","geometry":{"type":"Point","coordinates":[8,9]},"properties":{}}]}"""
            e = thrown(() -> GeoJSON.read(src; ndim=2))
            @test e isa GeoJSON.DimMismatch
            @test (e::GeoJSON.DimMismatch).expected == 2
            @test (e::GeoJSON.DimMismatch).got == 3
            @test (e::GeoJSON.DimMismatch).feature == 3
            @test sprint(showerror, e) ==
                  "coordinate with 3 values in a 2-D read (feature 3); pass `ndim=3`"

            # A bare geometry has no feature index.
            e = thrown(() -> GeoJSON.read(docs.bare_point; ndim=3))
            @test (e::GeoJSON.DimMismatch).feature == 0
            @test sprint(showerror, e) == "coordinate with 2 values in a 3-D read; pass `ndim=2`"
        end

        @testset "4D" begin
            fc = GeoJSON.read(docs.dims_4d)
            @test GeoJSON.coordinates(GeoJSON.geometry(fc[3])) === (1.0, 2.0, 3.0, 4.0)
            @test GeoJSON.write(fc) ==
                  """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":null,"properties":{}},{"type":"Feature","geometry":{"type":"MultiPoint","coordinates":[]},"properties":{}},{"type":"Feature","geometry":{"type":"Point","coordinates":[1.0,2.0,3.0,4.0]},"properties":{}}]}"""
        end
    end

    @testset "numbers" begin
        @test GeoJSON.coordinates(GeoJSON.read(docs.bare_point)) === (1.0, 2.0)

        g32 = GeoJSON.read(docs.bbox_geometry; numbertype=Float32)
        @test g32 isa GeoJSON.Point{2,Float32}
        @test GeoJSON.coordinates(g32) === (1.0f0, 2.0f0)
        @test GeoJSON.bbox(g32) isa Vector{Float32}
        @test GeoJSON.bbox(g32) == Float32[1, 2, 3, 4]

        @test GeoJSON.coordinates(GeoJSON.read(docs.numbers)) === (1.0e30, -2.5e-8)
        # Integers past 2^53 land on the nearest Float64.
        @test GeoJSON.coordinates(GeoJSON.read("""{"type":"Point","coordinates":[9007199254740993,123456789012345]}""")) ===
              (9.007199254740992e15, 1.23456789012345e14)

        @testset "property values keep their JSON types" begin
            p = GeoJSON.properties(GeoJSON.read(docs.property_types))
            @test collect(keys(p)) == ["i", "f", "s", "b", "n", "o", "a"]
            @test p["i"] === Int64(1)
            @test p["f"] === 1.5
            @test p["s"] === "x"
            @test p["b"] === true
            @test p["n"] === nothing
            # A nested object materializes as JSON.jl's ordered object, a nested array as Vector{Any}.
            @test p["o"] isa JSON.Object{String,Any}
            @test p["o"] == JSON.Object{String,Any}("k" => Any[1, 2])
            @test p["o"]["k"] isa Vector{Any}
            @test p["a"] isa Vector{Any}
            @test p["a"] == Any[1, "two", nothing]
        end
    end

    @testset "schemas" begin
        polydoc = """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,0]]]},"properties":{}}]}"""
        mixeddoc = """{"type":"FeatureCollection","features":[
            {"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,0]]]},"properties":{}},
            {"type":"Feature","geometry":{"type":"MultiPolygon","coordinates":[[[[0,0],[1,0],[1,1],[0,0]]]]},"properties":{}}]}"""

        @testset "geometries" begin
            e = thrown(() -> GeoJSON.read(polydoc; geometries=(GeoJSON.Point,)))
            @test e isa ArgumentError
            @test e.msg == "geometry type Polygon is not in the schema (Point)"
            # A bare type is sugar for a one-element tuple.
            @test thrown(() -> GeoJSON.read(polydoc; geometries=GeoJSON.Point)).msg == e.msg

            fc = GeoJSON.read(mixeddoc; geometries=(GeoJSON.Polygon, GeoJSON.MultiPolygon))
            G = Union{GeoJSON.Polygon{2,Float64},GeoJSON.MultiPolygon{2,Float64}}
            @test fc isa GeoJSON.FeatureCollection{2,Float64,G,Props}
            @test eltype(fc) == GeoJSON.Feature{2,Float64,G,Props}
            @test fieldtype(eltype(fc), :geometry) == Union{Nothing,G}
            @test GeoJSON.geometry(fc[1]) isa GeoJSON.Polygon{2,Float64}
            @test GeoJSON.geometry(fc[2]) isa GeoJSON.MultiPolygon{2,Float64}
            @test GeoJSON.read(polydoc; geometries=(GeoJSON.Polygon,)) isa
                  GeoJSON.FeatureCollection{2,Float64,GeoJSON.Polygon{2,Float64},Props}
        end

        @testset "NamedTuple properties" begin
            NT = NamedTuple{(:a, :b),Tuple{Union{Missing,Int64},Union{Missing,String}}}
            FCN = GeoJSON.FeatureCollection{2,Float64,P2,NT}
            feature(props) = """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[1,2]},"properties":$props}]}"""
            props(src) = GeoJSON.properties(GeoJSON.read(src, FCN)[1])

            @test props(feature("""{"a":1,"b":"x"}""")) isa NT
            @test props(feature("""{"a":1,"b":"x"}""")) == (a = Int64(1), b = "x")
            # Document order is free; the fields fill by name.
            @test props(feature("""{"b":"x","a":1}""")) == (a = Int64(1), b = "x")
            # Keys outside the schema are dropped.
            @test props(feature("""{"a":1,"b":"x","c":9}""")) == (a = Int64(1), b = "x")
            # A null value is `missing`.
            @test isequal(props(feature("""{"a":null,"b":"x"}""")), (a = missing, b = "x"))
            @test isequal(props(feature("""{"a":1,"b":null}""")), (a = Int64(1), b = missing))

            # An absent key takes the `missing` field default.
            @test isequal(props(feature("""{"a":1}""")), (a = Int64(1), b = missing))
            @test isequal(props(feature("{}")), (a = missing, b = missing))
            # A null or absent "properties" member is the empty schema.
            @test isequal(props(feature("null")), (a = missing, b = missing))
            noprops = """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":null}]}"""
            @test isequal(props(noprops), (a = missing, b = missing))
            # The lazy reader fills absent keys the same way: on the feature view, the parsed
            # feature, and the column pass.
            LFCN = GeoJSON.LazyFeatureCollection{2,Float64,P2,NT}
            two = """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[1,2]},"properties":{"a":1,"b":"x"}},{"type":"Feature","geometry":{"type":"Point","coordinates":[3,4]},"properties":{"a":2}}]}"""
            lfc = GeoJSON.read(two, LFCN)
            @test isequal(GeoJSON.properties(GeoJSON.lazyfeature(lfc, 2)), (a = Int64(2), b = missing))
            @test isequal(GeoJSON.properties(lfc[2]), (a = Int64(2), b = missing))
            @test isequal(lfc.b, ["x", missing])
            # A field without `Missing` rejects both an absent key and a null value.
            NTS = NamedTuple{(:a, :b),Tuple{Int64,Union{Missing,String}}}
            FCS = GeoJSON.FeatureCollection{2,Float64,P2,NTS}
            @test isequal(GeoJSON.properties(GeoJSON.read(feature("""{"a":1}"""), FCS)[1]), (a = Int64(1), b = missing))
            @test thrown(() -> GeoJSON.read(feature("""{"b":"x"}"""), FCS)) isa ArgumentError
            @test thrown(() -> GeoJSON.read(feature("null"), FCS)) isa ArgumentError
            @test thrown(() -> GeoJSON.read(feature("""{"a":null}"""), FCS)) !== nothing

            # `missing` writes as null.
            fc = GeoJSON.read(feature("""{"a":1,"b":null}"""), FCN)
            @test GeoJSON.write(fc) ==
                  """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[1.0,2.0]},"properties":{"a":1,"b":null}}]}"""
            @test GeoJSON.write(GeoJSON.read(GeoJSON.write(fc), FCN)) == GeoJSON.write(fc)
            # `==` and `isequal` treat a `missing` property as equal to itself, and `hash` agrees.
            @test GeoJSON.read(GeoJSON.write(fc), FCN) == fc
            @test isequal(GeoJSON.read(GeoJSON.write(fc), FCN), fc)
            @test hash(GeoJSON.read(GeoJSON.write(fc), FCN)) == hash(fc)
            @test GeoJSON.read(feature("""{"a":2,"b":null}"""), FCN) != fc
        end

        @testset "NamedTuple typed slots" begin
            NTT = NamedTuple{(:f, :v, :b, :s),Tuple{Float64,Union{Missing,Vector{Float64}},Bool,Union{Missing,String}}}
            FCT = GeoJSON.FeatureCollection{2,Float64,P2,NTT}
            feature(props) = """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[1,2]},"properties":$props}]}"""
            props(src) = GeoJSON.properties(GeoJSON.read(src, FCT)[1])

            # A JSON integer fills a Float64 field, an array fills a Vector{Float64} field, and an
            # absent key takes `missing`.
            p = props(feature("""{"f":3,"v":[1,2.5],"b":true}"""))
            @test p isa NTT
            @test p.f === 3.0
            @test p.v isa Vector{Float64} && p.v == [1.0, 2.5]
            @test p.b === true
            @test p.s === missing
            @test isequal(props(feature("""{"f":1.5,"v":null,"b":false,"s":"x"}""")), (f = 1.5, v = missing, b = false, s = "x"))
            # A value of the wrong kind, a null, or an absent key on a field without `Missing` is rejected.
            @test thrown(() -> props(feature("""{"f":"3","b":true}"""))) isa ArgumentError
            @test thrown(() -> props(feature("""{"f":3,"b":1}"""))) isa ArgumentError
            @test thrown(() -> props(feature("""{"f":null,"b":true}"""))) isa ArgumentError
            @test thrown(() -> props(feature("""{"f":3}"""))) isa ArgumentError
            # Every feature of a collection reuses one slot buffer; a value never carries over.
            two = """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":null,"properties":{"f":1,"v":[1],"b":true,"s":"x"}},{"type":"Feature","geometry":null,"properties":{"f":2,"b":false}}]}"""
            fc = GeoJSON.read(two, FCT)
            @test isequal(GeoJSON.properties(fc[1]), (f = 1.0, v = [1.0], b = true, s = "x"))
            @test isequal(GeoJSON.properties(fc[2]), (f = 2.0, v = missing, b = false, s = missing))
            @test GeoJSON.read(GeoJSON.write(fc), FCT) == fc
        end

        @testset "properties=false" begin
            fc = GeoJSON.read(polydoc; properties=false)
            @test fc isa GeoJSON.FeatureCollection{2,Float64,AG2,Nothing}
            @test GeoJSON.properties(fc[1]) === nothing
            @test GeoJSON.write(fc) ==
                  """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[0.0,0.0],[1.0,0.0],[1.0,1.0],[0.0,0.0]]]},"properties":null}]}"""
            @test GeoJSON.read(GeoJSON.write(fc); properties=false) == fc
        end

        @testset "wrong root type" begin
            @test thrown(() -> GeoJSON.read(polydoc, F2)).msg ==
                  "expected \"type\": \"Feature\", got \"FeatureCollection\""
            @test thrown(() -> GeoJSON.read(docs.bare_point, FC2)).msg ==
                  "expected \"type\": \"FeatureCollection\", got \"Point\""
            @test thrown(() -> GeoJSON.read(polydoc, P2)).msg ==
                  "\"FeatureCollection\" is not a GeoJSON geometry type"
            # A target type without D and T cannot be a schema.
            @test thrown(() -> GeoJSON.read(polydoc, GeoJSON.FeatureCollection)) isa ArgumentError
        end
    end

    @testset "round trips" begin
        @testset "$k" for k in keys(docs)
            x = GeoJSON.read(docs[k])
            @test GeoJSON.read(GeoJSON.write(x)) == x
        end

        g32 = GeoJSON.read(docs.bbox_geometry; numbertype=Float32)
        @test GeoJSON.read(GeoJSON.write(g32); numbertype=Float32) == g32

        @testset "key order" begin
            f = GeoJSON.read("""{"type":"Feature","bbox":[1,2,3,4],"id":7,"properties":{"a":1},"geometry":{"type":"Point","coordinates":[1,2]},"who":"me"}""")
            @test GeoJSON.write(f) ==
                  """{"type":"Feature","id":7,"bbox":[1.0,2.0,3.0,4.0],"geometry":{"type":"Point","coordinates":[1.0,2.0]},"properties":{"a":1},"who":"me"}"""
            # bbox and id vanish when unset; geometry and properties are always written.
            @test GeoJSON.write(GeoJSON.read(docs.null_geometry)) ==
                  """{"type":"Feature","geometry":null,"properties":{"a":1}}"""
            @test GeoJSON.write(GeoJSON.read(docs.bare_point)) ==
                  """{"type":"Point","coordinates":[1.0,2.0]}"""
        end

        @testset "pretty" begin
            @test GeoJSON.write(GeoJSON.read(docs.polygon_typelast); pretty=2) ==
                  "{\n  \"type\": \"Polygon\",\n  \"coordinates\": [[[0.0,0.0],[1.0,0.0],[1.0,1.0],[0.0,0.0]]]\n}"

            src = """{"type":"FeatureCollection","features":[""" *
                  join(["""{"type":"Feature","geometry":{"type":"Point","coordinates":[$i,$i]},"properties":{"a":$i}}""" for i in 1:4], ",") * "]}"
            out = GeoJSON.write(GeoJSON.read(src); pretty=2)
            @test startswith(out, "{\n  \"type\": \"FeatureCollection\",\n  \"features\": [\n")
            # Positions stay on one line, so every coordinate array is a single line of the output.
            @test count(l -> occursin("\"coordinates\": [1.0,1.0]", l), split(out, '\n')) == 1
            @test count(l -> occursin("coordinates", l), split(out, '\n')) == 4
            @test GeoJSON.read(out) == GeoJSON.read(src)
        end

        @testset "IO and path" begin
            fc = GeoJSON.read(docs.extras_everywhere)
            s = GeoJSON.write(fc)
            io = IOBuffer()
            GeoJSON.write(io, fc)
            @test String(take!(io)) == s
            path = tempname()
            GeoJSON.write(path, fc)
            @test Base.read(path, String) == s
            GeoJSON.write(path, fc; pretty=2)
            @test Base.read(path, String) == GeoJSON.write(fc; pretty=2)
            rm(path)
        end
    end

    @testset "sources" begin
        fc = GeoJSON.read(docs.extras_everywhere)
        path = tempname()
        Base.write(path, docs.extras_everywhere)

        @test GeoJSON.read("  \n\t" * docs.extras_everywhere) == fc
        @test GeoJSON.read(path) == fc
        @test open(GeoJSON.read, path) == fc
        @test GeoJSON.read(Vector{UInt8}(docs.extras_everywhere)) == fc
        @test GeoJSON.read(codeunits(docs.extras_everywhere)) == fc
        @test GeoJSON.read(path; mmap=true) == fc
        @test GeoJSON.read(GeoFormatTypes.GeoJSON(docs.extras_everywhere)) == fc
        @test GeoJSON.read(path, FC2) == fc

        dict = Dict("type" => "FeatureCollection",
                    "features" => [Dict("type" => "Feature",
                                        "geometry" => Dict("type" => "Point", "coordinates" => [1, 2]),
                                        "properties" => Dict("a" => 1))])
        @test GeoJSON.read(GeoFormatTypes.GeoJSON(dict)) ==
              GeoJSON.read("""{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[1,2]},"properties":{"a":1}}]}""")
        rm(path)
    end

    @testset "Properties" begin
        f = GeoJSON.read(docs.property_types)
        p = GeoJSON.properties(f)

        @test p isa AbstractDict{String,Any}
        @test p["i"] == 1
        @test p[:i] == 1
        @test f.i == 1
        @test haskey(p, "i")
        @test haskey(p, :i)
        @test !haskey(p, "zz")
        @test get(p, "zz", 42) == 42
        @test get(p, :zz, 42) == 42
        @test get(() -> 7, p, "zz") == 7
        @test get(p, "i", 42) == 1
        @test_throws KeyError p["zz"]

        # Document order, on every view.
        @test collect(keys(p)) == ["i", "f", "s", "b", "n", "o", "a"]
        @test first(collect(p)) === Pair{String,Any}("i", Int64(1))
        @test length(p) == 7
        @test collect(values(p))[1:4] == Any[1, 1.5, "x", true]

        # `getproperty` maps both an absent key and a stored null to `missing`.
        @test f.n === missing
        @test f.zz === missing
        @test propertynames(f) == (:geometry, :i, :f, :s, :b, :n, :o, :a)
        @test GeoJSON.geometry(f) === nothing
        @test f.geometry === missing

        p["c"] = 3
        @test p["c"] == 3
        @test collect(keys(p)) == ["i", "f", "s", "b", "n", "o", "a", "c"]
        @test f.c == 3                   # mutation lands in the feature, not a copy
        p[:c] = 4
        @test p["c"] == 4
        @test length(p) == 8
        delete!(p, :i)
        @test !haskey(p, "i")
        @test collect(keys(p)) == ["f", "s", "b", "n", "o", "a", "c"]
        delete!(p, "nosuchkey")
        @test length(p) == 7

        # Indexing a feature reaches its properties container.
        @test f["f"] == 1.5
        @test f[:f] == 1.5
        @test haskey(f, "f") && haskey(f, :f) && !haskey(f, "zz")
        @test get(f, "zz", 42) == 42
        @test get(f, :f, 42) == 1.5
        @test_throws KeyError f["zz"]
    end

    @testset "inference" begin
        bytes = Vector{UInt8}(docs.bare_feature)
        fcbytes = Vector{UInt8}("""{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[1,2]},"properties":{"a":1}}]}""")
        FCP = GeoJSON.FeatureCollection{2,Float64,P2,Nothing}
        @test (@inferred GeoJSON.read(fcbytes, FCP)) isa FCP
        @test only(Base.return_types(GeoJSON.read, Tuple{Vector{UInt8},Type{FCP}})) == FCP
        @test (@inferred GeoJSON.read(bytes, GeoJSON.Feature{2,Float64,P2,Props})) isa
              GeoJSON.Feature{2,Float64,P2,Props}

        # The untyped read is wider than the plan's three FeatureCollections: the root kind, the
        # `lazy` keyword and D are all runtime values, so every member is a UnionAll.
        rt = Base.return_types(GeoJSON.read, Tuple{Vector{UInt8}})
        @test length(rt) == 1
        members = Base.uniontypes(only(rt))
        @test length(members) == 10
        @test Set(Base.unwrap_unionall(m).name.name for m in members) ==
              Set((:Point, :LineString, :Polygon, :MultiPoint, :MultiLineString, :MultiPolygon,
                   :GeometryCollection, :Feature, :FeatureCollection, :LazyFeatureCollection))
        @test !any(isconcretetype, members)
        @test all(m -> m <: GeoJSON.GeoJSONT{D,Float64} where {D}, members)
        @test only(Base.return_types(GeoJSON.read, Tuple{String})) == only(rt)
    end
end
