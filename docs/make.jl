using GeoJSON
using Documenter

makedocs(;
    modules=[GeoJSON],
    sitename="GeoJSON.jl",
    format=Documenter.HTML(;
        repolink="https://github.com/JuliaGeo/GeoJSON.jl/",
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://JuliaGeo.github.io/GeoJSON.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/JuliaGeo/GeoJSON.jl",
    devbranch="main",
)
