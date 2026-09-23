# Benchmark results: 0.9.0 against 0.8.4

Medians of Chairmarks `@be` over a 6 s budget (2 s for the small file), single-threaded, one fresh
process, on the three Natural Earth files. The 0.8.4 column is the JSON3-backed release measured with
the same script on the same machine. Other processes were running during the 0.9.0 run, so treat
differences under about 10 % as noise.

Reproduce with:

```
julia --project=benchmark -t 1 benchmark/bench.jl main <datadir>    # the per-file tables
julia --project=benchmark -t 1 benchmark/bench.jl ttfx <datadir>    # load + first-call latency
julia --project=benchmark -t 1 benchmark/bench.jl info              # versioninfo + Pkg.status
```

`<datadir>` (or `GEOJSON_BENCH_DATA`) holds `ne_110m_countries.geojson`, `ne_10m_countries.geojson`,
and `ne_10m_populated_places.geojson`. The `read` rows carrying a container name come from a later
run of the same script's `@be` form; the lazy rows (`lfc[i]`, `collect(lfc)`) were measured with
`Properties`, then the default.

## Datasets

| file | MB | features | coordinate points | properties/feature | points/feature |
|---|---:|---:|---:|---:|---:|
| ne_110m_countries | 0.8 | 177 | 10,654 | 168 | 60.2 |
| ne_10m_countries | 12.7 | 258 | 548,471 | 168 | 2125.9 |
| ne_10m_populated_places | 18.5 | 7,342 | 7,342 | 137 | 1.0 |

## Headline

| file | `read` 0.9.0 | `read` 0.8.4 | speedup | `write` 0.9.0 | `write` 0.8.4 | speedup |
|---|---:|---:|---:|---:|---:|---:|
| ne_110m_countries | 3.54 ms | 17.49 ms | 4.9× | 2.44 ms | 35.21 ms | 14.4× |
| ne_10m_countries | 60.04 ms | 60.72 ms | 1.01× | 71.41 ms | 99.19 ms | 1.39× |
| ne_10m_populated_places | 107.90 ms | 602.49 ms | 5.6× | 37.55 ms | 770.23 ms | 20.5× |

0.9.0 reads `Float64` into a `Dict{String,Any}` per feature by default; the 0.8.4 `read` row is its
`Float32` default. On the coordinate-heavy file the two releases are within noise of each other on
the read; the `properties=false` read there (56.9 ms) and the lazy scan (53.1 ms) show the
remaining time is the coordinate parse itself.

### Property container

Medians of the default read against `properties=GeoJSON.Properties`, the insertion-ordered
container, from one later run on the same machine:

| file | container | median | allocs | alloc MiB | input MB/s |
|---|---|---:|---:|---:|---:|
| ne_110m_countries | `Dict{String,Any}` (default) | 3.54 ms | 55.1 k | 6.1 | 226 |
| ne_110m_countries | `Properties` | 2.67 ms | 53.7 k | 4.1 | 299 |
| ne_10m_countries | `Dict{String,Any}` (default) | 60.04 ms | 107.2 k | 31.8 | 211 |
| ne_10m_countries | `Properties` | 55.89 ms | 105.1 k | 28.8 | 227 |
| ne_10m_populated_places | `Dict{String,Any}` (default) | 107.90 ms | 1.56 M | 88.6 | 171 |
| ne_10m_populated_places | `Properties` | 90.90 ms | 1.54 M | 127.9 | 203 |

Both containers fill through the same `applyvalue` sink; the `Dict` pays its hashing and rehash
growth (1.07–1.33×) and, on the property-heavy file, allocates fewer bytes.

## Latency (fresh process)

| step | 0.9.0 | 0.8.4 |
|---|---:|---:|
| `using GeoJSON` | 208 ms | 108.8 ms |
| first `GeoJSON.read`, 0.8 MB | 5.0 ms | 226.4 ms |
| second `GeoJSON.read`, same bytes | 5.2 ms | 34.8 ms |
| first `GeoJSON.write` | 4.2 ms | 170.4 ms |
| load + first read + first write | 217 ms | 505.6 ms |

