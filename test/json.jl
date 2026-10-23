@testset "JSON typed parsing" begin
    point = """{"type":"Point","coordinates":[1,2]}"""
    point3d = """{"coordinates":[1,2,3],"type":"Point"}"""
    feature = """{"type":"Feature","geometry":$point,"properties":{"name":"café\\n東京","nested":{"x":[1,null,true]}}}"""
    collection = """{"features":[$feature],"type":"FeatureCollection","names":["ignored"],"types":{"ignored":1}}"""

    @test GeoJSON.coordinates(GeoJSON.read(point)) === (1.0f0, 2.0f0)
    @test GeoJSON.coordinates(GeoJSON.read(point; numbertype = Float64)) === (1.0, 2.0)
    @test GeoJSON.coordinates(GeoJSON.read(point3d; ndim = 3)) === (1.0f0, 2.0f0, 3.0f0)
    for source in (point3d, Vector{UInt8}(point3d), IOBuffer(point3d))
        @test_logs (:warn, r"trying 3D") GeoJSON.read(source)
    end
    @test_logs (:warn, r"trying 3D") GeoJSON.read(
        """{"type":"Feature","geometry":$point3d,"properties":null}""",
    )
    @test_logs (:warn, r"trying 3D") GeoJSON.read(
        """{"type":"GeometryCollection","geometries":[$point3d]}""",
    )
    @test_throws ArgumentError GeoJSON.read("""{"type":"Point","coordinates":[1,2,3,4]}""")
    @test GeoJSON.coordinates(
        GeoJSON.read("""{"type":"Point","coordinates":[1,2,3,4]}"""; ndim = 4),
    ) == (1, 2, 3, 4)
    @test_throws ArgumentError GeoJSON.read("""{"coordinates":[1,2]}""")
    @test_throws ArgumentError GeoJSON.read("""{"type":"Unknown","coordinates":[1,2]}""")
    @test_throws ArgumentError GeoJSON.read(
        """{"type":"Point","coordinates":[1,2]} trailing""",
    )
    @test_throws ArgumentError GeoJSON.read("""{"type":"Point","coordinates":[1,]}""")

    fc = GeoJSON.read(collection)
    @test getfield(fc, :names) isa Vector{Symbol}
    @test getfield(fc, :types) isa Dict{Symbol,Type}
    @test :ignored ∉ propertynames(fc)
    @test GeoJSON.properties(fc[1])[:nested] isa Dict{String,Any}
    @test GeoJSON.properties(fc[1])[:nested]["x"] == [1, nothing, true]
    encoded = JSON.parse(GeoJSON.write(fc))
    io = IOBuffer()
    @test GeoJSON.write(io, fc) == sizeof(GeoJSON.write(fc))
    @test String(take!(io)) == GeoJSON.write(fc)
    @test !haskey(encoded, "names")
    @test !haskey(encoded, "types")
    @test !haskey(encoded, "bbox")
    emptyfeature = GeoJSON.read("""{"type":"Feature","geometry":null,"properties":null}""")
    @test JSON.parse(GeoJSON.write(emptyfeature))["geometry"] === nothing
    @test JSON.parse(GeoJSON.write(emptyfeature))["properties"] === nothing
    @test !haskey(
        JSON.parse(GeoJSON.write(GeoJSON.Point{2,Float32}(Float32[], (1, 2)))),
        "bbox",
    )

    for source in (collection, Vector{UInt8}(collection), IOBuffer(collection))
        lazy = GeoJSON.read(source; lazyfc = true)
        GC.gc()
        @test length(lazy) == 1
        @test (@allocated length(lazy)) < 32
        @test size(lazy) == (1,)
        @test collect(lazy) == [fc[1]]
        @test lazy[1] == fc[1]
        @test GeoJSON.read(GeoJSON.write(lazy))[1] == fc[1]
        @test_throws BoundsError lazy[0]
        @test_throws BoundsError lazy[2]
    end
    mktemp() do path, io
        Base.write(io, collection)
        close(io)
        lazy = GeoJSON.read(path; lazyfc = true)
        @test lazy[1] == fc[1]
        GeoJSON.write(path, fc)
        @test GeoJSON.read(path)[1] == fc[1]
    end
    @test isempty(GeoJSON.read("""{"type":"FeatureCollection","features":[]}"""))
    mktempdir() do dir
        cd(dir) do
            for path in ("{point}.geojson", "[point].geojson")
                Base.write(path, point)
                @test GeoJSON.coordinates(GeoJSON.read(path)) == (1, 2)
            end
        end
    end
end

