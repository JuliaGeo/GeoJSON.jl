struct CustomTrimProperty
    value::Int
end
JSON.lower(x::CustomTrimProperty) = (custom=x.value,)

@testset "Typed reads and closed writes" begin
    style = GeoJSON.StrictStyle()
    for text in vcat(Samples.featurecollections, Samples.features, Samples.geometries)
        expected = GeoJSON.read(text)
        T = typeof(expected)
        x = @inferred GeoJSON.read(text, T)
        @test GeoJSON.write(x) == GeoJSON.write(expected)
        @test GeoJSON.write(x; style) == GeoJSON.write(expected)
    end
    text = """{"type":"Point","coordinates":[1,2]}"""
    T = GeoJSON.Point{2,Float64}
    for src in (text, SubString(" " * text, 2), Vector{UInt8}(text),
                codeunits(text), view(Vector{UInt8}(text), :), IOBuffer(text))
        @test (@inferred GeoJSON.read(src, T)).coordinates === (1.0,2.0)
    end
    for target in (GeoJSON.Point{2}, GeoJSON.Point, GeoJSON.FeatureCollection,
                   Union{GeoJSON.Point{2,Float64},GeoJSON.LineString{2,Float64}},
                   GeoJSON.AbstractGeometry{2,Float64})
        @test_throws ArgumentError GeoJSON.read(text, target)
    end
    for coords in ("[1]", "[1,2,3]", "[1,2,3,4]", "[true,2]")
        @test_throws ArgumentError GeoJSON.read("""{"type":"Point","coordinates":$coords}""", T)
    end
    @test (@inferred GeoJSON.read("""{"type":"Point","coordinates":[1,2,3]}""", GeoJSON.Point{3,Float64})).coordinates === (1.0,2.0,3.0)
    @test_throws ArgumentError GeoJSON.read(text * " trailing", T)
    # The existing default stays open for values callers put into Any containers.
    for value in (:symbol, (a=1,), [1,2], JSON.Dates.Date(2020,1,2), CustomTrimProperty(7))
        f = GeoJSON.Feature{2,Float64}(properties=Dict{Symbol,Any}(:custom => value))
        @test !isempty(GeoJSON.write(f))
        err = try GeoJSON.write(f; style) catch e; e end
        @test err isa ArgumentError
        @test occursin("custom", sprint(showerror, err))
        @test occursin(string(typeof(value)), sprint(showerror, err))
    end
    f = GeoJSON.Feature{2,Float64}(properties=Dict{Symbol,Any}(:missing => missing))
    @test GeoJSON.write(f; style) == GeoJSON.write(f)
    mktempdir() do dir
        path = joinpath(dir, "point.json")
        Base.write(path, text)
        p = @inferred GeoJSON.read(path, T)
        @test p.coordinates === (1.0,2.0)
        io = IOBuffer()
        @test GeoJSON.write(io, p; style) == sizeof(GeoJSON.write(p; style))
        @test String(take!(io)) == GeoJSON.write(p)
        @test GeoJSON.write(path, p; style) == path
        @test Base.read(path, String) == GeoJSON.write(p)
    end
    lazy = @inferred GeoJSON.read(Samples.tablenull, GeoJSON.LazyFeatureCollection{2,Float32})
    @test collect(lazy) == collect(GeoJSON.read(Samples.tablenull))
    @test GeoJSON.write(lazy; style) == GeoJSON.write(lazy)
    GC.gc()
    @test (@inferred lazy[1]) == first(GeoJSON.read(Samples.tablenull))
    mismatched = GeoJSON.read("""{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[1,2,3]}}]}""", GeoJSON.LazyFeatureCollection{2,Float64})
    @test_throws ArgumentError mismatched[1]
    @test_throws ArgumentError GeoJSON.read("""{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"x":NaN}}]}""", GeoJSON.LazyFeatureCollection{2,Float64})
    # Exercise the strict recursion with more than one nested collection.
    fixture = Base.read(joinpath(@__DIR__, "trim", "fixture.geojson"), String)
    fc = @inferred GeoJSON.read(fixture, GeoJSON.FeatureCollection{2,Float64})
    @test GeoJSON.write(fc; style) == GeoJSON.write(fc)
end

@testset "Strict collection writer options" begin
    style = GeoJSON.StrictStyle()
    p = GeoJSON.Point(coordinates=(NaN, 0.0))
    gc = GeoJSON.GeometryCollection(geometries=[p])
    nested = GeoJSON.GeometryCollection(geometries=[gc])
    for g in (gc, nested)
        @test_throws ArgumentError("GeoJSON.StrictStyle GeometryCollections require default JSON writer options; pretty, allownan and other format options are unsupported") JSON.json(g; style, allownan=true)
        @test_throws ArgumentError("GeoJSON.StrictStyle GeometryCollections require default JSON writer options; pretty, allownan and other format options are unsupported") JSON.json(g; style, pretty=true)
        @test_throws ArgumentError JSON.json(g; style, float_style=:fixed)
    end
    p = GeoJSON.Point(coordinates=(1.0, 2.0))
    gc = GeoJSON.GeometryCollection(geometries=[p])
    @test GeoJSON.write(gc; style) == GeoJSON.write(gc)
end

@testset "Lazy exceptional values retain parsed types" begin
    source = """{"type":"FeatureCollection","features":[{"type":"Feature","id":9007199254740993,
        "geometry":{"type":"Point","coordinates":[NaN,2]},
        "properties":{"nested":{"a":NaN,"int":7,"big":123456789012345678901234567890},
        "array":[1,Infinity,{"b":-Infinity}]}}]}"""
    lazy = GeoJSON.read(source; lazyfc=true, numbertype=Float64)
    feature = @inferred lazy[1]
    @test isnan(first(GeoJSON.coordinates(feature)))
    @test GeoJSON.id(feature) === 9007199254740993
    props = GeoJSON.properties(feature)
    @test isnan(props[:nested]["a"])
    @test props[:nested]["int"] === 7
    @test props[:nested]["big"] isa BigInt
    @test props[:array][1] === 1
    @test props[:array][2] === Inf
    @test props[:array][3]["b"] === -Inf
    @test occursin("NaN", GeoJSON.write(lazy; style=GeoJSON.StrictStyle()))
end
