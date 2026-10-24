@testset "Geometry kinds share feature types and preserve nested collections" begin
    point = """{"type":"Point","coordinates":[1,2]}"""
    kinds = [point,
        """{"type":"MultiPoint","coordinates":[[1,2]]}""",
        """{"type":"LineString","coordinates":[[1,2],[3,4]]}""",
        """{"type":"MultiLineString","coordinates":[[[1,2],[3,4]]]}""",
        """{"type":"Polygon","coordinates":[[[0,0],[1,0],[0,0]]]}""",
        """{"type":"MultiPolygon","coordinates":[[[[0,0],[1,0],[0,0]]]]}""",
        """{"type":"GeometryCollection","geometries":[$point,{"type":"GeometryCollection","geometries":[]}]}"""]
    for (D, T) in ((2, Float32), (2, Float64), (3, Float64))
        texts = D == 3 ? replace.(kinds, "[1,2]" => "[1,2,3]", "[3,4]" => "[3,4,5]", "[0,0]" => "[0,0,0]", "[1,0]" => "[1,0,0]") : kinds
        gs = GeoJSON.read.(texts; ndim=D, numbertype=T)
        @test all(zip(texts[1:6], gs[1:6])) do (text, g)
            typeof(GeoJSON.read(text; ndim=D, numbertype=T, geometrytype=typeof(g))) === typeof(g)
        end
        @test Set(typeof.(gs)) == Set(Base.uniontypes(GeoJSON.Geometry{D,T}))
        fs = [GeoJSON.Feature(geometry=g, properties=nothing) for g in gs]
        @test all(f -> typeof(f) === typeof(first(fs)), fs)
        fc = GeoJSON.FeatureCollection(features=fs)
        @test fieldtype(typeof(first(fs)), :geometry) === Union{Nothing,GeoJSON.Geometry{D,T}}
        gc = GeoJSON.GeometryCollection{D,T}(geometries=gs)
        @test eltype(gc.geometries) === GeoJSON.Geometry{D,T}
        if D == 3
            # One nested 3D roundtrip covers serialization and GeoInterface access.
            @test GeoJSON.features(GeoJSON.read(GeoJSON.write(fc); ndim=D, numbertype=T)) == fs
            @test all(g -> GI.geomtrait(g) isa GI.AbstractGeometryTrait, GI.getgeom(gc))
            @test GI.coordinates(gc) == GeoJSON.coordinates.(gs)
        end
    end
end

@testset "Property schemas accept every geometry kind" begin
    P = NamedTuple{(:name,),Tuple{String}}
    F = GeoJSON.Feature{2,Float64,P}
    point = GeoJSON.Point(coordinates=(1.0,2.0))
    line = GeoJSON.LineString(coordinates=[(1.0,2.0),(3.0,4.0)])
    fs = [F(nothing, nothing, g, (name="one",)) for g in (point, line, nothing)]
    fc = GeoJSON.FeatureCollection{2,Float64,P}(nothing, fs, nothing)
    again = @inferred GeoJSON.read(GeoJSON.write(fc), typeof(fc))
    @test GeoJSON.features(again) == fs
    @test eltype(again) === F
    @test_throws MethodError F(nothing, nothing, GeoJSON.Point(coordinates=(1.0f0,2.0f0)), (name="one",))
end

