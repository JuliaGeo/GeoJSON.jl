# deprecated in GeoJSON v0.5
@deprecate parse read
@deprecate parsefile(path) read(Base.read(path, String))
@deprecate geojson write
