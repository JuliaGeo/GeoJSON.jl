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
    # writing are both exercised. No network, randomness, or committed golden.
    json = GeoJSON.JSON.parsefile(fixture)
    features = json["features"]
    json["features"] = [features[mod1(i, length(features))] for i in 1:2000]
    Base.write(large, GeoJSON.JSON.json(json))
    args = [fixture, large]
    golden = joinpath(dir, "golden.txt")
    jit = `$(Base.julia_cmd()) --startup-file=no --project=$(@__DIR__) -e 'using GeoJSONTrimApp; GeoJSONTrimApp.main(ARGS)' $args`
    open(io -> run(pipeline(jit; stdout=io)), golden, "w")
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
    actual = read(`$executable $args`, String)
    @test actual == Base.read(golden, String)
    println("Trim executable bytes: ", filesize(executable))
end
