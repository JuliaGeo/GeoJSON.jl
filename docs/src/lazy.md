```@meta
CurrentModule = GeoJSON
```

# Lazy reading

A [`LazyFeatureCollection`](@ref) is the document's bytes plus one byte offset per feature. The
read is a single structural scan that parses only the collection's `bbox` and foreign members;
each feature parses when you index it. It suits files where you need a few features, one
property column, or a single pass.

```julia
lfc = GeoJSON.read("places.geojson"; lazy=true)      # scan only; mmap=true maps the file

lfc[1]                        # Feature: one feature parse
for f in lfc ... end          # one parse per feature, O(n)
collect(lfc)                  # Vector{Feature}
lfc.NAME                      # one column, parsed from the properties of every feature
```

| access | cost | yields |
|---|---|---|
| `lfc[i]`, iteration, `collect`, `Tables.rows` | one feature parse per element | `Feature{D,T,G,P}` |
| `lazyfeature(lfc, i)`, `lazyfeatures(lfc)`, `foreach(f, lfc)` | none | [`LazyFeature`](@ref) |
| `Tables.schema(lfc)`, `lfc.column` | one pass over properties and geometry `"type"` | `Tables.Schema`, `Vector` |
| `features(lfc)`, `write(lfc)` | every feature | `Vector{Feature}`, JSON text |

## One feature at a time

A [`LazyFeature`](@ref) is a byte offset into the buffer. Each accessor walks the feature object
once and parses only the member it needs:

```julia
lf = GeoJSON.lazyfeature(lfc, 1)
lf.NAME                       # one property value
GeoJSON.geometry(lf)          # the geometry alone
GeoJSON.lazygeometry(lf)      # a LazyGeometry: geomtrait without parsing coordinates
GeoJSON.materialize(lf)       # the whole Feature
```

`foreach(f, lfc)` hands `f` every feature as a `LazyFeature` with no parsing up front. For a
single pass with no offset table at all, [`LazyStream`](@ref) walks the document once:

```julia
n = 0
foreach(GeoJSON.LazyStream("places.geojson")) do lf
    lf.POP_MAX > 1_000_000 && (n += 1)
end
```

## Schemas and lifetime

The lazy types take the same `{D,T,G,P}` parameters as the eager ones, so
`read(src, LazyFeatureCollection{2,Float64,Geom,Props})` is the trim-safe form; see
[Schemas and static compilation](@ref). With a `NamedTuple` or struct `P`, `lf.NAME` parses
that one field with its declared type.

Every lazy value borrows the buffer. Mutating it, or unmapping a memory-mapped one, invalidates
the collection and everything derived from it.
