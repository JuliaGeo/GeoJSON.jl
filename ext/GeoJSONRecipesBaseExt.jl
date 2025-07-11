module GeoJSONRecipesBaseExt

import GeoInterface
import GeoJSON
import RecipesBase

GeoInterface.@enable_plots RecipesBase GeoJSON.AbstractGeometry

end
