module TrimGeoJSON

using GeoJSON

include("steps.jl")

const Geom = Union{GeoJSON.Polygon{2,Float64},GeoJSON.MultiPolygon{2,Float64}}
const Props = NamedTuple{(:NAME, :POP_EST),Tuple{Union{Missing,String},Union{Missing,Float64}}}
const Untyped = GeoJSON.FeatureCollection{2,Float64,Geom,Nothing}
const Typed = GeoJSON.FeatureCollection{2,Float64,Geom,Props}
const LazyProps = NamedTuple{(:NAME,),Tuple{Union{Missing,String}}}
const Lazy = GeoJSON.LazyFeatureCollection{2,Float64,Geom,LazyProps}
const Stream = GeoJSON.LazyStream{2,Float64,Geom,LazyProps}

sumx(::Nothing) = 0.0
function sumx(g::GeoJSON.Polygon{2,Float64})
    s = 0.0
    c = GeoJSON.coordinates(g)
    c === nothing && return s
    for ring in c, p in ring
        s += p[1]
    end
    return s
end
function sumx(g::GeoJSON.MultiPolygon{2,Float64})
    s = 0.0
    c = GeoJSON.coordinates(g)
    c === nothing && return s
    for poly in c, ring in poly, p in ring
        s += p[1]
    end
    return s
end
function sumx(fc::Untyped)
    s = 0.0
    for f in GeoJSON.features(fc)
        s += sumx(GeoJSON.geometry(f))
    end
    return s
end

function firstname(fc::Typed)
    fs = GeoJSON.features(fc)
    isempty(fs) && return "<none>"
    n = GeoJSON.properties(fs[1]).NAME
    return n isa String ? n : "missing"
end

function lazyname(lfc::Lazy)
    length(lfc) == 0 && return "<none>"
    n = GeoJSON.properties(lfc[1]).NAME
    return n isa String ? n : "missing"
end

# A `Ref` counter keeps the closure's captured field concretely typed under `--trim`.
function streamcount(path)
    n = Ref(0)
    foreach(_ -> n[] += 1, GeoJSON.read(path, Stream))
    return n[]
end

function @main(args)
    length(args) == 1 || (println(Core.stdout, "usage: trimgeojson <file.geojson>"); return 1)
    path = args[1]
    fc = GeoJSON.read(path, Untyped)
    println(Core.stdout, "features ", length(GeoJSON.features(fc)))
    println(Core.stdout, "sumx ", sumx(fc))
    typed = GeoJSON.read(read(path), Typed)
    println(Core.stdout, "name ", firstname(typed))
    lazy = GeoJSON.read(path, Lazy)
    println(Core.stdout, "lazylength ", length(lazy))
    println(Core.stdout, "lazyname ", lazyname(lazy))
    println(Core.stdout, "streamed ", streamcount(path))
    @static if WRITE
        println(Core.stdout, "written ", sizeof(GeoJSON.write(fc)))
    end
    return 0
end

end
