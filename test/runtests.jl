using GeoJSON, FactCheck, Compat

include(joinpath(dirname(@__FILE__),"geojson_samples.jl"))

feature = GeoJSON.parse(a)
@fact typeof(feature) --> Feature
@fact GeoJSON.geometry(feature) --> nothing
@fact GeoJSON.properties(feature) --> feature.properties
@fact typeof(feature.properties) --> Dict{AbstractString,Any}
@fact length(feature.properties) --> 1
@fact GeoJSON.hasbbox(feature) --> false
@fact GeoJSON.hascrs(feature) --> true
@fact GeoJSON.crs(feature) --> feature.crs
@fact feature.crs["properties"]["href"] --> "data.crs"
@fact feature.crs["properties"]["type"] --> "ogcwkt"
@fact feature.crs["type"] --> "link"
@fact "Ã" in keys(feature.properties) --> true
@fact feature.properties["Ã"] --> "Ã"
dict = GeoJSON.geojson2dict(feature)
@fact dict["geometry"] --> nothing
@fact dict["type"] --> "Feature"
@fact dict["crs"]["properties"]["href"] --> "data.crs"
@fact dict["crs"]["properties"]["type"] --> "ogcwkt"
@fact dict["crs"]["type"] --> "link"
@fact dict["properties"]["Ã"] --> "Ã"

feature = GeoJSON.parse(b)
@fact typeof(feature) --> Feature
@fact typeof(GeoJSON.geometry(feature)) --> MultiPoint
coords = GeoJSON.coordinates(GeoJSON.geometry(feature))
@fact string(GeoJSON.coordinates(GeoJSON.geometry(feature))) --> "[[-155.52,19.61],[-156.22,20.74],[-157.97,21.46]]"
@fact GeoJSON.properties(feature) --> feature.properties
@fact typeof(feature.properties) --> Dict{AbstractString,Any}
@fact length(feature.properties) --> 1
@fact GeoJSON.hasbbox(feature) --> false
@fact GeoJSON.hascrs(feature) --> false
@fact "Ã" in keys(feature.properties) --> false
@fact feature.properties["type"] --> "é"
@fact GeoJSON.hasid(feature) --> true
@fact GeoJSON.id(feature) --> feature.id
@fact feature.id --> 1

feature = GeoJSON.parse(c)
@fact typeof(feature) --> Feature
@fact GeoJSON.geometry(feature) --> nothing
@fact GeoJSON.properties(feature) --> feature.properties
@fact typeof(feature.properties) --> Dict{AbstractString,Any}
@fact length(feature.properties) --> 1
@fact feature.properties["type"] --> "meow"
@fact GeoJSON.hasbbox(feature) --> false
@fact GeoJSON.hascrs(feature) --> true
@fact GeoJSON.crs(feature) --> feature.crs
@fact typeof(feature.crs) --> Dict{AbstractString,Any}
@fact feature.crs["type"] --> "name"
@fact feature.crs["properties"]["name"] --> "urn:ogc:def:crs:EPSG::3785"
@fact GeoJSON.hasid(feature) --> true
@fact GeoJSON.id(feature) --> feature.id
@fact feature.id --> 1
dict = GeoJSON.geojson2dict(feature)
@fact dict["geometry"] --> nothing
@fact dict["id"] --> 1
@fact dict["type"] --> "Feature"
@fact dict["crs"]["properties"]["name"] --> "urn:ogc:def:crs:EPSG::3785"
@fact dict["crs"]["type"] --> "name"

feature = GeoJSON.parse(d)
@fact typeof(feature) --> Feature
@fact typeof(GeoJSON.geometry(feature)) --> MultiLineString
@fact GeoJSON.geometry(feature) --> feature.geometry
@fact string(feature.geometry.coordinates) --> "[[[3.75,9.25],[-130.95,1.52]],[[23.15,-34.25],[-1.35,-4.65],[3.45,77.95]]]"
@fact GeoJSON.hasbbox(feature.geometry) --> false
@fact GeoJSON.hascrs(feature.geometry) --> false
@fact GeoJSON.properties(feature) --> feature.properties
@fact typeof(feature.properties) --> Dict{AbstractString,Any}
@fact length(feature.properties) --> 1
@fact feature.properties["title"] --> "Dict 1"
@fact GeoJSON.hasbbox(feature) --> true
@fact GeoJSON.bbox(feature) --> feature.bbox
@fact GeoJSON.bbox(feature) --> roughly([-180.0, -90.0, 180.0, 90.0])
@fact GeoJSON.hascrs(feature) --> false
@fact GeoJSON.hasid(feature) --> true
@fact GeoJSON.id(feature) --> feature.id
@fact feature.id --> "1"

