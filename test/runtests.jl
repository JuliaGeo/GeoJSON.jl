using GeoJSON, GeoInterface, FactCheck

include(joinpath(dirname(@__FILE__),"geojson_samples.jl"))

feature = GeoJSON.parse(a)
@fact typeof(feature) --> GeoInterface.Feature{String}
@fact GeoInterface.geometry(feature) --> nothing
@fact GeoInterface.properties(feature) --> feature.properties
@fact typeof(feature.properties) --> Dict{String,Any}
@fact length(feature.properties) --> 2
@fact GeoInterface.bbox(feature) --> nothing
@fact GeoInterface.crs(feature) --> feature.properties["crs"]
@fact GeoInterface.crs(feature)["properties"]["href"] --> "data.crs"
@fact GeoInterface.crs(feature)["properties"]["type"] --> "ogcwkt"
@fact GeoInterface.crs(feature)["type"] --> "link"
@fact "Ã" in keys(GeoInterface.properties(feature)) --> true
@fact GeoInterface.properties(feature)["Ã"] --> "Ã"
dict = geojson(feature)
@fact dict["geometry"] --> nothing
@fact dict["type"] --> "Feature"
@fact dict["crs"]["properties"]["href"] --> "data.crs"
@fact dict["crs"]["properties"]["type"] --> "ogcwkt"
@fact dict["crs"]["type"] --> "link"

feature = GeoJSON.parse(b)
@fact typeof(feature) --> GeoInterface.Feature{String}
@fact typeof(GeoInterface.geometry(feature)) --> GeoInterface.MultiPoint
coords = GeoInterface.coordinates(GeoInterface.geometry(feature))
@fact string(GeoInterface.coordinates(GeoInterface.geometry(feature))) --> "[[-155.52,19.61],[-156.22,20.74],[-157.97,21.46]]"
@fact GeoInterface.properties(feature) --> feature.properties
@fact typeof(feature.properties) --> Dict{String,Any}
@fact length(feature.properties) --> 2
@fact "Ã" in keys(feature.properties) --> false
@fact feature.properties["type"] --> "é"
@fact feature.properties["featureid"] --> 1

feature = GeoJSON.parse(c)
@fact typeof(feature) --> GeoInterface.Feature{String}
@fact GeoInterface.geometry(feature) --> nothing
@fact GeoInterface.properties(feature) --> feature.properties
@fact typeof(feature.properties) --> Dict{String,Any}
@fact length(feature.properties) --> 3
@fact feature.properties["type"] --> "meow"
@fact GeoInterface.crs(feature) --> feature.properties["crs"]
@fact typeof(GeoInterface.crs(feature)) --> Dict{String,Any}
@fact GeoInterface.crs(feature)["type"] --> "name"
@fact GeoInterface.crs(feature)["properties"]["name"] --> "urn:ogc:def:crs:EPSG::3785"
dict = geojson(feature)
@fact dict["geometry"] --> nothing
@fact dict["id"] --> 1
@fact dict["type"] --> "Feature"
@fact dict["crs"]["properties"]["name"] --> "urn:ogc:def:crs:EPSG::3785"
@fact dict["crs"]["type"] --> "name"

feature = GeoJSON.parse(d)
@fact typeof(feature) --> GeoInterface.Feature{String}
@fact typeof(GeoInterface.geometry(feature)) --> GeoInterface.MultiLineString
@fact GeoInterface.geometry(feature) --> feature.geometry
@fact string(feature.geometry.coordinates) --> "[[[3.75,9.25],[-130.95,1.52]],[[23.15,-34.25],[-1.35,-4.65],[3.45,77.95]]]"
@fact GeoInterface.properties(feature) --> feature.properties
@fact typeof(feature.properties) --> Dict{String,Any}
@fact length(feature.properties) --> 3
@fact feature.properties["title"] --> "Dict 1"
@fact GeoInterface.bbox(feature) --> feature.properties["bbox"]
@fact GeoInterface.bbox(feature) --> [-180.0, -90.0, 180.0, 90.0]
@fact GeoInterface.properties(feature)["featureid"] --> "1"

