
# TODO this is type piracy, how to solve? define all these geometry types here?
# this could be an issue if JSON3 is used to encode geometries other than GeoJSON

GeoInterphase.geomtype(g::Point) = GeoInterphase.Point()
GeoInterphase.geomtype(g::LineString) = GeoInterphase.LineString()
GeoInterphase.geomtype(g::Polygon) = GeoInterphase.Polygon()
GeoInterphase.geomtype(g::MultiPoint) = GeoInterphase.MultiPoint()
GeoInterphase.geomtype(g::MultiLineString) = GeoInterphase.MultiLineString()
GeoInterphase.geomtype(g::MultiPolygon) = GeoInterphase.MultiPolygon()
GeoInterphase.geomtype(g::GeometryCollection) = GeoInterphase.GeometryCollection()
GeoInterphase.geomtype(f::Feature) = GeoInterphase.geomtype(geometry(f))

# we have to make use of the GeoInterphase fallbacks that call geomtype on the input

GeoInterphase.ncoord(g::Point) = length(g)
GeoInterphase.getcoord(g::Point, i) = g[i]

GeoInterphase.ncoord(g::LineString) = length(first(g))
GeoInterphase.npoint(g::LineString) = length(g)
GeoInterphase.getpoint(g::LineString, i) = Point(g[i])
# TODO what to return for length 0 and 1?
# TODO should this be an approximate equals for floating point?
GeoInterphase.isclosed(g::LineString, i) = first(g) == last(g)

GeoInterphase.ncoord(g::Polygon) = length(first(first(g)))
# TODO this should return a "LineString" according to GeoInterphase, but this cannot directly
# be identified as such, is that a problem?
GeoInterphase.getexterior(g::Polygon) = LineString(first(g))
GeoInterphase.nhole(g::Polygon) = length(g) - 1
GeoInterphase.gethole(g::Polygon, i) = LineString(g[i + 1])

GeoInterphase.ncoord(g::MultiPoint) = length(first(g))
GeoInterphase.npoint(g::MultiPoint) = length(g)
GeoInterphase.getpoint(g::MultiPoint, i) = Point(g[i])

GeoInterphase.ncoord(g::MultiLineString) = length(first(first(g)))
GeoInterphase.nlinestring(g::MultiLineString) = length(g)
GeoInterphase.getlinestring(g::MultiLineString, i) = LineString(g[i])

GeoInterphase.ncoord(g::MultiPolygon) = length(first(first(first(g))))
GeoInterphase.npolygon(g::MultiPolygon) = length(g)
GeoInterphase.getpolygon(g::MultiPolygon, i) = LineString(g[i])

GeoInterphase.ncoord(g::GeometryCollection) = GeoInterphase.ncoord(first(g))
GeoInterphase.ngeom(g::GeometryCollection) = length(g)
GeoInterphase.getgeom(g::GeometryCollection, i) = geometry(g[i])