feature = GeoJSON.parse(e)
@fact typeof(feature) --> Feature
@fact typeof(GeoJSON.geometry(feature)) --> Point
@fact GeoJSON.geometry(feature) --> feature.geometry
@fact feature.geometry.coordinates --> [53, -4]
@fact GeoJSON.hasbbox(feature.geometry) --> false
@fact GeoJSON.hascrs(feature.geometry) --> true
@fact GeoJSON.crs(feature.geometry) --> feature.geometry.crs
@fact feature.geometry.crs["properties"]["href"] --> "http://example.com/crs/42"
@fact GeoJSON.crs(feature.geometry)["properties"]["type"] --> "proj4"
@fact feature.geometry.crs["type"] --> "link"
@fact GeoJSON.properties(feature) --> feature.properties
@fact typeof(feature.properties) --> Dict{AbstractString,Any}
@fact length(feature.properties) --> 3
@fact feature.properties["title"] --> "Feature 1"
@fact feature.properties["summary"] --> "The first feature"
@fact feature.properties["link"] --> "http://example.org/features/1"
@fact GeoJSON.hasbbox(feature) --> false
@fact GeoJSON.hascrs(feature) --> false
dict = GeoJSON.geojson2dict(feature)
@fact dict["geometry"]["coordinates"] --> roughly([53.0,-4.0])
@fact dict["geometry"]["type"] --> "Point"
@fact dict["geometry"]["crs"]["properties"]["href"] --> "http://example.com/crs/42"
@fact dict["id"] --> "1"
@fact dict["type"] --> "Feature"

feature = GeoJSON.parse(f)
@fact typeof(feature) --> Feature
@fact GeoJSON.geometry(feature) --> nothing
@fact GeoJSON.properties(feature) --> feature.properties
@fact typeof(feature.properties) --> Dict{AbstractString,Any}
@fact length(feature.properties) --> 1
@fact feature.properties["foo"] --> "bar"
@fact GeoJSON.hasbbox(feature) --> false
@fact GeoJSON.hascrs(feature) --> false

testobj = GeoJSON.parse(multipolygon)
@fact typeof(testobj) --> FeatureCollection
@fact GeoJSON.hasbbox(testobj) --> false
@fact GeoJSON.hascrs(testobj) --> false
features = GeoJSON.features(testobj)
@fact length(features) --> 1
feature = features[1]
@fact GeoJSON.hasid(feature) --> false
@fact GeoJSON.hasbbox(feature) --> true
@fact GeoJSON.bbox(feature) --> feature.bbox
@fact GeoJSON.bbox(feature) --> roughly([100.0, 0.0, 105.0, 1.0])
@fact GeoJSON.hascrs(feature) --> false
@fact typeof(GeoJSON.geometry(feature)) --> MultiPolygon
@fact GeoJSON.geometry(feature) --> feature.geometry
@fact GeoJSON.hasbbox(feature.geometry) --> false
@fact GeoJSON.hascrs(feature.geometry) --> false
@fact size(feature.geometry.coordinates) --> (1,)
@fact length(feature.geometry.coordinates) --> 1
@fact length(feature.geometry.coordinates[1]) --> 1
@fact length(feature.geometry.coordinates[1][1]) --> 4
@fact feature.geometry.coordinates[1][1][1] -->
    roughly([-117.914, 33.9666])
@fact feature.geometry.coordinates[1][1][2] -->
    roughly([-117.908,33.9677])
@fact feature.geometry.coordinates[1][1][3] -->
    roughly([-117.913,33.9644])
@fact feature.geometry.coordinates[1][1][4] -->
    feature.geometry.coordinates[1][1][4]
@fact feature.properties["addr2"] --> "Rowland Heights"
@fact feature.properties["cartodb_id"] --> 46
@fact feature.properties["addr1"] --> "18150 E. Pathfinder Rd."
@fact feature.properties["park"] --> "Pathfinder Park"

