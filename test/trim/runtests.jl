# Run with Julia >= 1.12: julia --project=test/trim test/trim/runtests.jl
# Install the experimental compiler separately: Pkg.Apps.add("JuliaC"; version="0.3.12").
using Pkg, Test
cd(@__DIR__) do
    Pkg.develop(path="../..")
end
Pkg.instantiate()
using GeoJSON

mktempdir() do dir
    fixture = joinpath(@__DIR__, "fixture.geojson")
    large = joinpath(dir, "features-2000.geojson")
    # Repeat the whole mixed fixture so large-file scanning and nested collection
    # writing are both exercised, with no network or randomness.
    json = GeoJSON.JSON.parsefile(fixture)
    features = json["features"]
    json["features"] = [features[mod1(i, length(features))] for i in 1:2000]
    Base.write(large, GeoJSON.JSON.json(json))
    golden = Base.read(joinpath(@__DIR__, "fixture.golden.txt"), String)
    jit = `$(Base.julia_cmd()) --startup-file=no --project=$(@__DIR__) -e 'using GeoJSONTrimApp; GeoJSONTrimApp.main(ARGS)'`
    # The small fixture has an independent, committed expectation. The large
    # case additionally compares JIT and native behavior at realistic scale.
    @test read(`$jit $fixture`, String) == golden
    large_jit = read(`$jit $large`, String)
    bundle = joinpath(dir, "build")
    # JULIAC permits a task-local compiler env, avoiding a global app install.
    compiler = get(ENV, "JULIAC", "juliac")
    cmd = `$compiler --output-exe geojson-trim --bundle $bundle --trim=safe --experimental $(@__DIR__)`
    log = joinpath(dir, "build.log")
    result = open(log, "w") do io
        run(pipeline(ignorestatus(cmd); stdout=io, stderr=io))
    end
    buildlog = Base.read(log, String)
    print(buildlog)
    @test success(result) # --trim=safe makes any unresolved call fatal
    @test !occursin(r"(?im)^\s*(?:Error|Warning) #\d+:", buildlog)
    @test !occursin(r"Trim verify finished with (?!0 errors, 0 warnings)", buildlog)
    success(result) || error("trim build failed")
    executable = joinpath(bundle, "bin", "geojson-trim")
    @test read(`$executable $fixture`, String) == golden
    @test read(`$executable $large`, String) == large_jit
    println("Trim executable bytes: ", filesize(executable))
end
