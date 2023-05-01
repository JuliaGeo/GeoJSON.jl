"""
    GeoJSON.read(json::String; lazyfc=false, ndim=2, numbertype=Float32)

Read GeoJSON from a string to a GeoInterface.jl compatible object.
Set `ndim=3` for 3D geometries, which is also tried automatically when
parsing as `ndim=2` (default) fails. The `numbertype` is Float32 by default,
Float64 should be set when the precision is required.

When reading in huge featurecollections (1M+ features), set `lazyfc=true`
to only parse them into memory when accessed.
"""
function read(io; lazyfc=false, ndim=2, numbertype=Float32)
    if lazyfc
        obj = JSON3.read(io, LazyFeatureCollection{ndim,numbertype})
    else
        try
            obj = JSON3.read(io, GeoJSONWrapper{ndim,numbertype}).obj
        catch e
            if e isa ArgumentError
                @warn "Failed to parse GeoJSON as 2D, trying 3D. Set `ndim` to 3 to avoid this warning."
                obj = JSON3.read(io, GeoJSONWrapper{ndim + 1,numbertype}).obj
            else
                rethrow(e)
            end
        end
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

# GeoInterface supported objects
write(io, obj) = JSON3.write(io, _lower(obj))
write(obj) = JSON3.write(_lower(obj))

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
        if GI.ngeom(GI.geometry(obj)) > 0 
            return _add_bbox(GI.extent(obj), base)
        else
            return _add_bbox(nothing, base)
        end
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
