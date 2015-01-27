# The GeoJSON Format Specification (Revision 1.0, 16 June 2008)
# url: http://geojson.org/geojson-spec.html

# Coordinate Reference System Objects
# (has keys "type" and "properties")
typealias CRS Dict{String,Any}

# Abstract Interfaces

abstract AbstractGeoJSON

hasbbox(obj::AbstractGeoJSON) = isdefined(obj, :bbox)
hascrs(obj::AbstractGeoJSON) = isdefined(obj, :crs)
bbox(obj::AbstractGeoJSON) = obj.bbox
crs(obj::AbstractGeoJSON) = obj.crs

abstract Geometry <: AbstractGeoJSON

# Geometry Objects

type Point <: Geometry
    coordinates::Union(Nothing, Vector)
    # optional
    bbox::Vector{Float64}
    crs::CRS

    Point(coordinates; kwargs...) = fill_options!(new(coordinates); kwargs...)
end

type MultiPoint <: Geometry
    coordinates::Union(Nothing, Vector)
    # optional
    bbox::Vector{Float64}
    crs::CRS

    MultiPoint(coordinates; kwargs...) = fill_options!(new(coordinates); kwargs...)
end

type LineString <: Geometry
    coordinates::Union(Nothing, Vector)
    # optional
    bbox::Vector{Float64}
    crs::CRS

    LineString(coordinates; kwargs...) = fill_options!(new(coordinates); kwargs...)
end

type MultiLineString <: Geometry
    coordinates::Union(Nothing, Vector)
    # optional
    bbox::Vector{Float64}
    crs::CRS

    MultiLineString(coordinates; kwargs...) = fill_options!(new(coordinates); kwargs...)
end

type Polygon <: Geometry
    coordinates::Union(Nothing, Vector)
    # optional
    bbox::Vector{Float64}
    crs::CRS

    Polygon(coordinates; kwargs...) = fill_options!(new(coordinates); kwargs...)
end

type MultiPolygon <: Geometry
    coordinates::Union(Nothing, Vector)
    # optional
    bbox::Vector{Float64}
    crs::CRS

    MultiPolygon(coordinates; kwargs...) = fill_options!(new(coordinates); kwargs...)
end

type GeometryCollection <: Geometry
    geometries::Union(Nothing, Vector{Geometry})
    # optional
    bbox::Vector{Float64}
    crs::CRS

    GeometryCollection(geometries::Union(Nothing, Vector{Geometry}); kwargs...) =
        fill_options!(new(geometries); kwargs...)
end

# Feature Objects

type Feature <: AbstractGeoJSON
    geometry::Union(Nothing, Geometry)
    properties::Union(Nothing, Dict{String,Any})
    # optional
    id
    bbox::Vector{Float64}
    crs::CRS

    Feature(geometry::Union(Nothing, Geometry), properties::Union(Nothing, Dict{String,Any}); kwargs...) =
        fill_options!(new(geometry, properties); kwargs...)
end
has_id(obj::Feature) = isdefined(obj, :id)

type FeatureCollection <: AbstractGeoJSON
    features::Union(Nothing, Vector{Feature})
    # optional
    bbox::Vector{Float64}
    crs::CRS

    FeatureCollection(features::Union(Nothing, Vector{Feature}); kwargs...) =
        fill_options!(new(features); kwargs...)
end

# Helper Functions

function fill_options!(obj::AbstractGeoJSON, param::String, value)
    if param == "id"
        obj.id = value
    elseif param == "bbox"
        obj.bbox = value
    elseif param == "crs"
        obj.crs = value
    end
    obj
end

function fill_options!(obj::AbstractGeoJSON, param::Symbol, value)
    if param == :id
        obj.id = value
    elseif param == :bbox
        obj.bbox = value
    elseif param == :crs
        obj.crs = value
    end
    obj
end

function fill_options!(obj::AbstractGeoJSON; kwargs...)
    for (param, value) in kwargs
        fill_options!(obj, param, value)
    end
    obj
end

function fill_options!(obj::AbstractGeoJSON, kwargs::Dict{String,Any})
    for (param, value) in kwargs
        fill_options!(obj, param, value)
    end
    obj
end

# Additional Constructors (Dict -> GeoJSON)

function GeometryCollection(obj::Dict{String,Any})
    collection = GeometryCollection([])
    geometries = obj["geometries"]
    sizehint!(collection.geometries, length(geometries))
    for geometry in geometries
        push!(collection.geometries, dict2geojson(geometry))
    end
    fill_options!(collection, obj)
end

for geom in (:MultiPolygon, :Polygon, :MultiLineString, :LineString, :MultiPoint, :Point)
    @eval $(geom)(obj::Dict{String,Any}) = fill_options!($(geom)(obj["coordinates"]), obj)
end

function Feature(obj::Dict{String,Any})
    feature = Feature(dict2geojson(obj["geometry"]), obj["properties"])
    if haskey(obj, "id")
        feature.id = obj["id"]
    end
    fill_options!(feature, obj)
end

function FeatureCollection(obj::Dict{String,Any})
    features = obj["features"]
    collection = FeatureCollection(Feature[])
    sizehint!(collection.features, length(features))
    for feature in features
        push!(collection.features, Feature(feature))
    end
    fill_options!(collection, obj)
end

# Implement GEO interface

for (geom,attributes) in ((MultiPolygon, (:coordinates,)),
                          (Polygon, (:coordinates,)),
                          (MultiLineString, (:coordinates,)),
                          (LineString, (:coordinates,)),
                          (MultiPoint, (:coordinates,)),
                          (Point, (:coordinates,)),
                          (GeometryCollection, (:geometries,)),
                          (Feature, (:geometry, :properties)),
                          (FeatureCollection, (:features,)))
    for attr in attributes
        @eval $(attr)(obj::$geom) = obj.$(attr)
    end
end
