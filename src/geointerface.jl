
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

GeoInterphase.ncoord(g::Point) = length(g.coordinates)
GeoInterphase.getcoord(g::Point, i) = g.coordinates[i]

GeoInterphase.ncoord(g::LineString) = length(first(g.coordinates))
GeoInterphase.npoint(g::LineString) = length(g.coordinates)
GeoInterphase.getpoint(g::LineString, i) = g.coordinates[i]
# TODO what to return for length 0 and 1?
# TODO should this be an approximate equals for floating point?
GeoInterphase.isclosed(g::LineString, i) = first(g.coordinates) == last(g.coordinates)

GeoInterphase.ncoord(g::Polygon) = length(first(first(g.coordinates)))
# TODO this should return a "LineString" according to GeoInterphase, but this cannot directly
# be identified as such, is that a problem?
GeoInterphase.getexterior(g::Polygon) = first(g.coordinates)
GeoInterphase.nhole(g::Polygon) = length(g.coordinates) - 1
GeoInterphase.gethole(g::Polygon, i) = g.coordinates[i + 1]

GeoInterphase.ncoord(g::GeometryCollection) = GeoInterphase.ncoord(first(g.geometries))
GeoInterphase.ngeom(g::GeometryCollection) = length(g.geometries)
GeoInterphase.getgeom(g::GeometryCollection, i) = g.geometries[i]

GeoInterphase.ncoord(g::MultiPoint) = length(first(g.coordinates))
GeoInterphase.npoint(g::MultiPoint) = length(g.coordinates)
GeoInterphase.getpoint(g::MultiPoint, i) = g.coordinates[i]

GeoInterphase.ncoord(g::MultiLineString) = length(first(first(g.coordinates)))
GeoInterphase.nlinestring(g::MultiLineString) = length(g.coordinates)
GeoInterphase.getlinestring(g::MultiLineString, i) = g.coordinates[i]

GeoInterphase.ncoord(g::MultiPolygon) = length(first(first(first(g.coordinates))))
GeoInterphase.npolygon(g::MultiPolygon) = length(g.coordinates)
GeoInterphase.getpolygon(g::MultiPolygon, i) = g.coordinates[i]
