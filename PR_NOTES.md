# Minimal JSON.jl migration

Based on `main` (`0da2f66`), using `pr-129`'s strict coordinate adapter and
`pr-128`'s schema/callback approach. `pr-127`'s materialized intermediate JSON
objects were avoided for performance. No push was performed.

## Scope compared with PR #128

| PR #128 feature | Decision | Reason |
|---|---|---|
| JSON.jl / StructUtils migration | Kept | Removes JSON3 and StructTypes; JSON >=1.10 provides the direct value callback used for symbol-keyed properties. |
| Direct typed coordinate parsing | Kept | Avoids intermediate coordinate trees, preserves Float32 rounding, and rejects truncated coordinates. Parsers 3 is a direct dependency. |
| `Feature{D,T,G,P}` / `FeatureCollection{D,T,G,P}` and typed read | Kept | Static geometry/property schemas make trim possible; old two-parameter constructors and partial dispatch remain. |
| Restricted geometry schemas | Kept in typed form | `G` supplies the allowed geometry types; no extra keyword API. |
| Schema-typed write | Kept | Explicit callbacks and a closed fallback for dynamic schema IDs/CRS values satisfy the verifier. Ordinary writes still permit custom property values. |
| `test/trim` | Kept, reduced | One tiny fixture and one build covering read + write + reread; no read-only fallback. Separate CI job avoids JuliaC in ordinary package tests. |
| New lazy feature/geometry/stream tier | Dropped | Not needed for eager speed or schema trimming. The existing `lazyfc` API remains supported without deprecation. |
| Deferred table schema discovery | Kept, reduced | Cache existing `names`/`types` on first metadata access; no new lazy geometry or feature API. |
| mmap | Dropped | Not needed for these goals. |
| Extras / foreign-member preservation | Dropped | Keep ignoring unknown members; avoid new fields and serialization policy. |
| Ordered `Properties` and string-keyed default properties | Dropped | Keep `Dict{Symbol,Any}`, dot access, and existing Tables behavior. |
| Float64 default, dimension discovery, `ndim=Val(N)` | Dropped | Keep Float32, `ndim=2`, and the 3D retry. |
| Feature-indexed dimension errors | Dropped | Keep the dimension check and existing warning/error interface without an extra scan. |
| `properties=false` / skipped-properties schema | Dropped | The verified trim path uses a concrete NamedTuple schema. |
| CRS removal | Dropped | Preserve CRS reading/writing and constructors. |
| Restricted IDs for ordinary features | Dropped | Keep the existing Any-valued ID field and ordinary serializer behavior. |
| New constructor, equality/hash, GeoInterface, table-order changes | Dropped | Outside the migration scope; retain the existing table interfaces. |
| Streaming file writes, pretty/inline options | Dropped | Preserve existing IO bytes-written behavior and avoid extra API. |
| PrecompileTools workload | Dropped | Seven lines of direct precompile hints replace the stale JSON3 hints; no direct PrecompileTools dependency. JSON itself still depends on it. |
| Internal collection fields omitted on write | Kept | JSON output must not include Tables metadata (`names`, `types`). |
| IO retry and lazy length fixes | Kept | Read an IO once before retrying and avoid copying the lazy vector on every length call. |
| Extensive docs, benchmark reports, large fixture and unrelated fixes | Dropped/reduced | Retain focused migration docs, regression tests, one small benchmark, and the minimal trim fixture. |

## Compatibility

The material type change is that fully specified `Feature{D,T}` and
`FeatureCollection{D,T}` are now partial types. Existing constructors, `isa`
checks, Float32 defaults, symbol-keyed properties, lazyfc, CRS, GeoInterface and
Tables entry points remain. Nested properties remain native Dict/Vector values.
The selected JSON versions require Julia >=1.10; this branch requires JSON >=1.10,
StructUtils >=2.9.2 and Parsers 3. The version is bumped to 0.9.0.

Collection schema discovery now runs on the first `Tables.schema`, `propertynames`,
`.names`, or `.types` access, for both default and schema-typed collections. Reads,
iteration/indexing and writes do not scan the properties. Existing `names` and
`types` fields keep their Vector/Dict types and identities. One `Ref{Bool}` tracks
initialization (including empty collections); the collection remains immutable
and non-isbits, but its internal layout gains one field. Direct `getfield` access
sees empty metadata until discovery; ordinary dot access preserves behavior.
The private cache field does not shadow feature properties with the same name.

A shared `ReentrantLock` protects every cache lookup and publication, avoiding an
unsynchronized fast-path read or a per-collection lock. Concurrent schema requests
are safe; first scans for different collections serialize. The read/write paths
never acquire this lock, and the typed trim path does not reach schema discovery.
As before, concurrent user mutation of properties or exposed metadata containers
is unsupported. The snapshot moves from construction to first metadata access:
changes before discovery are included, later changes do not invalidate it. This
small, documented timing/layout change buys the default-read speed improvement.

