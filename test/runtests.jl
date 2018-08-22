using GeoJSON, GeoInterface
using Test

include(joinpath(@__DIR__, "geojson_samples.jl"))

@testset "GeoJSON" begin
@testset "A: CRS link" begin
    feature = GeoJSON.parse(a)
    @test feature isa GeoInterface.Feature
    @test GeoInterface.geometry(feature) == nothing
    @test GeoInterface.properties(feature) == feature.properties
    @test feature.properties isa Dict{String,Any}
    @test length(feature.properties) == 2
    @test GeoInterface.bbox(feature) == nothing
    @test GeoInterface.crs(feature) == feature.properties["crs"]
    @test GeoInterface.crs(feature)["properties"]["href"] == "data.crs"
    @test GeoInterface.crs(feature)["properties"]["type"] == "ogcwkt"
    @test GeoInterface.crs(feature)["type"] == "link"
    @test "Ã" in keys(GeoInterface.properties(feature))
    @test GeoInterface.properties(feature)["Ã"] == "Ã"
    dict = geo2dict(feature)
    @test dict["geometry"] == nothing
    @test dict["type"] == "Feature"
    @test dict["crs"]["properties"]["href"] == "data.crs"
    @test dict["crs"]["properties"]["type"] == "ogcwkt"
    @test dict["crs"]["type"] == "link"
end

@testset "B: Multipoint" begin
    feature = GeoJSON.parse(b)
    @test feature isa GeoInterface.Feature
    @test GeoInterface.geometry(feature) isa GeoInterface.MultiPoint
    coords = GeoInterface.coordinates(GeoInterface.geometry(feature))
    @test GeoInterface.coordinates(GeoInterface.geometry(feature)) == [[-155.52,19.61],[-156.22,20.74],[-157.97,21.46]]
    @test GeoInterface.properties(feature) == feature.properties
    @test feature.properties isa Dict{String,Any}
    @test length(feature.properties) == 2
    @test !("Ã" in keys(feature.properties))
    @test feature.properties["type"] == "é"
    @test feature.properties["featureid"] == 1
end

@testset "C: EPSG" begin
    feature = GeoJSON.parse(c)
    @test feature isa GeoInterface.Feature
    @test GeoInterface.geometry(feature) == nothing
    @test GeoInterface.properties(feature) == feature.properties
    @test feature.properties isa Dict{String,Any}
    @test length(feature.properties) == 3
    @test feature.properties["type"] == "meow"
    @test GeoInterface.crs(feature) == feature.properties["crs"]
    @test GeoInterface.crs(feature) isa Dict{String,Any}
    @test GeoInterface.crs(feature)["type"] == "name"
    @test GeoInterface.crs(feature)["properties"]["name"] == "urn:ogc:def:crs:EPSG::3785"
    dict = geo2dict(feature)
    @test dict["geometry"] == nothing
    @test dict["id"] == 1
    @test dict["type"] == "Feature"
    @test dict["crs"]["properties"]["name"] == "urn:ogc:def:crs:EPSG::3785"
    @test dict["crs"]["type"] == "name"
end

@testset "D: MultiLineString" begin
    feature = GeoJSON.parse(d)
    @test feature isa GeoInterface.Feature
    @test GeoInterface.geometry(feature) isa GeoInterface.MultiLineString
    @test GeoInterface.geometry(feature) == feature.geometry
    @test feature.geometry.coordinates == [[[3.75,9.25],[-130.95,1.52]],[[23.15,-34.25],[-1.35,-4.65],[3.45,77.95]]]
    @test GeoInterface.properties(feature) == feature.properties
    @test feature.properties isa Dict{String,Any}
    @test length(feature.properties) == 3
    @test feature.properties["title"] == "Dict 1"
    @test GeoInterface.bbox(feature) == feature.properties["bbox"]
    @test GeoInterface.bbox(feature) == [-180.0, -90.0, 180.0, 90.0]
    @test GeoInterface.properties(feature)["featureid"] == "1"
end

