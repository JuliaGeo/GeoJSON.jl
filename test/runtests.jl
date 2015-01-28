using GeoJSON, FactCheck

include(joinpath(dirname(@__FILE__),"geojson_samples.jl"))

feature = GeoJSON.parse(a)
@fact typeof(feature) => Feature
@fact GeoJSON.geometry(feature) => nothing
@fact GeoJSON.properties(feature) => feature.properties
@fact typeof(feature.properties) => Dict{String,Any}
@fact length(feature.properties) => 1
@fact GeoJSON.hasbbox(feature) => false
@fact GeoJSON.hascrs(feature) => false
@fact "Ã" in keys(feature.properties) => true
@fact feature.properties["Ã"] => "Ã"

feature = GeoJSON.parse(b)
@fact typeof(feature) => Feature
@fact GeoJSON.geometry(feature) => nothing
@fact GeoJSON.properties(feature) => feature.properties
@fact typeof(feature.properties) => Dict{String,Any}
@fact length(feature.properties) => 1
@fact GeoJSON.hasbbox(feature) => false
@fact GeoJSON.hascrs(feature) => false
@fact "Ã" in keys(feature.properties) => false
@fact feature.properties["type"] => "é"
@fact GeoJSON.hasid(feature) => true
@fact GeoJSON.id(feature) => feature.id
@fact feature.id => 1

feature = GeoJSON.parse(c)
@fact typeof(feature) => Feature
@fact GeoJSON.geometry(feature) => nothing
@fact GeoJSON.properties(feature) => feature.properties
@fact typeof(feature.properties) => Dict{String,Any}
@fact length(feature.properties) => 1
@fact feature.properties["type"] => "meow"
@fact GeoJSON.hasbbox(feature) => false
@fact GeoJSON.hascrs(feature) => true
@fact GeoJSON.crs(feature) => feature.crs
@fact typeof(feature.crs) => Dict{String,Any}
@fact feature.crs["type"] => "name"
@fact feature.crs["properties"]["name"] => "urn:ogc:def:crs:EPSG::3785"
@fact GeoJSON.hasid(feature) => true
@fact GeoJSON.id(feature) => feature.id
@fact feature.id => 1

feature = GeoJSON.parse(d)
@fact typeof(feature) => Feature
@fact typeof(GeoJSON.geometry(feature)) => Point
@fact GeoJSON.geometry(feature) => feature.geometry
@fact feature.geometry.coordinates => [53, -4]
@fact GeoJSON.hasbbox(feature.geometry) => false
@fact GeoJSON.hascrs(feature.geometry) => false
@fact GeoJSON.properties(feature) => feature.properties
@fact typeof(feature.properties) => Dict{String,Any}
@fact length(feature.properties) => 1
@fact feature.properties["title"] => "Dict 1"
@fact GeoJSON.hasbbox(feature) => false
@fact GeoJSON.hascrs(feature) => false
@fact GeoJSON.hasid(feature) => true
@fact GeoJSON.id(feature) => feature.id
@fact feature.id => "1"

feature = GeoJSON.parse(e)
@fact typeof(feature) => Feature
@fact typeof(GeoJSON.geometry(feature)) => Point
@fact GeoJSON.geometry(feature) => feature.geometry
@fact feature.geometry.coordinates => [53, -4]
@fact GeoJSON.hasbbox(feature.geometry) => false
@fact GeoJSON.hascrs(feature.geometry) => false
@fact GeoJSON.properties(feature) => feature.properties
@fact typeof(feature.properties) => Dict{String,Any}
@fact length(feature.properties) => 3
@fact feature.properties["title"] => "Feature 1"
@fact feature.properties["summary"] => "The first feature"
@fact feature.properties["link"] => "http://example.org/features/1"
@fact GeoJSON.hasbbox(feature) => false
@fact GeoJSON.hascrs(feature) => false

