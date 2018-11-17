using Documenter
using GeoJSON

makedocs(
    sitename = "GeoJSON",
    format = :html,
    modules = [GeoJSON],
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
