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
    for coords in ("[1]", "[1,2,3]", "[1,2,3,4]", "[true,2]")
        @test_throws ArgumentError GeoJSON.read("""{"type":"Point","coordinates":$coords}""", T)
    end
    @test (@inferred GeoJSON.read("""{"type":"Point","coordinates":[1,2,3]}""", GeoJSON.Point{3,Float64})).coordinates === (1.0,2.0,3.0)
    @test_throws ArgumentError GeoJSON.read(text * " trailing", T)
    # The existing default stays open for values callers put into Any containers.
    for value in (:symbol, (a=1,), [1,2], JSON.Dates.Date(2020,1,2), CustomTrimProperty(7))
        f = GeoJSON.Feature{2,Float64}(properties=Dict{Symbol,Any}(:custom => value))
        @test !isempty(GeoJSON.write(f))
        @test_throws ArgumentError GeoJSON.write(f; style)
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
    # Exercise the strict recursion with more than one nested collection.
    fixture = Base.read(joinpath(@__DIR__, "trim", "fixture.geojson"), String)
    fc = @inferred GeoJSON.read(fixture, GeoJSON.FeatureCollection{2,Float64})
    @test GeoJSON.write(fc; style) == GeoJSON.write(fc)
end
