
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

GeoInterphase.ncoord(::GeoInterphase.Point, g::JSON3.Object) = length(g.coordinates)
GeoInterphase.getcoord(::GeoInterphase.Point, g, i) = g.coordinates[i]

GeoInterphase.ncoord(::GeoInterphase.LineString, g::JSON3.Object) = length(first(g.coordinates))
GeoInterphase.npoint(::GeoInterphase.LineString, g::JSON3.Object) = length(g.coordinates)
GeoInterphase.getpoint(::GeoInterphase.LineString, g::JSON3.Object, i) = g.coordinates[i]
# TODO what to return for length 0 and 1?
# TODO should this be an approximate equals for floating point?
GeoInterphase.isclosed(::GeoInterphase.LineString, g::JSON3.Object, i) = first(g.coordinates) == last(g.coordinates)

GeoInterphase.ncoord(::GeoInterphase.Polygon, g::JSON3.Object) = length(first(first(g.coordinates)))
# TODO this should return a "LineString" according to GeoInterphase, but this cannot directly
# be identified as such, is that a problem?
GeoInterphase.getexterior(::GeoInterphase.Polygon, g::JSON3.Object) = first(g.coordinates)
GeoInterphase.nhole(::GeoInterphase.Polygon, g::JSON3.Object) = length(g.coordinates) - 1
GeoInterphase.gethole(::GeoInterphase.Polygon, g::JSON3.Object, i) = g.coordinates[i + 1]

GeoInterphase.ncoord(::GeoInterphase.GeometryCollection, g::JSON3.Object) = GeoInterphase.ncoord(first(g.geometries))
GeoInterphase.ngeom(::GeoInterphase.GeometryCollection, g::JSON3.Object) = length(g.geometries)
GeoInterphase.getgeom(::GeoInterphase.GeometryCollection, g::JSON3.Object, i) = g.geometries[i]

GeoInterphase.ncoord(::GeoInterphase.MultiPoint, g::JSON3.Object) = length(first(g.coordinates))
GeoInterphase.npoint(::GeoInterphase.MultiPoint, g::JSON3.Object) = length(g.coordinates)
GeoInterphase.getpoint(::GeoInterphase.MultiPoint, g::JSON3.Object, i) = g.coordinates[i]

GeoInterphase.ncoord(::GeoInterphase.MultiLineString, g::JSON3.Object) = length(first(first(g.coordinates)))
GeoInterphase.nlinestring(::GeoInterphase.MultiLineString, g::JSON3.Object) = length(g.coordinates)
GeoInterphase.getlinestring(::GeoInterphase.MultiLineString, g::JSON3.Object, i) = g.coordinates[i]

GeoInterphase.ncoord(::GeoInterphase.MultiPolygon, g::JSON3.Object) = length(first(first(first(g.coordinates))))
GeoInterphase.npolygon(::GeoInterphase.MultiPolygon, g::JSON3.Object) = length(g.coordinates)
GeoInterphase.getpolygon(::GeoInterphase.MultiPolygon, g::JSON3.Object, i) = g.coordinates[i]