@testset "Numeric coordinates and bounds" begin
    tokens = (
        "-0",
        "-0.0",
        "0",
        "1",
        "-12.5",
        "1e2",
        "1E-2",
        "1e+2",
        "16777217",
        "9007199254740993",
        "1.0000000596046447",
        "1.000000059604644775390625",
        "1.0000000596046448",
        "3.4028234e38",
        "1e-45",
        "-1e-1000",
    )
    for T in (Float32, Float64), token in tokens
        # Avoid platform-dependent rounding in Base.parse(Float32, token).
        value = setprecision(BigFloat, 256) do
            T(parse(BigFloat, token))
        end
        expected = (value, T(2))
        text = """{"type":"Point","coordinates":[$token,2]}"""
        @test isequal(GeoJSON.coordinates(GeoJSON.read(text; numbertype = T)), expected)
        line = """{"type":"LineString","coordinates":[[$token,2],[$token,2]]}"""
        @test isequal(
            GeoJSON.coordinates(GeoJSON.read(line; numbertype = T)),
            [expected, expected],
        )
    end
    for T in (Float32, Float64), token in ("1e400", "-1e400", "1e-1000", "-1e-1000")
        expected = startswith(token, "-") ? -one(T) : one(T)
        expected *= occursin("e-", token) ? zero(T) : T(Inf)
        point = """{"type":"Point","coordinates":[$token,2],"bbox":[$token,1,2,3]}"""
        for source in (point, Vector{UInt8}(point), IOBuffer(point))
            object = GeoJSON.read(source; numbertype = T)
            @test isequal(first(GeoJSON.coordinates(object)), expected)
            @test isequal(first(GeoJSON.bbox(object)), expected)
        end
    end
    for T in (Float16, BigFloat), token in ("-0", "-0.0")
        point = """{"type":"Point","coordinates":[$token,2],"bbox":[$token,1,2,3]}"""
        object = GeoJSON.read(point; numbertype = T)
        @test isequal(first(GeoJSON.coordinates(object)), -zero(T))
        @test isequal(first(GeoJSON.bbox(object)), -zero(T))
    end
    for token in (
        "true",
        "false",
        "null",
        "\"1\"",
        "{}",
        "[]",
        "01",
        "-01",
        "1.",
        "1.e2",
        "1e",
        "1e+",
        "+1",
        "NaN",
        "Infinity",
        "0x1p2",
        "0b10",
    )
        for kind in ("Point", "LineString")
            position = kind == "Point" ? "[$token,2]" : "[[$token,2]]"
            text = """{"type":"$kind","coordinates":$position}"""
            @test_throws ArgumentError GeoJSON.read(text)
        end
    end
    for coordinates in ("[1,2", "[1 2]", "[1,2,]", "[[1,2],]", "[[1,2] [3,4]]")
        kind = startswith(coordinates, "[[") ? "LineString" : "Point"
        text = """{"type":"$kind","coordinates":$coordinates}"""
        @test_throws ArgumentError GeoJSON.read(text)
    end
    for kind in ("LineString", "MultiPoint", "Polygon", "MultiLineString", "MultiPolygon")
        text = """{"type":"$kind","coordinates":[]}"""
        @test isempty(GeoJSON.coordinates(GeoJSON.read(GeoJSON.write(GeoJSON.read(text)))))
    end
    point = """{"type":"Point","coordinates":[1,2]}"""
    fields = (
        "\"type\":\"Point\",\"coordinates\":[1,2]",
        "\"type\":\"Feature\",\"geometry\":$point,\"properties\":{\"ok\":true}",
        "\"type\":\"FeatureCollection\",\"features\":[]",
        "\"type\":\"GeometryCollection\",\"geometries\":[$point]",
    )
    for T in (Float32, Float64), object in fields
        text = "{$object,\"bbox\":[-0,1,2,3]}"
        @test isequal(GeoJSON.bbox(GeoJSON.read(text; numbertype = T)), T[-0.0, 1, 2, 3])
        @test_throws ArgumentError GeoJSON.read(
            "{$object,\"bbox\":[true,1,2,3]}";
            numbertype = T,
        )
    end
    @test GeoJSON.properties(GeoJSON.read("{$(fields[2])}"))[:ok] === true
    bytes = Vector{UInt8}("""{"type":"LineString","coordinates":[ [1, 2],\n[3,4] ]}""")
    for source in (bytes, IOBuffer(bytes), String(copy(bytes)))
        @test GeoJSON.coordinates(GeoJSON.read(source)) == [(1, 2), (3, 4)]
    end
end

@testset "Long file paths" begin
    mktempdir() do dir
        path = joinpath(dir, repeat("nested", 20), repeat("nested", 20), "point.geojson")
        mkpath(dirname(path))
        Base.write(path, """{"type":"Point","coordinates":[1,2]}""")
        @test sizeof(path) > 255
        @test GeoJSON.coordinates(GeoJSON.read(path)) == (1,2)
    end
end