The trim contract is a concrete NamedTuple property schema and a fixed union of
coordinate geometry types, as exercised by `test/trim`. It does not promise
trimming arbitrary user-defined values, the default dictionary/table API,
recursive GeometryCollections, or lazyfc. Schema write IDs are String, Int64,
Float64 or absent; custom dynamic values remain available to ordinary writes.

## Benchmarks

Julia 1.13.2, macOS aarch64, one Julia/thread/precompile task at a time.
10,000 features per input; 1.18 MB points with scalar properties, 1.26 MB mixed
Point/LineString/Polygon, 1.94 MB points with nested objects/arrays/Unicode/bools.
Identical fully materialized Float64 reads on each branch, four warmups and
median of 21 samples with GC before each sample. Times exclude compilation and GC setup.
Each cell is **milliseconds / allocated MiB / allocation count**.

| Input / operation | main | pr-128 | minimal-v1 | minimal-v2 |
|---|---:|---:|---:|---:|
| large_fc / read | 47.20 / 21.41 / 570,012 | 6.63 / 9.45 / 100,022 | 23.92 / 12.25 / 220,028 | 6.24 / 8.13 / 120,022 |
| large_fc / write | 26.61 / 20.15 / 570,142 | 8.44 / 1.89 / 7 | 6.52 / 5.82 / 50,006 | 6.64 / 5.82 / 50,006 |
| mixed / read | 48.75 / 20.44 / 536,691 | 8.38 / 10.63 / 113,353 | 17.67 / 11.95 / 203,368 | 6.60 / 9.05 / 133,353 |
| mixed / write | 20.22 / 15.68 / 360,237 | 11.82 / 3.73 / 10,006 | 10.14 / 5.93 / 40,007 | 9.95 / 5.93 / 40,007 |
| properties / read | 69.93 / 33.62 / 890,012 | 14.61 / 17.19 / 310,014 | 46.70 / 26.75 / 520,021 | 15.59 / 20.19 / 360,015 |
| properties / write | 84.67 / 54.06 / 1,950,174 | 18.33 / 6.47 / 100,008 | 9.81 / 6.89 / 70,008 | 9.84 / 6.89 / 70,008 |

Minimal-v1 is the original `c6032ac` commit, archived into its own checkout;
minimal-v2 adds deferred metadata discovery. All four columns were rerun together
with the same script. The default reads fully materialize geometry and properties;
these timings exclude the now-deferred table-metadata scan.

