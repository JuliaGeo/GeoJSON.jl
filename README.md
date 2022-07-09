# GeoJSON

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaGeo.github.io/GeoJSON.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaGeo.github.io/GeoJSON.jl/dev)
[![CI](https://github.com/JuliaGeo/GeoJSON.jl/workflows/CI/badge.svg)](https://github.com/JuliaGeo/GeoJSON.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/JuliaGeo/GeoJSON.jl/branch/master/graph/badge.svg?token=ccpOaPSi08)](https://codecov.io/gh/JuliaGeo/GeoJSON.jl)

Read [GeoJSON](https://geojson.org/) files using [JSON3.jl](https://github.com/quinnj/JSON3.jl), and provide the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface.

This package is heavily inspired by, and borrows code from, [JSONTables.jl](https://github.com/JuliaData/JSONTables.jl), which
does the same thing for the general JSON format. GeoJSON puts the geometry in a `geometry` column, and adds all
properties in the columns individually.

## Usage

```julia
julia> using GeoJSON, DataFrames

julia> jsonbytes = read("path/to/a.geojson");

julia> fc = GeoJSON.read(jsonbytes)
FeatureCollection with 171 Features

julia> first(fc)
Feature with geometry type Polygon and properties Symbol[:geometry, :timestamp, :version, :changeset, :user, :uid, :area, :highway, :type, :id]

# use the Tables interface to convert the format, extract data, or iterate over the rows
julia> df = DataFrame(fc)
```
