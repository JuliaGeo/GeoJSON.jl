using GeoJSON
using Documenter

makedocs(;
    modules=[GeoJSON],
    sitename="GeoJSON.jl",
    # The Internals block on the index page collects every docstring except the module's, which is the README.
    checkdocs=:none,
    format=Documenter.HTML(;
        repolink="https://github.com/JuliaGeo/GeoJSON.jl/",
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://JuliaGeo.github.io/GeoJSON.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Schemas and static compilation" => "schemas.md",
        "Lazy reading" => "lazy.md",
    ],
)

deploydocs(;
    repo="github.com/JuliaGeo/GeoJSON.jl",
    devbranch="main",
)
