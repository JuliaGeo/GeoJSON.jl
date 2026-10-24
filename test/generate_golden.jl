# Run against an extracted v0.8.4 tag, never the working branch:
# git archive v0.8.4 | tar -x -C "$TMPDIR/geojson-0.8.4"
# julia --project="$TMPDIR/geojson-0.8.4" test/generate_golden.jl test/data/golden-0.8.4.txt
using Pkg
Pkg.instantiate()
using GeoJSON, Tables
Base.pkgversion(GeoJSON) == v"0.8.4" || error("Generate with GeoJSON v0.8.4")
include(joinpath(pkgdir(GeoJSON), "test", "geojson_samples.jl"))
docs = vcat(Samples.featurecollections, Samples.features, Samples.geometries)
# v0.8.4 accidentally writes its internal Tables schema after the spec members.
strip_schema(s) = replace(s, r",\"names\":\[.*$" => "}")
open(only(ARGS), "w") do io
    for (i, doc) in enumerate(docs), T in (Float32, Float64)
        x = GeoJSON.read(doc; numbertype=T)
        schema = x isa GeoJSON.FeatureCollection ? repr(Tables.schema(x)) : ""
        println(io, i, '\t', T, '\t', strip_schema(GeoJSON.write(x)), '\t', isempty(schema) ? "-" : escape_string(schema))
    end
end
