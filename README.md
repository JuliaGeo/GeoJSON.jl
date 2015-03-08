# GeoJSON.jl

[![Build Status](https://travis-ci.org/JuliaGeo/GeoJSON.jl.svg)](https://travis-ci.org/JuliaGeo/GeoJSON.jl)
[![Coverage Status](https://coveralls.io/repos/JuliaGeo/GeoJSON.jl/badge.svg)](https://coveralls.io/r/JuliaGeo/GeoJSON.jl)

This library is developed independently of, but is heavily influenced in design by the [python-geojson](https://github.com/frewsxcv/python-geojson) package. It contains:

- Functions for encoding and decoding GeoJSON formatted data
- a type hierarchy (according to the [GeoJSON specification](http://geojson.org/geojson-spec.html))
- An implementation of the [__geo_interface__](https://gist.github.com/sgillies/2217756), a GeoJSON-like protocol for geo-spatial (GIS) vector data.

## Installation
```julia
Pkg.add("GeoJSON")
# Running Pkg.update() will always give you the freshest version of GeoJSON
# Double-check that it works:
Pkg.test("GeoJSON")
```

## Basic Usage
Although we introduce types for representing GeoJSON objects, it works in tandem with the [JSON.jl](https://github.com/JuliaLang/JSON.jl) package, for parsing and printing objects. Here are some examples of its functionality:

- Parses a JSON String or IO stream into a GeoJSON object
```julia
julia> using GeoJSON
julia> osm_buildings = """{
                "type": "FeatureCollection",
                "features": [{
                  "type": "Feature",
                  "geometry": {
                    "type": "Polygon",
                    "coordinates": [
                      [
                        [13.42634, 52.49533],
                        [13.42660, 52.49524],
                        [13.42619, 52.49483],
                        [13.42583, 52.49495],
                        [13.42590, 52.49501],
                        [13.42611, 52.49494],
                        [13.42640, 52.49525],
                        [13.42630, 52.49529],
                        [13.42634, 52.49533]
                      ]
                    ]
                  },
                  "properties": {
                    "color": "rgb(255,200,150)",
                    "height": 150
                  }
                }]
              }"""
julia> buildings = GeoJSON.parse(osm_buildings) # GeoJSON.parse -- string or stream to AbstractGeoJSON types
FeatureCollection([Feature(Polygon({{{13.42634,52.49533},{13.4266,52.49524},{13.42619,52.49483},{13.42583,52.49495},{13.4259,52.49501},{13.42611,52.49494},{13.4264,52.49525},{13.4263,52.49529},{13.42634,52.49533}}},#undef,#undef),["height"=>150,"color"=>"rgb(255,200,150)"],#undef,#undef,#undef)],#undef,#undef)
```

- Transforms a GeoJSON object into a nested Array or Dict

```julia
julia> GeoJSON.geojson2dict(buildings) # geojson2dict -- AbstractGeoJSON to Dict/Array-representation
Dict{String,Any} with 2 entries:
  "features" => [["geometry"=>["coordinates"=>{{{13.42634,52.49533},{13.4266,52.49524},{13.42619,52.49483},{13.42583,52.49495},{13.4259,52.49…
  "type"     => "FeatureCollection"

julia> JSON.parse(osm_buildings) # should be comparable (if not the same)
Dict{String,Any} with 2 entries:
  "features" => {["geometry"=>["coordinates"=>{{{13.42634,52.49533},{13.4266,52.49524},{13.42619,52.49483},{13.42583,52.49495},{13.4259,52.49…
  "type"     => "FeatureCollection"
```

- Transforms from a nested Array/Dict to a GeoJSON object

```julia
julia> GeoJSON.dict2geojson(GeoJSON.geojson2dict(buildings))
FeatureCollection([Feature(Polygon({{{13.42634,52.49533},{13.4266,52.49524},{13.42619,52.49483},{13.42583,52.49495},{13.4259,52.49501},{13.42611,52.49494},{13.4264,52.49525},{13.4263,52.49529},{13.42634,52.49533}}},#undef,#undef),["height"=>150,"color"=>"rgb(255,200,150)"],#undef,#undef,#undef)],#undef,#undef)

julia> GeoJSON.parse(osm_buildings) # the original object (for comparison)
FeatureCollection([Feature(Polygon({{{13.42634,52.49533},{13.4266,52.49524},{13.42619,52.49483},{13.42583,52.49495},{13.4259,52.49501},{13.42611,52.49494},{13.4264,52.49525},{13.4263,52.49529},{13.42634,52.49533}}},#undef,#undef),["height"=>150,"color"=>"rgb(255,200,150)"],#undef,#undef,#undef)],#undef,#undef)
```

- Returns a compact JSON representation as a String

```julia
julia> geojson(buildings) # AbstractGeoJSON to a string
"{\"features\":[{\"geometry\":{\"coordinates\":[[[13.42634,52.49533],[13.4266,52.49524],[13.42619,52.49483],[13.42583,52.49495],[13.4259,52.49501],[13.42611,52.49494],[13.4264,52.49525],[13.4263,52.49529],[13.42634,52.49533]]],\"type\":\"Polygon\"},\"properties\":{\"height\":150,\"color\":\"rgb(255,200,150)\"},\"type\":\"Feature\"}],\"type\":\"FeatureCollection\"}"

julia> JSON.json(JSON.parse(osm_buildings)) # compared with the JSON parser
"{\"features\":[{\"geometry\":{\"coordinates\":[[[13.42634,52.49533],[13.4266,52.49524],[13.42619,52.49483],[13.42583,52.49495],[13.4259,52.49501],[13.42611,52.49494],[13.4264,52.49525],[13.4263,52.49529],[13.42634,52.49533]]],\"type\":\"Polygon\"},\"properties\":{\"height\":150,\"color\":\"rgb(255,200,150)\"},\"type\":\"Feature\"}],\"type\":\"FeatureCollection\"}"
```

- Convert a GeoJSON.FeatureCollection to a DataFrame

```julia
julia> GeoJSON.geojson2df(obj)
4x4 DataFrame
| Row | id |
|-----|----|
| 1   | NA |
| 2   | NA |
| 3   | NA |
| 4   | NA |

| Row | geometry                                                                                                                                                                                                                                                                                  |
|-----|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1   | Polygon([[[13.4263,52.4953],[13.4266,52.4952],[13.4262,52.4948],[13.4258,52.495],[13.4259,52.495],[13.4261,52.4949],[13.4264,52.4952],[13.4263,52.4953],[13.4263,52.4953]]],#undef,#undef)                                                                                                |
| 2   | Polygon([[[13.4271,52.4954],[13.4275,52.4952],[13.4275,52.4952],[13.4274,52.4952],[13.4272,52.4952],[13.4269,52.495],[13.4271,52.4949],[13.4269,52.4947],[13.4265,52.4948],[13.4266,52.4949],[13.4268,52.4948],[13.4269,52.495],[13.4268,52.495],[13.4271,52.4954]]],#undef,#undef)       |
| 3   | MultiPolygon([[[[13.4275,52.4944],[13.4279,52.4949],[13.428,52.4949],[13.4276,52.4944],[13.428,52.4943],[13.4285,52.4948],[13.4285,52.4948],[13.428,52.4942],[13.4275,52.4944]]],[[[13.428,52.495],[13.428,52.4949],[13.4284,52.4948],[13.4285,52.4948],[13.428,52.495]]]],#undef,#undef) |
| 4   | Polygon([[[13.4286,52.4948],[13.4292,52.4947],[13.4287,52.4941],[13.4285,52.4942],[13.429,52.4947],[13.4288,52.4947],[13.4284,52.4942],[13.4282,52.4943],[13.4286,52.4947],[13.4285,52.4948],[13.4286,52.4948]]],#undef,#undef)                                                           |

| Row | color              | height |
|-----|--------------------|--------|
| 1   | "rgb(255,200,150)" | 150    |
| 2   | "rgb(180,240,180)" | 130    |
| 3   | "rgb(200,200,250)" | 120    |
| 4   | "rgb(150,180,210)" | 140    |
```

- Writes a compact (no extra whitespace or identation) JSON representation to the supplied IO.

```julia
GeoJSON.print(io::IO, obj::AbstractGeoJSON)
```

## GeoJSON Objects
This library implements the following [GeoJSON Objects](http://www.geojson.org/geojson-spec.html#geojson-objects) described in The GeoJSON Format Specification.

- `CRS`
- `Position`
- `Geometry <: AbstractGeoJSON`
  - `Point <: Geometry`
  - `MultiPoint <: Geometry`
  - `LineString <: Geometry`
  - `MultiLineString <: Geometry`
  - `Polygon <: Geometry`
  - `MultiPolygon <: Geometry`
  - `GeometryCollection <: Geometry`
- `Feature <: AbstractGeoJSON`
- `FeatureCollection <: AbstractGeoJSON`

The following methods are implemented for all AbstractGeoJSON objects:
```julia
hasbbox(obj::AbstractGeoJSON) # returns true if obj has a "bbox" key
hascrs(obj::AbstractGeoJSON) # returns true if obj has a "crs" key
bbox(obj::AbstractGeoJSON) # returns the boundingbox of obj
crs(obj::AbstractGeoJSON) # returns the coordinate reference system
```
In addition, the `Feature` object also implements ```hasid(obj::Feature)```.

### GeoJSON Attributes (GEO_Interface)
In accordance with the [GeoJSON format](http://geojson.org/geojson-spec.html) (and the [__geo_interface__](https://gist.github.com/sgillies/2217756)), the following methods are implemented for each of the GeoJSON objects:
```julia
# GeoJSON             (methods,)
# --------------------------------------------
((MultiPolygon,       (coordinates,)),
 (Polygon,            (coordinates,)),
 (MultiLineString,    (coordinates,)),
 (LineString,         (coordinates,)),
 (MultiPoint,         (coordinates,)),
 (Point,              (coordinates,)),
 (GeometryCollection, (geometries,)),
 (Feature,            (geometry, properties, id)),
 (FeatureCollection,  (features,)))
```
