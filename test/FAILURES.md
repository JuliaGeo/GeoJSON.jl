# Test failures

Written by T3 (GeoInterface, Tables, Aqua). Each entry gives the failing test, the expectation, the
observed value, the suspected source, and a verdict on whether the test or the code disagrees with
the contract in `spikes/EXECUTION.md`.

Run: `test/geointerface.jl` 221 pass / 2 fail, `test/tables.jl` 110 pass / 0 fail,
`test/aqua.jl` 8 pass / 3 fail.

## `GI.nhole` on a Polygon without rings returns -1

- Test: `test/geointerface.jl`, testset `GeoInterface / getexterior, nhole and gethole`
- Expected: `GI.nhole(Polygon{2,Float64}(nothing, Vector{NTuple{2,Float64}}[])) == 0`, and the same
  for `Polygon{2,Float64}(nothing, nothing)`
- Got: `-1` in both cases
- Source: `src/geointerface.jl:30`, `GI.nhole(::GI.PolygonTrait, g::Polygon) = _ngeom(g) - 1`
- Verdict: code. A hole count is a cardinality, so an empty polygon has zero holes;
  `max(_ngeom(g) - 1, 0)` restores the invariant. This is the same empty-polygon case the plan fixes
  for `GI.ncoord`, which already returns `D` here.

## Aqua: 10 method ambiguities in the writer

- Test: `test/aqua.jl`, testset `Aqua / Method ambiguity`
- Expected: `iszero(num_ambiguities)`
- Got: 10, every one between `GeoJSON.applyeach(st::JSON.JSONStyle, f, x::T)` and
  `StructUtils.applyeach(f, st::StructUtils.StructStyle, x)`
- Source: `src/write.jl:45` (`Elements`), `:83` (`Point`, `LineString`, `MultiPoint`, `Polygon`,
  `MultiLineString`, `MultiPolygon`), `:91` (`GeometryCollection`), `:98` (`Feature`), `:107`
  (`FeatureCollection`)
- Verdict: code (WP2). `applyeach(st, f, x)` and `applyeach(f, st, x)` both match a call whose first
  two arguments are a style and a callable. Aqua's suggested fix is a three-argument method pinned to
  `(::JSON.JSONStyle, ::StructUtils.StructStyle, ::T)`; upstream argument order for `applyeach` needs
  a decision before the writer can be Aqua-clean.

## Aqua: 12 methods with unbound type parameters

- Test: `test/aqua.jl`, testset `Aqua / Unbound type parameters`
- Expected: no unbound parameters
- Got: 12 methods, all binding `D` and `T` only through an `NTuple{D,T}` element type
- Source:
  - `src/types.jl:37`, the six `X(; coordinates::C, bbox, extras) where {D,T}` constructors
  - `src/read/points.jl:44,64,78,79,80` (`readpoint`, `readcoords`, `readring`, `readsurface`,
    `readsolid`)
  - `src/read/geometry.jl:239` (`make` for `Union{Nothing,G}`)
- Verdict: code (WP0, WP1), low severity. The methods work — `GeoJSON.Point(coordinates=(1.0, 2.0))`
  returns `Point{2,Float64}` — because `D` is solved from the tuple length at dispatch. Aqua's static
  check counts a `Vararg` length parameter as unbound. Silencing it means
  `Aqua.test_unbound_args(GeoJSON; broken=true)` or a signature that takes `Val{D}`.

## Aqua: type piracy on `StructUtils.make`

- Test: `test/aqua.jl`, testset `Aqua / Piracy`
- Expected: no piracies
- Got: `make(st::JSON.JSONStyle, ::Type{Union{Nothing,G}}, src::JSON.LazyValues) where {D,T,G<:AbstractGeometry{D,T}}`
- Source: `src/read/geometry.jl:239`
- Verdict: code (WP1), reported rather than silenced per the brief. Every argument belongs to another
  package: the function is StructUtils', the style is JSON's, and `Union{Nothing,G}` is a Base `Union`
  even though `G` is ours. Dispatching on a wrapper that GeoJSON owns, or on `Type{G}` with the
  `Nothing` case handled by the caller, would make the method legitimately ours.

## `using DataAPI` is unavailable under `Pkg.test()`

- Test: `test/geointerface.jl` and `test/tables.jl` both load DataAPI for the metadata testsets
- Expected: the test environment resolves DataAPI
- Got: DataAPI is an indirect dependency (through Tables and GeoInterface) and is absent from both
  `[deps]` and `[extras]`, so `Pkg.test()` will fail at the `using` line
- Source: `Project.toml` (WP0)
- Verdict: infrastructure. Add `DataAPI = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"` to `[extras]` and
  `"DataAPI"` to the `test` target. Both files pass in a temp environment that adds it explicitly.
- Status: the working tree already carries this addition, uncommitted, from another agent.

## Open questions

- **Row column order versus table column order.** `propertynames(::Feature)` is
  `(:geometry, properties...)` while `Tables.schema(::FeatureCollection)` is
  `(properties..., :geometry)`, so `Tables.getcolumn(feature, 1)` returns the geometry while column 1
  of the table is the first property. Both orders are contractual, and materialization is unaffected
  because `Tables.eachcolumn` resolves by name; a consumer that indexes a row by schema position gets
  the wrong column. `test/tables.jl` asserts each side against its own contract.