@testset "Read-time geometry restrictions preserve small-union storage" begin
    point = """{"type":"Point","coordinates":[1,2]}"""
    polygon = """{"type":"Polygon","coordinates":[[[0,0],[1,0],[0,0]]]}"""
    multi = """{"type":"MultiPolygon","coordinates":[[[[0,0],[1,0],[0,0]]]]}"""
    feature(g) = """{"type":"Feature","geometry":$g,"properties":{"name":"one"}}"""
    collection(gs) = """{"type":"FeatureCollection","features":[$(join(feature.(gs), ','))]}"""
    P = NamedTuple{(:name,),Tuple{String}}
    FC = GeoJSON.FeatureCollection{2,Float64,P}
    allowed = Union{GeoJSON.Polygon,GeoJSON.MultiPolygon}
    for reader in (s -> GeoJSON.read(s; geometrytype=allowed, numbertype=Float64),
                   s -> GeoJSON.read(s, FC; geometrytype=allowed))
        fc = reader(collection([polygon, multi, "null"]))
        @test typeof(fc) === typeof(reader(collection([polygon])))
        @test fieldtype(eltype(fc), :geometry) === Union{Nothing,GeoJSON.Geometry{2,Float64}}
        @test GeoJSON.geometry(fc[3]) === nothing
        @test_throws "Point is excluded by geometrytype" reader(collection([polygon, point]))
    end
    @test GeoJSON.read(polygon; geometrytype=GeoJSON.Polygon) isa GeoJSON.Polygon
    @test_throws ArgumentError GeoJSON.read(point; geometrytype=GeoJSON.Polygon)
    @test_throws ArgumentError GeoJSON.read(point, GeoJSON.Point{2,Float64}; geometrytype=allowed)
    nested = """{"type":"GeometryCollection","geometries":[$polygon,{"type":"GeometryCollection","geometries":[$point]}]}"""
    nestedtypes = Union{GeoJSON.GeometryCollection,GeoJSON.Polygon}
    @test_throws "Point is excluded by geometrytype" GeoJSON.read(nested; geometrytype=nestedtypes)
    @test GeoJSON.read(replace(nested, point=>polygon); geometrytype=nestedtypes) isa GeoJSON.GeometryCollection
    @test_logs (:warn, r"trying 3D") GeoJSON.read(replace(point, "[1,2]"=>"[1,2,3]"); geometrytype=GeoJSON.Point)
    @test_logs (:warn, r"trying 3D") @test_throws "LineString is excluded" GeoJSON.read(
        collection([replace(point, "[1,2]"=>"[1,2,3]"), """{"type":"LineString","coordinates":[]}"""]);
        geometrytype=GeoJSON.Point)
    @test GeoJSON.read(GeoFormatTypes.GeoJSON(point); geometrytype=GeoJSON.Point) isa GeoJSON.Point
    @test_throws ArgumentError GeoJSON.read(GeoFormatTypes.GeoJSON(Dict("type"=>"Point", "coordinates"=>[1,2])); geometrytype=allowed)
    for invalid in (Int, Union{GeoJSON.Point,Int}, Union{}, "Polygon")
        @test_throws ArgumentError GeoJSON.read(point; geometrytype=invalid)
    end
    @test_throws "requires lazyfc=false" GeoJSON.read(collection([polygon]); lazyfc=true, geometrytype=allowed)
    fc = @inferred GeoJSON.read(collection([polygon]), FC; geometrytype=allowed)
    @test GeoJSON.geometry(fc[1]) isa GeoJSON.Polygon{2,Float64}
end

include("../benchmark/geometry_workload.jl")
@testset "Obtained geometries feed inferred user and GeoInterface calls" begin
    P = NamedTuple{(:name,),Tuple{String}}
    F = GeoJSON.Feature{2,Float64,P}
    gs = (GeoJSON.Point(coordinates=(1.0,2.0)),
          GeoJSON.LineString(coordinates=[(1.0,2.0),(3.0,4.0)]),
          GeoJSON.Polygon(coordinates=[[(0.0,0.0),(1.0,0.0),(0.0,0.0)]]),
          nothing)
    fs = [F(nothing, nothing, g, (name="one",)) for g in gs]
    fc = GeoJSON.FeatureCollection{2,Float64,P}(nothing, fs, nothing)
    fc = @inferred GeoJSON.read(GeoJSON.write(fc), typeof(fc);
        geometrytype=Union{GeoJSON.Point,GeoJSON.LineString,GeoJSON.Polygon})
    for (f, expected) in zip(fc, (1.0, 2.0, 1.0, 0.0))
        @test (@inferred feature_score(f)) === expected
    end
    @test (@inferred collection_score(fc)) === 4.0
end
