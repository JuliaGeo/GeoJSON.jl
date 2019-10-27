# even though we don't subtype the GeoInterphase abstract types
# we can still extend some of their methods to make interoperation easier

GeoInterphase.geotype(::Feature) = :Feature
GeoInterphase.geotype(::FeatureCollection) = :FeatureCollection

function GeoInterphase.properties(f::Feature)
    props = properties(f)
    Dict{String, Any}(String(k) => v for (k, v) in props)
end

# TODO implement for FeatureCollection, currently only features are captured
function GeoInterphase.bbox(f::Feature)
    bbox = get(json(f), :bbox, nothing)
    if bbox === nothing
        return nothing
    else
        return copy(bbox)
    end
end

GeoInterphase.coordinates(f::Feature) = copy(geometry(f).coordinates)

function _geometry(g::JSON3.Object)
    if g.type == "Point"
        GeoInterphase.Point(g.coordinates)
    elseif g.type == "LineString"
        GeoInterphase.LineString(g.coordinates)
    elseif g.type == "Polygon"
        GeoInterphase.Polygon(g.coordinates)
    elseif g.type == "MultiPoint"
        GeoInterphase.MultiPoint(g.coordinates)
    elseif g.type == "MultiLineString"
        GeoInterphase.MultiLineString(g.coordinates)
    elseif g.type == "MultiPolygon"
        GeoInterphase.MultiPolygon(g.coordinates)
    elseif g.type == "GeometryCollection"
        _geometry.(g.geometries)
    else
        throw(ArgumentError("Unknown geometry type"))
    end
end

function GeoInterphase.geometry(f::Feature)
    _geometry(geometry(f))
end

function GeoInterphase.Feature(f::Feature)
    GeoInterphase.Feature(GeoInterphase.geometry(f), GeoInterphase.properties(f))
end

function GeoInterphase.FeatureCollection(fc::FeatureCollection)
    GeoInterphase.FeatureCollection(GeoInterphase.Feature.(fc), nothing, nothing)
end