Default v2 reads are **7.6x / 7.4x / 4.5x faster than main**, and **3.8x / 2.7x /
3.0x faster than v1**. Against PR #128 they are **5.9% faster / 21.2% faster / 6.7%
slower**, meeting the approximately 10% target on all inputs. The remaining nested
properties cost retains native `Dict{String,Any}` values (main's representation)
instead of PR #128's JSON.Object. The two simpler inputs allocate fewer bytes than
PR #128, while nested properties allocate 17.4% more; allocation counts remain
higher than PR #128 because the existing dictionary representation is retained.

Writes are **2.0–8.6x faster than main** and **16–46% faster than PR #128**.
Compared with v1, times differ by at most 1.9% (two slightly slower and one faster),
consistent with run-to-run noise; the writer implementation and allocation counts
are unchanged. Allocated bytes increase by just 16 per write.

The schema work is deferred, not eliminated: the first metadata request still
scans the full collection. Later metadata requests reuse the cached names/types;
`Tables.schema` still constructs its small Tables.Schema wrapper, as before.
Applications that immediately request a table schema still pay for that scan.
The optional `schema` benchmark argument measures the scan separately.

Reproduce sequentially in checkouts of main, PR #128, `c6032ac` and this branch:

```sh
julia --project=CHECKOUT benchmark/bench.jl LABEL
julia --compiled-modules=no --project=PR128_CHECKOUT benchmark/bench.jl pr-128
julia --project=. benchmark/bench.jl minimal-v2 schema
```

Main used JSON3 1.14.3 / StructTypes 1.11.1 / Parsers 2.8.8. Both migrations used
JSON 1.11.0 / StructUtils 2.10.0 / Parsers 3.0.0. The pristine pr-128 (`e321a3c`)
precompile workload fails on a removed `convert(String, ::JSON.PtrString)` method
in JSON 1.11. It was measured using `--compiled-modules=no`, with no source edits;
its workload is outside the warmed timings. The input deliberately needs no
foreign-member or lazy API workarounds. Main emits a few extra bytes of internal
collection metadata; the new branches omit it.

## Validation

Julia 1.13.2 / JuliaC 0.3.12 / JSON 1.11.0 / StructUtils 2.10.0 on macOS aarch64:
`juliac --trim=safe --experimental` built the executable with no verifier errors
or warnings. The run emitted the existing registry HTTP 403 and macOS libunwind
linker warnings; dependencies were available and the build succeeded. The native
smoke test covers Polygon/MultiPolygon, nullable typed properties, ID, CRS,
writing, rereading, and checks the round-tripped coordinate,
property and ID values. Five harness checks pass; there is no fallback build.
The small fixture replaces PR #128's large country dataset. Run:

```sh
julia --project=test/trim -e 'using Pkg; Pkg.instantiate(); include("test/trim/runtests.jl")'
```

`GKSwstype=100 julia --startup-file=no --project=. -e 'using Pkg; Pkg.test()'`
passed **569 checks**: 56 parser/API, 184 numeric, 2 long-path, 40 schema/API,
7 writer compatibility, 3 schema property types, 43 deferred-cache checks, and
234 original package/Aqua/GeoInterface/Tables/plotting checks. The lazy length
allocation guard fails on main (80 bytes) and passes here (less than 32 bytes).
The final trim harness passed all 5 checks. The 93 focused schema/writer/cache
checks also passed in a
separate `--threads=2` run (only one Julia process at a time). Against minimal-v1,
the new default-cache testset fails 4 assertions and errors on 4 missing schema
keys; the typed-cache identity assertions fail on all 3 input forms. Tests cover
all four metadata entry points, heterogeneous/missing properties, post-discovery
mutation, empty collections, concurrent requests and cache-field name collisions.
No required test was skipped.

Context7 was attempted with the full migration question; the runner rejected
npm with HTTP 403. API verification used the installed JSON.jl, StructUtils,
and JuliaC source and actual package/trim runs.

## Diff against main

Without this coordinator-only notes file: **22 files, +1162 / −490**
(1,652 changed lines; **72.3% less churn** than PR #128's
40 files, +4,842 / −1,121). V1 without notes was +1096 / −489; deferring the
schema adds only **67 changed lines** to the shipping diff (4.2%). The complete
committed diff below includes notes; compare its total with v1's **+1284 / −489**.

<!-- diffstat -->
```text
 .github/workflows/Trim.yml               |  19 ++
 .gitignore                               |   3 +
 CHANGELOG.md                             |  20 ++
 PR_NOTES.md                              | 217 ++++++++++++++++
 Project.toml                             |  16 +-
 README.md                                |   2 +-
 benchmark/bench.jl                       |  50 ++++
 docs/src/index.md                        |  40 +++
 src/GeoJSON.jl                           |   3 +-
 src/geojson_types.jl                     |  89 +++----
 src/io.jl                                |  48 +++-
 src/json.jl                              | 432 +++++++++++++++++++++++++++++++
 src/precompile.jl                        | 400 +---------------------------
 src/table.jl                             |  18 +-
 src/utils.jl                             | 134 ++++++++--
 test/json.jl                             | 195 ++++++++++++++
 test/runtests.jl                         |   4 +-
 test/schema.jl                           | 105 ++++++++
 test/trim/Project.toml                   |   7 +
 test/trim/TrimGeoJSON/Project.toml       |   9 +
 test/trim/TrimGeoJSON/src/TrimGeoJSON.jl |  28 ++
 test/trim/data.geojson                   |   1 +
 test/trim/runtests.jl                    |  29 +++
 23 files changed, 1379 insertions(+), 490 deletions(-)
```
<!-- /diffstat -->

## Proposed PR description

Migrate GeoJSON parsing and writing to JSON.jl 1.x while preserving Float32
coordinates, symbol-keyed properties, CRS, lazyfc, and existing constructors.
Add a schema-typed read/write path for safe trimming, without the new lazy tier,
foreign-member storage, or broad API changes from the original rewrite.

Validation: package tests, a compiled schema read/write round trip under
`--trim=safe`, and warmed read/write/allocation comparisons against main and
PR #128 and the previous minimal version. Defer and cache Tables metadata until
first use, preserving the existing names/types API with synchronized discovery.
Default reads now meet the approximately 10% PR #128 target; writes are unchanged
and both operations beat main.

## Delivery

The original two commits (`4d2df8b`, `c6032ac`) were fetched from the local git
store onto the assigned factory branch; the cache change is committed on top.
No other branch was created and nothing was pushed. `dev/` remains ignored;
no bundle, git store, benchmark checkout, manifest, or log is committed.

No open maintainer decision is required. The documented deferred snapshot timing,
shared metadata lock and internal layout change are the compatibility trade-offs.
