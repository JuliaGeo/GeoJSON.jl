
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
        return FeatureCollection(object, features)
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
    bbox = [ext.X[1], ext.Y[1], ext.X[2], ext.Y[2]]
    merge(nt, (; bbox))
end

miss(x) = ifelse(x === nothing, missing, x)

"""
    geometry(g::JSON3.Object)

Convert a GeoJSON geometry from JSON object to a struct specific
to that geometry type.
"""
function geometry(g::JSON3.Object)
    t = g.type
    if t == "Point"
        Point(g.coordinates)
    elseif t == "LineString"
        LineString(g.coordinates)
    elseif t == "Polygon"
        Polygon(g.coordinates)
    elseif t == "MultiPoint"
        MultiPoint(g.coordinates)
    elseif t == "MultiLineString"
        MultiLineString(g.coordinates)
    elseif t == "MultiPolygon"
        MultiPolygon(g.coordinates)
    elseif t == "GeometryCollection"
        GeometryCollection(g.geometries)
    else
        throw(ArgumentError("Unknown geometry type $t"))
    end
end
geometry(g::Nothing) = nothing
