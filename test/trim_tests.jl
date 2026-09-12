using Test
using GeoJSON
import Pkg

const TRIM_DIR = joinpath(@__DIR__, "trim")
const TRIM_PACKAGE = joinpath(TRIM_DIR, "TrimGeoJSON")
const TRIM_DATA = joinpath(TRIM_DIR, "data.geojson")
const TRIM_EXE = "trimgeojson"
const TRIM_COMPILE_TIMEOUT_S = 900.0
const TRIM_RUN_TIMEOUT_S = 60.0

include(joinpath(TRIM_PACKAGE, "src", "TrimGeoJSON.jl"))

geojson_root() = normpath(joinpath(dirname(pathof(GeoJSON)), ".."))

# The copy gets an absolute `[sources]` path for GeoJSON, so JuliaC's own temp copy resolves it.
function prepare_trim_package(tmpdir::String)::String
    pkg = joinpath(tmpdir, "TrimGeoJSON")
    cp(TRIM_PACKAGE, pkg)
    original = Base.active_project()
    try
        Pkg.activate(pkg; io=devnull)
        Pkg.develop(Pkg.PackageSpec(path=geojson_root()); io=devnull)
        Pkg.instantiate(; io=devnull)
    finally
        original === nothing || Pkg.activate(original; io=devnull)
    end
    return pkg
end

set_steps!(pkg::String; write::Bool) =
    Base.write(joinpath(pkg, "src", "steps.jl"),
               "# Build-time switches; the harness rewrites this file to build a subset.\nconst WRITE = $write\n")

function run_with_timeout(cmd::Cmd; timeout_s::Float64, label::String)
    logpath = tempname()
    proc = open(logpath, "w") do out
        run(pipeline(ignorestatus(cmd); stdout=out, stderr=out); wait=false)
    end
    started = time()
    next_log = started + 30.0
    timed_out = false
    while process_running(proc)
        if time() - started >= timeout_s
            kill(proc)
            timed_out = true
            break
        end
        if time() >= next_log
            println("[trim] $label running for $(round(Int, time() - started)) s")
            next_log += 30.0
        end
        sleep(0.2)
    end
    wait(proc)
    output = read(logpath, String)
    rm(logpath; force=true)
    return proc.exitcode, output, timed_out
end

function juliac_build(pkg::String, outdir::String)
    julia = joinpath(Sys.BINDIR, Base.julia_exename())
    project = Base.active_project()
    cmd = `$julia --startup-file=no --history-file=no --project=$project
           -e "using JuliaC; JuliaC.main(ARGS)" --
           --output-exe $TRIM_EXE --bundle $outdir --trim=safe --experimental $pkg`
    return run_with_timeout(cmd; timeout_s=TRIM_COMPILE_TIMEOUT_S, label="compile")
end

# A clean build prints no summary line, so the fallback counts individual messages.
function verifier_totals(output::String)
    m = match(r"Trim verify finished with\s+(\d+)\s+errors,\s+(\d+)\s+warnings", output)
    m !== nothing && return parse(Int, m.captures[1]), parse(Int, m.captures[2])
    errors = count(_ -> true, eachmatch(r"Verifier error #\d+:", output))
    warnings = count(_ -> true, eachmatch(r"Verifier warning #\d+:", output))
    return errors, warnings
end

function build_variant(pkg::String, tmpdir::String; write::Bool)
    set_steps!(pkg; write)
    outdir = joinpath(tmpdir, write ? "build_full" : "build_read")
    label = write ? "read+write" : "read-only"
    println("[trim] build START ($label)")
    started = time()
    exit_code, output, timed_out = juliac_build(pkg, outdir)
    elapsed = round(time() - started; digits=1)
    timed_out && error("trim build ($label) timed out after $(TRIM_COMPILE_TIMEOUT_S) s:\n$output")
    errors, warnings = verifier_totals(output)
    exe = joinpath(outdir, "bin", TRIM_EXE)
    println("[trim] build DONE ($label): $(elapsed) s, exit $exit_code, verifier $errors errors / $warnings warnings")
    isfile(exe) && println("[trim] binary $(filesize(exe)) bytes at $exe")
    return (; exe, exit_code, output, errors, warnings, elapsed)
end

function parse_binary_output(output::String)
    values = Dict{String,String}()
    for line in eachline(IOBuffer(output))
        parts = split(line, ' '; limit=2)
        length(parts) == 2 && (values[parts[1]] = parts[2])
    end
    return values
end

function check_binary(exe::String; write::Bool)
    exit_code, output, timed_out = run_with_timeout(`$exe $TRIM_DATA`; timeout_s=TRIM_RUN_TIMEOUT_S, label="run")
    timed_out && error("trim binary timed out:\n$output")
    println("[trim] binary output:\n$output")
    @test exit_code == 0
    got = parse_binary_output(output)

    fc = GeoJSON.read(TRIM_DATA, TrimGeoJSON.Untyped)
    typed = GeoJSON.read(TRIM_DATA, TrimGeoJSON.Typed)
    @test parse(Int, got["features"]) == length(GeoJSON.features(fc))
    @test parse(Float64, got["sumx"]) == TrimGeoJSON.sumx(fc)
    @test got["name"] == TrimGeoJSON.firstname(typed)
    if write
        @test parse(Int, got["written"]) == sizeof(GeoJSON.write(fc))
    else
        @test !haskey(got, "written")
    end
end

@testset "Trim compile" begin
    if Sys.iswindows()
        println("[trim] skip Windows: JuliaC trim builds are not covered there")
        @test true
    elseif VERSION < v"1.12.0-rc1"
        println("[trim] skip Julia < 1.12: --trim is unavailable")
        @test true
    elseif Base.find_package("JuliaC") === nothing
        println("[trim] skip: JuliaC is not in the active environment (run through Pkg.test)")
        @test true
    else
        @test isfile(TRIM_DATA)
        mktempdir() do tmpdir
            pkg = prepare_trim_package(tmpdir)
            full = build_variant(pkg, tmpdir; write=true)
            if full.errors > 0 || full.warnings > 0
                println("---- trim verifier output (read+write) ----")
                for m in eachmatch(r"Verifier (?:error|warning) #\d+:[^\n]*", full.output)
                    println(m.match)
                end
                println("---- end verifier output ----")
            end
            @test full.errors == 0
            @test full.warnings == 0
            @test full.exit_code == 0
            if isfile(full.exe)
                check_binary(full.exe; write=true)
            else
                # The read paths verify on their own, so the binary contract stays covered.
                partial = build_variant(pkg, tmpdir; write=false)
                @test partial.errors == 0
                @test partial.warnings == 0
                @test partial.exit_code == 0
                @test isfile(partial.exe)
                isfile(partial.exe) && check_binary(partial.exe; write=false)
            end
        end
    end
end
