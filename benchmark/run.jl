# julia benchmark/run.jl CHECKOUT_OR_REVISION
# Uses a temporary environment and fixed-seed data. Run revisions sequentially
# on the same machine and Julia version; each case warms up before measurement.
using Pkg
if !isempty(ARGS)
    target = abspath(ARGS[1])
    if !isdir(target)
        target = mktempdir()
        run(pipeline(`git archive $(ARGS[1])`, `tar -x -C $target`))
    end
    Pkg.activate(mktempdir())
    Pkg.develop(path=target)
    Pkg.add(["BenchmarkTools", "DataFrames", "Tables"])
end
using GeoJSON, BenchmarkTools, DataFrames, Statistics, Printf, Tables
const datadir = get(ENV, "GEOJSON_BENCH_DATA", joinpath(tempdir(), "geojson-benchdata"))
isfile(joinpath(datadir, "bigpoly.json")) || include("gen_data.jl")
function measure(label, f)
    f()
    trial = @benchmark $f() samples=15 evals=1 seconds=60
    @printf("| %s | %.3f | %.3f | %d | %d |\n", label,
        minimum(trial).time / 1e6, median(trial).time / 1e6,
        minimum(trial).memory, minimum(trial).allocs)
end
println("Julia $VERSION, GeoJSON $(pkgversion(GeoJSON))")
println("| Case | Minimum ms | Median ms | Bytes | Allocations |")
println("|:-----|-----------:|----------:|------:|------------:|")
for name in ("points10k", "polys2k_50", "bigpoly", "wide2k_100"), T in (Float32, Float64)
    s = read(joinpath(datadir, name * ".json"), String)
    x = GeoJSON.read(s; numbertype=T)
    measure("$name $T read", () -> GeoJSON.read(s; numbertype=T))
    measure("$name $T write", () -> GeoJSON.write(x))
    if get(ENV, "GEOJSON_BENCH_EXTRA", "false") == "true"
        lazy = GeoJSON.read(s; numbertype=T, lazyfc=true)
        measure("$name $T lazy", () -> GeoJSON.read(s; numbertype=T, lazyfc=true))
        measure("$name $T lazy first feature", () -> lazy[1])
        measure("$name $T schema", () -> Tables.schema(x))
        measure("$name $T DataFrame", () -> DataFrame(x))
    end
end