testobj = GeoJSON.parse(realmultipolygon)
@fact typeof(testobj) --> FeatureCollection
@fact GeoJSON.hasbbox(testobj) --> false
@fact GeoJSON.hascrs(testobj) --> false
features = GeoJSON.features(testobj)
@fact length(features) --> 1
feature = features[1]
@fact GeoJSON.hasid(feature) --> false
@fact GeoJSON.hasbbox(feature) --> false
@fact GeoJSON.hascrs(feature) --> false
@fact typeof(GeoJSON.geometry(feature)) --> MultiPolygon
@fact GeoJSON.geometry(feature) --> feature.geometry
@fact GeoJSON.hasbbox(feature.geometry) --> false
@fact GeoJSON.hascrs(feature.geometry) --> false
@fact size(feature.geometry.coordinates) --> (2,)
@fact string(feature.geometry.coordinates) --> "[[[[102.0,2.0],[103.0,2.0],[103.0,3.0],[102.0,3.0],[102.0,2.0]]],[[[100.0,0.0],[101.0,0.0],[101.0,1.0],[100.0,1.0],[100.0,0.0]],[[100.2,0.2],[100.8,0.2],[100.8,0.8],[100.2,0.8],[100.2,0.2]]]]"
dict = GeoJSON.geojson2dict(testobj)
@fact dict["type"] --> "FeatureCollection"
@fact dict["features"][1]["geometry"]["type"] --> "MultiPolygon"
dict = GeoJSON.geojson2dict(feature)
@fact dict["type"] --> "Feature"
@fact length(dict["geometry"]["coordinates"]) --> 2

testobj = GeoJSON.parse(polyline)
@fact typeof(testobj) --> FeatureCollection
@fact GeoJSON.hasbbox(testobj) --> false
@fact GeoJSON.hascrs(testobj) --> false
features = GeoJSON.features(testobj)
@fact length(features) --> 1
feature = features[1]
@fact typeof(feature.geometry) --> LineString
@fact feature.properties["InLine_FID"] --> 0
@fact feature.properties["SimLnFLag"] --> 0
@fact string(feature.geometry.coordinates) --> "[[-89.0,43.0],[-88.0,44.0],[-88.0,45.0]]"
dict = GeoJSON.geojson2dict(testobj)
@fact dict["type"] --> "FeatureCollection"
@fact dict["features"][1]["geometry"]["type"] --> "LineString"
dict = GeoJSON.geojson2dict(feature)
@fact dict["type"] --> "Feature"
@fact dict["id"] --> "a73ws67n775q"
@fact length(dict["geometry"]["coordinates"]) --> 3

testobj = GeoJSON.parse(point)
@fact typeof(testobj) --> FeatureCollection
feature = testobj.features[1]
@fact feature.properties["fax"] --> "305-571-8347"
@fact feature.properties["phone"] --> "305-571-8345"
@fact typeof(feature.geometry) --> Point
@fact feature.geometry.coordinates --> [-89.0, 44.0]
dict = GeoJSON.geojson2dict(testobj)
@fact dict["type"] --> "FeatureCollection"
@fact dict["features"][1]["geometry"]["type"] --> "Point"
dict = GeoJSON.geojson2dict(feature)
@fact dict["type"] --> "Feature"
@fact dict["id"] --> "a7vs0i9rnyyx"
@fact length(dict["geometry"]["coordinates"]) --> 2

testobj = GeoJSON.parse(pointnull)
@fact typeof(testobj) --> FeatureCollection
feature = testobj.features[1]
@fact GeoJSON.id(feature) --> feature.id
@fact feature.id --> "a7vs0i9rnyyx"
@fact feature.properties["fax"] --> "305-571-8347"
@fact feature.properties["phone"] --> "305-571-8345"
@fact typeof(feature.geometry) --> Void
dict = GeoJSON.geojson2dict(testobj)
@fact dict["type"] --> "FeatureCollection"
@fact dict["features"][1]["geometry"] --> "null"
dict = GeoJSON.geojson2dict(feature)
@fact dict["geometry"] --> "null"
@fact dict["id"] --> "a7vs0i9rnyyx"
@fact dict["type"] --> "Feature"

