module GeoJSONMakieExt
using GeoInterfaceMakie: GeoInterfaceMakie
using GeoJSON: GeoJSON

GeoInterfaceMakie.@enable GeoJSON.AbstractGeometry

end
