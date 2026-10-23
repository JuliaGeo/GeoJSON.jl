# julia --project=test/trim -e 'using Pkg; Pkg.instantiate(); include("test/trim/runtests.jl")'
using Test, Pkg, JuliaC

@testset "Schema read and write under --trim=safe" begin
    mktempdir() do dir
        package = joinpath(dir, "TrimGeoJSON")
        cp(joinpath(@__DIR__, "TrimGeoJSON"), package)
        original = Base.active_project()
        try
            Pkg.activate(package)
            Pkg.develop(path=normpath(joinpath(@__DIR__, "../..")))
            Pkg.instantiate()
        finally
            Pkg.activate(dirname(original))
        end
        output = joinpath(dir, "build")
        # Safe mode rejects unresolved calls; failures must not fall back to read-only.
        JuliaC.main(["--output-exe", "trimgeojson", "--bundle", output,
                     "--trim=safe", "--experimental", package])
        exe = joinpath(output, "bin", "trimgeojson")
        @test isfile(exe)
        text = read(`$exe $(joinpath(@__DIR__, "data.geojson"))`, String)
        @test occursin("features 2", text)
        @test occursin("name Alpha", text)
        @test occursin("roundtrip 2", text)
        @test occursin(r"written [1-9][0-9]*", text)
        println(text)
    end
end
