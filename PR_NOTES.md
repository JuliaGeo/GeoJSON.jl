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
| mmap | Dropped | Not needed for these goals. |
| Extras / foreign-member preservation | Dropped | Keep ignoring unknown members; avoid new fields and serialization policy. |
| Ordered `Properties` and string-keyed default properties | Dropped | Keep `Dict{Symbol,Any}`, dot access, and existing Tables behavior. |
| Float64 default, dimension discovery, `ndim=Val(N)` | Dropped | Keep Float32, `ndim=2`, and the 3D retry. |
| Feature-indexed dimension errors | Dropped | Keep the dimension check and existing warning/error interface without an extra scan. |
| `properties=false` / skipped-properties schema | Dropped | The verified trim path uses a concrete NamedTuple schema. |
| CRS removal | Dropped | Preserve CRS reading/writing and constructors. |
| Restricted IDs for ordinary features | Dropped | Keep the existing Any-valued ID field and ordinary serializer behavior. |
| New constructor, equality/hash, GeoInterface, table-order changes | Dropped | Outside the migration scope. Default collection schema still computes eagerly. |
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

The trim contract is a concrete NamedTuple property schema and a fixed union of
coordinate geometry types, as exercised by `test/trim`. It does not promise
trimming arbitrary user-defined values, the default dictionary/table API,
recursive GeometryCollections, or lazyfc. Schema write IDs are String, Int64,
Float64 or absent; custom dynamic values remain available to ordinary writes.

## Benchmarks

Julia 1.13.2, macOS aarch64, one Julia/thread/precompile task at a time.
10,000 features per input; 1.18 MB points with scalar properties, 1.26 MB mixed
Point/LineString/Polygon, 1.94 MB points with nested objects/arrays/Unicode/bools.
Identical eager Float64 reads on each branch, four warmups and median of 21
samples with GC before each sample. Times exclude compilation and GC setup.
Each cell is **milliseconds / allocated MiB / allocation count**.

| Input / operation | main | pr-128 | minimal |
|---|---:|---:|---:|
| large_fc / read | 47.26 / 21.41 / 570,012 | 6.97 / 9.45 / 100,022 | 19.84 / 12.25 / 220,028 |
| large_fc / write | 26.68 / 20.15 / 570,142 | 8.87 / 1.89 / 7 | 6.57 / 5.82 / 50,006 |
| mixed / read | 48.94 / 20.44 / 536,691 | 8.61 / 10.63 / 113,353 | 16.28 / 11.95 / 203,368 |
| mixed / write | 20.49 / 15.68 / 360,237 | 12.02 / 3.73 / 10,006 | 10.05 / 5.93 / 40,007 |
| properties / read | 69.62 / 33.62 / 890,012 | 14.75 / 17.19 / 310,014 | 42.96 / 26.75 / 520,021 |
| properties / write | 84.72 / 54.06 / 1,950,174 | 18.77 / 6.47 / 100,008 | 9.72 / 6.89 / 70,008 |

All default reads/writes beat main: reads are 1.6–3.0x faster and writes 2.0–8.7x
faster, with fewer allocated bytes and allocations throughout. Writes beat
pr-128 by 16–48%. Default reads are **1.9–2.9x slower than pr-128**, deliberately
preserving main's eager Tables schema and native symbol-keyed/nested dictionary
representation. This does not meet the 10% target for the default API.

The separately measured, unchanged table-schema pass costs 13.05 / 11.31 / 23.28
ms for the three inputs. The optional explicit dictionary schema parses every
property but discovers table metadata only when requested:

| Input | Minimal explicit schema read (ms) | pr-128 default read (ms) |
|---|---:|---:|
| large_fc | 6.44 | 6.97 |
| mixed | 6.85 | 8.61 |
| properties | 16.36 | 14.75 |

This schema is `FeatureCollection{2,Float64,AbstractGeometry{2,Float64},Dict{Symbol,Any}}`;
all benchmark inputs have non-null properties. It is faster than pr-128 on the
first two cases and about 11% slower on nested properties. Retaining nested
`Dict{String,Any}` (verified on main), instead of pr-128's JSON.Object, trades some
allocations for compatibility. The default-reader gap is therefore mainly the
preserved table contract, not coordinate parsing. The benchmark's optional
`schema` argument reproduces both diagnostics; they are separate timings, not an
exact additive decomposition of the default read.

