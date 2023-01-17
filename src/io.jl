"""
    GeoJSON.read(json::String; lazyfc=false, ndim=2)

Read GeoJSON from a string or file to a GeoInterface.jl compatible object.
Set `ndim=3` for 3D geometries.
When reading in huge featurecollections (1M+ features), set `lazyfc=true`
to only parse them into memory when accessed.
"""
function read(io; lazyfc=false, ndim=2)
    if lazyfc
        obj = JSON3.read(io, LazyFeatureCollection{ndim})
    else
        obj = JSON3.read(io, GeoJSONWrapper{ndim}).obj
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
write(io, obj::GeoJSONT) = JSON3.write(io, obj)
write(obj::GeoJSONT) = JSON3.write(obj)

function _lower(obj)
    if GI.isfeaturecollection(obj)
        base = (type="FeatureCollection", features=_lower.(GI.getfeature(obj)))
        return _add_bbox(GI.extent(obj), base)
    elseif GI.isfeature(obj)
        base = (
            type="Feature",
            geometry=_lower(GI.geometry(obj)),
            properties=GI.properties(obj),
        )
        return _add_bbox(GI.extent(obj), base)
    elseif GI.isgeometry(obj)
        _lower(GI.geomtrait(obj), obj)
    else
        # null geometry
        nothing
    end
end
_lower(::GI.AbstractPointTrait, obj) = (type="Point", coordinates=GI.coordinates(obj))
_lower(::GI.AbstractLineStringTrait, obj) =
    (type="LineString", coordinates=GI.coordinates(obj))
_lower(::GI.AbstractPolygonTrait, obj) =
    (type="Polygon", coordinates=GI.coordinates(obj))
_lower(::GI.AbstractMultiPointTrait, obj) =
    (type="MultiPoint", coordinates=GI.coordinates(obj))
_lower(::GI.AbstractMultiLineStringTrait, obj) =
    (type="Polygon", coordinates=GI.coordinates(obj))
_lower(::GI.AbstractMultiPolygonTrait, obj) =
    (type="MultiPolygon", coordinates=collect(GI.coordinates(obj)))
_lower(::GI.AbstractGeometryCollectionTrait, obj) =
    (type="GeometryCollection", geometries=_lower.(GI.getgeom(obj)))

_add_bbox(::Nothing, nt::NamedTuple) = nt
function _add_bbox(ext::Extents.Extent, nt::NamedTuple)
    if haskey(ext, :Z)
        bbox = [ext.X[1], ext.Y[1], ext.Z[1], ext.X[2], ext.Y[2], ext.Z[2]]
    else
        bbox = [ext.X[1], ext.Y[1], ext.X[2], ext.Y[2]]
    end
    merge(nt, (; bbox))
end