The PrecompileTools workload in `src/precompile.jl` covers the interactive default path (2-D,
`Dict{String,Any}` properties, every geometry, `write`) and holds those first calls to their
steady-state time; a lazy, 3-D or `properties=false` first call compiles at run time. The package
image that workload produces is what raises the load time. Medians of five fresh processes:

| workload | `using GeoJSON` | image (`.so`) | first `read`, 0.8 MB | first `write` |
|---|---:|---:|---:|---:|
| every path (3-D, `properties=false`, lazy, `Val` variants) | 208 ms | 16.1 MB | 3.0 ms | 7.7 ms |
| default path only (shipped) | 208 ms | 14.3 MB | 5.0 ms | 4.2 ms |
| default path, `write` left out | 189 ms | 10.7 MB | 4.8 ms | 2045 ms |
| none | 64–72 ms | 1.2 MB | 5900 ms | 2489 ms |

The dependencies load in about 60 ms (`@time_imports`: JSON 10.5 ms, Dates 11.1 ms, Parsers 6.5 ms,
Tables 4.0 ms, GeoInterface 3.3 ms); the rest is GeoJSON's own image. Of its 14.3 MB, 1.05 MB is
native code and 11.5 MB is serialized Julia data: 7,999 cached specializations, dominated by
trivial callees (`Base.getproperty` 554, `Base.setproperty!` 408, `Base.convert` 248) and
`JSON.WriteClosure` (489), one per concrete `(key, value)` pair the writer's `isa` ladders hand it.

## ne_110m_countries.geojson — 0.8 MB, 177 features, 10.7 k coordinate points

| operation | 0.9.0 median | allocs | alloc MiB | ns/point | input MB/s | 0.8.4 median |
|---|---:|---:|---:|---:|---:|---:|
| `GeoJSON.read` (default: Float64, discovered ndim, `Dict{String,Any}`) | 3.54 ms | 55.1 k | 6.1 | 332 | 226 | 17.49 ms |
| `GeoJSON.read(; properties=GeoJSON.Properties)` | 2.67 ms | 53.7 k | 4.1 | 251 | 299 | — |
| `GeoJSON.read(bytes, FeatureCollection{2,Float64,AnyGeometry{2,Float64},Nothing})` | 1.82 ms | 3.1 k | 0.6 | 171 | 440 | — |
| `GeoJSON.read(; lazy=true)` | 1.74 ms | 44 | 0.0 | 163 | 460 | 2.36 ms |
|   ↳ `lfc[1]` (parse one feature) | 11.27 µs | 308 | 0.0 | — | — | 29.25 µs |
|   ↳ parse all via `lfc[i]` | 2.82 ms | 53.7 k | 4.1 | 264 | 284 | 5.96 ms |
|   ↳ `collect(lfc)` | 3.00 ms | 53.7 k | 4.1 | 281 | 267 | 6.16 ms |
| `GeoJSON.write(fc)` | 2.44 ms | 196 | 1.2 | 229 | 328 | 35.21 ms |
| `JSON.parse` (untyped) | 4.58 ms | 152.7 k | 7.4 | 430 | 175 | 3.73 ms |

## ne_10m_countries.geojson — 12.7 MB, 258 features, 548.5 k coordinate points

