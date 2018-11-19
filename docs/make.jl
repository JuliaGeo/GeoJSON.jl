using Documenter
using GeoJSON

makedocs(
    sitename = "GeoJSON",
    format = :html,
    modules = [GeoJSON],
)

deploydocs(
    repo = "github.com/JuliaGeo/GeoJSON.jl.git"
)
