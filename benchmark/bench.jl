# Run in each checkout: julia --project=CHECKOUT benchmark/bench.jl LABEL
using GeoJSON
using Statistics
import GeoInterface as GI
include("geometry_workload.jl")

function inputs(n=10_000)
    point = "{\"type\":\"Point\",\"coordinates\":[12.25,-34.125]}"
    line = "{\"type\":\"LineString\",\"coordinates\":[[12.25,-34.125],[13.5,6.25],[9.5,10.125]]}"
    polygon = "{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[10.25,0],[10.25,10.5],[0,0]]]}"
    props = "{\"name\":\"café 東京\",\"count\":42,\"active\":true,\"details\":{\"rating\":4.5,\"tags\":[\"a\",\"b\"],\"empty\":null}}"
    feature(g,p) = "{\"type\":\"Feature\",\"geometry\":$g,\"properties\":$p}"
    collection(fs) = "{\"type\":\"FeatureCollection\",\"features\":[" * join(fs, ',') * "]}"
    ["large_fc" => collection(fill(feature(point, "{\"name\":\"point\",\"value\":42}"), n)),
     "mixed" => collection([feature((point,line,polygon)[mod1(i,3)], "{\"name\":\"mixed\"}") for i=1:n]),
     "properties" => collection(fill(feature(point, props), n))]
end

function measure(f; samples=21)
    for _=1:4
        f()
    end
    times, bytes, allocs = Float64[], Int[], Int[]
    for _=1:samples
        GC.gc()
        stats = @timed f()
        push!(times, stats.time * 1000)
        push!(bytes, stats.bytes)
        push!(allocs, Base.gc_alloc_count(stats.gcstats))
    end
    (ms=median(times), bytes=Int(median(bytes)), allocations=Int(median(allocs)))
end

println("label,input,operation,ms,bytes,allocations,input_bytes")
for (name, text) in inputs()
    # Same Float64 coordinates and eager materialization on all branches.
    object = GeoJSON.read(text; ndim=2, numbertype=Float64)
    for (op,f) in (("read", () -> GeoJSON.read(text; ndim=2, numbertype=Float64)),
                   ("iterate", () -> count(f -> GeoJSON.geometry(f) !== nothing, object)),
                   ("geometry_score", () -> collection_score(object)),
                   ("write", () -> GeoJSON.write(object)))
        result = measure(f)
        println(join((get(ARGS,1,"current"),name,op,result.ms,result.bytes,result.allocations,sizeof(text)), ','))
    end
    if get(ARGS, 2, "") == "restriction"
        G = name == "mixed" ? Union{GeoJSON.Point,GeoJSON.LineString,GeoJSON.Polygon} : GeoJSON.Point
        result = measure(() -> GeoJSON.read(text; ndim=2, numbertype=Float64, geometrytype=G))
        println(join((ARGS[1],name,"restricted_read",result.ms,result.bytes,result.allocations,sizeof(text)), ','))
    end
    # Optional on the migration branches: measure typed reads and the deferred scan.
    if get(ARGS, 2, "") == "schema"
        X = length(Base.unwrap_unionall(GeoJSON.FeatureCollection).parameters) == 3 ?
            GeoJSON.FeatureCollection{2,Float64,Dict{Symbol,Any}} :
            GeoJSON.FeatureCollection{2,Float64,GeoJSON.AbstractGeometry{2,Float64},Dict{Symbol,Any}}
        for (op,f) in (("schema_read", () -> GeoJSON.read(text, X)),
                       ("table_schema", () -> GeoJSON.property_schema(GeoJSON.features(object))))
            result = measure(f)
            println(join((ARGS[1],name,op,result.ms,result.bytes,result.allocations,sizeof(text)), ','))
        end
    end
end
