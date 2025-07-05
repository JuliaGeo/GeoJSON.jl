# Geometry
GI.isgeometry(g::Type{<:AbstractGeometry}) = true

GI.geomtrait(::Point) = GI.PointTrait()
GI.geomtrait(::LineString) = GI.LineStringTrait()
GI.geomtrait(::Polygon) = GI.PolygonTrait()
GI.geomtrait(::MultiPoint) = GI.MultiPointTrait()
GI.geomtrait(::MultiLineString) = GI.MultiLineStringTrait()
GI.geomtrait(::MultiPolygon) = GI.MultiPolygonTrait()
GI.geomtrait(::GeometryCollection) = GI.GeometryCollectionTrait()

GI.ncoord(::GI.AbstractTrait, ::AbstractGeometry{D,T}) where {D,T} = D
GI.coordinates(::GI.AbstractGeometryTrait, g::AbstractGeometry) = coordinates(g)
GI.coordinates(::GI.AbstractPointTrait, g::AbstractGeometry) = coordinates(g)  # prevent ambiguity

# we have to make use of the GI fallbacks that call geomtrait on the input
GI.getcoord(::GI.PointTrait, g::Point, i::Int) = g[i]

GI.ngeom(::GI.LineStringTrait, g::LineString) = length(g)
GI.getgeom(::GI.LineStringTrait, g::LineString{D,T}, i::Integer) where {D,T} = Point{D,T}(nothing, g[i])
GI.getpoint(::GI.LineStringTrait, g::LineString{D,T}, i::Int) where {D,T} = Point{D,T}(nothing, g[i])
# TODO what to return for length 0 and 1?
# TODO should this be an approximate equals for floating point?
GI.isclosed(::GI.LineStringTrait, g::LineString) = first(g) == last(g)

GI.ngeom(::GI.PolygonTrait, g::Polygon) = length(g)
GI.getgeom(::GI.PolygonTrait, g::Polygon{D,T}, i::Integer) where {D,T} = LineString{D,T}(nothing, g[i])
GI.ncoord(::GI.PolygonTrait, g::Polygon) = length(first(first(g)))
GI.getexterior(::GI.PolygonTrait, g::Polygon{D,T}) where {D,T} = LineString{D,T}(nothing, first(g))
GI.nhole(::GI.PolygonTrait, g::Polygon) = length(g) - 1
GI.gethole(::GI.PolygonTrait, g::Polygon{D,T}, i::Int) where {D,T} = LineString{D,T}(nothing, g[i+1])

GI.ngeom(::GI.MultiPointTrait, g::MultiPoint) = length(g)
GI.getgeom(::GI.MultiPointTrait, g::MultiPoint{D,T}, i::Int) where {D,T} = Point{D,T}(nothing, g[i])

GI.ngeom(::GI.MultiLineStringTrait, g::MultiLineString) = length(g)
GI.getgeom(::GI.MultiLineStringTrait, g::MultiLineString{D,T}, i::Int) where {D,T} =
    LineString{D,T}(nothing, g[i])

GI.ngeom(::GI.MultiPolygonTrait, g::MultiPolygon) = length(g)
GI.getgeom(::GI.MultiPolygonTrait, g::MultiPolygon{D,T}, i::Int) where {D,T} = Polygon{D,T}(nothing, g[i])

GI.ngeom(::GI.GeometryCollectionTrait, g::GeometryCollection) = length(g)
GI.getgeom(::GI.GeometryCollectionTrait, g::GeometryCollection, i::Int) = g[i]
GI.coordinates(::GI.GeometryCollectionTrait, g::GeometryCollection) = coordinates.(geometry(g))

# Feature
GI.isfeature(::Type{<:Feature}) = true
GI.trait(::Feature) = GI.FeatureTrait()
GI.geometry(f::Feature) = geometry(f)
GI.properties(f::Feature) = properties(f)

# FeatureCollection
GI.isfeaturecollection(::Type{<:AbstractFeatureCollection}) = true
GI.trait(::AbstractFeatureCollection) = GI.FeatureCollectionTrait()
GI.getfeature(::GI.FeatureCollectionTrait, fc::AbstractFeatureCollection, i::Integer) = fc[i]
GI.nfeature(::GI.FeatureCollectionTrait, fc::AbstractFeatureCollection) = length(fc)

# Metadata support for FeatureCollection, since it's also a Tables.jl table
GI.DataAPI.metadatasupport(::Type{<: AbstractFeatureCollection}) = (; read = true, write = false)
GI.DataAPI.metadatakeys(::AbstractFeatureCollection) = ("GEOINTERFACE:geometrycolumns", "GEOINTERFACE:crs")

function GI.DataAPI.metadata(fc::AbstractFeatureCollection, key, default; style = false)
    val, thisstyle = if key == "GEOINTERFACE:geometrycolumns"
        (:geometry,), :note # only this one geom column is supported by the GeoJSON spec
    elseif key == "GEOINTERFACE:crs"
        GI.crs(fc), :note
    else
        default, :default
    end
    return style ? (val, thisstyle) : val
end

function GI.DataAPI.metadata(fc::AbstractFeatureCollection, key; style = false)
    if !(key in GI.DataAPI.metadatakeys(fc))
        throw(KeyError(key))
    else
        return GI.DataAPI.metadata(fc, key, nothing; style)
    end
end

# Any GeoJSON Object
GI.Extents.extent(x::GeoJSONT{2}) = _extent2(x)
GI.Extents.extent(x::GeoJSONT{3}) = _extent3(x)

function _extent3(x)
    bb = bbox(x)
    isnothing(bb) ? nothing :
    Extents.Extent(
        X=(bb[1], bb[4]),
        Y=(bb[2], bb[5]),
        Z=(bb[3], bb[6]),
    )
end
function _extent2(x)
    bb = bbox(x)
    ex = isnothing(bb) ? nothing : Extents.Extent(X=(bb[1], bb[3]), Y=(bb[2], bb[4]))
    return ex
end

GI.crs(::GeoJSONT) = GeoFormatTypes.EPSG(4326)