feature = GeoJSON.parse(e)
@fact typeof(feature) --> GeoInterface.Feature{String}
@fact typeof(GeoInterface.geometry(feature)) --> GeoInterface.Point
@fact GeoInterface.geometry(feature) --> feature.geometry
@fact feature.geometry.coordinates --> [53, -4]
@fact GeoInterface.properties(feature) --> feature.properties
@fact typeof(feature.properties) --> Dict{String,Any}
@fact length(feature.properties) --> 4
@fact feature.properties["title"] --> "Feature 1"
@fact feature.properties["summary"] --> "The first feature"
@fact feature.properties["link"] --> "http://example.org/features/1"
dict = geojson(feature)
@fact dict["geometry"]["coordinates"] --> roughly([53.0,-4.0])
@fact dict["geometry"]["type"] --> "Point"
@fact dict["id"] --> "1"
@fact dict["type"] --> "Feature"

feature = GeoJSON.parse(f)
@fact typeof(feature) --> GeoInterface.Feature{String}
@fact GeoInterface.geometry(feature) --> nothing
@fact GeoInterface.properties(feature) --> feature.properties
@fact typeof(feature.properties) --> Dict{String,Any}
@fact length(feature.properties) --> 2
@fact feature.properties["foo"] --> "bar"
@fact feature.properties["featureid"] --> 12

featurecollection = GeoJSON.parse(g)
@fact sprint(print,JSON.json(featurecollection)) -->
    "{\"features\":[{\"geometry\":{\"coordinates\":[[[[-117.913883,33.96657],[-117.907767,33.967747],[-117.912919,33.96445],[-117.913883,33.96657]]]],\"type\":\"MultiPolygon\"},\"properties\":{\"addr2\":\"Rowland Heights\",\"cartodb_id\":46,\"addr1\":\"18150 E. Pathfinder Rd.\",\"park\":\"Pathfinder Park\"},\"type\":\"Feature\"}],\"bbox\":[100.0,0.0,105.0,1.0],\"type\":\"FeatureCollection\",\"crs\":{\"properties\":{\"name\":\"urn:ogc:def:crs:EPSG::3785\"},\"type\":\"name\"}}"
@fact featurecollection.bbox --> roughly([100,0,105,1])
@fact featurecollection.crs --> Dict("properties" => Dict("name" => "urn:ogc:def:crs:EPSG::3785"),
                                     "type" => "name")

feature = GeoJSON.parse(h)
@fact sprint(print,JSON.json(feature)) -->
    "{\"geometry\":{\"coordinates\":[[[3.75,9.25],[-130.95,1.52]],[[23.15,-34.25],[-1.35,-4.65],[3.45,77.95]]],\"type\":\"MultiLineString\"},\"properties\":{\"title\":\"Dict 1\"},\"bbox\":[-180.0,-90.0,180.0,90.0],\"type\":\"Feature\"}"

testobj = GeoJSON.parse(multipolygon)
@fact typeof(testobj) --> GeoInterface.FeatureCollection{GeoInterface.Feature}
features = GeoInterface.features(testobj)
@fact length(features) --> 1
feature = features[1]
@fact GeoInterface.bbox(feature) --> feature.properties["bbox"]
@fact GeoInterface.bbox(feature) --> [100.0, 0.0, 105.0, 1.0]
@fact typeof(GeoInterface.geometry(feature)) --> GeoInterface.MultiPolygon
@fact GeoInterface.geometry(feature) --> feature.geometry
@fact size(feature.geometry.coordinates) --> (1,)
@fact length(feature.geometry.coordinates) --> 1
@fact length(feature.geometry.coordinates[1]) --> 1
@fact length(feature.geometry.coordinates[1][1]) --> 4
@fact feature.geometry.coordinates[1][1][1] -->
    roughly([-117.914, 33.9666], 1e-3)
@fact feature.geometry.coordinates[1][1][2] -->
    roughly([-117.908,33.9677], 1e-3)
@fact feature.geometry.coordinates[1][1][3] -->
    roughly([-117.913,33.9644], 1e-3)
@fact feature.geometry.coordinates[1][1][4] -->
    feature.geometry.coordinates[1][1][4]
