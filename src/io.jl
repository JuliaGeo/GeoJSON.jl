"""
    GeoJSON.read(json; lazyfc=false, ndim=2, numbertype=Float32)

Read GeoJSON to a GeoInterface.jl compatible object.

# Arguments
- `json`: A file path, string, IO, or bytes (`AbstractVector{UInt8`) containing JSON to read.
- `lazyfc::Bool=false`: When reading in huge featurecollections (1M+ features),
    set `lazyfc=true` to only parse them into memory when accessed.
- `ndim::Int=2`: Use 3 for 3D geometries, which is also used when 2D parsing fails.
- `numbertype::DataType=Float32`: Use Float64 when the precision is required.
"""
function read(io; lazyfc=false, ndim=2, numbertype=Float32)
    eof(io) && seekstart(io)
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
        return _add_bbox(GI.extent(obj), base)
    elseif GI.isgeometry(obj)
        if GI.is3d(obj)
            _lower(GI.geomtrait(obj), Val{true}(), obj)
        else
            _lower(GI.geomtrait(obj), Val{false}(), obj)
        end
    else
        # null geometry
        nothing
    end
end
_lower(t::GI.AbstractPointTrait, d, obj) =
    (type="Point", coordinates=_to_vector_ntuple(t, d, obj))
_lower(t::GI.AbstractLineStringTrait, d, obj) =
    (type="LineString", coordinates=_to_vector_ntuple(t, d, obj))
_lower(t::GI.AbstractPolygonTrait, d, obj) =
    (type="Polygon", coordinates=_to_vector_ntuple(t, d, obj))
_lower(t::GI.AbstractMultiPointTrait, d, obj) =
    (type="MultiPoint", coordinates=_to_vector_ntuple(t, d, obj))
_lower(t::GI.AbstractMultiLineStringTrait, d, obj) =
    (type="MultiLineString", coordinates=_to_vector_ntuple(t, d, obj))
_lower(t::GI.AbstractMultiPolygonTrait, d, obj) =
    (type="MultiPolygon", coordinates=_to_vector_ntuple(t, d, obj))
_lower(t::GI.AbstractGeometryCollectionTrait, d, obj) =
    (type="GeometryCollection", geometries=_lower.(GI.getgeom(obj)))

function _to_vector_ntuple(::GI.PointTrait, is3d::Val{false}, geom)
    (GI.x(geom), GI.y(geom))
end
function _to_vector_ntuple(::GI.PointTrait, is3d::Val{true}, geom)
    (GI.x(geom), GI.y(geom), GI.z(geom))
end
function _to_vector_ntuple(::GI.AbstractGeometryTrait, is3d, geom)
    map(GI.getgeom(geom)) do child_geom
        _to_vector_ntuple(GI.geomtrait(child_geom), is3d, child_geom)
    end
end

_add_bbox(::Nothing, nt::NamedTuple) = nt
function _add_bbox(ext::Extents.Extent, nt::NamedTuple)
    if haskey(ext, :Z)
        bbox = [ext.X[1], ext.Y[1], ext.Z[1], ext.X[2], ext.Y[2], ext.Z[2]]
    else
        bbox = [ext.X[1], ext.Y[1], ext.X[2], ext.Y[2]]
    end
    merge(nt, (; bbox))
end
