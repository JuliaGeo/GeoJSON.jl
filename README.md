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
To read JSON from a URL, use HTTP.jl
```julia

julia> using GeoJSON, HTTP

julia> resp = HTTP.get("https://path/to/file.json")

julia> fc = GeoJSON.read(resp.body)
```

### Creating a GeoJSON File
This example illustrates the process of generating a GeoJSON file from a JSON file that contains coordinate data.

This example uses [GeoInterface.jl](https://juliageo.org/GeoInterface.jl/stable/) for constructing the GeoJSON.
```julia
# First we import the packages we need
using GeoJSON # for writing the GeoJSON
using JSON3 # for reading the JSON data
import GeoInterface as GI # For creating Feature, FeatureCollection and geometry types like Point

# Example JSON snippet
json_string = """
{
  "results": [
    {
      "locality": "Wekerom",
      "name": "Wekerom-Riemterdijk",
      "coordinates": {
        "latitude": 52.111599999999996,
        "longitude": 5.70842
      }
    },
    {
      "name": "Zaanstad-Hemkade",
      "locality": "Zaandam",
      "coordinates": {
        "latitude": 52.420230000140556,
        "longitude": 4.832060000156797
      }
    }
  ]
}
"""

# Read the JSON snippet
data = JSON3.read(json_string)

# Create a vector to store the features
features = []

# Loop through each result and create a feature
for result in data.results
    # Extract the coordinates and name
    lat::Float64 = result.coordinates.latitude
    lon::Float64 = result.coordinates.longitude
    name = result.name
    locality = result.locality

    # Create a GeoJSON point feature with properties
    point = GI.Point([lon, lat])
    props = Dict(
        :name => name,
        :locality => locality
    )
    feature = GI.Feature(
        point,
        properties=props
    )

    # Add the feature to the vector
    push!(features, feature)
end

# Create a feature collection
fc = GI.FeatureCollection(features)

# Write the feature collection to a GeoJSON file
output_file = "output.geojson"
GeoJSON.write(output_file, fc)
```
