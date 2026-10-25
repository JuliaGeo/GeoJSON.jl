# Run in an environment that develops the desired GeoJSON checkout and includes
# BenchmarkTools + DataFrames. Generate fixtures with benchmark/gen_data.jl first.
using GeoJSON, BenchmarkTools, DataFrames, Statistics, Printf, Tables
const datadir = get(ENV, "GEOJSON_BENCH_DATA", joinpath(ENV["TMPDIR"], "benchdata"))
function measure(label, f)
    f() # compile before timing/allocations
    trial = @benchmark $f() samples=15 evals=1 seconds=60
    @printf("%s,%.3f,%.3f,%d,%d\n", label, minimum(trial).time/1e6,
        median(trial).time/1e6, minimum(trial).memory, minimum(trial).allocs)
end
println("# Julia $VERSION GeoJSON $(pkgversion(GeoJSON)) $(pathof(GeoJSON))")
println("case,min_ms,median_ms,bytes,allocations")
for name in ("points10k", "polys2k_50", "bigpoly", "wide2k_100"), T in (Float32, Float64)
    s = read(joinpath(datadir, name * ".json"), String)
    x = GeoJSON.read(s; numbertype=T)
    measure("$name/$T/read", () -> GeoJSON.read(s; numbertype=T))
    measure("$name/$T/write", () -> GeoJSON.write(x))
    if get(ENV, "GEOJSON_BENCH_EXTRA", "false") == "true"
        lazy = GeoJSON.read(s; numbertype=T, lazyfc=true)
        measure("$name/$T/lazy", () -> GeoJSON.read(s; numbertype=T, lazyfc=true))
        measure("$name/$T/lazy[1]", () -> lazy[1])
        measure("$name/$T/schema", () -> Tables.schema(x))
        measure("$name/$T/DataFrame", () -> DataFrame(x))
    end
end
