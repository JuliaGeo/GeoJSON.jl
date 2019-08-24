# even though we don't subtype the GeoInterface abstract types
# we can still extend some of their methods to make interoperation easier

GeoInterface.geotype(::Feature) = :Feature
GeoInterface.geotype(::FeatureCollection) = :FeatureCollection

function GeoInterface.properties(f::Feature)
    props = properties(f)
    Dict{String, Any}(String(k) => v for (k, v) in props)
end

# TODO implement for FeatureCollection, currently only features are captured
function GeoInterface.bbox(f::Feature)
    bbox = get(json(f), :bbox, nothing)
    if bbox === nothing
        return nothing
    else
        return copy(bbox)
    end
end

GeoInterface.coordinates(f::Feature) = copy(geometry(f).coordinates)

function _geometry(g::JSON3.Object)
    if g.type == "Point"
        GeoInterface.Point(g.coordinates)
    elseif g.type == "LineString"
        GeoInterface.LineString(g.coordinates)
    elseif g.type == "Polygon"
        GeoInterface.Polygon(g.coordinates)
    elseif g.type == "MultiPoint"
        GeoInterface.MultiPoint(g.coordinates)
    elseif g.type == "MultiLineString"
        GeoInterface.MultiLineString(g.coordinates)
    elseif g.type == "MultiPolygon"
        GeoInterface.MultiPolygon(g.coordinates)
    elseif g.type == "GeometryCollection"
        _geometry.(g.geometries)
    else
        throw(ArgumentError("Unknown geometry type"))
    end
end

function GeoInterface.geometry(f::Feature)
    _geometry(geometry(f))
end

function GeoInterface.Feature(f::Feature)
    GeoInterface.Feature(GeoInterface.geometry(f), GeoInterface.properties(f))
end

function GeoInterface.FeatureCollection(fc::FeatureCollection)
    GeoInterface.FeatureCollection(GeoInterface.Feature.(fc), nothing, nothing)
end