@testset "E: HTTP Links" begin
    feature = GeoJSON.parse(e)
    @test feature isa GeoInterface.Feature
    @test GeoInterface.geometry(feature) isa GeoInterface.Point
    @test GeoInterface.geometry(feature) == feature.geometry
    @test feature.geometry.coordinates == [53, -4]
    @test GeoInterface.properties(feature) == feature.properties
    @test feature.properties isa Dict{String,Any}
    @test length(feature.properties) == 4
    @test feature.properties["title"] == "Feature 1"
    @test feature.properties["summary"] == "The first feature"
    @test feature.properties["link"] == "http://example.org/features/1"
    dict = geo2dict(feature)
    @test dict["geometry"]["coordinates"] ≈ [53.0,-4.0]
    @test dict["geometry"]["type"] == "Point"
    @test dict["id"] == "1"
    @test dict["type"] == "Feature"
end

@testset "F: Null geometry" begin
    feature = GeoJSON.parse(f)
    @test feature isa GeoInterface.Feature
    @test GeoInterface.geometry(feature) == nothing
    @test GeoInterface.properties(feature) == feature.properties
    @test feature.properties isa Dict{String,Any}
    @test length(feature.properties) == 2
    @test feature.properties["foo"] == "bar"
    @test feature.properties["featureid"] == 12
end

@testset "G: MultiPolygon" begin
    featurecollection = GeoJSON.parse(g)
    # printing to GeoJSON not yet implemented
    # @test sprint(print,JSON.json(featurecollection)) ==
    #     "{\"features\":[{\"geometry\":{\"coordinates\":[[[[-117.913883,33.96657],[-117.907767,33.967747],[-117.912919,33.96445],[-117.913883,33.96657]]]],\"type\":\"MultiPolygon\"},\"properties\":{\"addr2\":\"Rowland Heights\",\"cartodb_id\":46,\"addr1\":\"18150 E. Pathfinder Rd.\",\"park\":\"Pathfinder Park\"},\"type\":\"Feature\"}],\"bbox\":[100.0,0.0,105.0,1.0],\"type\":\"FeatureCollection\",\"crs\":{\"properties\":{\"name\":\"urn:ogc:def:crs:EPSG::3785\"},\"type\":\"name\"}}"
    @test featurecollection.bbox ≈ [100,0,105,1]
    @test featurecollection.crs == Dict("properties" => Dict("name" => "urn:ogc:def:crs:EPSG::3785"),
                                         "type" => "name")
end

@testset "H: Print" begin
    feature = GeoJSON.parse(h)
    # printing to GeoJSON not yet implemented
    # @test sprint(print,JSON.json(feature)) ==
    #     "{\"geometry\":{\"coordinates\":[[[3.75,9.25],[-130.95,1.52]],[[23.15,-34.25],[-1.35,-4.65],[3.45,77.95]]],\"type\":\"MultiLineString\"},\"properties\":{\"title\":\"Dict 1\"},\"bbox\":[-180.0,-90.0,180.0,90.0],\"type\":\"Feature\"}"
end

@testset "Multipolygon" begin
    testobj = GeoJSON.parse(multipolygon)
    @test testobj isa GeoInterface.FeatureCollection{GeoInterface.Feature}
    features = GeoInterface.features(testobj)
    @test length(features) == 1
    feature = features[1]
    @test GeoInterface.bbox(feature) == feature.properties["bbox"]
    @test GeoInterface.bbox(feature) == [100.0, 0.0, 105.0, 1.0]
    @test GeoInterface.geometry(feature) isa GeoInterface.MultiPolygon
    @test GeoInterface.geometry(feature) == feature.geometry
    @test size(feature.geometry.coordinates) == (1,)
    @test length(feature.geometry.coordinates) == 1
    @test length(feature.geometry.coordinates[1]) == 1
    @test length(feature.geometry.coordinates[1][1]) == 4
    @test feature.geometry.coordinates[1][1][1] ≈ [-117.914, 33.9666] atol=1e-3
    @test feature.geometry.coordinates[1][1][2] ≈ [-117.908,33.9677] atol=1e-3
    @test feature.geometry.coordinates[1][1][3] ≈ [-117.913,33.9644] atol=1e-3
    @test feature.geometry.coordinates[1][1][4] ==
        feature.geometry.coordinates[1][1][4]
    @test feature.properties["addr2"] == "Rowland Heights"
    @test feature.properties["cartodb_id"] == 46
    @test feature.properties["addr1"] == "18150 E. Pathfinder Rd."
    @test feature.properties["park"] == "Pathfinder Park"
