# Changelog

## Unreleased

- Bind inferred positional `Feature` constructors to a non-null geometry; null
  geometry requires explicit `Feature{D,T}` or `Feature{D,T,P}` parameters.
- Replace JSON3/StructTypes with JSON.jl 1.x/StructUtils. Julia 1.10 or later is
  required. Keep Float32 coordinates, symbol-keyed properties, CRS, `lazyfc`,
  existing constructors, and GeoInterface/Tables behavior by default.
- Add schema-typed `read(source, FeatureCollection{D,T,P})`, `Feature{D,T,P}`,
  and concrete geometry reads for static compilation. Feature and collection
  types gain a property parameter; two-parameter constructors remain.
- Spike `Geometry{D,T}`, a union of the seven spec geometry kinds, in features
  and geometry collections. Feature types no longer depend on geometry subsets;
  migration-branch four-parameter schemas must drop `G` and use `geometrytype`
  for geometry-subset validation. GeometryCollection iteration now
  correctly visits its children, including nested collections.
- Add `read(source; geometrytype=Polygon)` and the same keyword for schema reads.
  Validate geometry kinds recursively without changing storage types; excluded
  kinds raise `ArgumentError`, null remains allowed. Restrictions require eager
  reads (`lazyfc=false`). Custom geometry subtypes still need external storage
  or conversion to built-in kinds.
- Use JSON.jl's direct parser and serializer; keep strict coordinate dimensions
  and Float32 rounding. Foreign members remain ignored.
- Exclude internal collection `names`/`types` from JSON output. Retain the IO
  bytes-written return value and preserve null geometry/properties.
- Buffer IO once so a 3D retry works. Preserve long file paths and buffer lifetime
  for lazy feature spans. Avoid copying the lazy feature vector for `length`.
- Discover and cache collection table metadata on first `Tables.schema`,
  `propertynames`, `.names`, or `.types` access, rather than during parsing.
  Initialization is synchronized; property changes before first access are
  reflected in the schema. Later changes do not invalidate the cached snapshot.
