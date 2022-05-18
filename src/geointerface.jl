# Geometry
GeoInterface.isgeometry(g::Type{<:Geometry}) = true

GeoInterface.geomtrait(g::Point) = GeoInterface.PointTrait()
GeoInterface.geomtrait(g::LineString) = GeoInterface.LineStringTrait()
GeoInterface.geomtrait(g::Polygon) = GeoInterface.PolygonTrait()
GeoInterface.geomtrait(g::MultiPoint) = GeoInterface.MultiPointTrait()
GeoInterface.geomtrait(g::MultiLineString) = GeoInterface.MultiLineStringTrait()
GeoInterface.geomtrait(g::MultiPolygon) = GeoInterface.MultiPolygonTrait()
GeoInterface.geomtrait(g::GeometryCollection) = GeoInterface.GeometryCollectionTrait()
GeoInterface.geomtrait(f::Feature) = GeoInterface.geomtrait(geometry(f))

# we have to make use of the GeoInterface fallbacks that call geomtrait on the input
GeoInterface.ncoord(g::Point) = length(g)
GeoInterface.getcoord(g::Point, i::Int) = g[i]

GeoInterface.ncoord(g::LineString) = length(first(g))
GeoInterface.ngeom(g::LineString) = length(g)
GeoInterface.getgeom(g::LineString, i::Integer) = Point(g[i])
GeoInterface.getpoint(g::LineString, i::Int) = Point(g[i])
# TODO what to return for length 0 and 1?
# TODO should this be an approximate equals for floating point?
GeoInterface.isclosed(g::LineString) = first(g) == last(g)

GeoInterface.ngeom(g::Polygon) = length(first(g))
GeoInterface.getgeom(g::Polygon, i::Integer) = LineString(g[i])
GeoInterface.ncoord(g::Polygon) = length(first(first(g)))
GeoInterface.getexterior(g::Polygon) = LineString(first(g))
GeoInterface.nhole(g::Polygon) = length(g) - 1 
GeoInterface.gethole(g::Polygon, i::Int) = LineString(g[i + 1])

GeoInterface.ncoord(g::MultiPoint) = length(first(g))
GeoInterface.ngeom(g::MultiPoint) = length(g)
GeoInterface.getgeom(g::MultiPoint, i::Int) = Point(g[i])

GeoInterface.ncoord(g::MultiLineString) = length(first(first(g)))
GeoInterface.ngeom(g::MultiLineString) = length(g)
GeoInterface.getgeom(g::MultiLineString, i::Int) = LineString(g[i])

GeoInterface.ncoord(g::MultiPolygon) = length(first(first(first(g))))
GeoInterface.ngeom(g::MultiPolygon) = length(g)
GeoInterface.getgeom(g::MultiPolygon, i::Int) = Polygon(g[i])

GeoInterface.ncoord(g::GeometryCollection) = GeoInterface.ncoord(first(g))
GeoInterface.ngeom(g::GeometryCollection) = length(g)
GeoInterface.getgeom(g::GeometryCollection, i::Int) = geometry(g[i])

# Features
function GeoInterface.extent(f::Union{Feature,FeatureCollection})
    bb = bbox(f)
    if isnothing(bb)
        return nothing
    else
        if length(bb) == 4
            return Extents.Extent(X=(bb[1], bb[3]), Y=(bb[2], bb[4]))
        elseif length(bb) == 6
            return Extents.Extent(X=(bb[1], bb[4]), Y=(bb[2], bb[5]), Z=(bb[3], bb[6]))
        else
            error("Incorrectly specified bbox: must have 4 or 6 values")
        end
    end
end
GeoInterface.crs(f::Union{Feature,FeatureCollection,Geometry}) = GeoFormatTypes.EPSG(4326)
GeoInterface.isfeature(::Union{Feature,FeatureCollection}) = true
GeoInterface.geometry(f::Union{Feature,FeatureCollection}) = geometry(f)
