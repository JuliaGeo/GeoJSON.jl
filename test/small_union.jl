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
