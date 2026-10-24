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
drop `G` and use the `geometrytype` keyword to restrict geometry kinds. Geometry
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

## Restricting geometry kinds

```julia
polygons = Union{GeoJSON.Polygon,GeoJSON.MultiPolygon}
fc = GeoJSON.read(source; geometrytype=polygons)
fc = GeoJSON.read(source, FC; geometrytype=polygons)
```

`geometrytype` validates each geometry kind during parsing and throws an
`ArgumentError` naming an excluded kind. Storage stays the same small union;
this is an input restriction, not a type invariant on later construction or
mutation. Null geometry remains allowed. A GeometryCollection and all its
children must be allowed, so include `GeoJSON.GeometryCollection` along with
its permitted child kinds. Type parameters on a supplied geometry type select
only its kind; dimensions and numeric types come from `ndim`/`numbertype` or the
schema. The default `nothing` permits all seven kinds. Restricted reads require
`lazyfc=false`; lazy reads defer materialization and cannot promise validation
at read time.

Obtained geometries work with GeoInterface and ordinary Julia functions. Narrow
the kind when different operations need different return types:

```julia
import GeoInterface as GI
function score(g)
    if g isa GeoJSON.Point
        return Float64(GI.x(g))
    elseif g isa GeoJSON.LineString || g isa GeoJSON.Polygon
        return Float64(GI.ngeom(g))
    end
    0.0
end
sum(f -> score(GI.geometry(f)), fc; init=0.0)
```

Use `GI.geometry(f)` or `GeoJSON.geometry(f)` to retrieve the geometry: a property
named `geometry` can override `f.geometry`. A function barrier also lets Julia
specialize on the concrete geometry passed to a user function. Inference and
union splitting depend on the operation; the union does not guarantee either
for every GeoInterface function.

Custom `AbstractGeometry` subtypes cannot be stored in these closed fields. There
is no second concrete-`G` feature family: use a separate vector of custom
geometries, a GeoInterface-compatible feature/table wrapper, or convert custom
objects to one of the seven built-in kinds. The generic GeoInterface writer
accepts compatible wrappers.
