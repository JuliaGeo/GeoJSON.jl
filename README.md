# GeoJSON.jl

[![Build Status](https://travis-ci.org/JuliaGeo/GeoJSON.jl.svg)](https://travis-ci.org/JuliaGeo/GeoJSON.jl)
[![Coverage Status](https://coveralls.io/repos/JuliaGeo/GeoJSON.jl/badge.svg)](https://coveralls.io/r/JuliaGeo/GeoJSON.jl)

This library is developed independently of, but is heavily influenced in design by the [python-geojson](https://github.com/frewsxcv/python-geojson) package, and contains functions for encoding and decoding GeoJSON formatted data.

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
FeatureCollection{Feature}([Feature(Polygon([[[13.4263,52.4953],[13.4266,52.4952],[13.4262,52.4948],[13.4258,52.495],[13.4259,52.495],[13.4261,52.4949],[13.4264,52.4952],[13.4263,52.4953],[13.4263,52.4953]]]),["height"=>150,"color"=>"rgb(255,200,150)"])],nothing,nothing)
```

- Transforms a GeoJSON object into a nested Array or Dict

```julia
julia> GeoJSON.geojson(buildings)
Dict{ASCIIString,Any} with 2 entries:
  "features" => [["geometry"=>["coordinates"=>[[[13.42634,52.49533],[13.4266,52…
  "type"     => "FeatureCollection"

julia> JSON.parse(osm_buildings) # should be comparable (if not the same)
Dict{String,Any} with 2 entries:
  "features" => {["geometry"=>["coordinates"=>{{{13.42634,52.49533},{13.4266,52…
  "type"     => "FeatureCollection"
```

- Transforms from a nested Array/Dict to a GeoJSON object

```julia
julia> GeoJSON.dict2geo(GeoJSON.geojson2dict(buildings))
FeatureCollection{Feature}([Feature(Polygon([[[13.4263,52.4953],[13.4266,52.4952],[13.4262,52.4948],[13.4258,52.495],[13.4259,52.495],[13.4261,52.4949],[13.4264,52.4952],[13.4263,52.4953],[13.4263,52.4953]]]),["height"=>150,"color"=>"rgb(255,200,150)"])],nothing,nothing)

julia> GeoJSON.parse(osm_buildings) # the original object (for comparison)
FeatureCollection{Feature}([Feature(Polygon([[[13.4263,52.4953],[13.4266,52.4952],[13.4262,52.4948],[13.4258,52.495],[13.4259,52.495],[13.4261,52.4949],[13.4264,52.4952],[13.4263,52.4953],[13.4263,52.4953]]]),["height"=>150,"color"=>"rgb(255,200,150)"])],nothing,nothing)
```

- You can use JSON to returns a compact GeoJSON representation as a String

```julia
julia> buildings
FeatureCollection{Feature}([Feature(Polygon([[[13.4263,52.4953],[13.4266,52.4952],[13.4262,52.4948],[13.4258,52.495],[13.4259,52.495],[13.4261,52.4949],[13.4264,52.4952],[13.4263,52.4953],[13.4263,52.4953]]]),["height"=>150,"color"=>"rgb(255,200,150)"])],nothing,nothing)

julia> JSON.json(buildings)
"{\"features\":[{\"geometry\":{\"coordinates\":[[[13.42634,52.49533],[13.4266,52.49524],[13.42619,52.49483],[13.42583,52.49495],[13.4259,52.49501],[13.42611,52.49494],[13.4264,52.49525],[13.4263,52.49529],[13.42634,52.49533]]]},\"properties\":{\"height\":150,\"color\":\"rgb(255,200,150)\"}}],\"bbox\":null,\"crs\":null}"
```

- Writes a compact (no extra whitespace or identation) JSON representation to the supplied IO.

```julia
GeoJSON.print(io::IO, obj::AbstractGeoJSON)
```