testobj = GeoJSON.parse(poly)
@fact typeof(testobj) --> FeatureCollection
feature = testobj.features[1]
@fact GeoJSON.id(feature) --> "a7ws7wldxold"
@fact feature.properties["DIST_NUM"] --> 7.0
@fact feature.properties["PHONE"] --> "686-3070"
@fact feature.properties["AREA_SQMI"] --> 12.41643
@fact feature.properties["LOCATION"]  --> "Bustleton Ave. & Bowler St"
@fact feature.properties["DIV_CODE"]  --> "NEPD"
@fact feature.properties["DIST_NUMC"] --> "07"
@fact typeof(feature.geometry) --> Polygon
@fact length(feature.geometry.coordinates) --> 1
@fact length(feature.geometry.coordinates[1]) --> 5
@fact feature.geometry.coordinates[1][1] -->
    feature.geometry.coordinates[1][end]
dict = GeoJSON.geojson2dict(testobj)
@fact dict["type"] --> "FeatureCollection"
@fact dict["features"][1] --> GeoJSON.geojson2dict(feature)
dict = GeoJSON.geojson2dict(feature)
@fact dict["geometry"]["type"] --> "Polygon"
@fact dict["id"] --> "a7ws7wldxold"
@fact dict["type"] --> "Feature"


testobj = GeoJSON.parse(polyhole)
@fact typeof(testobj) --> FeatureCollection
feature = testobj.features[1]
@fact feature.id --> "a7ws7wldxold"
@fact feature.properties["DIST_NUM"] --> 7.0
@fact feature.properties["PHONE"] --> "686-3070"
@fact feature.properties["AREA_SQMI"] --> 12.41643
@fact feature.properties["LOCATION"]  --> "Bustleton Ave. & Bowler St"
@fact feature.properties["DIV_CODE"]  --> "NEPD"
@fact feature.properties["DIST_NUMC"] --> "07"
@fact typeof(feature.geometry) --> Polygon
@fact length(feature.geometry.coordinates) --> 2
@fact length(feature.geometry.coordinates[1]) --> 5
@fact feature.geometry.coordinates[1][1] -->
    feature.geometry.coordinates[1][end]
@fact length(feature.geometry.coordinates[2]) --> 5
@fact feature.geometry.coordinates[2][1] -->
    feature.geometry.coordinates[2][end]
dict = GeoJSON.geojson2dict(testobj)
@fact dict["type"] --> "FeatureCollection"
@fact dict["features"][1] --> GeoJSON.geojson2dict(feature)
dict = GeoJSON.geojson2dict(feature)
@fact dict["geometry"]["type"] --> "Polygon"
@fact dict["id"] --> "a7ws7wldxold"
@fact dict["type"] --> "Feature"

testobj = GeoJSON.parse(collection)
@fact typeof(testobj) --> FeatureCollection
feature = testobj.features[1]
@fact feature.properties["STATE_ABBR"] --> "ZZ"
@fact feature.properties["STATE_NAME"] --> "Top"
@fact typeof(feature.geometry) --> GeometryCollection
@fact length(feature.geometry.geometries) --> 3
@fact typeof(feature.geometry.geometries[1]) --> Polygon
@fact typeof(feature.geometry.geometries[2]) --> Polygon
@fact typeof(feature.geometry.geometries[3]) --> Point
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
dict = GeoJSON.geojson2dict(testobj)
@fact dict["type"] --> "FeatureCollection"
@fact dict["features"][1] --> GeoJSON.geojson2dict(feature)
dict = GeoJSON.geojson2dict(feature)
@fact dict["geometry"]["type"] --> "GeometryCollection"
@fact length(dict["geometry"]["geometries"]) --> 3
@fact dict["geometry"]["geometries"][1]["type"] --> "Polygon"
@fact dict["geometry"]["geometries"][2]["type"] --> "Polygon"
@fact dict["geometry"]["geometries"][3]["type"] --> "Point"
@fact dict["id"] --> "a7xlmuwyjioy"
@fact dict["type"] --> "Feature"

buildings = GeoJSON.parse(osm_buildings)
@fact typeof(buildings) --> FeatureCollection
@fact GeoJSON.hasbbox(buildings) --> false
@fact GeoJSON.hascrs(buildings) --> false
@fact length(buildings.features) --> 4
@fact map(typeof,buildings.features) --> fill(Feature,4)

feature = buildings.features[1]
@fact typeof(feature) --> Feature
@fact typeof(GeoJSON.geometry(feature)) --> Polygon
@fact GeoJSON.properties(feature) --> feature.properties
@fact typeof(feature.properties) --> Dict{AbstractString,Any}
@fact length(feature.properties) --> 2
@fact feature.properties["height"] --> 150
@fact feature.properties["color"] --> "rgb(255,200,150)"
@fact GeoJSON.hasbbox(feature) --> false
@fact GeoJSON.hascrs(feature) --> false

