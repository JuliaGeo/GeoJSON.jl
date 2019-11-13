
# TODO this is type piracy, how to solve? define all these geometry types here?
# this could be an issue if JSON3 is used to encode geometries other than GeoJSON

GeoInterfaceRFC.geomtype(g::Point) = GeoInterfaceRFC.Point()
GeoInterfaceRFC.geomtype(g::LineString) = GeoInterfaceRFC.LineString()
GeoInterfaceRFC.geomtype(g::Polygon) = GeoInterfaceRFC.Polygon()
GeoInterfaceRFC.geomtype(g::MultiPoint) = GeoInterfaceRFC.MultiPoint()
GeoInterfaceRFC.geomtype(g::MultiLineString) = GeoInterfaceRFC.MultiLineString()
GeoInterfaceRFC.geomtype(g::MultiPolygon) = GeoInterfaceRFC.MultiPolygon()
GeoInterfaceRFC.geomtype(g::GeometryCollection) = GeoInterfaceRFC.GeometryCollection()
GeoInterfaceRFC.geomtype(f::Feature) = GeoInterfaceRFC.geomtype(geometry(f))

# we have to make use of the GeoInterfaceRFC fallbacks that call geomtype on the input

GeoInterfaceRFC.ncoord(g::Point) = length(g)
GeoInterfaceRFC.getcoord(g::Point, i::Int) = g[i]

GeoInterfaceRFC.ncoord(g::LineString) = length(first(g))
GeoInterfaceRFC.npoint(g::LineString) = length(g)
GeoInterfaceRFC.getpoint(g::LineString, i::Int) = Point(g[i])
# TODO what to return for length 0 and 1?
# TODO should this be an approximate equals for floating point?
GeoInterfaceRFC.isclosed(g::LineString) = first(g) == last(g)

GeoInterfaceRFC.ncoord(g::Polygon) = length(first(first(g)))
# TODO this should return a "LineString" according to GeoInterfaceRFC, but this cannot directly
# be identified as such, is that a problem?
GeoInterfaceRFC.getexterior(g::Polygon) = LineString(first(g))
GeoInterfaceRFC.nhole(g::Polygon) = length(g) - 1
GeoInterfaceRFC.gethole(g::Polygon, i::Int) = LineString(g[i + 1])

GeoInterfaceRFC.ncoord(g::MultiPoint) = length(first(g))
GeoInterfaceRFC.npoint(g::MultiPoint) = length(g)
GeoInterfaceRFC.getpoint(g::MultiPoint, i::Int) = Point(g[i])

GeoInterfaceRFC.ncoord(g::MultiLineString) = length(first(first(g)))
GeoInterfaceRFC.nlinestring(g::MultiLineString) = length(g)
GeoInterfaceRFC.getlinestring(g::MultiLineString, i::Int) = LineString(g[i])

GeoInterfaceRFC.ncoord(g::MultiPolygon) = length(first(first(first(g))))
GeoInterfaceRFC.npolygon(g::MultiPolygon) = length(g)
GeoInterfaceRFC.getpolygon(g::MultiPolygon, i::Int) = LineString(g[i])

GeoInterfaceRFC.ncoord(g::GeometryCollection) = GeoInterfaceRFC.ncoord(first(g))
GeoInterfaceRFC.ngeom(g::GeometryCollection) = length(g)
GeoInterfaceRFC.getgeom(g::GeometryCollection, i::Int) = geometry(g[i])