feature = GeoJSON.parse(f)
@fact typeof(feature) => Feature
@fact GeoJSON.geometry(feature) => nothing
@fact GeoJSON.properties(feature) => feature.properties
@fact typeof(feature.properties) => Dict{String,Any}
@fact length(feature.properties) => 1
@fact feature.properties["foo"] => "bar"
@fact GeoJSON.hasbbox(feature) => false
@fact GeoJSON.hascrs(feature) => false

buildings = GeoJSON.parse(osm_buildings)
@fact typeof(buildings) => FeatureCollection
@fact GeoJSON.hasbbox(buildings) => false
@fact GeoJSON.hascrs(buildings) => false
@fact length(buildings.features) => 4
@fact map(typeof,buildings.features) => fill(Feature,4)

feature = buildings.features[1]
@fact typeof(feature) => Feature
@fact typeof(GeoJSON.geometry(feature)) => Polygon
@fact GeoJSON.properties(feature) => feature.properties
@fact typeof(feature.properties) => Dict{String,Any}
@fact length(feature.properties) => 2
@fact feature.properties["height"] => 150
@fact feature.properties["color"] => "rgb(255,200,150)"
@fact GeoJSON.hasbbox(feature) => false
@fact GeoJSON.hascrs(feature) => false

building_dict = GeoJSON.geojson2dict(buildings)
@fact typeof(building_dict) => Dict{String,Any}
@fact string(GeoJSON.parse(osm_buildings)) => string(GeoJSON.dict2geojson(building_dict))

@fact GeoJSON.geojson(buildings) =>
"""{\"features\":[{\"geometry\":{\"coordinates\":[[[13.42634,52.49533],[13.4266,52.49524],[13.42619,52.49483],[13.42583,52.49495],[13.4259,52.49501],[13.42611,52.49494],[13.4264,52.49525],[13.4263,52.49529],[13.42634,52.49533]]],\"type\":\"Polygon\"},\"properties\":{\"height\":150,\"color\":\"rgb(255,200,150)\"},\"type\":\"Feature\"},{\"geometry\":{\"coordinates\":[[[13.42706,52.49535],[13.42745,52.4952],[13.42745,52.4952],[13.42741,52.49516],[13.42717,52.49525],[13.42692,52.49501],[13.42714,52.49494],[13.42686,52.49466],[13.4265,52.49478],[13.42657,52.49486],[13.42678,52.4948],[13.42694,52.49496],[13.42675,52.49503],[13.42706,52.49535]]],\"type\":\"Polygon\"},\"properties\":{\"height\":130,\"color\":\"rgb(180,240,180)\"},\"type\":\"Feature\"},{\"geometry\":{\"coordinates\":[[[[13.42746,52.4944],[13.42794,52.49494],[13.42799,52.49492],[13.42755,52.49442],[13.42798,52.49428],[13.42846,52.4948],[13.42851,52.49478],[13.428,52.49422],[13.42746,52.4944]]],[[[13.42803,52.49497],[13.428,52.49493],[13.42844,52.49479],[13.42847,52.49483],[13.42803,52.49497]]]],\"type\":\"MultiPolygon\"},\"properties\":{\"height\":120,\"color\":\"rgb(200,200,250)\"},\"type\":\"Feature\"},{\"geometry\":{\"coordinates\":[[[13.42857,52.4948],[13.42918,52.49465],[13.42867,52.49412],[13.4285,52.49419],[13.42896,52.49465],[13.42882,52.49469],[13.42837,52.49423],[13.42821,52.49428],[13.42863,52.49473],[13.42853,52.49476],[13.42857,52.4948]]],\"type\":\"Polygon\"},\"properties\":{\"height\":140,\"color\":\"rgb(150,180,210)\"},\"type\":\"Feature\"}],\"type\":\"FeatureCollection\"}"""

@fact GeoJSON.geojson(buildings) => JSON.json(JSON.parse(osm_buildings))
@fact building_dict => JSON.parse(osm_buildings)
