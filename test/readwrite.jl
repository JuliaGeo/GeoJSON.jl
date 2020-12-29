using GeoJSON
using Test
using StaticArrays

# create all example geometries from https://en.wikipedia.org/wiki/Well-known_text_representation_of_geometry
point = SVector{2, Float64}(30, 20)
linestring = GeoJSON.LineString(SVector{2, Float64}[(30, 10), (10, 30), (40, 40)])
polygon1 = GeoJSON.Polygon(SVector{2, Float64}[(30, 10), (40, 40), (20, 40), (10, 20), (30, 10)])
polygon2 = GeoJSON.Polygon(GeoJSON.LineString(SVector{2, Float64}[(35, 10), (45, 45), (15, 40), (10, 20), (35, 10)]),
    [GeoJSON.LineString(SVector{2, Float64}[(20, 30), (35, 35), (30, 20), (20, 30)])])
multipoint = SVector{2, Float64}[(10, 40), (40, 30), (20, 20), (30, 10)]
multilinestring = [GeoJSON.LineString(SVector{2, Float64}[(10, 10), (20, 20), (10, 40)]),
GeoJSON.LineString(SVector{2, Float64}[(40, 40), (30, 30), (40, 20), (30, 10)])]
multipolygon1 = [
    GeoJSON.Polygon(SVector{2, Float64}[(30, 20), (45, 40), (10, 40), (30, 20)]),
    GeoJSON.Polygon(SVector{2, Float64}[(15, 5), (40, 10), (10, 20), (5, 10), (15, 5)])
]
multipolygon2 = [
    GeoJSON.Polygon(SVector{2, Float64}[(40, 40), (20, 45), (45, 30), (40, 40)]),
    GeoJSON.Polygon(GeoJSON.LineString(SVector{2, Float64}[(20, 35), (10, 30), (10, 10), (30, 5), (45, 20), (20, 35)]),
        [GeoJSON.LineString(SVector{2, Float64}[(30, 20), (20, 15), (20, 25), (30, 20)])])
]
geometrycollection = GeoJSON.GeometryCollection([
    SVector{2, Float64}(40, 10),
    GeoJSON.LineString(SVector{2, Float64}[(10, 10), (20, 20), (10, 40)]),
    GeoJSON.Polygon(SVector{2, Float64}[(40, 40), (20, 45), (45, 30), (40, 40)]),
])

fpt = GeoJSON.Feature(point)
fls = GeoJSON.Feature(linestring)
fcol = GeoJSON.FeatureCollection([fpt,fls])

@testset "Round trip geometries" begin
    @test GeoJSON.read(GeoJSON.write(point)) == point
    @test GeoJSON.read(GeoJSON.write(point)) === point
    @test GeoJSON.read(GeoJSON.write(linestring)) == linestring
    @test GeoJSON.read(GeoJSON.write(polygon1)) == polygon1
    @test GeoJSON.read(GeoJSON.write(polygon2)) == polygon2
    @test GeoJSON.read(GeoJSON.write(multipoint)) == multipoint
    @test GeoJSON.read(GeoJSON.write(multilinestring)) == multilinestring
    @test GeoJSON.read(GeoJSON.write(multipolygon1)) == multipolygon1
    @test GeoJSON.read(GeoJSON.write(multipolygon2)) == multipolygon2
    @test GeoJSON.read(GeoJSON.write(geometrycollection)) == geometrycollection
end

@testset "Features and FeatureCollections" begin
    @test fpt.geometry == point
    @test fls.geometry == linestring
    @test GeoJSON.FeatureCollection(fpt)[1] == fpt
    @test length(fcol) === 2
    @test size(fcol) === (2,)
    @test fcol[1] == fpt
    @test fcol[2] == fls
    @test GeoJSON.read(GeoJSON.write(fpt)) == fpt
    @test GeoJSON.read(GeoJSON.write(fls)) == fls
    @test GeoJSON.read(GeoJSON.write(fcol)) == fcol
end

@testset "BBox" begin
    g = GeoJSON.GeometryCollection(geometrycollection, GeoJSON.BBox{3}(SMatrix{3,2}(1:6)))
    @test g.bbox isa GeoJSON.BBox{3}
    @test JSON3.write(g.bbox.bounds) === "[1.0,2.0,3.0,4.0,5.0,6.0]"
    f = GeoJSON.Feature(fpt, bbox=GeoJSON.BBox{2}(SMatrix{2,2}(1:4)))
    @test f.bbox isa GeoJSON.BBox{2}
    @test JSON3.write(f.bbox.bounds) === "[1.0,2.0,3.0,4.0]"
    fc = GeoJSON.FeatureCollection(fcol, GeoJSON.BBox{2}(SMatrix{2,2}(ones(2,2))))
    @test fc.bbox isa GeoJSON.BBox{2}
    @test JSON3.write(fc.bbox.bounds) === "[1.0,1.0,1.0,1.0]"
end
