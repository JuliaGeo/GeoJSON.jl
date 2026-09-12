```@meta
CurrentModule = GeoJSON
```

# GeoJSON

Documentation for [GeoJSON.jl](https://github.com/JuliaGeo/GeoJSON.jl): reading and writing
[GeoJSON](https://geojson.org/) through [JSON.jl](https://github.com/JuliaIO/JSON.jl), into types
that implement [GeoInterface.jl](https://juliageo.org/GeoInterface.jl/stable/) and
[Tables.jl](https://tables.juliadata.org/stable/).

| page | covers |
|---|---|
| this page | reading, writing, the types, and the full API |
| [Schemas and static compilation](@ref) | naming the target type, and what builds under `--trim=safe` |
| [Lazy reading](@ref) | the offset-table tier for large files |

## Reading and writing

```julia
using GeoJSON

fc = GeoJSON.read("countries.geojson")           # FeatureCollection, Feature, or geometry
fc[1].NAME                                       # property access
GeoJSON.geometry(fc[1])                          # a GeoJSON geometry
GeoJSON.write("out.geojson", fc)                 # or write(io, fc), write(fc) -> String
```

The document's root `"type"` picks the result type. `read` accepts a path, a JSON string, an `IO`,
or a byte vector; its keywords (`ndim`, `numbertype`, `geometries`, `properties`, `lazy`, `mmap`)
build the target type, and passing that type directly is the [schema form](@ref "Schemas and static compilation").

## Types

Every type carries the dimension `D` and coordinate element type `T`. Coordinates are nested
vectors of `NTuple{D,T}`: a `Point` holds one tuple, a `LineString` a vector of them, a `Polygon`
a vector of rings, and so on. `Feature{D,T,G,P}` adds the geometry type `G` and the property
container `P`; `FeatureCollection{D,T,G,P}` is a vector of such features and a Tables.jl table.
Foreign members of any object live in `extras(x)`.

## API

### Reading and writing

```@docs
read
write
```

### Geometries

```@docs
Point
LineString
Polygon
MultiPoint
MultiLineString
MultiPolygon
GeometryCollection
```

### Features and collections

```@docs
Feature
FeatureCollection
Properties
Extras
DimMismatch
```

### Accessors

```@docs
geometry
coordinates
properties
id
bbox
extras
typestring
```

### Lazy tier

```@docs
LazyFeatureCollection
LazyFeature
LazyGeometry
LazyStream
lazyfeature
lazygeometry
materialize
features
Base.foreach(f, fc::LazyFeatureCollection)
```

### Internals

Docstrings on the reader and writer machinery, for anyone extending the package.

```@autodocs
Modules = [GeoJSON]
Filter = t -> !(t in (GeoJSON, GeoJSON.read, GeoJSON.write, GeoJSON.Point, GeoJSON.LineString,
                      GeoJSON.Polygon, GeoJSON.MultiPoint, GeoJSON.MultiLineString,
                      GeoJSON.MultiPolygon, GeoJSON.GeometryCollection, GeoJSON.Feature,
                      GeoJSON.FeatureCollection, GeoJSON.Properties, GeoJSON.Extras,
                      GeoJSON.DimMismatch, GeoJSON.LazyFeatureCollection, GeoJSON.LazyFeature,
                      GeoJSON.LazyGeometry, GeoJSON.LazyStream, GeoJSON.lazyfeature,
                      GeoJSON.lazygeometry, GeoJSON.materialize, GeoJSON.features, Base.foreach,
                      GeoJSON.geometry, GeoJSON.coordinates, GeoJSON.properties, GeoJSON.id,
                      GeoJSON.bbox, GeoJSON.extras, GeoJSON.typestring))
```