- **Unlocated points.** `GI.testgeometry(Point{2,Float64}(nothing, nothing))` throws
  `MethodError: getindex(::Nothing, ::Int64)` from `GI.getcoord` at `src/geointerface.jl:17`, because
  `GI.ncoord` promises `D` coordinates that the geometry does not hold. GeoJSON allows
  `{"type": "Point", "coordinates": []}`, so the reader's representation of it decides whether this
  needs a fix. Every other geometry type with empty or `nothing` coordinates passes `GI.testgeometry`.

## Intentional changes observed

Behaviors that differ from 0.8.4 by design, encoded in the new tests rather than reported as failures.

- **`Float64` is the default number type.** All fixtures use `Float64` literals and
  `Point{2,Float64}`; 0.8.4 asserted `Tuple{Float32,Float32}` coordinates throughout.
- **`properties(f)` returns `Properties`.** An insertion-ordered `AbstractDict{String,Any}`, so
  `GI.properties(f)["name"]` replaces 0.8.4's `properties isa Dict{Symbol,Any}` and `properties[:name]`.
  `f.name` still works through `getproperty`.
- **Column order is document order with `geometry` last.** `propertynames(fc)`,
  `Tables.columnnames(fc)` and `Tables.schema(fc).names` are deterministic, so the tests compare
  ordered names directly where 0.8.4 had to `sort` them.
- **`GI.ncoord` on an empty Polygon returns `D`** instead of throwing.
- **`@inferred GeoJSON.geometry(f)` carries an explicit type.** The field is `Union{Nothing,G}` by
  contract, so the test is written as
  `@inferred(Union{Nothing,Point{2,Float64}}, GeoJSON.geometry(f))`; the bare form fails because
  `@inferred` demands the inferred type equal `typeof(result)`.

# T1: the ported 0.8.4 suite

`test/runtests.jl` runs 272 assertions across 18 testsets, all passing, so it contributes no
`@test_broken`. Every expectation that moved is an intentional change and is recorded in
`test/CHANGES.md` instead.

Full run, `julia --project=. -e 'using Pkg; Pkg.test()'`: 611 pass / 5 fail / 0 broken. The five
failures are the ones already reported above, all from `test/geointerface.jl` and `test/aqua.jl`.

- **`using DataAPI` is unavailable under `Pkg.test()`** — resolved. `DataAPI` is now in `[extras]`,
  `[compat]` and the `test` target of `Project.toml`, committed with the ported suite.

# WP5/T4: trim verification

`test/trim_tests.jl` builds `test/trim/TrimGeoJSON` with JuliaC 0.3.10 on Julia 1.13.0 under
`--trim=safe`, once with the writer and once read-only, and runs the binary on
`test/trim/data.geojson` (`ne_110m_countries`, 177 features).

| Build | Verifier | Build time | Binary |
|---|---|---|---|
| read (typed, `P = Nothing`) + read (`NamedTuple` schema) + `GeoJSON.write` | 22 errors, 0 warnings | 7.9 s | none |
| read (typed, `P = Nothing`) + read (`NamedTuple` schema) | 0 errors, 0 warnings | 8.5 s | 4,391,720 B |

The read-only binary prints `features 177`, `sumx 121572.13516100003`, `name Fiji`, equal to the
in-process values. Both reads verify clean, including the path-string entry through `_bytes` and
the `NamedTuple{(:NAME,:POP_EST),Tuple{Union{Missing,String},Union{Missing,Float64}}}` schema. All
22 errors are in `src/write.jl`; the two entries below account for every one. The lazy step is
absent because `src/lazy.jl` was empty when the package was written.

## Trim: writer lowers `Any`-valued extras through a dynamic call

- Test: `test/trim_tests.jl`, testset `Trim compile`, read+write build
- Expected: 0 errors / 0 warnings
- Got: 16 errors, one pair per `FeatureCollection`, `Feature`, `Polygon`, `MultiPolygon`, each
  counted twice across the two entrypoint roots:
  ```
  Verifier error #1: unresolved call from statement (StructUtils.lower)(st::JSON.JSONWriteStyle, Base.getfield(φ ()::Pair{String, Any}, 2)::Any)::Any
  Verifier error #2: unresolved call from statement (f::JSON.WriteClosure{JSON.WriteOptions{JSON.JSONWriteStyle}, false, GeoJSON.FeatureCollection{2, Float64, Union{GeoJSON.MultiPolygon{2, Float64}, GeoJSON.Polygon{2, Float64}}, Nothing}, Nothing})(Base.getfield(φ ()::Pair{String, Any}, 1)::String, (StructUtils.lower)(st::JSON.JSONWriteStyle, Base.getfield(φ ()::Pair{String, Any}, 2)::Any)::Any)::Nothing
  ```
- Source: `src/write.jl:76`, `_emitextras`: `f(k, StructUtils.lower(st, v))` over
  `Vector{Pair{String,Any}}`