Reproduce sequentially in checkouts of main, pr-128, and this branch:

```sh
julia --project=CHECKOUT benchmark/bench.jl LABEL
julia --project=. benchmark/bench.jl minimal schema
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
or warnings. The native smoke test covers Polygon/MultiPolygon, nullable typed
properties, ID, CRS, writing, rereading, and checks the round-tripped coordinate,
property and ID values. Five harness checks pass; there is no fallback build.
The small fixture replaces PR #128's large country dataset. Run:

```sh
julia --project=test/trim -e 'using Pkg; Pkg.instantiate(); include("test/trim/runtests.jl")'
```

`GKSwstype=100 julia --startup-file=no --project=. -e 'using Pkg; Pkg.test()'`
passed **523 checks**: 56 parser/API, 184 numeric, 2 long-path, 37 schema/API,
7 writer compatibility, 3 schema property types, and 234 original package/Aqua/
GeoInterface/Tables/plotting checks. The lazy length allocation guard fails on
main (80 bytes) and passes here (less than 32 bytes). The final trim harness also
passed all 5 checks. No required test was skipped.

Context7 was attempted with the full migration question; the runner rejected
npm with HTTP 403. API verification used the installed JSON.jl, StructUtils,
and JuliaC source and actual package/trim runs.

## Diff against main

Without this coordinator-only notes file: **22 files, +1096 / −489**
(1,585 changed lines; **73.4% less churn** than PR #128's
40 files, +4,842 / −1,121). The complete committed diff, including notes:

<!-- diffstat -->
```text
 .github/workflows/Trim.yml               |  19 ++
 .gitignore                               |   3 +
 CHANGELOG.md                             |  16 ++
 PR_NOTES.md                              | 188 ++++++++++++++
 Project.toml                             |  16 +-
 README.md                                |   2 +-
 benchmark/bench.jl                       |  50 ++++
 docs/src/index.md                        |  32 +++
 src/GeoJSON.jl                           |   3 +-
 src/geojson_types.jl                     |  83 +++---
 src/io.jl                                |  48 +++-
 src/json.jl                              | 432 +++++++++++++++++++++++++++++++
 src/precompile.jl                        | 400 +---------------------------
 src/table.jl                             |   8 +-
 src/utils.jl                             | 134 ++++++++--
 test/json.jl                             | 195 ++++++++++++++
 test/runtests.jl                         |   4 +-
 test/schema.jl                           |  66 +++++
 test/trim/Project.toml                   |   7 +
 test/trim/TrimGeoJSON/Project.toml       |   9 +
 test/trim/TrimGeoJSON/src/TrimGeoJSON.jl |  28 ++
 test/trim/data.geojson                   |   1 +
 test/trim/runtests.jl                    |  29 +++
 23 files changed, 1284 insertions(+), 489 deletions(-)
```
<!-- /diffstat -->

## Proposed PR description

Migrate GeoJSON parsing and writing to JSON.jl 1.x while preserving Float32
coordinates, symbol-keyed properties, CRS, lazyfc, and existing constructors.
Add a schema-typed read/write path for safe trimming, without the new lazy tier,
foreign-member storage, or broad API changes from the original rewrite.

Validation: package tests, a compiled schema read/write round trip under
`--trim=safe`, and warmed read/write/allocation comparisons against main and
PR #128. Default reads retain eager Tables schema computation; its measured cost
explains the remaining gap to PR #128. Writes and reads beat main.

## Delivery

The factory sandbox denies writes to the shared repository's `.git`. Commits
and branch `json-v1-minimal` are stored in `dev/commits.git`, with this same working
tree. `dev/json-v1-minimal.bundle` contains the branch commits relative to main;
the coordinator can import it with `git fetch /absolute/path/to/bundle
json-v1-minimal:json-v1-minimal`. Source changes are also visible in the assigned
worktree. No user permission was declined and nothing was pushed.

Maintainer consideration: whether preserving eager default table metadata is
worth its measured read cost. A future separately reviewed lazy-schema change
could narrow that gap without expanding this migration.
