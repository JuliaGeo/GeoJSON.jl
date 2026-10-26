module GeoJSONTrimApp
using GeoJSON

positionsum(::Nothing) = 0.0
positionsum(c::Tuple) = sum(c)
positionsum(c::Vector) = sum(positionsum, c; init=0.0)
@inline function geometrysum(g::GeoJSON.AbstractGeometry{D,T}) where {D,T}
    g isa GeoJSON.Point{D,T} && return positionsum(getfield(g, :coordinates))
    g isa GeoJSON.LineString{D,T} && return positionsum(getfield(g, :coordinates))
    g isa GeoJSON.Polygon{D,T} && return positionsum(getfield(g, :coordinates))
    g isa GeoJSON.MultiPoint{D,T} && return positionsum(getfield(g, :coordinates))
    g isa GeoJSON.MultiLineString{D,T} && return positionsum(getfield(g, :coordinates))
    g isa GeoJSON.MultiPolygon{D,T} && return positionsum(getfield(g, :coordinates))
    g isa GeoJSON.GeometryCollection{D,T} && return collectionsum(g)
    throw(ArgumentError("unsupported geometry"))
end
geometrysum(::Nothing) = 0.0
function collectionsum(g::GeoJSON.GeometryCollection)
    total = 0.0
    for child in getfield(g, :geometries); total += geometrysum(child); end
    total
end

function @main(args::Vector{String})
    for path in args
        fc = GeoJSON.read(path, GeoJSON.FeatureCollection{2,Float64})
        total = 0.0
        for feature in getfield(fc, :features)
            total += geometrysum(getfield(feature, :geometry))
        end
        println(Core.stdout, length(fc), ":", total)
        println(Core.stdout, GeoJSON.write(fc; style=GeoJSON.StrictStyle()))
        lazy = GeoJSON.read(path, GeoJSON.LazyFeatureCollection{2,Float64})
        lazytotal = 0.0
        for feature in lazy
            lazytotal += geometrysum(getfield(feature, :geometry))
        end
        println(Core.stdout, length(lazy), ":", lazytotal)
        println(Core.stdout, GeoJSON.write(lazy; style=GeoJSON.StrictStyle()))
    end
    return 0
end
end