- Verdict: code (WP2). `Extras` carries `Any` values by contract, so the trimmed writer needs a
  typed path: an `isa` ladder over the value types `applyvalue` produces (`String`, `Int64`,
  `Float64`, `Bool`, `Nothing`, `Vector{Any}`, `JSON.Object{String,Any}`), recursing for the two
  containers, is the shape trim-e2e's "Never do this" table prescribes. The alternative is a
  documented JIT-only status for extras on write plus a schema knob that drops them, which the trim
  package would then exercise.

## Trim: geometry members unresolved beneath a union-typed `"geometry"` emit

- Test: `test/trim_tests.jl`, testset `Trim compile`, read+write build
- Expected: 0 errors / 0 warnings
- Got: 6 errors, three per geometry type in the schema:
  ```
  Verifier error #5: unresolved invoke from statement (f::JSON.WriteClosure{JSON.WriteOptions{JSON.JSONWriteStyle}, false, GeoJSON.Polygon{2, Float64}, Nothing})("bbox", φ ()::JSON.Omit)::Nothing
  Verifier error #6: unresolved call from statement (f::JSON.WriteClosure{JSON.WriteOptions{JSON.JSONWriteStyle}, false, GeoJSON.Polygon{2, Float64}, Nothing})("bbox", φ ()::Union{JSON.Omit, GeoJSON.Elements{Vector{Float64}}})::Nothing
  Verifier error #7: unresolved call from statement (f::JSON.WriteClosure{JSON.WriteOptions{JSON.JSONWriteStyle}, false, GeoJSON.Polygon{2, Float64}, Nothing})("coordinates", φ ()::Union{Nothing, GeoJSON.Elements{Vector{Vector{Tuple{Float64, Float64}}}}})::Nothing
  Verifier error #10: unresolved invoke from statement (f::JSON.WriteClosure{JSON.WriteOptions{JSON.JSONWriteStyle}, false, GeoJSON.MultiPolygon{2, Float64}, Nothing})("bbox", φ ()::JSON.Omit)::Nothing
  Verifier error #11: unresolved call from statement (f::JSON.WriteClosure{JSON.WriteOptions{JSON.JSONWriteStyle}, false, GeoJSON.MultiPolygon{2, Float64}, Nothing})("bbox", φ ()::Union{JSON.Omit, GeoJSON.Elements{Vector{Float64}}})::Nothing
  Verifier error #12: unresolved call from statement (f::JSON.WriteClosure{JSON.WriteOptions{JSON.JSONWriteStyle}, false, GeoJSON.MultiPolygon{2, Float64}, Nothing})("coordinates", φ ()::Union{Nothing, GeoJSON.Elements{Vector{Vector{Vector{Tuple{Float64, Float64}}}}}})::Nothing
  ```
- Source: `src/write.jl:103`, `@emit "geometry" geometry(x)` hands
  `Union{Nothing,Polygon{2,Float64},MultiPolygon{2,Float64}}` to the write closure; the geometry
  writers at `src/write.jl:83-87` then hand `Union{JSON.Omit,Elements{Vector{T}}}` (`_bboxvalue`)
  and `Union{Nothing,Elements{…}}` (`_coordsvalue`) to theirs. The errors need both unions plus one
  array level above the `Feature`: a bare `Feature` or a bare geometry writes clean, and so does a
  `Vector{Polygon}`. Standalone replicas of the `write.jl` pattern (JSON 1.8.0, StructUtils 2.8.5,
  Julia 1.13.0, `JSON.json([feature])`):

  | `"geometry"` emit | geometry `bbox`/`coordinates` emit | Verifier |
  |---|---|---|
  | `Union{Nothing,Poly}` as is | `Omit`/`Elements` unions | 3 errors |
  | `Union{Nothing,Poly}` narrowed by `=== nothing` | `Omit`/`Elements` unions | clean |
  | `Union{Poly,Poly2}` as is, no `Nothing` | `Omit`/`Elements` unions | 6 errors |
  | `Union{Nothing,Poly,Poly2}` narrowed by `=== nothing` only | `Omit`/`Elements` unions | 6 errors |
  | `Union{Nothing,Poly,Poly2}` through an `isa` ladder | `Omit`/`Elements` unions | clean |
  | `Union{Nothing,Poly,Poly2}` through `@noinline` per-type emitters | `Omit`/`Elements` unions | clean |
  | `Union{Poly,Poly2}` as is | `bb === nothing \|\| @emit`, `if` on coordinates | clean |
  | `Union{Poly,Poly2}` as is | `Omit` kept, per-depth `Vector` `applyeach` | 6 errors |

- Verdict: code (WP2). Either change alone verifies clean: split the geometry union before the
  emit (an `isa` ladder over the members of `G`, or one `@noinline` emitter per geometry type), or
  emit `bbox` and `coordinates` from a narrowed local (`bb = bbox(x); bb === nothing || @emit "bbox"
  Elements(bb)`, an `if` for coordinates) as trim-e2e's writer does. The second also drops `Omit`
  from the hot path. The `Elements` wrapper, the geometry `Union` on its own, nullable coordinates,
  `id`, and the `Feature`-level `bbox` are each innocent.
