# Benchmark of GeoJSON.jl against the JSON.jl untyped floor on the Natural Earth files.
#
#   julia --project=benchmark -t 1 benchmark/bench.jl [main|ttfx|info] [datadir]
#
# `datadir` holds ne_110m_countries.geojson, ne_10m_countries.geojson and
# ne_10m_populated_places.geojson; it defaults to `ENV["GEOJSON_BENCH_DATA"]`.
# `BENCH_SECONDS` overrides the per-measurement budget.

mode = isempty(ARGS) ? "main" : ARGS[1]
const DATA = length(ARGS) > 1 ? ARGS[2] : get(ENV, "GEOJSON_BENCH_DATA", "")
const FILES = ["ne_110m_countries", "ne_10m_countries", "ne_10m_populated_places"]

isdir(DATA) || error("data directory not found: pass it as the second argument or set GEOJSON_BENCH_DATA")

if mode == "ttfx"
    t = @elapsed @eval using GeoJSON
    bytes = read(joinpath(DATA, "ne_110m_countries.geojson"))
    println("## Time to first X (fresh process)\n")
    println("`using GeoJSON`: ", round(t * 1000; digits = 1), " ms\n")
    for (label, ex) in (
        ("First `GeoJSON.read`, ne_110m_countries.geojson (0.8 MB)", :(fc = GeoJSON.read(bytes))),
        ("Second `GeoJSON.read`, same bytes", :(GeoJSON.read(bytes))),
        ("First `GeoJSON.read(; lazy=true)` and `fc[1]`", :(GeoJSON.read(bytes; lazy = true)[1])),
        ("First `GeoJSON.write`", :(GeoJSON.write(fc))),
    )
        println(label, ":\n\n```")
        @eval @time $ex
        println("```\n")
    end
    exit()
elseif mode == "info"
    using InteractiveUtils, Pkg
    print("```\n"); versioninfo(); print("```\n\n")
    print("```\n"); Pkg.status(); print("```\n")
    exit()
end

using GeoJSON, JSON, Chairmarks, Statistics, Printf
import GeoInterface as GI

npoints(g) = _np(GI.geomtrait(g), g)
_np(::Nothing, _) = 0
_np(::GI.PointTrait, _) = 1
_np(::GI.AbstractGeometryTrait, g) = sum(c -> _np(GI.geomtrait(c), c), GI.getgeom(g); init = 0)

fmt_time(t) = t < 1e-6 ? @sprintf("%.0f ns", t * 1e9) :
              t < 1e-3 ? @sprintf("%.2f µs", t * 1e6) :
              t < 1.0  ? @sprintf("%.2f ms", t * 1e3) : @sprintf("%.3f s", t)
fmt_n(n) = n >= 1e6 ? @sprintf("%.2f M", n / 1e6) :
           n >= 1e3 ? @sprintf("%.1f k", n / 1e3) : @sprintf("%d", n)
fmt_mib(b) = @sprintf("%.1f", b / 2^20)

struct Row
    op::String
    t::Float64
    allocs::Float64
    bytes::Float64
    perpoint::Bool   # normalise to ns/point and MB/s of input
end

function torow(op, b, perpoint)
    s = median(b)
    Row(op, s.time, s.allocs, s.bytes, perpoint)
end

function table(rows, nbytes, npts)
    println("| operation | median | allocs | alloc MiB | ns/point | input MB/s |")
    println("|---|---:|---:|---:|---:|---:|")
    for r in rows
        nsp = r.perpoint ? @sprintf("%.0f", r.t * 1e9 / npts) : "—"
        mbs = r.perpoint ? @sprintf("%.0f", nbytes / 2^20 / r.t) : "—"
        @printf("| %s | %s | %s | %s | %s | %s |\n",
                r.op, fmt_time(r.t), fmt_n(r.allocs), fmt_mib(r.bytes), nsp, mbs)
    end
    println()
end

const NoProps = GeoJSON.FeatureCollection{2,Float64,GeoJSON.AnyGeometry{2,Float64},Nothing}
parseall(lfc) = [lfc[i] for i in eachindex(lfc)]

function main()
    budget = parse(Float64, get(ENV, "BENCH_SECONDS", "0"))
    secs(nbytes) = budget > 0 ? budget : (nbytes > 4_000_000 ? 6.0 : 2.0)
    meta = []
    for name in FILES
        bytes = read(joinpath(DATA, name * ".geojson"))
        nbytes = length(bytes)
        S = secs(nbytes)

        fc = GeoJSON.read(bytes)
        nfeat = length(fc)
        npts = sum(f -> npoints(GI.geometry(f)), fc)
        nprops = length(GeoJSON.properties(fc[1]))
        push!(meta, (name, nbytes, nfeat, npts, nprops))

        lfc = GeoJSON.read(bytes; lazy = true)

        rows = Row[
            torow("`GeoJSON.read` (Float64, discovered ndim)", (@be bytes GeoJSON.read seconds = S), true),
            torow("`GeoJSON.read(bytes, FeatureCollection{2,Float64,AnyGeometry{2,Float64},Nothing})`",
                  (@be bytes GeoJSON.read(_, NoProps) seconds = S), true),
            torow("`GeoJSON.read(; lazy=true)`",
                  (@be bytes GeoJSON.read(_; lazy = true) seconds = S), true),
            torow("  ↳ `lfc[1]` (parse one feature)", (@be lfc _[1] seconds = min(S, 1.0)), false),
            torow("  ↳ parse all via `lfc[i]`", (@be lfc parseall seconds = S), true),
            torow("  ↳ `collect(lfc)`", (@be lfc collect seconds = S), true),
            torow("`GeoJSON.write(fc)`", (@be fc GeoJSON.write seconds = S), true),
            torow("`JSON.parse` (untyped)", (@be bytes JSON.parse seconds = S), true),
        ]

        @printf("### %s.geojson — %.1f MB, %s features, %s coordinate points, %d properties/feature\n\n",
                name, nbytes / 2^20, fmt_n(nfeat), fmt_n(npts), nprops)
        table(rows, nbytes, npts)
    end

    println("### Dataset summary\n")
    println("| file | MB | features | coordinate points | properties/feature | points/feature |")
    println("|---|---:|---:|---:|---:|---:|")
    for (name, nbytes, nfeat, npts, nprops) in meta
        @printf("| %s | %.1f | %d | %d | %d | %.1f |\n",
                name, nbytes / 2^20, nfeat, npts, nprops, npts / nfeat)
    end
    println()
end

main()
