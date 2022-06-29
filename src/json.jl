
"""
    read(source)

Read a GeoJSON string to a GeoInterface.jl compatible feature or geometry object.
"""
function read(source)
    object = JSON3.read(source)
    if object === nothing
        error("JSON string is empty")
    end
    object_type = get(object, :type, nothing)
    if object_type == "FeatureCollection"
        features = get(object, :features, nothing)
        features isa JSON3.Array || error("GeoJSON field \"features\" is not an array")
        return FeatureCollection(object)
    elseif object_type == "Feature"
        return Feature(object)
    elseif object_type === nothing
        error(
            "String does not follow the GeoJSON specification: must have a \"features\" field",
        )
    else
        return geometry(object)
    end
end

read(source::GeoFormatTypes.GeoJSON) = read(GeoFormatTypes.val(source))

function read(source::GeoFormatTypes.GeoJSON{<:AbstractDict})
    dict = GeoFormatTypes.val(source)
    str = JSON3.write(dict)
    return read(str)
end

"""
    write([io], geometry)

Write a GeoInterface.jl compatible feature or geometry to a GeoJSON `String`.

`io` may be a filename `String` or `IO` object.
"""
write(obj) = JSON3.write(_lower(obj))
write(io, obj) = JSON3.write(io, _lower(obj))

function _lower(obj)
    if GI.isfeaturecollection(obj)
        base = (type = "FeatureCollection", features = _lower.(GI.getfeature(obj)))
        return _add_bbox(GI.extent(obj), base)
    elseif GI.isfeature(obj)
        base = (
            type = "Feature",
            geometry = _lower(GI.geometry(obj)),
            properties = GI.properties(obj),
        )
        return _add_bbox(GI.extent(obj), base)
    elseif GI.isgeometry(obj)
        _lower(GI.geomtrait(obj), obj)
    else
        # null geometry
        nothing
    end
end
_lower(::GI.AbstractPointTrait, obj) = (type = "Point", coordinates = GI.coordinates(obj))
_lower(::GI.AbstractLineStringTrait, obj) =
    (type = "LineString", coordinates = GI.coordinates(obj))
_lower(::GI.AbstractPolygonTrait, obj) =
    (type = "Polygon", coordinates = GI.coordinates(obj))
_lower(::GI.AbstractMultiPointTrait, obj) =
    (type = "MultiPoint", coordinates = GI.coordinates(obj))
_lower(::GI.AbstractMultiLineStringTrait, obj) =
    (type = "Polygon", coordinates = GI.coordinates(obj))
_lower(::GI.AbstractMultiPolygonTrait, obj) =
    (type = "MultiPolygon", coordinates = collect(GI.coordinates(obj)))
_lower(::GI.AbstractGeometryCollectionTrait, obj) =
    (type = "GeometryCollection", geometries = _lower.(GI.getgeom(obj)))

_add_bbox(::Nothing, nt::NamedTuple) = nt
function _add_bbox(ext::Extents.Extent, nt::NamedTuple)
    if haskey(ext, :Z)
        bbox = [ext.X[1], ext.Y[1], ext.Z[1], ext.X[2], ext.Y[2], ext.Z[2]]
    else
        bbox = [ext.X[1], ext.Y[1], ext.X[2], ext.Y[2]]
    end
    merge(nt, (; bbox))
end

"""
    geometry(g)

Convert a GeoJSON geometry from JSON style object to a struct specific
to that geometry type.
"""
function geometry(g)
    t = type(g)
    if t == "Point"
        Point(g)
    elseif t == "LineString"
        LineString(g)
    elseif t == "Polygon"
        Polygon(g)
    elseif t == "MultiPoint"
        MultiPoint(g)
    elseif t == "MultiLineString"
        MultiLineString(g)
    elseif t == "MultiPolygon"
        MultiPolygon(g)
    elseif t == "GeometryCollection"
        GeometryCollection(g)
    else
        throw(ArgumentError("Unknown geometry type $t"))
    end
end
geometry(g::Geometry) = g
geometry(::Nothing) = nothing