end

@testset "Realmultipolygon" begin
    testobj = GeoJSON.parse(realmultipolygon)
    @test testobj isa GeoInterface.FeatureCollection{GeoInterface.Feature}
    features = GeoInterface.features(testobj)
    @test length(features) == 1
    feature = features[1]
    @test GeoInterface.geometry(feature) isa GeoInterface.MultiPolygon
    @test GeoInterface.geometry(feature) == feature.geometry
    @test size(feature.geometry.coordinates) == (2,)
    @test feature.geometry.coordinates == [[[[102.0,2.0],[103.0,2.0],[103.0,3.0],[102.0,3.0],[102.0,2.0]]],[[[100.0,0.0],[101.0,0.0],[101.0,1.0],[100.0,1.0],[100.0,0.0]],[[100.2,0.2],[100.8,0.2],[100.8,0.8],[100.2,0.8],[100.2,0.2]]]]
    dict = geo2dict(testobj)
    @test dict["type"] == "FeatureCollection"
    @test dict["features"][1]["geometry"]["type"] == "MultiPolygon"
    dict = geo2dict(feature)
    @test dict["type"] == "Feature"
    @test length(dict["geometry"]["coordinates"]) == 2
end

@testset "Polyline" begin
    testobj = GeoJSON.parse(polyline)
    @test testobj isa GeoInterface.FeatureCollection{GeoInterface.Feature}
    features = GeoInterface.features(testobj)
    @test length(features) == 1
    feature = features[1]
    @test feature.geometry isa GeoInterface.LineString
    @test feature.properties["InLine_FID"] == 0
    @test feature.properties["SimLnFLag"] == 0
    @test feature.geometry.coordinates == [[-89.0,43.0],[-88.0,44.0],[-88.0,45.0]]
    dict = geo2dict(testobj)
    @test dict["type"] == "FeatureCollection"
    @test dict["features"][1]["geometry"]["type"] == "LineString"
    dict = geo2dict(feature)
    @test dict["type"] == "Feature"
    @test dict["id"] == "a73ws67n775q"
    @test length(dict["geometry"]["coordinates"]) == 3
end

@testset "Point" begin
    testobj = GeoJSON.parse(point)
    @test testobj isa GeoInterface.FeatureCollection{GeoInterface.Feature}
    feature = testobj.features[1]
    @test feature.properties["fax"] == "305-571-8347"
    @test feature.properties["phone"] == "305-571-8345"
    @test feature.geometry isa GeoInterface.Point
    @test feature.geometry.coordinates == [-89.0, 44.0]
    dict = geo2dict(testobj)
    @test dict["type"] == "FeatureCollection"
    @test dict["features"][1]["geometry"]["type"] == "Point"
    dict = geo2dict(feature)
    @test dict["type"] == "Feature"
    @test dict["id"] == "a7vs0i9rnyyx"
    @test length(dict["geometry"]["coordinates"]) == 2
end

@testset "Pointnull" begin
    testobj = GeoJSON.parse(pointnull)
    @test testobj isa GeoInterface.FeatureCollection{GeoInterface.Feature}
    feature = testobj.features[1]
    @test feature.properties["featureid"] == "a7vs0i9rnyyx"
    @test feature.properties["fax"] == "305-571-8347"
    @test feature.properties["phone"] == "305-571-8345"
    @test feature.geometry isa Nothing
    dict = geo2dict(testobj)
    @test dict["type"] == "FeatureCollection"
    @test dict["features"][1]["geometry"] == nothing
    dict = geo2dict(feature)
    @test dict["geometry"] == nothing
    @test dict["id"] == "a7vs0i9rnyyx"
    @test dict["type"] == "Feature"
end

