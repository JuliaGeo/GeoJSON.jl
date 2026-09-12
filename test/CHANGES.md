# Ported expectations

`test/runtests.jl` is the 0.8.4 suite on the JSON.jl 1.x API. Every testset survives; the
expectations below changed because the behaviour changed on purpose. Each reason cites a bullet of
`spikes/PLAN.md`, "Breaking changes versus 0.8.4".

## Changed expectations

| Testset | Old expectation | New expectation | Reason |
|---|---|---|---|
| all coordinate, `bbox` and `Extent` literals | `Float32`: `(-35.1f0, -6.6f0)`, `Tuple{Float32,Float32}` coordinate vectors, `Extent(X=(-180.0f0, 180.0f0), ...)` | `Float64`: `(-35.1, -6.6)`, `Tuple{Float64,Float64}`, `Extent(X=(-180.0, 180.0), ...)` | Default `numbertype` becomes `Float64` |
| `numbertype` | `read(Samples.point_int)` yields `eltype == Float32` | `read(Samples.point_int)` yields `eltype == Float64`; `read(Samples.point_int; numbertype=Float32)` yields `Float32` | Default `numbertype` becomes `Float64`; the keyword still selects any other element type |
| `Tables with missings` / `With NamedTuple feature` | `GeoJSON.Feature{2,Float32}(...)` | `GeoJSON.Feature{2,Float64}(...)` | Default `numbertype` becomes `Float64`; the geometries fed to the constructor are `Point{2,Float64}` |
| `Features`, sample `e` | `[:link => ..., :title => ..., :summary => ...]` | `["link" => ..., "summary" => ..., "title" => ...]` | Property iteration order becomes document order |
| `FeatureCollection of one MultiPolygon` | `propertynames(f1) === (:geometry, :park, :cartodb_id, :addr1, :addr2)` | `propertynames(f1) === (:geometry, :cartodb_id, :addr1, :addr2, :park)` | Property iteration order becomes document order |
| `Features`, all samples | property pairs carry `Symbol` keys | property pairs carry `String` keys | `properties(f)` returns `Properties`, an `AbstractDict{String,Any}` |
| `FeatureCollection of one MultiPolygon` / `GeoInterface` | `properties isa Dict{Symbol,Any}`, `properties[:addr2]` | `properties isa GeoJSON.Properties <: AbstractDict{String,Any}`, `properties["addr2"]` and `properties[:addr2]` both resolve | `properties(f)` returns `Properties`; `getindex` accepts `Symbol` |
| `Construct from NamedTuple` | `propertynames(p) === (:bbox, :coordinates)` | `propertynames(p) === (:bbox, :coordinates, :extras)` | Foreign members are preserved, so every geometry carries an `extras` field |
| `crs` | `CRS` objects reachable through the collection | `extras(read(Samples.a))[1][1] == "crs"`, and the same for `Samples.g` | `CRS` is dropped as a type; `"crs"` is a foreign member. `GI.crs` still returns `EPSG(4326)` |
| `write` / GeoInterface round trip | `geom == geom1` after `read(write(GI.convert(GI, geom)))` | `typeof(geom1) === typeof(geom)` and equal coordinates | Foreign members are preserved and `==` compares them; sample `e` holds a `"crs"` on its geometry that a generic GeoInterface wrapper cannot carry |
| `NamedTuple point order ...` | `(Z=3, X=1.0, Y=2.0)` writes `[1.0,2.0,3]` | writes `[1.0,2.0,3.0]` | The writer promotes one `T` across the position, reported by WP2 |
| `Geometries` | `read(Samples.bbox_z, ndim=3)` names the dimension | `read(Samples.bbox_z)` discovers it, and `ndim=3` says the same thing | The 2D→3D silent retry is gone; discovery replaces it |
| `GeoJSON` (top level) | `Aqua.test_all(GeoJSON)` inline | `include("aqua.jl")` when the file exists | `test/aqua.jl` is T3's file, per the file-ownership table |

