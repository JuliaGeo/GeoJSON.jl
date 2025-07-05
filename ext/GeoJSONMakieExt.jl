module GeoJSONMakieExt

import GeoInterface
import GeoJSON
import Makie

GeoInterface.@enable_makie Makie GeoJSON.AbstractGeometry

end
