# Changelog

## 0.9.0

GeoJSON.jl 0.9 is a rewrite of the reader and writer on [JSON.jl](https://github.com/JuliaIO/JSON.jl) 1.x
and [StructUtils.jl](https://github.com/JuliaData/StructUtils.jl). The reader parses from the JSON.jl lazy
layer straight into GeoJSON's own types; the writer describes those types to the JSON.jl writer through
`StructUtils.applyeach`. The target type is the schema: `read(src, FeatureCollection{D,T,G,P})` names the
dimension, number type, geometry union, and property container, and that form builds under
`juliac --trim=safe`. JSON3.jl and StructTypes.jl leave the dependency list; JSON.jl 1.8, StructUtils 2.8.5,
and PrecompileTools join it.

### Breaking

- The default `numbertype` is `Float64`; `numbertype=Float32` restores the 0.8 element type.
- `Feature` and `FeatureCollection` carry four parameters, `{D,T,G,P}`: geometry type `G` and property
  container `P` join dimension `D` and number type `T`. `Feature{2}`, `Feature{2,Float64}` and
  `AbstractGeometry{2}` still dispatch, and `Feature{D,T}(...)` fills `G=AnyGeometry{D,T}`, `P=Properties`.
- `properties(f)` returns `Properties`, an insertion-ordered `AbstractDict{String,Any}`, in place of
  `Dict{Symbol,Any}`. Lookups accept `String` and `Symbol` keys; `f.name` keeps working.
- Property iteration, `propertynames(f)`, and Tables.jl columns follow document order.
- Foreign members are preserved in `extras(x)` and written back; `==` compares them. Every geometry
  gains an `extras` field, so `propertynames(::Point)` is `(:bbox, :coordinates, :extras)`.
- `CRS` is gone as a type: a `"crs"` member is a foreign member of the collection. `GeoInterface.crs`
  still returns `EPSG(4326)`.
- Mixed-dimension input throws `DimMismatch`, which names the offending feature. The dimension is
  discovered from the first coordinate, replacing the 2D-then-3D retry.
- Writing a NamedTuple point promotes every coordinate to one type: `(X=1.0, Y=2.0, Z=3)` writes `[1.0,2.0,3.0]`.
- `lazyfc=true` is deprecated; use `lazy=true`.

### Added

- Schema-typed reads: `read(src, FeatureCollection{D,T,G,P})`, `read(src, Feature{D,T,G,P})`, and
  `read(src, ::Type{<:AbstractGeometry{D,T}})`. `G` is a geometry type or a union of them; `P` is
  `Properties`, `Nothing`, a `NamedTuple`, or a struct.
- `properties=false` (`P = Nothing`) skips the `"properties"` member without parsing it.
- `geometries=(Point, Polygon)` restricts the admitted geometry types and narrows the return type.
- `ndim=Val(N)` gives the keyword form an inferable return type.
- Lazy tier: `LazyFeatureCollection` keeps the bytes and one offset per feature, so `fc[i]` is O(1) and
  iteration O(n); `LazyFeature` parses one member per accessor; `LazyGeometry` answers `GeoInterface.geomtrait`
  without parsing coordinates; `LazyStream` walks a collection once under `foreach`. `lazyfeature`,
  `lazyfeatures`, `lazygeometry`, and `materialize` move between the tiers.
- `mmap=true` memory-maps a path; the collection borrows the mapped bytes.
- Foreign members on geometries, features, and collections are kept in `extras`, in document order.
- Static compilation: schema-typed reads, lazy reads, and `write` build under `juliac --trim=safe`
  with zero errors and warnings; `test/trim` holds the verification package.
- `write(::LazyFeatureCollection)`, and `write(path, x)` streams to the file.
- `write` keywords `pretty` (a `Bool` or an indent width) and `inline_limit` (short arrays stay on one line).
- A PrecompileTools workload covering 2D and 3D reads, `properties=false`, the lazy tier, and `write`.

### Fixed

- `write` emitted the internal `names` and `types` fields of a `FeatureCollection` as members.
- Lazy iteration and `collect` were O(n²): `length` copied the feature vector on every call.
- Reading from an `IO` drained the stream on the 2D attempt, so the 3D retry parsed nothing.
- Mixed-dimension input failed with an opaque `Float32` parse error; it now throws `DimMismatch`.
- `GeoInterface.ncoord` on an empty `Polygon` threw; it returns `D`.