building_dict = GeoJSON.geojson2dict(buildings)
@fact typeof(building_dict) --> Dict{AbstractString,Any}
@fact string(GeoJSON.parse(osm_buildings)) --> string(GeoJSON.dict2geojson(building_dict))

@fact GeoJSON.geojson(buildings) -->
"""{\"features\":[{\"geometry\":{\"coordinates\":[[[13.42634,52.49533],[13.4266,52.49524],[13.42619,52.49483],[13.42583,52.49495],[13.4259,52.49501],[13.42611,52.49494],[13.4264,52.49525],[13.4263,52.49529],[13.42634,52.49533]]],\"type\":\"Polygon\"},\"properties\":{\"height\":150,\"color\":\"rgb(255,200,150)\"},\"type\":\"Feature\"},{\"geometry\":{\"coordinates\":[[[13.42706,52.49535],[13.42745,52.4952],[13.42745,52.4952],[13.42741,52.49516],[13.42717,52.49525],[13.42692,52.49501],[13.42714,52.49494],[13.42686,52.49466],[13.4265,52.49478],[13.42657,52.49486],[13.42678,52.4948],[13.42694,52.49496],[13.42675,52.49503],[13.42706,52.49535]]],\"type\":\"Polygon\"},\"properties\":{\"height\":130,\"color\":\"rgb(180,240,180)\"},\"type\":\"Feature\"},{\"geometry\":{\"coordinates\":[[[[13.42746,52.4944],[13.42794,52.49494],[13.42799,52.49492],[13.42755,52.49442],[13.42798,52.49428],[13.42846,52.4948],[13.42851,52.49478],[13.428,52.49422],[13.42746,52.4944]]],[[[13.42803,52.49497],[13.428,52.49493],[13.42844,52.49479],[13.42847,52.49483],[13.42803,52.49497]]]],\"type\":\"MultiPolygon\"},\"properties\":{\"height\":120,\"color\":\"rgb(200,200,250)\"},\"type\":\"Feature\"},{\"geometry\":{\"coordinates\":[[[13.42857,52.4948],[13.42918,52.49465],[13.42867,52.49412],[13.4285,52.49419],[13.42896,52.49465],[13.42882,52.49469],[13.42837,52.49423],[13.42821,52.49428],[13.42863,52.49473],[13.42853,52.49476],[13.42857,52.4948]]],\"type\":\"Polygon\"},\"properties\":{\"height\":140,\"color\":\"rgb(150,180,210)\"},\"type\":\"Feature\"}],\"type\":\"FeatureCollection\"}"""

@fact GeoJSON.geojson(buildings) --> JSON.json(JSON.parse(osm_buildings))
@fact building_dict --> JSON.parse(osm_buildings)


obj = GeoJSON.parsefile(joinpath(dirname(@__FILE__),"tech_square.geojson"))
@fact typeof(obj) --> FeatureCollection
@fact length(GeoJSON.features(obj)) --> 171
feature = obj.features[1]
@fact GeoJSON.hasbbox(feature) --> false
@fact GeoJSON.hascrs(feature) --> false
@fact GeoJSON.hasid(feature) --> true
@fact GeoJSON.id(feature) --> feature.id
@fact feature.id --> "relation/2119819"
@fact typeof(feature.geometry) --> Polygon
@fact length(feature.geometry.coordinates) --> 1
@fact length(feature.geometry.coordinates[1]) --> 38
@fact feature.geometry.coordinates[1][1] --> feature.geometry.coordinates[1][end]

# Tests added for PR #19
v = Vector{Float64}[]
push!(v, [1.0;2.0])
push!(v, [3.0;4.0])
ls = LineString(v)
f = Feature(ls)
fc = FeatureCollection(Feature[f])
gj = GeoJSON.geojson2dict(ls)
fj = GeoJSON.geojson2dict(f)
fcj = GeoJSON.geojson2dict(fc)
@fact gj["type"] --> "LineString"
@fact fj["type"] --> "Feature"
@fact fj["geometry"]["type"] --> "LineString"
@fact fcj["type"] --> "FeatureCollection"
@fact fcj["features"][1]["type"] --> "Feature"
@fact fcj["features"][1]["geometry"]["type"] --> "LineString"
