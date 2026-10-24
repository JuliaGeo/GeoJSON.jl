# Small-union geometry spike

## Scope and measurement

Baseline **B** is PR #128 at `d52e7b1`; union **U** is `f1241f9` (production
layout introduced in `2ae28cc`). Julia 1.13.2, Linux x86_64, Ryzen 5 3600,
one Julia workload at a time per worker, one Julia thread. Dependencies include
JSON 1.12.2, StructUtils 2.11.1, GeoInterface 1.6.2 and Tables 1.14.0.

`Geometry{D,T}` is the closed union of all seven spec kinds, including recursive
`GeometryCollection{D,T}`. Collections store a vector of that union; feature and
feature-collection types become `{D,T,P}`. Two-parameter constructors, nulls,
GeoInterface and Tables behavior remain covered. Four-parameter migration-branch
schemas must drop `G`; restricted geometry validation is lost. Custom subtypes of
`AbstractGeometry` can no longer be stored in these closed fields.

Each variant/mode runs in a fresh process with precompiled package caches.
`benchmark/compile_latency.jl` reads synthetic file contents: 100 features with
nested mixed GeometryCollections, 200 Polygon/MultiPolygon features, 100 Polygons,
200 Points/LineStrings, then 800 interleaved features. It measures read, iteration
with a geometry count, and a GeoInterface coordinates walk with a length checksum.
Input construction is outside the timer. `Base.invokelatest` keeps workload
compilation inside `@timed`; without this barrier a typed closure could compile
before the timer. Compile time uses `Base.cumulative_compile_timing(true)`.
Specializations are newly cached `MethodInstance`s of discoverable GeoJSON-owned
methods, including extensions to Base/GI/JSON/StructUtils/Tables: a package-local
proxy, **not** a count of all compiler/native-code instances. Package load is
recorded separately in CSV, excluded from the totals below.

## Ordinary reads

| Input | First read ms B / U | First iterate ms B / U | GI coordinates ms B / U | Compile ms B / U | New specializations B / U |
|---|---:|---:|---:|---:|---:|
| collections | 4551.505 / 4420.365 | 11.149 / 11.229 | 239.295 / 364.387 | 4799.29 / 4789.21 | 68 / 84 |
| polygon_multi | 0.306 / 0.219 | 0.005 / 0.001 | 8.038 / 0.013 | 7.98 / 0.00 | 5 / 0 |
| polygons | 0.148 / 0.093 | 0.000 / 0.000 | 0.005 / 0.006 | 0.00 / 0.00 | 0 / 0 |
| point_line | 0.222 / 0.148 | 0.000 / 0.000 | 7.512 / 0.006 | 7.44 / 0.00 | 4 / 0 |
| interleaved | 15.578 / 1.057 | 0.001 / 0.001 | 3.661 / 11.320 | 0.03 / 0.03 | 0 / 0 |
| **Total compilation / specializations** | | | | 4814.73 / 4789.24 | 77 / 84 |

Ordinary baseline reads already use `AbstractGeometry{D,T}` as a fixed `G`.
Their feature types do not vary with file contents. This run shows essentially
unchanged total compilation (4.815 vs 4.789 seconds), with more package
specializations for the union (77 vs 84). The union front-loads the coordinates
walk: 364 vs 239 ms on the first collection mix. It does not provide a general
compile-time improvement for the default API.

## Explicit property schemas

For B, the experiment selects a geometry subset per file (`GeometryCollection`,
Polygon/MultiPolygon union, Polygon, Point/LineString union, then abstract geometry).
For U, every file uses the same `{2,Float64,P}`. This deliberately measures the
benefit of giving up geometry-subset precision, rather than ordinary-read behavior.

| Input | First read ms B / U | First iterate ms B / U | GI coordinates ms B / U | Compile ms B / U | New specializations B / U |
|---|---:|---:|---:|---:|---:|
| collections | 5660.592 / 6713.461 | 11.088 / 12.031 | 248.235 / 375.450 | 5917.59 / 7093.25 | 70 / 83 |
| polygon_multi | 1355.806 / 15.462 | 11.496 / 0.004 | 10.090 / 0.016 | 1377.16 / 0.00 | 24 / 0 |
| polygons | 481.589 / 0.087 | 11.481 / 0.000 | 9.247 / 0.006 | 502.18 / 0.00 | 19 / 0 |
| point_line | 484.952 / 0.135 | 11.462 / 0.000 | 12.547 / 0.007 | 508.79 / 0.00 | 23 / 0 |
| interleaved | 472.824 / 1.025 | 11.164 / 0.001 | 30.536 / 12.109 | 509.65 / 0.03 | 17 / 0 |
| **Total compilation / specializations** | | | | 8815.36 / 7093.27 | 153 / 83 |