| operation | 0.9.0 median | allocs | alloc MiB | ns/point | input MB/s | 0.8.4 median |
|---|---:|---:|---:|---:|---:|---:|
| `GeoJSON.read` (default: `Dict{String,Any}`) | 60.04 ms | 107.2 k | 31.8 | 109 | 211 | 60.72 ms |
| `GeoJSON.read(; properties=GeoJSON.Properties)` | 55.89 ms | 105.1 k | 28.8 | 102 | 227 | — |
| `GeoJSON.read(bytes, FeatureCollection{2,Float64,AnyGeometry{2,Float64},Nothing})` | 56.88 ms | 31.1 k | 23.7 | 104 | 223 | — |
| `GeoJSON.read(; lazy=true)` | 53.06 ms | 44 | 0.0 | 97 | 239 | 61.97 ms |
|   ↳ `lfc[1]` (parse one feature) | 2.25 ms | 2.1 k | 0.9 | — | — | 1.35 ms |
|   ↳ parse all via `lfc[i]` | 64.38 ms | 105.1 k | 28.8 | 117 | 197 | 50.98 ms |
|   ↳ `collect(lfc)` | 61.99 ms | 105.1 k | 28.8 | 113 | 204 | 51.36 ms |
| `GeoJSON.write(fc)` | 71.41 ms | 277 | 24.1 | 130 | 177 | 99.19 ms |
| `JSON.parse` (untyped) | 228.62 ms | 3.44 M | 185.5 | 417 | 55 | 185.96 ms |

## ne_10m_populated_places.geojson — 18.5 MB, 7.3 k features, 7.3 k coordinate points

| operation | 0.9.0 median | allocs | alloc MiB | ns/point | input MB/s | 0.8.4 median |
|---|---:|---:|---:|---:|---:|---:|
| `GeoJSON.read` (default: `Dict{String,Any}`) | 107.90 ms | 1.56 M | 88.6 | 14696 | 171 | 602.49 ms |
| `GeoJSON.read(; properties=GeoJSON.Properties)` | 90.90 ms | 1.54 M | 127.9 | 12381 | 203 | — |
| `GeoJSON.read(bytes, FeatureCollection{2,Float64,AnyGeometry{2,Float64},Nothing})` | 26.56 ms | 44.1 k | 3.6 | 3618 | 695 | — |
| `GeoJSON.read(; lazy=true)` | 27.02 ms | 49 | 0.2 | 3680 | 683 | 44.62 ms |
|   ↳ `lfc[1]` (parse one feature) | 7.57 µs | 196 | 0.0 | — | — | 22.23 µs |
|   ↳ parse all via `lfc[i]` | 92.71 ms | 1.54 M | 127.2 | 12627 | 199 | 191.26 ms |
|   ↳ `collect(lfc)` | 105.28 ms | 1.54 M | 127.2 | 14339 | 175 | 519.44 ms |
| `GeoJSON.write(fc)` | 37.55 ms | 7.4 k | 25.8 | 5114 | 492 | 770.23 ms |
| `JSON.parse` (untyped) | 155.81 ms | 2.84 M | 134.6 | 21222 | 118 | 110.01 ms |

## Machine

Both runs used the same machine and Julia build; the `JSON.parse` rows, which are the same code in both
releases, put the load-dependent drift between the two runs at 20–40 %.

```
Julia Version 1.13.0
Commit d1c37793dd2 (2026-09-09 19:00 UTC)
Build Info:
  Official https://julialang.org release
Platform Info:
  OS: Linux (x86_64-linux-gnu)
  CPU: 16 × AMD Ryzen 7 5800XT 8-Core Processor
  WORD_SIZE: 64
  LLVM: libLLVM-20.1.8 (ORCJIT, znver3)
  GC: Built with stock GC
Threads: 1 default, 0 interactive, 1 GC (on 16 virtual cores)
Environment:
  JULIA_PKG_USE_CLI_GIT = true
  JULIA_PKG_SERVER_REGISTRY_PREFERENCE = eager
  JULIA_NUM_THREADS = 8
```

```
Status `benchmark/Project.toml`
  [0ca39b1e] Chairmarks v1.3.1
  [cf35fbd7] GeoInterface v1.6.2
  [61d90e0f] GeoJSON v0.9.0 `..`
  [682c06a0] JSON v1.8.0
  [10745b16] Statistics v1.11.5
  [b77e0a4c] InteractiveUtils v1.11.0
  [de0858da] Printf v1.11.0
```
