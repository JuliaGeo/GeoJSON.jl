# Dict -> GeoJSON

function dict2geojson(obj::Dict{String,Any})
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

dict2geojson(obj::Nothing) = obj

# GeoJSON -> Dict

for geom in (MultiPolygon, MultiLineString, MultiPoint,
             Polygon, LineString, Point)
    @eval begin
        function geojson2dict(obj::$geom)
            dict = ["type" => string($geom),
                    "coordinates" => coordinates(obj)]
            hasbbox(obj) && (dict["bbox"] = bbox(obj))
            hascrs(obj) && (dict["crs"] = crs(obj))
            dict
        end
    end
end

function geojson2dict(obj::GeometryCollection)
    dict = ["type" => "GeometryCollection",
            "geometries" => map(geojson2dict, geometries(obj))]
    hasbbox(obj) && (dict["bbox"] = bbox(obj))
    hascrs(obj) && (dict["crs"] = crs(obj))
    dict
end

function geojson2dict(obj::Feature)
    dict = ["type" => "Feature",
            "geometry" => geojson2dict(geometry(obj))]
    hasbbox(obj) && (dict["bbox"] = bbox(obj))
    hascrs(obj) && (dict["crs"] = crs(obj))
    hasid(obj) && (dict["id"] = id(obj))
    dict
end

function geojson2dict(obj::FeatureCollection)
    dict = ["type" => "FeatureCollection",
            "features" => map(geojson2dict, features(obj))]
    hasbbox(obj) && (dict["bbox"] = bbox(obj))
    hascrs(obj) && (dict["crs"] = crs(obj))
    dict
end

geojson2dict(obj::Nothing) = obj

function propertynames(obj::FeatureCollection)
    columns = Set()
    for feature in obj.features
        if isdefined(feature, :properties)
            for key in keys(feature.properties)
                if in(key, columns)
                    continue
                end
                push!(columns, key)
            end
        end
    end
    [["id","geometry"],sort(collect(columns))]
end

function geojson2df(obj::FeatureCollection)
    nrows = length(obj.features)
    if nrows == 0
        return DataFrame()
    end
    colnames = propertynames(obj)
    ncols = length(colnames)
    df = DataFrame([[Any, Geometry], repeat([Any], inner = [ncols-2])],
                   convert(Vector{Symbol}, colnames), nrows)
    for i in 1:nrows
        df[i, 1] = hasid(obj.features[i]) ? obj.features[i].id : NA
        df[i, 2] = obj.features[i].geometry
        if isdefined(obj.features[i], :properties)
            for j in 3:ncols
                df[i, j] = get(obj.features[i].properties, colnames[j], NA)
            end
        end
    end
    df
end

# String/File -> GeoJSON
parse(input; kwargs...) = dict2geojson(JSON.parse(input; kwargs...))
parsefile(filename; kwargs...) = dict2geojson(JSON.parsefile(filename; kwargs...))

# GeoJSON -> String/IO
geojson(obj::AbstractGeoJSON) = JSON.json(geojson2dict(obj))
geojson{T <: AbstractGeoJSON}(obj::Vector{T}) = JSON.json(map(geojson2dict, obj))
print(io::IO, obj::AbstractGeoJSON) = JSON.print(io, geojson2dict(obj))
