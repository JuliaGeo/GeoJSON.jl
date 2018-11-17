module GeoJSON

import GeoInterface
import JSON

export dict2geo,
    geo2dict,
    geojson

"""
    parse(input::Union{String, IO}, inttype::Type{<:Real}=Int64)

Parse a GeoJSON string or IO stream into a GeoInterface object.

See also: [`parsefile`](@ref)

# Examples
```jldoctest
julia> GeoJSON.parse("{\"type\": \"Point\", \"coordinates\": [30, 10]}")
GeoInterface.Point([30.0, 10.0])
```
"""
parse(input; kwargs...) = dict2geo(JSON.parse(input; kwargs...))

"""
    parsefile(filename::AbstractString, inttype::Type{<:Real}=Int64)

Parse a GeoJSON file into a GeoInterface object.

See also: [`parse`](@ref)
"""
parsefile(filename; kwargs...) = dict2geo(JSON.parsefile(filename; kwargs...))

"""
    geojson(obj)

Create a GeoJSON string from an object that implements the GeoInterface, either
`AbstractGeometry`, `AbstractFeature` or `AbstractFeatureCollection`.

# Examples
```jldoctest
julia> using GeoInterface; p = Point([30.0, 10.0])
Point([30.0, 10.0])

julia> geojson(p)
"{\"coordinates\":[30.0,10.0],\"type\":\"Point\"}"
```
"""
function geojson end

for geom in (:AbstractFeatureCollection, :AbstractGeometryCollection, :AbstractFeature,
        :AbstractMultiPolygon, :AbstractPolygon, :AbstractMultiLineString,
        :AbstractLineString, :AbstractMultiPoint, :AbstractPoint)
    @eval geojson(obj::GeoInterface.$geom) = JSON.json(geo2dict(obj))
end

"""
    dict2geo(obj::Dict{String, Any})

Transform a parsed JSON dictionary to a GeoInterface object.

See also: [`geo2dict`](@ref)

# Examples
```jldoctest
julia> dict2geo(Dict("type" => "Point", "coordinates" => [30.0, 10.0]))
Point([30.0, 10.0])
```
"""
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

dict2geo(obj::Nothing) = nothing

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

"""
    geo2dict(obj)

Transform a GeoInterface object to a JSON dictionary.

See also: [`dict2geo`](@ref)

# Examples
```jldoctest
julia> using GeoInterface; geo2dict(Point([30.0, 10.0]))
Dict{String,Any} with 2 entries:
  "coordinates" => [30.0, 10.0]
  "type"        => "Point"
```
"""
function geo2dict end

function geo2dict(obj::GeoInterface.AbstractGeometry)
    Dict("type" => string(GeoInterface.geotype(obj)),
        "coordinates" => GeoInterface.coordinates(obj))
end

function geo2dict(obj::GeoInterface.AbstractGeometryCollection)
    Dict("type" => string(GeoInterface.geotype(obj)),
        "geometries" => map(geo2dict, GeoInterface.geometries(obj)))
end

function geo2dict(obj::GeoInterface.AbstractFeature)
    result = Dict("type" => string(GeoInterface.geotype(obj)),
        "geometry" => geo2dict(GeoInterface.geometry(obj)),
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

function geo2dict(obj::GeoInterface.AbstractFeatureCollection)
    result = Dict("type" => string(GeoInterface.geotype(obj)),
        "features" => map(geo2dict, GeoInterface.features(obj)))
    if GeoInterface.bbox(obj) != nothing
        result["bbox"] = GeoInterface.bbox(obj)
    end
    if GeoInterface.crs(obj) != nothing
        result["crs"] = GeoInterface.crs(obj)
    end
    result
end

geo2dict(obj::Nothing) = nothing

end  # module