## Default properties container: `Dict{String,Any}`

`read(src)` fills a `Dict{String,Any}`; `read(src; properties=GeoJSON.Properties)` selects the
ordered container. Assertions on a default read compare `Dict`s or `Set`s of names, and every
document-order assertion moved under an explicit `properties=GeoJSON.Properties` read.

| Testset | Old expectation | New expectation |
|---|---|---|
| `Features` | `collect(pairs(properties(read(s)))) == p` in document order | `properties(read(s)) == Dict{String,Any}(p)`; the ordered comparison runs on `read(s; properties=Properties)` |
| `Construct from NamedTuple` | `propertynames(f) === (:geometry, :a, :b)` | `Set(propertynames(f))`, `first(propertynames(f)) === :geometry`; the ordered tuple holds for a `Feature{…,Properties}` |
| `FeatureCollection of one MultiPolygon` | `propertynames(f1) === (:geometry, :cartodb_id, …)`, `properties isa Properties` | `Set` comparison, `properties isa Dict{String,Any}`; the ordered tuple holds for `read(Samples.g; properties=Properties)` |
| `Tables with missings` | `show` names `(:geometry, :a, :b)` on the default read | `Set(propertynames(t[1]))` on the default read; the `show` string holds for the `Properties` read |
| `spec`: `Props` shorthand | `GeoJSON.Properties` | `Dict{String,Any}`; a `properties container` testset covers `true`, `Dict{String,Any}`, `Properties`, `false` and another `AbstractDict{String,Any}` on the eager and lazy readers and the writer |
| `spec`: `Properties` | the container API on a default read | the same API on `read(…; properties=Properties)`; a `Dict{String,Any} properties` testset covers the default |
| `tables.jl` | fixtures on `Feature{2,Float64}` | fixtures on `Feature{2,Float64,AnyGeometry{2,Float64},Properties}` so column order stays assertable; a `Dict{String,Any} properties` testset covers the default |
| `geointerface.jl` | `properties2 = Properties(…)` | `properties2 = Dict{String,Any}(…)`, so `GI.properties(feature2) === properties2` holds on the default `P` |

## Added assertions

New tests for behaviour the plan introduces, alongside the ported ones:

| Testset | Assertion | Reason |
|---|---|---|
| `write` | `f == f1` and `extras(f) == extras(f1)` on every feature sample, `extras(fc) == extras(f1c)` on every collection | Foreign members are preserved and written back; `==` compares them |
| `write` | the output of `write(read(Samples.g))` contains neither `"names"` nor `"types"` | `write` no longer leaks `names`/`types` |
| `Construct from NamedTuple` | `properties(f)["a"] === 1` beside `properties(f)[:a] === 1` | `Properties` keys are `String`s and `getindex` also accepts `Symbol` |
| `read and write methods` | `read(String(bytes))` returns the same geometry and properties as the path, IO and byte forms | `src` is a path, a JSON `String`, an `IO`, or bytes |
| `GeoFormatTypes` | `coordinates(p) == (-105.0, 39.5)` for a `GeoFormatTypes.GeoJSON{<:AbstractDict}` | The dictionary form reaches the reader through `JSON.json`, so the value is worth checking |

## Unchanged

`Feature{2}` and `AbstractGeometry{2}` still dispatch, `@inferred first(t)` and `@inferred t[1]`
still hold, `show` output still names the property tuple, and the Plots and Makie recipes still
accept every geometry, so those testsets are byte-for-byte the 0.8.4 ones.

## Test dependencies

`Project.toml` gains `DataAPI` in `[extras]`, `[compat]` and the `test` target: `test/geointerface.jl`
and `test/tables.jl` load it directly for the metadata testsets, and it reaches the package only as an
indirect dependency of GeoInterface and Tables. The 0.8.4 suite's `using JSON3` is gone with JSON3.
