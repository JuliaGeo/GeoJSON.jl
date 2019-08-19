# even though we don't subtype the GeoInterface abstract types
# we can still extend some of their methods to make interoperation easier

GeoInterface.geotype(::Feature) = :Feature
GeoInterface.geotype(::FeatureCollection) = :FeatureCollection

function GeoInterface.properties(f::Feature)
    properties = getfield(f, :x).properties
    Dict{String, Any}(String(k) => v for (k, v) in properties)
end

# TODO implement for FeatureCollection, currently only features are captured
function GeoInterface.bbox(f::Feature)
    feature = getfield(f, :x)
    if :bbox in propertynames(feature)
        copy(feature.bbox)
    else
        nothing
    end
end

GeoInterface.coordinates(f::Feature) = copy(f.geometry.coordinates)

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
    _geometry(f.geometry)
end
