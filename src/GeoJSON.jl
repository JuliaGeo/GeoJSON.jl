__precompile__()

module GeoJSON

    import GeoInterface
    import JSON

    export dict2geo,
           geojson

    # String/File -> GeoJSON
    parse(input; kwargs...) = dict2geo(JSON.parse(input; kwargs...))
    parsefile(filename; kwargs...) = dict2geo(JSON.parsefile(filename; kwargs...))

    # GeoJSON -> String/IO
    for geom in (:AbstractFeatureCollection, :AbstractGeometryCollection, :AbstractFeature,
                 :AbstractMultiPolygon, :AbstractPolygon, :AbstractMultiLineString,
                 :AbstractLineString, :AbstractMultiPoint, :AbstractPoint)
        @eval json(obj::GeoInterface.$geom) = JSON.json(geojson(obj))
        @eval print(io::IO, obj::GeoInterface.$geom) = JSON.print(io, geojson(obj))
    end

    dict2geo(obj::Void) = nothing
    
    function dict2geo(obj::Dict{String,Any})
        t = Symbol(obj["type"])
        if t == :FeatureCollection
            return parseFeatureCollection(obj)
        elseif t == :Feature
            return parseFeature(obj)
        elseif t == :GeometryCollection
            return parseGeometryCollection(obj)
        elseif t == :MultiPolygon
            return GeoInterface.MultiPolygon(obj["coordinates"])
        elseif t == :Polygon
            return GeoInterface.Polygon(obj["coordinates"])
        elseif t == :MultiLineString
            return GeoInterface.MultiLineString(obj["coordinates"])
        elseif t == :LineString
            return GeoInterface.LineString(obj["coordinates"])
        elseif t == :MultiPoint
            return GeoInterface.MultiPoint(obj["coordinates"])
        elseif t == :Point
            return GeoInterface.Point(obj["coordinates"])
        end
    end

    parseGeometryCollection(obj::Dict{String,Any}) =
        GeoInterface.GeometryCollection(map(dict2geo,obj["geometries"]))

    function parseFeature(obj::Dict{String,Any})
        feature = GeoInterface.Feature(dict2geo(obj["geometry"]), obj["properties"])
        if haskey(obj, "id")
            feature.properties["featureid"] = obj["id"]
        end
        if haskey(obj, "bbox")
            feature.properties["bbox"] = GeoInterface.BBox(obj["bbox"])
        end
        if haskey(obj, "crs")
            feature.properties["crs"] = obj["crs"]
        end
        feature
    end

    function parseFeatureCollection(obj::Dict{String,Any})
        features = GeoInterface.Feature[map(parseFeature,obj["features"])...]
        featurecollection = GeoInterface.FeatureCollection(features)
        if haskey(obj, "bbox")
            featurecollection.bbox = GeoInterface.BBox(obj["bbox"])
        end
        if haskey(obj, "crs")
            featurecollection.crs = obj["crs"]
        end
        featurecollection
    end

    geojson(obj::Void) = nothing

    function geojson(obj::GeoInterface.AbstractGeometry)
        Dict("type" => string(GeoInterface.geotype(obj)),
             "coordinates" => GeoInterface.coordinates(obj))
    end

    function geojson(obj::GeoInterface.AbstractGeometryCollection)
        Dict("type" => string(GeoInterface.geotype(obj)),
             "geometries" => map(geojson, GeoInterface.geometries(obj)))
    end

    function geojson(obj::GeoInterface.AbstractFeature)
        result = Dict("type" => string(GeoInterface.geotype(obj)),
                      "geometry" => geojson(GeoInterface.geometry(obj)),
                      "properties" => copy(GeoInterface.properties(obj)))
        if haskey(result["properties"], "bbox")
            result["bbox"] = result["properties"]["bbox"]
            delete!(result["properties"], "bbox")
        end
        if haskey(result["properties"], "crs")
            result["crs"] = result["properties"]["crs"]
            delete!(result["properties"], "crs")
        end
        if haskey(result["properties"], "featureid")
            result["id"] = result["properties"]["featureid"]
            delete!(result["properties"], "featureid")
        end
        result
    end

    function geojson(obj::GeoInterface.AbstractFeatureCollection)
        result = Dict("type" => string(GeoInterface.geotype(obj)),
                      "features" => map(geojson, GeoInterface.features(obj)))
        if GeoInterface.bbox(obj) != nothing
            result["bbox"] = GeoInterface.bbox(obj)
        end
        if GeoInterface.crs(obj) != nothing
            result["crs"] = GeoInterface.crs(obj)
        end
        result
    end

end