@testset "Poly" begin
    testobj = GeoJSON.parse(poly)
    @test testobj isa GeoInterface.FeatureCollection{GeoInterface.Feature}
    feature = testobj.features[1]
    @test feature.properties["featureid"] == "a7ws7wldxold"
    @test feature.properties["DIST_NUM"] == 7.0
    @test feature.properties["PHONE"] == "686-3070"
    @test feature.properties["AREA_SQMI"] == 12.41643
    @test feature.properties["LOCATION"]  == "Bustleton Ave. & Bowler St"
    @test feature.properties["DIV_CODE"]  == "NEPD"
    @test feature.properties["DIST_NUMC"] == "07"
    @test feature.geometry isa GeoInterface.Polygon
    @test length(feature.geometry.coordinates) == 1
    @test length(feature.geometry.coordinates[1]) == 5
    @test feature.geometry.coordinates[1][1] ==
        feature.geometry.coordinates[1][end]
    dict = geo2dict(testobj)
    @test dict["type"] == "FeatureCollection"
    @test dict["features"][1] == geo2dict(feature)
    dict = geo2dict(feature)
    @test dict["geometry"]["type"] == "Polygon"
    @test dict["id"] == "a7ws7wldxold"
    @test dict["type"] == "Feature"
end

@testset "Polyhole" begin
    testobj = GeoJSON.parse(polyhole)
    @test testobj isa GeoInterface.FeatureCollection{GeoInterface.Feature}
    feature = testobj.features[1]
    @test feature.properties["featureid"] == "a7ws7wldxold"
    @test feature.properties["DIST_NUM"] == 7.0
    @test feature.properties["PHONE"] == "686-3070"
    @test feature.properties["AREA_SQMI"] == 12.41643
    @test feature.properties["LOCATION"]  == "Bustleton Ave. & Bowler St"
    @test feature.properties["DIV_CODE"]  == "NEPD"
    @test feature.properties["DIST_NUMC"] == "07"
    @test feature.geometry isa GeoInterface.Polygon
    @test length(feature.geometry.coordinates) == 2
    @test length(feature.geometry.coordinates[1]) == 5
    @test feature.geometry.coordinates[1][1] ==
        feature.geometry.coordinates[1][end]
    @test length(feature.geometry.coordinates[2]) == 5
    @test feature.geometry.coordinates[2][1] ==
        feature.geometry.coordinates[2][end]
    dict = geo2dict(testobj)
    @test dict["type"] == "FeatureCollection"
    @test dict["features"][1] == geo2dict(feature)
    dict = geo2dict(feature)
    @test dict["geometry"]["type"] == "Polygon"
    @test dict["id"] == "a7ws7wldxold"
    @test dict["type"] == "Feature"
end

@testset "Collection" begin
    testobj = GeoJSON.parse(collection)
    @test testobj isa GeoInterface.FeatureCollection{GeoInterface.Feature}
    feature = testobj.features[1]
    @test feature.properties["STATE_ABBR"] == "ZZ"
    @test feature.properties["STATE_NAME"] == "Top"
    @test feature.geometry isa GeoInterface.GeometryCollection
    @test length(feature.geometry.geometries) == 3
    @test feature.geometry.geometries[1] isa GeoInterface.Polygon
    @test feature.geometry.geometries[2] isa GeoInterface.Polygon
    @test feature.geometry.geometries[3] isa GeoInterface.Point
    coords = feature.geometry.geometries[1].coordinates
    @test length(coords) == 1
    @test length(coords[1]) == 5
    @test coords[1][1] == coords[1][end]
    coords = feature.geometry.geometries[2].coordinates
    @test length(coords) == 1
    @test length(coords[1]) == 5
    @test coords[1][1] == coords[1][end]
    @test feature.geometry.geometries[3].coordinates ≈ [-94.0,46.0]
    dict = geo2dict(testobj)
    @test dict["type"] == "FeatureCollection"
    @test dict["features"][1] == geo2dict(feature)
    dict = geo2dict(feature)
    @test dict["geometry"]["type"] == "GeometryCollection"
    @test length(dict["geometry"]["geometries"]) == 3
    @test dict["geometry"]["geometries"][1]["type"] == "Polygon"
    @test dict["geometry"]["geometries"][2]["type"] == "Polygon"
    @test dict["geometry"]["geometries"][3]["type"] == "Point"
    @test dict["id"] == "a7xlmuwyjioy"
    @test dict["type"] == "Feature"
