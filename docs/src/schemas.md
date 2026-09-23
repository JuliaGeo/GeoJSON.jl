```@meta
CurrentModule = GeoJSON
```

# Schemas and static compilation

The target type of a read is its schema. `FeatureCollection{D,T,G,P}` names everything the parser
will construct, so `read(src, FeatureCollection{D,T,G,P})` parses straight into it with an
inferable return type, and builds under `juliac --trim=safe`.

| parameter | meaning | trim-safe values |
|---|---|---|
| `D` | coordinate dimension | `2`, `3`, `4` |
| `T` | coordinate element type | `Float64`, `Float32`, … |
| `G` | geometry type admitted | one concrete geometry, or a `Union` of them |
| `P` | property container | `Nothing`, a `NamedTuple`, or a struct |

```julia
const Geom = Union{GeoJSON.Polygon{2,Float64}, GeoJSON.MultiPolygon{2,Float64}}
const Props = @NamedTuple{NAME::Union{Missing,String}, POP_EST::Union{Missing,Float64}}

fc = GeoJSON.read(path, GeoJSON.FeatureCollection{2,Float64,Geom,Props})
GeoJSON.properties(fc[1]).NAME                    # ::Union{Missing,String}
```

A property field absent from a feature reads as `missing`, so each `NamedTuple` field type is
`Union{Missing,T}`. A geometry kind outside `G` is an error that names the kind and the schema.
`P = Nothing` skips the `"properties"` member without parsing it; `Feature{D,T,G,P}` and every
geometry type are valid targets too.

## Keyword sugar

The keyword form of [`read`](@ref) builds the same target type at run time:

| keyword form | target type |
|---|---|
| `read(src)` | `FeatureCollection{D,Float64,AnyGeometry{D,Float64},Dict{String,Any}}`, `D` discovered |
| `read(src; ndim=3, numbertype=Float32)` | `FeatureCollection{3,Float32,AnyGeometry{3,Float32},Dict{String,Any}}` |
| `read(src; geometries=(Point, Polygon))` | `G = Union{Point{D,T},Polygon{D,T}}` |
| `read(src; properties=false)` | `P = Nothing` |
| `read(src; properties=GeoJSON.Properties)` | `P = Properties`, document order |
| `read(src; properties=Props)` | `P = Props` |
| `read(src; lazy=true)` | `LazyFeatureCollection{...}` |

## What builds under `--trim=safe`

A trimmed binary contains only code the compiler can prove reachable from concrete types.

| form | trim |
|---|---|
| `read(src, FeatureCollection{D,T,G,P})` with any `G`, including `AnyGeometry{D,T}`, and `P` a `NamedTuple`, struct, `Dict{String,Any}`, `Properties`, or `Nothing` | builds |
| `read(src, LazyFeatureCollection{D,T,G,P})`, `read(src, LazyStream{D,T,G,P})` | builds |
| `write(x)` for any GeoJSON type | builds; a value in an `Any` container must be a type `read` stores (see [`GeoJSONStyle`](@ref)) |
| `read(src)` with `ndim` unspecified | JIT only: the dimension is discovered at run time |
| keyword sugar `ndim=`, `geometries=`, `properties=` | JIT only: the type is built at run time |

The `test/trim` package in the repository builds a binary from the schema form and checks for zero
verification errors and warnings.
