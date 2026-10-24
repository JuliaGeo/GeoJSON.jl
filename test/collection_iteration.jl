@testset "GeometryCollection iteration preserves child values and element type" begin
    gs = [GeoJSON.Point(coordinates=(1.0,2.0)), GeoJSON.GeometryCollection{2,Float64}()]
    gc = GeoJSON.GeometryCollection(geometries=gs)
    children = collect(gc)
    @test children isa Vector{GeoJSON.Geometry{2,Float64}}
    @test children == gs
end

@testset "LazyFeatureCollection iteration has concrete feature elements" begin
    text = """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":null,"properties":null}]}"""
    fc = GeoJSON.read(text; lazyfc=true)
    @test collect(fc) isa Vector{GeoJSON.Feature{2,Float32,GeoJSON.DefaultProperties}}
end
