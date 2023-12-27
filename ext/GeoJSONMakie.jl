module GeoJSONMakie
using GeoInterfaceMakie: GeoInterfaceMakie
using GeoJSON: GeoJSON

GeoInterfaceMakie.@enable GeoJSON.AbstractShape

end
