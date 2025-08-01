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
    write([io], geometry; geometrycolumn)

Write a GeoInterface.jl compatible feature or geometry to a string of GeoJSON.

`io` may be a filename `String`, or an `IO` object.

If `geometry` is a `Tables.Table`, you may pass a `Symbol` to the `geometrycolumn` keyword argument,
to indicate which column of the table holds the geometries.  Note that this will not keep the name,
the geometry must be written to the `:geometry` column of the GeoJSON according to the spec.
"""
write(io, obj::GeoJSONT) = JSON3.write(io, obj)
write(obj::GeoJSONT) = JSON3.write(obj)

# GeoInterface supported objects
write(io, obj; geometrycolumn = first(GI.geometrycolumns(obj))) = JSON3.write(io, _lower(obj; geometrycolumn))
write(obj; geometrycolumn = first(GI.geometrycolumns(obj))) = JSON3.write(_lower(obj; geometrycolumn))

function _lower(obj; geometrycolumn = first(GI.geometrycolumns(obj)))
    if GI.isfeaturecollection(obj)
        # This is recursive into this method technically
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
    elseif Tables.istable(obj)
        !(geometrycolumn isa Symbol) && throw(ArgumentError("GeoJSON.jl can only write a single geometry column which must be specified as a `Symbol`, but was passed `$(geometrycolumn)` instead."))
        geom_col_idx = Tables.columnindex(obj, geometrycolumn)
        # There is a strange bug where Tables.columnnames on some tables is empty, 
        # so we use the schema instead
        colnames = Tables.schema(obj).names
        non_geomcol_keys = tuple(setdiff(colnames, (geometrycolumn,))...)
        features = map(Tables.rows(obj)) do row
            geom = Tables.getcolumn(row, geom_col_idx)
            properties = NamedTuple{non_geomcol_keys}(map(k -> Tables.getcolumn(row, k), non_geomcol_keys))
            fbase = (;
                type="Feature",
                geometry=_lower(geom),
                properties=properties,
            )
            _add_bbox(GI.extent(geom), fbase)
        end
        base = (type="FeatureCollection", features=features)
        return _add_bbox(mapreduce(x -> GI.extent(x.geometry), Extents.union, features), base)
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