@fact feature.properties["addr2"] --> "Rowland Heights"
@fact feature.properties["cartodb_id"] --> 46
@fact feature.properties["addr1"] --> "18150 E. Pathfinder Rd."
@fact feature.properties["park"] --> "Pathfinder Park"

testobj = GeoJSON.parse(realmultipolygon)
@fact typeof(testobj) --> GeoInterface.FeatureCollection{GeoInterface.Feature}
features = GeoInterface.features(testobj)
@fact length(features) --> 1
feature = features[1]
@fact typeof(GeoInterface.geometry(feature)) --> GeoInterface.MultiPolygon
@fact GeoInterface.geometry(feature) --> feature.geometry
@fact size(feature.geometry.coordinates) --> (2,)
@fact string(feature.geometry.coordinates) --> "[[[[102.0,2.0],[103.0,2.0],[103.0,3.0],[102.0,3.0],[102.0,2.0]]],[[[100.0,0.0],[101.0,0.0],[101.0,1.0],[100.0,1.0],[100.0,0.0]],[[100.2,0.2],[100.8,0.2],[100.8,0.8],[100.2,0.8],[100.2,0.2]]]]"
dict = geojson(testobj)
@fact dict["type"] --> "FeatureCollection"
@fact dict["features"][1]["geometry"]["type"] --> "MultiPolygon"
dict = geojson(feature)
@fact dict["type"] --> "Feature"
@fact length(dict["geometry"]["coordinates"]) --> 2

testobj = GeoJSON.parse(polyline)
@fact typeof(testobj) --> GeoInterface.FeatureCollection{GeoInterface.Feature}
features = GeoInterface.features(testobj)
@fact length(features) --> 1
feature = features[1]
@fact typeof(feature.geometry) --> GeoInterface.LineString
@fact feature.properties["InLine_FID"] --> 0
@fact feature.properties["SimLnFLag"] --> 0
@fact string(feature.geometry.coordinates) --> "[[-89.0,43.0],[-88.0,44.0],[-88.0,45.0]]"
dict = geojson(testobj)
@fact dict["type"] --> "FeatureCollection"
@fact dict["features"][1]["geometry"]["type"] --> "LineString"
dict = geojson(feature)
@fact dict["type"] --> "Feature"
@fact dict["id"] --> "a73ws67n775q"
@fact length(dict["geometry"]["coordinates"]) --> 3

testobj = GeoJSON.parse(point)
@fact typeof(testobj) --> GeoInterface.FeatureCollection{GeoInterface.Feature}
feature = testobj.features[1]
@fact feature.properties["fax"] --> "305-571-8347"
@fact feature.properties["phone"] --> "305-571-8345"
@fact typeof(feature.geometry) --> GeoInterface.Point
@fact feature.geometry.coordinates --> [-89.0, 44.0]
dict = geojson(testobj)
@fact dict["type"] --> "FeatureCollection"
@fact dict["features"][1]["geometry"]["type"] --> "Point"
dict = geojson(feature)
@fact dict["type"] --> "Feature"
@fact dict["id"] --> "a7vs0i9rnyyx"
@fact length(dict["geometry"]["coordinates"]) --> 2

testobj = GeoJSON.parse(pointnull)
@fact typeof(testobj) --> GeoInterface.FeatureCollection{GeoInterface.Feature}
feature = testobj.features[1]
@fact feature.properties["featureid"] --> "a7vs0i9rnyyx"
@fact feature.properties["fax"] --> "305-571-8347"
@fact feature.properties["phone"] --> "305-571-8345"
@fact typeof(feature.geometry) --> Nothing
dict = geojson(testobj)
@fact dict["type"] --> "FeatureCollection"
@fact dict["features"][1]["geometry"] --> nothing
dict = geojson(feature)
@fact dict["geometry"] --> nothing
@fact dict["id"] --> "a7vs0i9rnyyx"
@fact dict["type"] --> "Feature"

