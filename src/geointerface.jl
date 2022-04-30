
# TODO this is type piracy, how to solve? define all these geometry types here?
# this could be an issue if JSON3 is used to encode geometries other than GeoJSON

GeoInterface.geomtype(g::Point) = GeoInterface.PointTrait()
GeoInterface.geomtype(g::LineString) = GeoInterface.LineStringTrait()
GeoInterface.geomtype(g::Polygon) = GeoInterface.PolygonTrait()
GeoInterface.geomtype(g::MultiPoint) = GeoInterface.MultiPointTrait()
GeoInterface.geomtype(g::MultiLineString) = GeoInterface.MultiLineStringTrait()
GeoInterface.geomtype(g::MultiPolygon) = GeoInterface.MultiPolygonTrait()
GeoInterface.geomtype(g::GeometryCollection) = GeoInterface.GeometryCollectionTrait()
GeoInterface.geomtype(f::Feature) = GeoInterface.geomtype(geometry(f))

# we have to make use of the GeoInterface fallbacks that call geomtype on the input

GeoInterface.ncoord(g::Point) = length(g)
GeoInterface.getcoord(g::Point, i::Int) = g[i]

GeoInterface.ncoord(g::LineString) = length(first(g))
GeoInterface.npoint(g::LineString) = length(g)
GeoInterface.getpoint(g::LineString, i::Int) = Point(g[i])
# TODO what to return for length 0 and 1?
# TODO should this be an approximate equals for floating point?
GeoInterface.isclosed(g::LineString) = first(g) == last(g)

GeoInterface.ncoord(g::Polygon) = length(first(first(g)))
# TODO this should return a "LineString" according to GeoInterface, but this cannot directly
# be identified as such, is that a problem?
GeoInterface.getexterior(g::Polygon) = LineString(first(g))
GeoInterface.nhole(g::Polygon) = length(g) - 1
GeoInterface.gethole(g::Polygon, i::Int) = LineString(g[i + 1])

GeoInterface.ncoord(g::MultiPoint) = length(first(g))
GeoInterface.npoint(g::MultiPoint) = length(g)
GeoInterface.getpoint(g::MultiPoint, i::Int) = Point(g[i])

GeoInterface.ncoord(g::MultiLineString) = length(first(first(g)))
GeoInterface.nlinestring(g::MultiLineString) = length(g)
GeoInterface.getlinestring(g::MultiLineString, i::Int) = LineString(g[i])

GeoInterface.ncoord(g::MultiPolygon) = length(first(first(first(g))))
GeoInterface.npolygon(g::MultiPolygon) = length(g)
GeoInterface.getpolygon(g::MultiPolygon, i::Int) = LineString(g[i])

GeoInterface.ncoord(g::GeometryCollection) = GeoInterface.ncoord(first(g))
GeoInterface.ngeom(g::GeometryCollection) = length(g)
GeoInterface.getgeom(g::GeometryCollection, i::Int) = geometry(g[i])
