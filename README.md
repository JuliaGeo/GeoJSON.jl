# GeoJSON

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaGeo.github.io/GeoJSON.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaGeo.github.io/GeoJSON.jl/dev)
[![CI](https://github.com/JuliaGeo/GeoJSON.jl/workflows/CI/badge.svg)](https://github.com/JuliaGeo/GeoJSON.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/JuliaGeo/GeoJSON.jl/branch/main/graph/badge.svg?token=ccpOaPSi08)](https://codecov.io/gh/JuliaGeo/GeoJSON.jl)

Read and write [GeoJSON](https://geojson.org/) with [JSON.jl](https://github.com/JuliaIO/JSON.jl), into
types that implement [GeoInterface.jl](https://github.com/JuliaGeo/GeoInterface.jl) and
[Tables.jl](https://github.com/JuliaData/Tables.jl). A `FeatureCollection` is a table with one row per
feature: the geometry sits in a `geometry` column and every property is a column of its own.

## Usage

### Reading

`GeoJSON.read` takes a file path, a JSON string, an `IO`, or a byte vector, and returns a
`FeatureCollection`, a `Feature`, or a geometry, whichever the document's root `"type"` names.

```julia
julia> using GeoJSON

julia> fc = GeoJSON.read("countries.geojson")
FeatureCollection with 177 Features

julia> f = fc[1]
Feature with 2D MultiPolygon geometry and 169 properties: (:geometry, :featurecla, :scalerank, …)

julia> f.NAME, f.POP_EST
("Fiji", 889953)

julia> GeoJSON.geometry(f)
2D MultiPolygon with 3 sub-geometries

julia> GeoJSON.properties(f)["NAME"]    # a Dict{String,Any}
"Fiji"
```

Properties land in a plain `Dict{String,Any}`, so they iterate in hash order; `f.NAME`, `f[:NAME]`
and `f["NAME"]` all reach the same entry. `properties=GeoJSON.Properties` keeps document order:

```julia
julia> fc = GeoJSON.read("countries.geojson"; properties=GeoJSON.Properties);

julia> collect(keys(GeoJSON.properties(fc[1])))[1:3]    # the order the file lists them
3-element Vector{String}:
 "featurecla"
 "scalerank"
 "LABELRANK"
```

Keywords shape the result:

| keyword | effect |
|---|---|
| `ndim=3` | coordinate dimension; discovered from the first coordinate by default |
| `numbertype=Float32` | coordinate element type; `Float64` by default |
| `geometries=(Point, Polygon)` | geometry types admitted; every other kind is an error |
| `properties=GeoJSON.Properties` | property container: `Dict{String,Any}` by default, `Properties` for document order, or a `NamedTuple`/struct schema |
| `properties=false` | skip the `"properties"` member entirely |
| `lazy=true` | keep the bytes and parse each feature on access |
| `mmap=true` | memory-map a path |

The target type is the schema, and the keyword form is sugar that builds it. Naming the type directly
gives an inferable result and a typed property container:

```julia
julia> const Geom = Union{GeoJSON.Polygon{2,Float64}, GeoJSON.MultiPolygon{2,Float64}};

julia> const Props = @NamedTuple{NAME::Union{Missing,String}, POP_EST::Union{Missing,Float64}};

julia> fc = GeoJSON.read("countries.geojson", GeoJSON.FeatureCollection{2,Float64,Geom,Props});

julia> GeoJSON.properties(fc[1])
(NAME = "Fiji", POP_EST = 889953.0)
```

Lazy reading scans the document once, records where each feature starts, and parses a feature only
when you index it:

```julia
julia> lfc = GeoJSON.read("places.geojson"; lazy=true)
LazyFeatureCollection with 7342 Features

julia> lfc[1]                              # parses one feature
Feature with 2D Point geometry and 137 properties: (:geometry, :SCALERANK, …)

julia> GeoJSON.lazyfeature(lfc, 1).NAME    # parses one property
"Colonia del Sacramento"

julia> collect(lfc)                        # parses everything, once
```

### Writing

`GeoJSON.write` returns a `String`, or writes to an `IO` or a file path. It accepts GeoJSON's own
types, any GeoInterface.jl geometry, feature, or feature collection, and any Tables.jl table with a
geometry column.

```julia
julia> GeoJSON.write(fc[1])
"{\"type\":\"Feature\",\"geometry\":{\"type\":\"MultiPolygon\",\"coordinates\":[[[[180.0,-16.067133],…"

julia> GeoJSON.write("out.geojson", fc)                 # streams to the file

julia> GeoJSON.write(stdout, fc[1].geometry; pretty=true)
{
  "type": "MultiPolygon",
  "coordinates": [
    [
      [
        [180.0, -16.067133],
        …
```

### Tables

Every `FeatureCollection` is a Tables.jl table, and any table with a geometry column writes as one:

```julia
julia> using DataFrames

julia> df = DataFrame(fc)                  # columns: geometry, featurecla, scalerank, …

julia> GeoJSON.write(df)                   # one feature per row
```

### HTTP access

To read GeoJSON from a URL, fetch the bytes with HTTP.jl:

```julia
julia> using GeoJSON, HTTP

julia> resp = HTTP.get("https://path/to/file.json")

julia> fc = GeoJSON.read(resp.body)
```

## Static compilation

A schema-typed read and `write` build under `juliac --trim=safe`, because every type the parser
constructs is spelled out in the target type:

```julia
const Geom = Union{GeoJSON.Polygon{2,Float64}, GeoJSON.MultiPolygon{2,Float64}}
const Props = @NamedTuple{NAME::Union{Missing,String}, POP_EST::Union{Missing,Float64}}

fc = GeoJSON.read(path, GeoJSON.FeatureCollection{2,Float64,Geom,Props})
fc = GeoJSON.read(path, GeoJSON.FeatureCollection{2,Float64,Geom,Nothing})   # properties skipped
lfc = GeoJSON.read(path, GeoJSON.LazyFeatureCollection{2,Float64,Geom,Props})
GeoJSON.write(fc)
```

These forms are JIT-only and fail trim verification:

- `Dict{String,Any}` or `Properties` as `P`, and `AnyGeometry` as `G`: `Any`-valued containers cannot be verified.
- Dimension discovery, i.e. `read(src)` without `ndim`: the return type is chosen at run time.
- The keyword sugar (`ndim=`, `geometries=`, `properties=`): it builds the target type at run time.
