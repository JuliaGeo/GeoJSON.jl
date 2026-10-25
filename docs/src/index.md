```@meta
CurrentModule = GeoJSON
```

# GeoJSON

Documentation for [GeoJSON](https://github.com/JuliaGeo/GeoJSON.jl).

See the [GeoInterfaces.jl](https://juliageo.org/GeoInterface.jl/stable/) and
[Tables.jl](https://tables.juliadata.org/stable/) documentation for most
applicable methods.

```@autodocs
Modules = [GeoJSON]
```

## Typed reads and trimmed applications

Use `GeoJSON.read(source, GeoJSON.FeatureCollection{2,Float64})` when the target
is known at compile time. The typed entry point fixes the coordinate dimension
and throws `ArgumentError` on a mismatch, without the ordinary reader's 3D
retry. It reads standard JSON; use the ordinary reader for NaN/Inf literals.

Use `GeoJSON.write(x; style=GeoJSON.StrictStyle())` in safely trimmed applications.
This opts into a closed writer for the value types produced by JSON parsing.
The default writer continues to accept custom property values and lowering.
The strict style uses the same compact coordinate format and preserves member
order, including for nested GeometryCollections.

`test/trim` contains a standalone read/sum/write app and compares its safely
trimmed executable with JIT-generated output on mixed and 2,000-feature inputs.
Trimming is experimental; the CI job pins JuliaC 0.3.12 and tests Julia 1.12 and
the latest release. Run it with `julia --project=test/trim test/trim/runtests.jl`
after installing that JuliaC app.