Compilation falls from 8.815 to 7.093 seconds (19.5%); specialization growth falls
from 153 to 83 (45.8%). The first typed read grows from 5.661 to 6.713 seconds;
subsequent geometry mixes reuse the union feature type. A baseline caller can
also keep a fixed `G` across files; the per-file specialization cost is conditional
on choosing different explicit schemas.

## Steady state

`benchmark/bench.jl` retains its three existing datasets, adds iteration, warms
four times, and takes the median of 21 samples with GC outside each timer.
Both variants read Float64 coordinates eagerly.

| 10,000 features | Read ms B / U | Iterate µs B / U | Write ms B / U |
|---|---:|---:|---:|
| large_fc | 8.182 / 7.608 | 10.790 / 9.859 | 6.758 / 5.986 |
| mixed | 8.289 / 7.920 | 10.570 / 10.449 | 9.552 / 8.506 |
| properties | 18.034 / 17.654 | 17.213 / 18.245 | 12.015 / 11.139 |

Read allocation counts and bytes are identical. Union writes allocate 20,000
fewer objects and approximately 1.76 MB less per dataset in this run. Iteration is
allocation-free. The repeat below shows that small read/iteration timing differences are not uniform gains.
The first interleaved coordinates walk allocates about 1.80 MB for U versus
0.95 MB for B; closed unions do not guarantee better recursive broadcast behavior.

These geometry structs contain reference fields. `Geometry{2,Float64}` is not an
isbits union and does **not** gain inline isbits-union storage. A fixed union also
does not guarantee union splitting at every GeoInterface call or an inferred
concrete coordinates result; inspect the workload rather than assuming a
universal four-member rule. `results/union-layout.txt` confirms `isbitsunion=false`, `allocatedinline=false`,
all seven members non-isbits, and a 32-byte feature header. Inference preserves
the full nullable geometry union in the field getter; the GI coordinates return
is a broad union including array types.

## Repeat in independent fresh sessions

The same script was rerun locally after both Gemini workers were cancelled.
This is reproducibility evidence, **not** an independently authored experiment.

| Workload | Compile seconds B / U, run 1 | Compile seconds B / U, repeat | New package specializations B / U, both runs |
|---|---:|---:|---:|
| Ordinary | 4.815 / 4.789 | 4.687 / 4.967 | 77 / 84 |
| Varying explicit schemas | 8.815 / 7.093 | 9.199 / 7.017 | 153 / 83 |

Ordinary compile-time direction reverses in the repeat; there is no reliable
improvement. The varying-schema saving repeats at 19.5–23.7%, with identical
specialization counts. Steady-state timing differences also vary (some read
cases reverse direction); unchanged read allocations and reduced write
allocations repeat exactly. See `results/*-repeat.csv`.

## Tests

| Suite | Passed checks | Sum of reported testset times |
|---|---:|---:|
| PR #128 | 569 | 88.6 s |
| Retained/merged existing contracts | 390 | 83.6 s |
| New union and iteration regressions | 19 | 6.6 s |
| Final | **409** | **90.2 s** |

Counts decrease 28.1%. No overall cold-suite runtime win is demonstrated: the new
coverage offsets savings in the retained suites. Pkg.test wall times were 737.5 s
baseline and 114.0 s union; the baseline installed/precompiled the test dependency
stack, so that wall-time difference is **not** evidence of a code speedup. Times
above sum rounded testset reports and exclude imports/setup. Both Pkg.test runs
passed; raw summaries are in `results/*-tests.txt`.

Removed repeated numeric-token × position-shape and overflow × transport products,
mechanical subtype/coordinate-index assertions, repeated constructor/display
checks, no-assertion parse smoke loops, duplicate schema assertions for each
transport/accessor, and repeated plotting calls per feature. Retained strict
numeric grammar and rounding boundaries, one vector-scanner check, spec sample
roundtrips, nulls/empty collections, 3D, bbox/CRS, foreign members, IO/path handling,
lazy buffer lifetime and deferred errors, on-demand cached/concurrent schema
behavior, Tables missing/absent columns and metadata, GeoInterface conformance,
errors, and asserted smoke checks for both plotting extensions. Testset names
state their contracts. The added regression file isolates GeometryCollection's
existing `geometries(g)` iteration typo: it errors with `UndefVarError` on B
and passes on U (confirmed by the standalone baseline run and final Pkg.test).

## Reproduction

```sh
# Extract the baseline under an ignored task directory and instantiate it.
mkdir -p dev/baseline
git archive d52e7b1 | tar -x -C dev/baseline
julia --project=dev/baseline -e 'using Pkg; Pkg.instantiate()'
# Use baseline or . as CHECKOUT; run each command in a fresh Julia process.
julia --startup-file=no --project=CHECKOUT benchmark/compile_latency.jl LABEL default
julia --startup-file=no --project=CHECKOUT benchmark/compile_latency.jl LABEL schema
julia --startup-file=no --project=CHECKOUT benchmark/bench.jl LABEL
julia --project=. -e 'using Pkg; Pkg.test()'
julia --project=test/trim -e 'using Pkg; Pkg.instantiate(); include("test/trim/runtests.jl")'
```