testobj = GeoJSON.parse(poly)
@fact typeof(testobj) --> GeoInterface.FeatureCollection{GeoInterface.Feature}
feature = testobj.features[1]
@fact feature.properties["featureid"] --> "a7ws7wldxold"
@fact feature.properties["DIST_NUM"] --> 7.0
@fact feature.properties["PHONE"] --> "686-3070"
@fact feature.properties["AREA_SQMI"] --> 12.41643
@fact feature.properties["LOCATION"]  --> "Bustleton Ave. & Bowler St"
@fact feature.properties["DIV_CODE"]  --> "NEPD"
@fact feature.properties["DIST_NUMC"] --> "07"
@fact typeof(feature.geometry) --> GeoInterface.Polygon
@fact length(feature.geometry.coordinates) --> 1
@fact length(feature.geometry.coordinates[1]) --> 5
@fact feature.geometry.coordinates[1][1] -->
    feature.geometry.coordinates[1][end]
dict = geojson(testobj)
@fact dict["type"] --> "FeatureCollection"
@fact dict["features"][1] --> geojson(feature)
dict = geojson(feature)
@fact dict["geometry"]["type"] --> "Polygon"
@fact dict["id"] --> "a7ws7wldxold"
@fact dict["type"] --> "Feature"

testobj = GeoJSON.parse(polyhole)
@fact typeof(testobj) --> GeoInterface.FeatureCollection{GeoInterface.Feature}
feature = testobj.features[1]
@fact feature.properties["featureid"] --> "a7ws7wldxold"
@fact feature.properties["DIST_NUM"] --> 7.0
@fact feature.properties["PHONE"] --> "686-3070"
@fact feature.properties["AREA_SQMI"] --> 12.41643
@fact feature.properties["LOCATION"]  --> "Bustleton Ave. & Bowler St"
@fact feature.properties["DIV_CODE"]  --> "NEPD"
@fact feature.properties["DIST_NUMC"] --> "07"
@fact typeof(feature.geometry) --> GeoInterface.Polygon
@fact length(feature.geometry.coordinates) --> 2
@fact length(feature.geometry.coordinates[1]) --> 5
@fact feature.geometry.coordinates[1][1] -->
    feature.geometry.coordinates[1][end]
@fact length(feature.geometry.coordinates[2]) --> 5
@fact feature.geometry.coordinates[2][1] -->
    feature.geometry.coordinates[2][end]
dict = geojson(testobj)
@fact dict["type"] --> "FeatureCollection"
@fact dict["features"][1] --> geojson(feature)
dict = geojson(feature)
@fact dict["geometry"]["type"] --> "Polygon"
@fact dict["id"] --> "a7ws7wldxold"
@fact dict["type"] --> "Feature"

testobj = GeoJSON.parse(collection)
@fact typeof(testobj) --> GeoInterface.FeatureCollection{GeoInterface.Feature}
feature = testobj.features[1]
@fact feature.properties["STATE_ABBR"] --> "ZZ"
@fact feature.properties["STATE_NAME"] --> "Top"
@fact typeof(feature.geometry) --> GeoInterface.GeometryCollection
@fact length(feature.geometry.geometries) --> 3
@fact typeof(feature.geometry.geometries[1]) --> GeoInterface.Polygon
@fact typeof(feature.geometry.geometries[2]) --> GeoInterface.Polygon
@fact typeof(feature.geometry.geometries[3]) --> GeoInterface.Point
coords = feature.geometry.geometries[1].coordinates
@fact length(coords) --> 1
@fact length(coords[1]) --> 5
@fact coords[1][1] --> coords[1][end]
coords = feature.geometry.geometries[2].coordinates
@fact length(coords) --> 1
@fact length(coords[1]) --> 5
@fact coords[1][1] --> coords[1][end]
@fact feature.geometry.geometries[3].coordinates -->
    roughly([-94.0,46.0])
dict = geojson(testobj)
@fact dict["type"] --> "FeatureCollection"
@fact dict["features"][1] --> geojson(feature)
dict = geojson(feature)
@fact dict["geometry"]["type"] --> "GeometryCollection"
@fact length(dict["geometry"]["geometries"]) --> 3
@fact dict["geometry"]["geometries"][1]["type"] --> "Polygon"
@fact dict["geometry"]["geometries"][2]["type"] --> "Polygon"
@fact dict["geometry"]["geometries"][3]["type"] --> "Point"
@fact dict["id"] --> "a7xlmuwyjioy"
@fact dict["type"] --> "Feature"

