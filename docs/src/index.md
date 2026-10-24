```@meta
CurrentModule = GeoJSON
```

# GeoJSON

Documentation for [GeoJSON](https://github.com/JuliaGeo/GeoJSON.jl).

See the [GeoInterfaces.jl](https://juliageo.org/GeoInterface.jl/stable/) and
[Tables.jl](https://tables.juliadata.org/stable/) documentation for most
applicable methods.

```@autodocs
Modules = [GeoJSON]
```

## Schema-typed parsing

The usual `GeoJSON.read(source)` keeps its `Float32` coordinates, two-dimensional
read with a three-dimensional retry, and `Dict{Symbol,Any}` properties. For a
statically known property schema, specify the property type:

```julia
P = NamedTuple{(:name, :population),Tuple{String,Union{Missing,Int}}}
FC = GeoJSON.FeatureCollection{2,Float64,P}
fc = GeoJSON.read(source, FC)
text = GeoJSON.write(fc)
```

The typed entry point accepts all seven geometry kinds and does not retry coordinate
dimensions. Missing property fields can be represented by `Union{Missing,T}`.
The schema form reads directly into the requested types; it does not first build
an untyped JSON tree. `test/trim` compiles and runs a schema read/write round trip
with `juliac --trim=safe`. Ordinary dictionary-based reads and arbitrary custom
property values remain supported but are outside that static-compilation contract.

`Feature` and `FeatureCollection` have three type parameters (`D,T,P`). Their
geometry storage uses `Geometry{D,T}`, the union of the seven GeoJSON kinds;
`GeometryCollection{D,T}` uses a vector with that element type, including nested
collections. Existing two-parameter constructors and GeoInterface behavior remain.
The spike replaces the migration branch's four-parameter schemas: callers must
drop `G`, and validate a restricted set of geometry kinds themselves. Geometry
structs contain references, so this union does not provide isbits-union storage.
Schema writes accept JSON string/numeric IDs and JSON-compatible CRS values;
ordinary writes retain JSON.jl's custom-value serialization support.

Run the standalone trim check with:

```sh
julia --project=test/trim -e 'using Pkg; Pkg.instantiate(); include("test/trim/runtests.jl")'
```

Collection column names and types are discovered on the first `Tables.schema`,
`propertynames`, `.names`, or `.types` access and cached thereafter. Reading,
indexing, iterating, and writing do not perform this scan. Discovery is synchronized
across tasks; concurrent mutation of feature properties is not supported. Property
changes before discovery are reflected in the schema, while later changes do not
invalidate the cached snapshot. `FeatureCollection` remains immutable and non-isbits;
its internal layout gains a cache-state reference.