Raw CSV files and test summaries are in `results/`.

## Verification and provisional recommendation

**Do not adopt the full replacement for #128 yet.** Ordinary-read compilation
is unchanged; the measured explicit-schema savings trade away geometry-subset
validation and increase the first typed-read cost. There is no inline-union
storage benefit. Both trim fixtures now build and run successfully, removing the
compiler blocker, but this establishes trim viability rather than a reason to
replace #128. Reassess after independent review; the API/validation tradeoffs and
ordinary-read compilation findings above still apply.

## Trim verification (2026-10-23)

**Both variants pass `--trim=safe` compilation, C linking and executable checks.**
The former missing-compiler blocker is resolved. This follow-up uses Julia 1.13.2,
JuliaC 0.3.12, PackageCompiler 2.4.5 and gcc 15.2.0 from `/usr/bin/gcc`;
clang 21.1.8 is also installed. The host and package dependency versions match
those recorded above. Baseline is the unmodified `d52e7b1`; union is the task's
starting HEAD `d0a93e1` (the same production layout as the earlier measurements).

| Variant | Executable bytes, warm build | Warm command wall time | Warm testset time | First command wall time |
|---|---:|---:|---:|---:|
| PR #128 baseline | 19,267,040 | 35.354 s | 33.9 s | 305.581 s |
| Small union | 21,051,080 | 38.081 s | 36.6 s | 61.528 s |

Each command runs serially in a fresh Julia process with one Julia thread.
Wall time includes `Pkg.instantiate()`, temporary fixture setup, the JuliaC build,
bundling and executable checks; testset time excludes outer environment setup.
These are build-and-test measurements, not isolated compiler timings. The first
baseline run installed dependencies and populated native/generic precompile
caches, so its wall time is not comparable with the first union run. The table's
warm repeat follows both first runs. Sizes use `stat` on `bin/trimgeojson`, without
stripping; they exclude runtime libraries (JuliaC reports 75.954 MiB of libraries
for each bundle). First-run executable sizes were 19,272,440 / 21,051,248 bytes;
byte-identical builds are not assumed.

Both warm suites pass **5/5** assertions. Baseline runs its original two-feature
Polygon/MultiPolygon input; union runs that input and `all-geometries.geojson`
(all seven geometry kinds, nested collections and null geometry/properties).
Both report `features 2`, `name Alpha`, `roundtrip 2`, `written 454`. Union also
reports `features 8`, `name Alpha`, `roundtrip 8`, `written 1235`. Each executable
reads, writes and rereads its input; its return code checks the first Polygon's
coordinate, property name and id. The harness checks feature counts and positive
serialized size. This does not assert equality of every feature field. The saved
warm executables were also rerun directly on these inputs with exit code 0.

**No trim warnings, unresolved-call diagnostics, or build/runtime errors were
reported in either run.** There is no union-only trim failure or remaining dynamic
dispatch reported by the safe-trim checker for this fixture. This is limited to
the fixture's reachable read/write paths, not a claim that every package API trims.
The union executable is about 9.3% larger in the warm run, but its schema and
fixture cover more geometry kinds than the baseline's restricted two-kind schema;
these sizes do not isolate the cost of the representation change.

The exact recorded Julia invocations were run baseline first, then union, with
external wall-clock timing and a file watcher to preserve the temporary binaries.
The same commands were repeated after caches warmed. Reproduce with:

```sh
# A detached temporary worktree; this does not change the spike branch's history.
mkdir -p dev
git worktree add --detach dev/baseline d52e7b1
for checkout in dev/baseline .; do julia --project="$checkout/test/trim" -e 'using Pkg; Pkg.instantiate(); include(joinpath(ARGS[1], "test/trim/runtests.jl"))' "$checkout" || exit $?; done
```

Here the shared Git metadata was read-only, so `dev/baseline` was instead made as
a detached worktree of a task-local shared clone of this repository. Its tracked
files remain unchanged. Raw warm logs, with temporary paths normalized, are in
`results/trim-baseline.txt` and `results/trim-union.txt`; timings and size definitions
are also summarized in `results/trim-status.txt`. No package behavior changed and
no regression test was added; this follow-up executes the existing trim tests.
The final `julia --project=. -e 'using Pkg; Pkg.test()'` also passes all
409 checks, including both plotting extensions; see `results/trim-package-tests.txt`.
Its fresh test environment precompiled 326 dependencies in 554 seconds, excluded
from the trim timings above.

Both requested agy/Gemini workers were launched, then cancelled by coordinator
instruction because their harness stopped on permission_denied while using tools.
No independent findings or second measurement were produced, so there are no
review disagreements to reconcile yet. Gemini review and independent testing
remain owed after the agy lights-off fix. Local fresh-session repeats are
reported above; they do not replace that independent second opinion.