end

@testset "OSM buildings" begin
    buildings = GeoJSON.parse(osm_buildings)
    @test buildings isa GeoInterface.FeatureCollection{GeoInterface.Feature}
    @test length(buildings.features) == 4
    @test map(typeof,buildings.features) == fill(GeoInterface.Feature,4)

    feature = buildings.features[1]
    @test feature isa GeoInterface.Feature
    @test GeoInterface.geometry(feature) isa GeoInterface.Polygon
    @test GeoInterface.properties(feature) == feature.properties
    @test feature.properties isa Dict{String,Any}
    @test length(feature.properties) == 2
    @test feature.properties["height"] == 150
    @test feature.properties["color"] == "rgb(255,200,150)"

    building_dict = geo2dict(buildings)
    @test building_dict isa Dict{String,Any}

    # printing to GeoJSON not yet implemented
    # @test GeoJSON.json(buildings) ==
    # """{\"features\":[{\"geometry\":{\"coordinates\":[[[13.42634,52.49533],[13.4266,52.49524],[13.42619,52.49483],[13.42583,52.49495],[13.4259,52.49501],[13.42611,52.49494],[13.4264,52.49525],[13.4263,52.49529],[13.42634,52.49533]]],\"type\":\"Polygon\"},\"properties\":{\"height\":150,\"color\":\"rgb(255,200,150)\"},\"type\":\"Feature\"},{\"geometry\":{\"coordinates\":[[[13.42706,52.49535],[13.42745,52.4952],[13.42745,52.4952],[13.42741,52.49516],[13.42717,52.49525],[13.42692,52.49501],[13.42714,52.49494],[13.42686,52.49466],[13.4265,52.49478],[13.42657,52.49486],[13.42678,52.4948],[13.42694,52.49496],[13.42675,52.49503],[13.42706,52.49535]]],\"type\":\"Polygon\"},\"properties\":{\"height\":130,\"color\":\"rgb(180,240,180)\"},\"type\":\"Feature\"},{\"geometry\":{\"coordinates\":[[[[13.42746,52.4944],[13.42794,52.49494],[13.42799,52.49492],[13.42755,52.49442],[13.42798,52.49428],[13.42846,52.4948],[13.42851,52.49478],[13.428,52.49422],[13.42746,52.4944]]],[[[13.42803,52.49497],[13.428,52.49493],[13.42844,52.49479],[13.42847,52.49483],[13.42803,52.49497]]]],\"type\":\"MultiPolygon\"},\"properties\":{\"height\":120,\"color\":\"rgb(200,200,250)\"},\"type\":\"Feature\"},{\"geometry\":{\"coordinates\":[[[13.42857,52.4948],[13.42918,52.49465],[13.42867,52.49412],[13.4285,52.49419],[13.42896,52.49465],[13.42882,52.49469],[13.42837,52.49423],[13.42821,52.49428],[13.42863,52.49473],[13.42853,52.49476],[13.42857,52.4948]]],\"type\":\"Polygon\"},\"properties\":{\"height\":140,\"color\":\"rgb(150,180,210)\"},\"type\":\"Feature\"}],\"type\":\"FeatureCollection\"}"""
    # @test GeoJSON.json(buildings) == JSON.json(JSON.parse(osm_buildings))
    # @test building_dict == JSON.parse(osm_buildings)
end

@testset "Tech Square: parsefile" begin
    obj = GeoJSON.parsefile(joinpath(@__DIR__,"tech_square.geojson"))
    @test obj isa GeoInterface.FeatureCollection{GeoInterface.Feature}
    @test length(GeoInterface.features(obj)) == 171
    feature = obj.features[1]
    @test feature.properties["featureid"] == "relation/2119819"
    @test feature.geometry isa GeoInterface.Polygon
    @test length(feature.geometry.coordinates) == 1
    @test length(feature.geometry.coordinates[1]) == 38
    @test feature.geometry.coordinates[1][1] == feature.geometry.coordinates[1][end]
end
end # testset "GeoJSON"
