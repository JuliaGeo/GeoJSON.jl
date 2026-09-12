GI.isgeometry(::Type{<:AbstractGeometry}) = true

GI.geomtrait(::Point) = GI.PointTrait()
GI.geomtrait(::LineString) = GI.LineStringTrait()
GI.geomtrait(::Polygon) = GI.PolygonTrait()
GI.geomtrait(::MultiPoint) = GI.MultiPointTrait()
GI.geomtrait(::MultiLineString) = GI.MultiLineStringTrait()
GI.geomtrait(::MultiPolygon) = GI.MultiPolygonTrait()
GI.geomtrait(::GeometryCollection) = GI.GeometryCollectionTrait()

GI.ncoord(::GI.AbstractTrait, ::AbstractGeometry{D}) where {D} = D
GI.coordinates(::GI.AbstractGeometryTrait, g::AbstractGeometry) = coordinates(g)
GI.coordinates(::GI.AbstractPointTrait, g::AbstractGeometry) = coordinates(g)  # resolves ambiguity with GI's point fallback

_ngeom(g::AbstractGeometry) = (x = _items(g); x === nothing ? 0 : length(x))

GI.getcoord(::GI.PointTrait, g::Point, i::Integer) = g[i]

# GeoInterface reads an NTuple{D,<:Real} as a point, so the stored tuples serve as sub-points without a wrapper.
GI.ngeom(::GI.LineStringTrait, g::LineString) = _ngeom(g)
GI.getgeom(::GI.LineStringTrait, g::LineString, i::Integer) = g[i]
GI.isclosed(::GI.LineStringTrait, g::LineString) = first(g) == last(g)

GI.ngeom(::GI.MultiPointTrait, g::MultiPoint) = _ngeom(g)
GI.getgeom(::GI.MultiPointTrait, g::MultiPoint, i::Integer) = g[i]

GI.ngeom(::GI.PolygonTrait, g::Polygon) = _ngeom(g)
GI.getgeom(::GI.PolygonTrait, g::Polygon{D,T}, i::Integer) where {D,T} = LineString{D,T}(nothing, g[i])
GI.getexterior(::GI.PolygonTrait, g::Polygon{D,T}) where {D,T} = LineString{D,T}(nothing, first(g))
GI.nhole(::GI.PolygonTrait, g::Polygon) = _ngeom(g) - 1
GI.gethole(::GI.PolygonTrait, g::Polygon{D,T}, i::Integer) where {D,T} = LineString{D,T}(nothing, g[i+1])

GI.ngeom(::GI.MultiLineStringTrait, g::MultiLineString) = _ngeom(g)
GI.getgeom(::GI.MultiLineStringTrait, g::MultiLineString{D,T}, i::Integer) where {D,T} = LineString{D,T}(nothing, g[i])

GI.ngeom(::GI.MultiPolygonTrait, g::MultiPolygon) = _ngeom(g)
GI.getgeom(::GI.MultiPolygonTrait, g::MultiPolygon{D,T}, i::Integer) where {D,T} = Polygon{D,T}(nothing, g[i])

GI.ngeom(::GI.GeometryCollectionTrait, g::GeometryCollection) = _ngeom(g)
GI.getgeom(::GI.GeometryCollectionTrait, g::GeometryCollection, i::Integer) = g[i]

GI.isfeature(::Type{<:Feature}) = true
GI.trait(::Feature) = GI.FeatureTrait()
GI.geometry(f::Feature) = geometry(f)
GI.properties(f::Feature) = properties(f)

GI.isfeaturecollection(::Type{<:AbstractFeatureCollection}) = true
GI.trait(::AbstractFeatureCollection) = GI.FeatureCollectionTrait()
GI.getfeature(::GI.FeatureCollectionTrait, fc::AbstractFeatureCollection, i::Integer) = fc[i]
GI.nfeature(::GI.FeatureCollectionTrait, fc::AbstractFeatureCollection) = length(fc)

GI.DataAPI.metadatasupport(::Type{<:AbstractFeatureCollection}) = (; read=true, write=false)
GI.DataAPI.metadatakeys(::AbstractFeatureCollection) = ("GEOINTERFACE:geometrycolumns", "GEOINTERFACE:crs")

function GI.DataAPI.metadata(fc::AbstractFeatureCollection, key, default; style=false)
    val, thisstyle = if key == "GEOINTERFACE:geometrycolumns"
        (:geometry,), :note
    elseif key == "GEOINTERFACE:crs"
        GI.crs(fc), :note
    else
        default, :default
    end
    return style ? (val, thisstyle) : val
end

function GI.DataAPI.metadata(fc::AbstractFeatureCollection, key; style=false)
    key in GI.DataAPI.metadatakeys(fc) || throw(KeyError(key))
    return GI.DataAPI.metadata(fc, key, nothing; style)
end

function Extents.extent(x::GeoJSONT)
    bb = bbox(x)
    bb === nothing && return nothing
    length(bb) == 4 && return Extents.Extent(X=(bb[1], bb[3]), Y=(bb[2], bb[4]))
    length(bb) == 6 && return Extents.Extent(X=(bb[1], bb[4]), Y=(bb[2], bb[5]), Z=(bb[3], bb[6]))
    return nothing
end

GI.crs(::GeoJSONT) = GeoFormatTypes.EPSG(4326)
