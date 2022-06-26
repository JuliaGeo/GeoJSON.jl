# Geometry
GI.isgeometry(g::Type{<:Geometry}) = true
GI.coordinates(::GI.AbstractGeometryTrait, g::Geometry) = GI.coordinates.(GI.getgeom(g))
# resolve ambiguity with GeoInterface fallback
GI.coordinates(::GI.AbstractPointTrait, g::Geometry) = GI.coordinates.(GI.getgeom(g))

GI.geomtrait(g::Point) = GI.PointTrait()
GI.geomtrait(g::LineString) = GI.LineStringTrait()
GI.geomtrait(g::Polygon) = GI.PolygonTrait()
GI.geomtrait(g::MultiPoint) = GI.MultiPointTrait()
GI.geomtrait(g::MultiLineString) = GI.MultiLineStringTrait()
GI.geomtrait(g::MultiPolygon) = GI.MultiPolygonTrait()
GI.geomtrait(g::GeometryCollection) = GI.GeometryCollectionTrait()

# we have to make use of the GI fallbacks that call geomtrait on the input
GI.ncoord(::GI.PointTrait, g::Point) = length(g)
GI.getcoord(::GI.PointTrait, g::Point, i::Int) = g[i]
GI.coordinates(::GI.PointTrait, g::Point) = collect(g)

GI.ncoord(::GI.LineStringTrait, g::LineString) = length(first(g))
GI.ngeom(::GI.LineStringTrait, g::LineString) = length(g)
GI.getgeom(::GI.LineStringTrait, g::LineString, i::Integer) = Point(g[i])
GI.getpoint(::GI.LineStringTrait, g::LineString, i::Int) = Point(g[i])
# TODO what to return for length 0 and 1?
# TODO should this be an approximate equals for floating point?
GI.isclosed(::GI.LineStringTrait, g::LineString) = first(g) == last(g)

GI.ngeom(::GI.PolygonTrait, g::Polygon) = length(g)
GI.getgeom(::GI.PolygonTrait, g::Polygon, i::Integer) = LineString(g[i])
GI.ncoord(::GI.PolygonTrait, g::Polygon) = length(first(first(g)))
GI.getexterior(::GI.PolygonTrait, g::Polygon) = LineString(first(g))
GI.nhole(::GI.PolygonTrait, g::Polygon) = length(g) - 1
GI.gethole(::GI.PolygonTrait, g::Polygon, i::Int) = LineString(g[i+1])

GI.ncoord(::GI.MultiPointTrait, g::MultiPoint) = length(first(g))
GI.ngeom(::GI.MultiPointTrait, g::MultiPoint) = length(g)
GI.getgeom(::GI.MultiPointTrait, g::MultiPoint, i::Int) = Point(g[i])

GI.ncoord(::GI.MultiLineStringTrait, g::MultiLineString) = length(first(first(g)))
GI.ngeom(::GI.MultiLineStringTrait, g::MultiLineString) = length(g)
GI.getgeom(::GI.MultiLineStringTrait, g::MultiLineString, i::Int) = LineString(g[i])

GI.ncoord(::GI.MultiPolygonTrait, g::MultiPolygon) = length(first(first(first(g))))
GI.ngeom(::GI.MultiPolygonTrait, g::MultiPolygon) = length(g)
GI.getgeom(::GI.MultiPolygonTrait, g::MultiPolygon, i::Int) = Polygon(g[i])

GI.ncoord(::GI.GeometryCollectionTrait, g::GeometryCollection) = GI.ncoord(first(g))
GI.ngeom(::GI.GeometryCollectionTrait, g::GeometryCollection) = length(g)
GI.getgeom(::GI.GeometryCollectionTrait, g::GeometryCollection, i::Int) = geometry(g[i])

# Features
function GI.extent(f::Union{Feature,FeatureCollection})
    bb = bbox(f)
    if isnothing(bb)
        return nothing
    else
        if length(bb) == 4
            return Extents.Extent(X = (bb[1], bb[3]), Y = (bb[2], bb[4]))
        elseif length(bb) == 6
            return Extents.Extent(
                X = (bb[1], bb[4]),
                Y = (bb[2], bb[5]),
                Z = (bb[3], bb[6]),
            )
        else
            error("Incorrectly specified bbox: must have 4 or 6 values")
        end
    end
end

GI.crs(::GeoJSONObject) = GeoFormatTypes.EPSG(4326)

GI.isfeature(::Type{<:Feature}) = true
GI.trait(::Feature) = GI.FeatureTrait()
GI.geometry(f::Feature) = geometry(f)
GI.properties(f::Feature) = properties(f)

GI.isfeaturecollection(::Type{<:FeatureCollection{T}}) where {T} = true
GI.trait(::FeatureCollection) = GI.FeatureCollectionTrait()
GI.getfeature(::GI.FeatureCollectionTrait, fc::FeatureCollection, i::Integer) = fc[i]
GI.nfeature(::GI.FeatureCollectionTrait, fc::FeatureCollection) = length(fc)
