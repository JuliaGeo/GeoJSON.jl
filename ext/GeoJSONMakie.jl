module GeoJSONMakie
using GeoInterfaceMakie: GeoInterfaceMakie
using GeoJSON: GeoJSON

@show "here in GeoJSONMakie"
GeoInterfaceMakie.@enable GeoJSON.AbstractGeometry

end
