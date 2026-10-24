# Fresh process per checkout and mode:
# julia --startup-file=no --project=CHECKOUT benchmark/compile_latency.jl LABEL [default|schema]
Base.cumulative_compile_timing(true)
const load_stats = @timed @eval using GeoJSON, GeoInterface, StructUtils, JSON, Tables

const GI = GeoInterface
const label = get(ARGS, 1, "current")
const mode = get(ARGS, 2, "default")
const P = NamedTuple{(:name,),Tuple{String}}
point = """{"type":"Point","coordinates":[1,2]}"""
line = """{"type":"LineString","coordinates":[[1,2],[3,4]]}"""
poly = """{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,0]]]}"""
multi = """{"type":"MultiPolygon","coordinates":[[[[0,0],[1,0],[1,1],[0,0]]]]}"""
gc = """{"type":"GeometryCollection","geometries":[$point,$line,$poly,{"type":"GeometryCollection","geometries":[$point]}]}"""
feature(g) = """{"type":"Feature","geometry":$g,"properties":{"name":"sample"}}"""
collection(gs) = """{"type":"FeatureCollection","features":[$(join(feature.(gs), ','))]}"""
mixes = [("collections", [gc]), ("polygon_multi", [poly,multi]),
         ("polygons", [poly]), ("point_line", [point,line]),
         ("interleaved", [gc,poly,point,multi,line,poly,gc,line])]
gtypes = [GeoJSON.GeometryCollection{2,Float64},
          Union{GeoJSON.Polygon{2,Float64},GeoJSON.MultiPolygon{2,Float64}},
          GeoJSON.Polygon{2,Float64},
          Union{GeoJSON.Point{2,Float64},GeoJSON.LineString{2,Float64}},
          GeoJSON.AbstractGeometry{2,Float64}]
function schema(G)
    length(Base.unwrap_unionall(GeoJSON.FeatureCollection).parameters) == 3 ?
        GeoJSON.FeatureCollection{2,Float64,P} : GeoJSON.FeatureCollection{2,Float64,G,P}
end
readdefault(text, _) = GeoJSON.read(text; ndim=2, numbertype=Float64)
readschema(text, X) = GeoJSON.read(text, X)
function iteratefeatures(fc)
    n = 0
    for f in fc
        n += GeoJSON.geometry(f) !== nothing
    end
    n
end
function coordinates(fc)
    n = 0
    for f in fc
        g = GI.geometry(f)
        g === nothing || (n += length(GI.coordinates(g)))
    end
    n
end

# Count cached MethodInstances of methods defined by GeoJSON, including extensions
# to Base/GI/JSON/Tables. This is a specialization proxy, not native-code counts.
function ownedmethods()
    result = Set{Method}()
    for mod in (GeoJSON, Base, GI, JSON, StructUtils, Tables), name in names(mod; all=true, imported=true)
        isdefined(mod, name) || continue
        x = getfield(mod, name)
        (x isa Function || x isa Type) || continue
        for m in methods(x)
            m.module === GeoJSON && push!(result, m)
        end
    end
    collect(result)
end
const measured_methods = ownedmethods()
specializations() = sum(m -> count(x -> x isa Core.MethodInstance, Base.specializations(m)), measured_methods; init=0)
specializations() # Warm instrumentation, without reading GeoJSON.
Base.cumulative_compile_timing(true)
function record(op, stage, f)
    before = specializations()
    stats = @timed f()
    after = specializations()
    println(join((label,mode,stage,op,stats.time*1000,stats.compile_time*1000,
                  stats.recompile_time*1000,after-before,stats.bytes), ','))
    flush(stdout)
    stats.value
end
println("variant,mode,input,operation,ms,compile_ms,recompile_ms,new_package_specializations,bytes")
println(join((label,mode,"package_load","load",load_stats.time*1000,load_stats.compile_time*1000,
              load_stats.recompile_time*1000,0,load_stats.bytes), ','))
for (i,(name, gs)) in enumerate(mixes)
    text = collection(repeat(gs, 100))
    X = mode == "schema" ? schema(gtypes[i]) : nothing
    reader = mode == "schema" ? readschema : readdefault
    fc = record("read", name, () -> reader(text, X))
    record("iterate", name, () -> iteratefeatures(fc))
    record("coordinates", name, () -> coordinates(fc))
end
