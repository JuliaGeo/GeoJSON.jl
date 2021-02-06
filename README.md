# GeoJSON.jl

[![CI](https://github.com/JuliaGeo/GeoJSON.jl/workflows/CI/badge.svg)](https://github.com/JuliaGeo/GeoJSON.jl/actions?query=workflow%3ACI)
[![Coverage Status](https://coveralls.io/repos/JuliaGeo/GeoJSON.jl/badge.svg)](https://coveralls.io/r/JuliaGeo/GeoJSON.jl)
[![Latest Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliageo.github.io/GeoJSON.jl/dev/)

This library is developed independently of, but is heavily influenced in design by the [python-geojson](https://github.com/frewsxcv/python-geojson) package. It contains:

- Functions for encoding and decoding GeoJSON formatted data
- a type hierarchy (according to the [GeoJSON specification](http://geojson.org/geojson-spec.html))
- An implementation of the [\__geo_interface\__](https://gist.github.com/sgillies/2217756), a GeoJSON-like protocol for geo-spatial (GIS) vector data.

Note that GeoJSON.jl loads features into the GeoInterface.jl format and that this differs from GeoJSON in the following ways:

- Julia Geometries do not provide a `bbox` and `crs` method. If you wish to provide a `bbox` or `crs` attribute, wrap the geometry into a `Feature` or `FeatureCollection`.
- Features do not have special fields for `id`, `bbox`, and `crs`. These are to be provided (or found) in the `properties` field, under the keys `featureid`, `bbox`, and `crs` respectively (if they exist).

When saving GeoJSON, these transformations will be reversed: if `properties` has a key `featureid`, that will be removed from `properties` and a matching member `id` will be added to the Feature; similarly for `crs` and `bbox`.

## Documentation

Documentation for GeoJSON.jl can be found at https://juliageo.github.io/GeoJSON.jl/dev/.
