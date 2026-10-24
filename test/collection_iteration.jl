@testset "GeometryCollection iteration visits children rather than coordinates" begin
    gs = [GeoJSON.Point(coordinates=(1.0,2.0)), GeoJSON.GeometryCollection{2,Float64}()]
    gc = GeoJSON.GeometryCollection(geometries=gs)
    @test collect(gc) == gs
end
