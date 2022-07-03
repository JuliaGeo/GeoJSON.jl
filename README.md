# GeoJSON

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
