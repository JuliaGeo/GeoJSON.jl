using Documenter
using GeoJSON

makedocs(
    sitename = "GeoJSON",
    modules = [GeoJSON],
)

deploydocs(
    repo = "github.com/JuliaGeo/GeoJSON.jl.git"
)
