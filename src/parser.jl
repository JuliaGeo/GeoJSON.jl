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

dict2geojson(::Nothing) = Nothing()

# GeoJSON -> Dict

geo_interface = 

for (geom,attributes) in ((MultiPolygon, (coordinates,)),
                          (Polygon,  (coordinates,)),
                          (MultiLineString, (coordinates,)),
                          (LineString, (coordinates,)),
                          (MultiPoint, (coordinates,)),
                          (Point, (coordinates,)),
                          (GeometryCollection, (geometries,)),
                          (Feature, (geometry, properties)),
                          (FeatureCollection, (features,)))
    @eval begin
        function geojson2dict(obj::$geom)
            dict = Dict{String,Any}()
            dict["type"] = string($geom)
            for attr in $attributes
                #println(geojson2dict(obj))
                attribute = attr(obj)

                objtype = typeof(attribute)
                if super(objtype) == Geometry
                    if objtype == GeometryCollection
                        dict[string(attr)] = map(geojson2dict, attribute)
                    else
                        dict[string(attr)] = geojson2dict(attribute)
                    end
                elseif objtype == Feature
                    dict[string(attr)] = geojson2dict(attribute)
                else
                    @assert !isa(attribute, AbstractGeoJSON)
                    if typeof(obj) == FeatureCollection
                        dict[string(attr)] = map(geojson2dict, attribute)
                    else # properties/coordinates
                        dict[string(attr)] = attribute
                    end
                end
            end
            if hasbbox(obj)
                dict["bbox"] = bbox(obj)
            end
            if hascrs(obj)
                dict["crs"] = crs(obj)
            end
            dict
        end
    end
end

# String/File -> GeoJSON
parse(input; kwargs...) = dict2geojson(JSON.parse(input; kwargs...))
parsefile(filename; kwargs...) = dict2geojson(JSON.parsefile(filename; kwargs...))

# GeoJSON -> String/IO
geojson(obj::AbstractGeoJSON) = JSON.json(geojson2dict(obj))
print(io::IO, obj::AbstractGeoJSON) = JSON.print(io, geojson2dict(obj))