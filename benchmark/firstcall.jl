# Run each input form in a separate process, e.g. julia --project=env firstcall.jl bytes.
# Run five times per form and compare medians after package precompilation.
t0 = time_ns()
using GeoJSON
load_ms = (time_ns() - t0)/1e6
s = read(joinpath(ENV["TMPDIR"], "benchdata", "polys2k_50.json"), String)
form = isempty(ARGS) ? "String" : ARGS[1]
source = if form == "SubString"
    SubString(" " * s, 2)
elseif form == "bytes"
    Vector{UInt8}(s)
elseif form == "IOBuffer"
    IOBuffer(s)
elseif form == "path"
    joinpath(ENV["TMPDIR"], "benchdata", "polys2k_50.json")
elseif form == "codeunits"
    codeunits(s)
elseif form == "view"
    view(Vector{UInt8}(" " * s), 2:ncodeunits(s)+1)
else
    s
end
r0 = time_ns(); x = GeoJSON.read(source); read_ms = (time_ns() - r0)/1e6
w0 = time_ns(); GeoJSON.write(x); write_ms = (time_ns() - w0)/1e6
println("$form,$load_ms,$read_ms,$write_ms")
