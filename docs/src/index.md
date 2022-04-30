# GeoJSON.jl

## Introduction
[![Build Status](https://travis-ci.org/JuliaGeo/GeoJSON.jl.svg)](https://travis-ci.org/JuliaGeo/GeoJSON.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/JuliaGeo/GeoJSON.jl?svg=true&branch=master)](https://ci.appveyor.com/project/JuliaGeo/GeoJSON-jl/branch/master)
[![Coverage Status](https://coveralls.io/repos/JuliaGeo/GeoJSON.jl/badge.svg)](https://coveralls.io/r/JuliaGeo/GeoJSON.jl)
[![Latest Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliageo.github.io/GeoJSON.jl/dev/)

This library is developed independently of, but is heavily influenced in design by the [python-geojson](https://github.com/frewsxcv/python-geojson) package. It contains:

- Functions for encoding and decoding GeoJSON formatted data
- a type hierarchy (according to the [GeoJSON specification](http://geojson.org/geojson-spec.html))
- An implementation of the [\__geo_interface\__](https://gist.github.com/sgillies/2217756), a GeoJSON-like protocol for geo-spatial (GIS) vector data.

## Contents
```@contents
```

## Installation
The package is registered and can be added using the package manager:
```julia
pkg> add GeoJSON
```

To test if it is installed correctly run:
```julia
pkg> test GeoJSON
```

## Basic Usage
Although we use GeoInterface types for representing GeoJSON objects, it works in tandem 
with the [JSON3.jl](https://github.com/quinnj/JSON3.jl) package, for parsing and some
printing of objects. Here are some examples of its functionality:

### Reads a GeoJSON String or IO stream into a GeoInterface object

```@example basic
using GeoJSON
osm_buildings = """
{
    "type": "FeatureCollection",
    "features": [{
        "type": "Feature",
        "geometry": {
            "type": "Polygon",
            "coordinates": [
                [
                    [13.42634, 52.49533],
                    [13.42630, 52.49529],
                    [13.42640, 52.49525],
                    [13.42611, 52.49494],
                    [13.42590, 52.49501],
                    [13.42583, 52.49495],
                    [13.42619, 52.49483],
                    [13.42660, 52.49524],
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
buildings = GeoJSON.read(osm_buildings)
buildings
```

Use `GeoJSON.read(read("tech_square.geojson"))` to read GeoJSON files from disk.

### Create a GeoInterface object and write to disk as a GeoJSON
```@example write2disk
using GeoJSON
using Pkg; Pkg.add("GeoInterface"); using GeoInterface

# create a polygon
obj = GeoInterface.Polygon([[[13.42634, 52.49533], [13.4263, 52.49529], [13.4264, 52.49525], [13.42611, 52.49494], [13.4259, 52.49501], [13.42583, 52.49495], [13.42619, 52.49483], [13.4266, 52.49524], [13.42634, 52.49533]]])

# write to disk as a geojson 
write("filename.json", GeoJSON.write(obj))
```

### Transforms a GeoInterface object into a nested Array or Dict

```@example basic
dict = geo2dict(buildings) # geo2dict -- GeoInterface object to Dict/Array-representation
dict
```

```@example basic
using JSON3
JSON3.read(osm_buildings) # should be comparable (if not the same)
```

### Transforms from a nested Array/Dict to a GeoInterface object

```@example basic
dict2geo(dict)
```

```@example basic
GeoJSON.read(osm_buildings) # the original object (for comparison)
```

## GeoInterface
This library implements the [GeoInterface](https://github.com/JuliaGeo/GeoInterface.jl).
For more information on the types that are returned by this package, and the methods that can be
used on them, refer to the documentation of the GeoInterface package.

## Functions
### Input
To read in GeoJSON data, use [`GeoJSON.read`](@ref).
```@docs
GeoJSON.read
```

### Output
```@docs
GeoJSON.write
```

### Conversion
For more fine grained control, to construct or deconstruct parts of a GeoJSON, use
[`geo2dict`](@ref) or [`dict2geo`](@ref).
```@docs
geo2dict
dict2geo
```

## Index
```@index
```
