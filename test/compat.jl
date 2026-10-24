@testset "0.8 compatibility contract" begin
    docs = vcat(Samples.featurecollections, Samples.features, Samples.geometries)
    @testset "v0.8.4 golden bytes and schemas" begin
        for line in eachline(joinpath(@__DIR__, "data", "golden-0.8.4.txt"))
            i, typename, golden, schema = split(line, '\t'; keepempty=true)
            T = typename == "Float32" ? Float32 : Float64
            x = GeoJSON.read(docs[parse(Int, i)]; numbertype=T)
            # Collections in 0.8.4 leaked their internal names/types fields.
            actual = replace(GeoJSON.write(x), r",\"names\":\[.*$" => "}")
            @test actual == golden
            if x isa GeoJSON.FeatureCollection
                @test repr(Tables.schema(x)) == unescape_string(schema)
            end
        end
    end
    point = """{"foreign":{"x":[1,2]},"coordinates":[1,2],"type":"Point"}"""
    @test GeoJSON.read(point) isa GeoJSON.Point{2,Float32}
    @test GeoJSON.read(point; numbertype=Int).coordinates === (1, 2)
    @test GeoJSON.read(Vector{UInt8}(point)) == GeoJSON.read(IOBuffer(point)) == GeoJSON.read(point)
    @test GeoJSON.read(GeoFormatTypes.GeoJSON(point)) == GeoJSON.read(point)
    @test GeoJSON.read(GeoFormatTypes.GeoJSON(Dict("type"=>"Point", "coordinates"=>[1,2]))) == GeoJSON.read(point)
    mktempdir() do dir
        path = joinpath(dir, "point.geojson")
        p = GeoJSON.read(point)
        @test GeoJSON.write(path, p) == path
        @test GeoJSON.read(path) == p
        io = IOBuffer()
        @test GeoJSON.write(io, p) == sizeof(GeoJSON.write(p))
        @test String(take!(io)) == GeoJSON.write(p)
    end
    feature = """{"type":"Feature","id":"abc","properties":{"s":"é/\\n","i":7,"b":true,"n":null,"a":[1,{"x":"y"}]}}"""
    f = GeoJSON.read(feature)
    @test isconcretetype(GeoJSON.Feature{2,Float32})
    @test fieldnames(typeof(f)) == (:id, :bbox, :geometry, :properties)
    @test fieldtype(typeof(f), :geometry) == Union{Nothing,GeoJSON.AbstractGeometry{2,Float32}}
    @test fieldtype(typeof(f), :properties) == Union{Nothing,Dict{Symbol,Any}}
    p = GeoJSON.properties(f)
    @test p isa Dict{Symbol,Any}
    @test p[:s] isa String && p[:i] isa Int64 && p[:b] isa Bool
    @test p[:n] === nothing && f.n === missing
    @test p[:a] isa Vector{Any} && p[:a][2] isa Dict{String,Any}
    @test GeoJSON.id(f) === "abc" && GeoJSON.geometry(f) === nothing
    @test GeoJSON.properties(GeoJSON.read("""{"type":"Feature","properties":null}""")) == Dict{Symbol,Any}()
    @test GeoJSON.properties(GeoJSON.read("""{"type":"Feature"}""")) == Dict{Symbol,Any}()
    # Capture the supported scalar IDs; precision corrections land with migration.
    for (literal, value) in (
        ("7", 7), ("1.5", 1.5), ("null", nothing), ("\"a\"", "a"),
        ("7.0", 7), ("1e2", 100), ("-0.0", 0),
        ("123456789012345678901234567890", Float64(big"123456789012345678901234567890")),
    )
        @test GeoJSON.id(GeoJSON.read("""{"type":"Feature","id":$literal}""")) === value
    end

    fc = GeoJSON.read(Samples.tablenull)
    @test isconcretetype(GeoJSON.FeatureCollection{2,Float32})
    @test fieldnames(typeof(fc)) == (:bbox, :features, :crs, :names, :types)
    @test Tables.rows(fc) === fc
    @test Tables.istable(typeof(fc)) && Tables.rowaccess(typeof(fc))
    @test :geometry in Tables.schema(fc).names
    @test size(DataFrame(fc), 1) == length(fc)
    @test GI.crs(fc) == GeoFormatTypes.EPSG(4326)
    lazy = GeoJSON.read(Samples.tablenull; lazyfc=true)
    @test lazy isa GeoJSON.LazyFeatureCollection{2,Float32}
    @test Tables.rows(lazy) === lazy && Tables.schema(lazy) === nothing
    @test length(lazy) == length(fc)
    @test collect(lazy) == collect(fc)
    @test GeoJSON.features(lazy) isa Vector{GeoJSON.LazyFeature{2,Float32}}
    @test GeoJSON.read(codeunits(first(GeoJSON.features(lazy)))) == fc[1]
    @test signbit(GeoJSON.read("""{"type":"Point","coordinates":[-0.0,0]}""").coordinates[1])
    @test GeoJSON.read("""{"type":"Point","coordinates":[1e400,1e-400]}"""; numbertype=Float64).coordinates === (Inf, 0.0)
    @test GeoJSON.read("""{"type":"Point","coordinates":[1.000000059604644775390625000001,0]}""").coordinates[1] === nextfloat(1f0)
    for bad in ("[1]", "[\"a\",1]", "[true,1]")
        @test_throws ArgumentError GeoJSON.read("""{"type":"Point","coordinates":$bad}""")
    end
    @test_throws ErrorException GeoJSON.write(GeoJSON.Point(coordinates=(NaN, 0.0)))
end
