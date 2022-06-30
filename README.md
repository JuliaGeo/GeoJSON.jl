# GeoJSONTables

Read [GeoJSON](https://geojson.org/) [FeatureCollections](https://tools.ietf.org/html/rfc7946#section-3.3) using [JSON3.jl](https://github.com/quinnj/JSON3.jl), and provide the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface.

This package is unregistered and in development, so expect changes. It only supports reading, and only of FeatureCollections.

This package is heavily inspired by, and borrows code from, [JSONTables.jl](https://github.com/JuliaData/JSONTables.jl), which
does the same thing for the general JSON format. GeoJSONTables puts the geometry in a `geometry` column, and adds all
properties in the columns individually. The geometry and non-scalar properties are kept as JSON3.Object and JSON3.Array.
Right now that means the geometries are hard to use, but at least parsing is fast.

Going forward, it would be nice to try developing a GeoTables.jl, similarly to Tables.jl, but with special support
for a geometry column, that supports a diverse set of geometries, such as those of [LibGEOS](https://github.com/JuliaGeo/LibGEOS.jl), [Shapefile](https://github.com/JuliaGeo/Shapefile.jl), [ArchGDAL.jl](https://github.com/yeesian/ArchGDAL.jl/), [GeometryBasics](https://github.com/SimonDanisch/GeometryBasics.jl) and of course this package.

It would also be good to explore integrating this code into [GeoJSON.jl](https://github.com/JuliaGeo/GeoJSON.jl) and
archiving this package. See [GeoJSON.jl#23](https://github.com/JuliaGeo/GeoJSON.jl/pull/23) for discussion.

## Usage

```julia
julia> using GeoJSONTables, DataFrames

julia> jsonbytes = read("path/to/a.geojson");

julia> fc = GeoJSONTables.read(jsonbytes)
FeatureCollection with 171 Features

julia> first(fc)
Feature with geometry type Polygon and properties Symbol[:geometry, :timestamp, :version, :changeset, :user, :uid, :area, :highway, :type, :id]

# use the Tables interface to convert the format, extract data, or iterate over the rows
julia> df = DataFrame(fc)
```
