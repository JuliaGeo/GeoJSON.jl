# GeoJSON

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaGeo.github.io/GeoJSON.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaGeo.github.io/GeoJSON.jl/dev)
[![CI](https://github.com/JuliaGeo/GeoJSON.jl/workflows/CI/badge.svg)](https://github.com/JuliaGeo/GeoJSON.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/JuliaGeo/GeoJSON.jl/branch/main/graph/badge.svg?token=ccpOaPSi08)](https://codecov.io/gh/JuliaGeo/GeoJSON.jl)

Read [GeoJSON](https://geojson.org/) files using [JSON3.jl](https://github.com/quinnj/JSON3.jl), and provide the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface.

This package is heavily inspired by, and borrows code from, [JSONTables.jl](https://github.com/JuliaData/JSONTables.jl), which
does the same thing for the general JSON format. GeoJSON puts the geometry in a `geometry` column, and adds all
properties in the columns individually.

## Usage
GeoJSON only provides simple `read` and `write` methods.
`GeoJSON.read` takes a file path, string, IO, or bytes.

```julia
julia> using GeoJSON, DataFrames

julia> fc = GeoJSON.read("path/to/a.geojson")
FeatureCollection with 171 Features

julia> first(fc)
Feature with geometry type Polygon and properties Symbol[:geometry, :timestamp, :version, :changeset, :user, :uid, :area, :highway, :type, :id]

# use the Tables interface to convert the format, extract data, or iterate over the rows
julia> df = DataFrame(fc)

# write to string
julia> write(fc)
"{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[-69.99693762899992...
```


### HTTP access
To read JSON from a URL, use Downloads
```julia

julia> using GeoJSON, Downloads

julia> io = Downloads.download("https://its-live-data.s3.amazonaws.com/datacubes/catalog_v02.json", IOBuffer())

julia> fc = GeoJSON.read(io)
```
