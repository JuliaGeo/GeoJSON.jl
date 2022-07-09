using GeoJSON
using Documenter

makedocs(;
    modules=[GeoJSON],
    repo="https://github.com/JuliaGeo/GeoJSON.jl/blob/{commit}{path}#{line}",
    sitename="GeoJSON.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://JuliaGeo.github.io/GeoJSON.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
    strict=true,
)

deploydocs(;
    repo="github.com/JuliaGeo/GeoJSON.jl",
    devbranch="main",
)