buildings = GeoJSON.parse(osm_buildings)
@fact typeof(buildings) --> GeoInterface.FeatureCollection{GeoInterface.Feature}
@fact length(buildings.features) --> 4
@fact map(typeof,buildings.features) --> fill(GeoInterface.Feature{String},4)

feature = buildings.features[1]
@fact typeof(feature) --> GeoInterface.Feature{String}
@fact typeof(GeoInterface.geometry(feature)) --> GeoInterface.Polygon
@fact GeoInterface.properties(feature) --> feature.properties
@fact typeof(feature.properties) --> Dict{String,Any}
@fact length(feature.properties) --> 2
@fact feature.properties["height"] --> 150
@fact feature.properties["color"] --> "rgb(255,200,150)"

building_dict = geojson(buildings)
@fact typeof(building_dict) --> Dict{String,Any}
@fact string(GeoJSON.parse(osm_buildings)) --> string(buildings)
# @fact string(GeoJSON.parse(osm_buildings)) --> string(geojson(building_dict))

@fact GeoJSON.json(buildings) -->
"""{\"features\":[{\"geometry\":{\"coordinates\":[[[13.42634,52.49533],[13.4266,52.49524],[13.42619,52.49483],[13.42583,52.49495],[13.4259,52.49501],[13.42611,52.49494],[13.4264,52.49525],[13.4263,52.49529],[13.42634,52.49533]]],\"type\":\"Polygon\"},\"properties\":{\"height\":150,\"color\":\"rgb(255,200,150)\"},\"type\":\"Feature\"},{\"geometry\":{\"coordinates\":[[[13.42706,52.49535],[13.42745,52.4952],[13.42745,52.4952],[13.42741,52.49516],[13.42717,52.49525],[13.42692,52.49501],[13.42714,52.49494],[13.42686,52.49466],[13.4265,52.49478],[13.42657,52.49486],[13.42678,52.4948],[13.42694,52.49496],[13.42675,52.49503],[13.42706,52.49535]]],\"type\":\"Polygon\"},\"properties\":{\"height\":130,\"color\":\"rgb(180,240,180)\"},\"type\":\"Feature\"},{\"geometry\":{\"coordinates\":[[[[13.42746,52.4944],[13.42794,52.49494],[13.42799,52.49492],[13.42755,52.49442],[13.42798,52.49428],[13.42846,52.4948],[13.42851,52.49478],[13.428,52.49422],[13.42746,52.4944]]],[[[13.42803,52.49497],[13.428,52.49493],[13.42844,52.49479],[13.42847,52.49483],[13.42803,52.49497]]]],\"type\":\"MultiPolygon\"},\"properties\":{\"height\":120,\"color\":\"rgb(200,200,250)\"},\"type\":\"Feature\"},{\"geometry\":{\"coordinates\":[[[13.42857,52.4948],[13.42918,52.49465],[13.42867,52.49412],[13.4285,52.49419],[13.42896,52.49465],[13.42882,52.49469],[13.42837,52.49423],[13.42821,52.49428],[13.42863,52.49473],[13.42853,52.49476],[13.42857,52.4948]]],\"type\":\"Polygon\"},\"properties\":{\"height\":140,\"color\":\"rgb(150,180,210)\"},\"type\":\"Feature\"}],\"type\":\"FeatureCollection\"}"""

@fact GeoJSON.json(buildings) --> JSON.json(JSON.parse(osm_buildings))
@fact building_dict --> JSON.parse(osm_buildings)

obj = GeoJSON.parsefile(joinpath(dirname(@__FILE__),"tech_square.geojson"))
@fact typeof(obj) --> GeoInterface.FeatureCollection{GeoInterface.Feature}
@fact length(GeoInterface.features(obj)) --> 171
feature = obj.features[1]
@fact feature.properties["featureid"] --> "relation/2119819"
@fact typeof(feature.geometry) --> GeoInterface.Polygon
@fact length(feature.geometry.coordinates) --> 1
@fact length(feature.geometry.coordinates[1]) --> 38
@fact feature.geometry.coordinates[1][1] --> feature.geometry.coordinates[1][end]
