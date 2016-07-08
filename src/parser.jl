# Dict -> GeoJSON

function dict2geojson(obj::Dict)
    t = symbol(obj["type"])
    if t == :FeatureCollection
        return FeatureCollection(obj)
    elseif t == :Feature
        return Feature(obj)
    elseif t == :GeometryCollection
        return GeometryCollection(obj)
    elseif t == :MultiPolygon
        return MultiPolygon(obj)
    elseif t == :Polygon
        return Polygon(obj)
    elseif t == :MultiLineString
        return MultiLineString(obj)
    elseif t == :LineString
        return LineString(obj)
    elseif t == :MultiPoint
        return MultiPoint(obj)
    elseif t == :Point
        return Point(obj)
    end
end

dict2geojson(obj::@compat(Void)) = obj

# GeoJSON -> Dict

for geom in (MultiPolygon, MultiLineString, MultiPoint,
             Polygon, LineString, Point)
    @eval begin
        function geojson2dict(obj::$geom)
            dict = @compat Dict("type" => string($(geom).name.name),
                                "coordinates" => coordinates(obj))
            hasbbox(obj) && (dict["bbox"] = bbox(obj))
            hascrs(obj) && (dict["crs"] = crs(obj))
            dict
        end
    end
end

function geojson2dict(obj::GeometryCollection)
    dict = @compat Dict("type" => "GeometryCollection",
                        "geometries" => map(geojson2dict, geometries(obj)))
    hasbbox(obj) && (dict["bbox"] = bbox(obj))
    hascrs(obj) && (dict["crs"] = crs(obj))
    dict
end

function geojson2dict(obj::Feature)
    dict = @compat Dict("type" => "Feature",
                        "properties" => properties(obj),
                        "geometry" => geojson2dict(geometry(obj)))
    hasbbox(obj) && (dict["bbox"] = bbox(obj))
    hascrs(obj) && (dict["crs"] = crs(obj))
    hasid(obj) && (dict["id"] = id(obj))
    dict
end

function geojson2dict(obj::FeatureCollection)
    dict = @compat Dict("type" => "FeatureCollection",
                        "features" => map(geojson2dict, features(obj)))
    hasbbox(obj) && (dict["bbox"] = bbox(obj))
    hascrs(obj) && (dict["crs"] = crs(obj))
    dict
end

geojson2dict(obj::@compat(Void)) = obj

# @compat(AbstractString)/File -> GeoJSON
parse(input; kwargs...) = dict2geojson(JSON.parse(input; kwargs...))
parsefile(filename; kwargs...) = dict2geojson(JSON.parsefile(filename; kwargs...))

# GeoJSON -> @compat(AbstractString)/IO
geojson(obj::AbstractGeoJSON) = JSON.json(geojson2dict(obj))
print(io::IO, obj::AbstractGeoJSON) = JSON.print(io, geojson2dict(obj))
