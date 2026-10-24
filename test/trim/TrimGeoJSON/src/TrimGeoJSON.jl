module TrimGeoJSON
using GeoJSON
const Props = NamedTuple{(:NAME, :POP_EST),Tuple{Union{Missing,String},Union{Missing,Float64}}}
const Typed = GeoJSON.FeatureCollection{2,Float64,Props}

function @main(args)
    length(args) == 1 || return 1
    fc = GeoJSON.read(read(args[1]), Typed)
    fs = GeoJSON.features(fc)
    println(Core.stdout, "features ", length(fs))
    println(Core.stdout, "name ", GeoJSON.properties(fs[1]).NAME)
    text = GeoJSON.write(fc)
    again = GeoJSON.read(text, Typed)
    firstfeature = GeoJSON.features(again)[1]
    g = GeoJSON.geometry(firstfeature)
    g isa GeoJSON.Polygon{2,Float64} || return 2
    c = GeoJSON.coordinates(g)
    c === nothing && return 2
    c[1][2] == (1.0, 0.0) || return 2
    isequal(GeoJSON.properties(firstfeature).NAME, "Alpha") || return 2
    id = GeoJSON.id(firstfeature)
    (id isa String && id == "Alpha") || return 2
    println(Core.stdout, "roundtrip ", length(GeoJSON.features(again)))
    println(Core.stdout, "written ", sizeof(text))
    return 0
end
end
