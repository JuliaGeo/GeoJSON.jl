# Geometry
GI.isgeometry(g::Type{<:AbstractGeometry}) = true

GI.geomtrait(::Point) = GI.PointTrait()
GI.geomtrait(::LineString) = GI.LineStringTrait()
GI.geomtrait(::Polygon) = GI.PolygonTrait()
GI.geomtrait(::MultiPoint) = GI.MultiPointTrait()
GI.geomtrait(::MultiLineString) = GI.MultiLineStringTrait()
GI.geomtrait(::MultiPolygon) = GI.MultiPolygonTrait()
GI.geomtrait(::GeometryCollection) = GI.GeometryCollectionTrait()

GI.ncoord(::GI.AbstractTrait, ::AbstractGeometry{D}) where {D} = D
GI.coordinates(::GI.AbstractGeometryTrait, g::AbstractGeometry) = coordinates(g)
GI.coordinates(::GI.AbstractPointTrait, g::AbstractGeometry) = coordinates(g)  # prevent ambiguity

# we have to make use of the GI fallbacks that call geomtrait on the input
GI.getcoord(::GI.PointTrait, g::Point, i::Int) = g[i]

GI.ngeom(::GI.LineStringTrait, g::LineString) = length(g)
GI.getgeom(::GI.LineStringTrait, g::LineString, i::Integer) = Point(nothing, g[i])
GI.getpoint(::GI.LineStringTrait, g::LineString, i::Int) = Point(nothing, g[i])
# TODO what to return for length 0 and 1?
# TODO should this be an approximate equals for floating point?
GI.isclosed(::GI.LineStringTrait, g::LineString) = first(g) == last(g)

GI.ngeom(::GI.PolygonTrait, g::Polygon) = length(g)
GI.getgeom(::GI.PolygonTrait, g::Polygon, i::Integer) = LineString(nothing, g[i])
GI.ncoord(::GI.PolygonTrait, g::Polygon) = length(first(first(g)))
GI.getexterior(::GI.PolygonTrait, g::Polygon) = LineString(nothing, first(g))
GI.nhole(::GI.PolygonTrait, g::Polygon) = length(g) - 1
GI.gethole(::GI.PolygonTrait, g::Polygon, i::Int) = LineString(nothing, g[i+1])

GI.ngeom(::GI.MultiPointTrait, g::MultiPoint) = length(g)
GI.getgeom(::GI.MultiPointTrait, g::MultiPoint, i::Int) = Point(nothing, g[i])

GI.ngeom(::GI.MultiLineStringTrait, g::MultiLineString) = length(g)
GI.getgeom(::GI.MultiLineStringTrait, g::MultiLineString, i::Int) =
    LineString(nothing, g[i])

GI.ngeom(::GI.MultiPolygonTrait, g::MultiPolygon) = length(g)
GI.getgeom(::GI.MultiPolygonTrait, g::MultiPolygon, i::Int) = Polygon(nothing, g[i])

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

# Any GeoJSON Object
GI.extent(::GI.FeatureTrait, x::GeoJSONT{2}) = _extent2(x)
GI.extent(::GI.FeatureCollectionTrait, x::GeoJSONT{2}) = _extent2(x)
GI.extent(::GI.AbstractGeometryTrait, x::GeoJSONT{2}) = _extent2(x)
GI.extent(::GI.FeatureTrait, x::GeoJSONT{3}) = _extent3(x)
GI.extent(::GI.FeatureCollectionTrait, x::GeoJSONT{3}) = _extent3(x)
GI.extent(::GI.AbstractGeometryTrait, x::GeoJSONT{3}) = _extent3(x)

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
    isnothing(bb) ? nothing : Extents.Extent(X=(bb[1], bb[3]), Y=(bb[2], bb[4]))
end

GI.crs(::GeoJSONT) = GeoFormatTypes.EPSG(4326)

GeoInterfaceRecipes.@enable_geo_plots GeoJSON.AbstractGeometry
