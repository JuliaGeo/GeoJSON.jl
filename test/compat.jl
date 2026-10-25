@testset "0.8 compatibility contract" begin
    docs = vcat(Samples.featurecollections, Samples.features, Samples.geometries)
    @testset "v0.8.4 golden bytes and schemas" begin
        overrides = Dict((i, t) => bytes for (i, t, bytes) in
            (split(line, '\t') for line in eachline(joinpath(@__DIR__, "data", "golden-json1.txt")) if !startswith(line, "#")))
        @test Set(keys(overrides)) == Set((string(i), string(T)) for i in (7, 8, 20), T in (Float32, Float64))
        for line in eachline(joinpath(@__DIR__, "data", "golden-0.8.4.txt"))
            i, typename, golden, schema = split(line, '\t'; keepempty=true)
            T = typename == "Float32" ? Float32 : Float64
            x = GeoJSON.read(docs[parse(Int, i)]; numbertype=T)
            # Only the historical fixture is stripped; a schema leak in A fails.
            # Six exact overrides retain the deliberate property-number changes.
            @test GeoJSON.write(x) == get(overrides, (i, typename), golden)
            if x isa GeoJSON.FeatureCollection
                expected = unescape_string(schema)
                if parse(Int, i) in (7, 8)
                    expected = replace(expected, "DIST_NUM   Int64" => "DIST_NUM   Float64")
                end
                @test repr(Tables.schema(x)) == expected
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
    # Keep Int64 IDs exact; oversized numbers and integral Float64 normalize.
    for (literal, value) in (
        ("7", 7), ("1.5", 1.5), ("null", nothing), ("\"a\"", "a"),
        ("7.0", 7), ("1e2", 100), ("-0.0", 0), ("1e400", Inf),
        ("9007199254740993", 9007199254740993),
        ("12345678901234567", 12345678901234567),
        ("9223372036854775807", typemax(Int64)),
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
    @test_throws ArgumentError GeoJSON.write(GeoJSON.Point(coordinates=(NaN, 0.0)))
end

@testset "JSON v1 migration" begin
    rounded = GeoJSON.read("""{"type":"Point","coordinates":[1.000000059604644775390625000001,0],"bbox":[1.000000059604644775390625000001,0,2,2]}""")
    @test GeoJSON.bbox(rounded)[1] === GeoJSON.coordinates(rounded)[1] === nextfloat(1f0)
    @test GeoJSON.read("""{"type":"Point","coordinates":[1e400,1e-400]}""").coordinates === (Inf32, 0f0)
    point3 = """{"type":"Point","coordinates":[1,2,3]}"""
    warning = "Failed to parse GeoJSON as 2D, trying 3D. Set `ndim` to 3 to avoid this warning."
    @test_logs (:warn, warning) GeoJSON.read(point3)
    @test_logs (:warn, warning) GeoJSON.read(IOBuffer(point3))
    @test GeoJSON.read(point3; ndim=3) isa GeoJSON.Point{3,Float32}
    for bad in ("[]", "[1]", "[true,2]", "[null,2]", "[\"1\",2]", "[[1],2]", "{}", "[1,]")
        @test_throws ArgumentError GeoJSON.read("""{"type":"Point","coordinates":$bad}""")
    end
    @test_throws ArgumentError GeoJSON.read("""{"type":"LineString","coordinates":[[1,2,3],[1,2]]}""")
    @test_throws ArgumentError GeoJSON.read("""{"type":"Point","coordinates":[1,2,3,4]}""")
    for bad in ("{}", "{\"type\":\"Unknown\"}", "{\"type\":\"Point\"} garbage", "{\"type\":\"Point\"} {}")
        @test_throws ArgumentError GeoJSON.read(bad)
    end
    @test_throws SystemError GeoJSON.read(joinpath(@__DIR__, "nonexistent.geojson"))
    f = GeoJSON.read("""{"type":"Feature","properties":{"f":7.0,"e":1e2,"z":-0.0,"big":123456789012345678901234567890,"nested":{"f":7.0}}}""")
    p = GeoJSON.properties(f)
    @test p[:f] === 7.0 && p[:e] === 100.0 && signbit(p[:z])
    @test p[:big] isa BigInt && p[:nested]["f"] === 7.0
    @test GeoJSON.write(GeoJSON.Point{2,Float32}()) == """{"type":"Point","coordinates":null}"""
    @test GeoJSON.write(GeoJSON.Feature{2,Float32}(nothing,nothing,nothing,nothing)) ==
        """{"type":"Feature","geometry":null,"properties":null}"""
    fc = GeoJSON.read(Samples.tablenull)
    @test !occursin("\"names\":", GeoJSON.write(fc)) && !occursin("\"types\":", GeoJSON.write(fc))
    @test JSON.json(fc; sort_keys=false) == GeoJSON.write(fc)
    lazy = GeoJSON.read(Samples.tablenull; lazyfc=true)
    @test collect(GeoJSON.read(GeoJSON.write(lazy))) == collect(fc)
    # Collection length and write preserve text without materialising features.
    delayed = GeoJSON.read("""{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Unknown"}}]}"""; lazyfc=true)
    @test length(delayed) == 1
    @test occursin("Unknown", GeoJSON.write(delayed))
    @test_throws ArgumentError delayed[1]
    gc = GeoJSON.read("""{"type":"GeometryCollection","geometries":[{"type":"GeometryCollection","geometries":[{"type":"Point","coordinates":[1,2]}]}]}""")
    @test collect(gc) == [gc[1]]
    @test GeoJSON.read(GeoJSON.write(gc)) == gc
    @test GeoJSON.read(GeoFormatTypes.GeoJSON(point3); ndim=3,numbertype=Float64) isa GeoJSON.Point{3,Float64}
    mktempdir() do dir
        path = joinpath(dir, "table.json")
        table = DataFrame(geometry=[GeoJSON.Point(coordinates=(1.0,2.0))], value=[1])
        @test GeoJSON.write(path, table; geometrycolumn=:geometry) == path
        @test GeoJSON.read(path)[1].value == 1
        io = IOBuffer()
        @test GeoJSON.write(io, table; geometrycolumn=:geometry) == sizeof(GeoJSON.write(table; geometrycolumn=:geometry))
    end
end

@testset "Review regressions" begin
    for source in ("""{"type":"Point","coordinates":[1,2]}""",
                   """{"type":"Feature"}""", """{"type":"GeometryCollection","geometries":[]}""")
        @test_throws ArgumentError GeoJSON.read(source; lazyfc=true)
    end
    for value in ("[1,2]", "1", "true", "\"string\"", "NaN")
        @test_throws ArgumentError("Feature properties must be an object or null") GeoJSON.read(
            """{"type":"Feature","properties":$value}""")
    end
    for kind in ("1", "null", "true", "[\"Point\"]")
        source = """{"type":$kind,"coordinates":[1,2]}"""
        @test_throws ArgumentError GeoJSON.read(source)
        @test_throws ArgumentError GeoJSON.read(source; lazyfc=true)
    end
    for value in ("1.5", "9223372036854775808", "1e400", "NaN", "Inf", "-Inf")
        @test_throws ArgumentError GeoJSON.read("""{"type":"Point","coordinates":[$value,0]}"""; numbertype=Int)
        @test_throws ArgumentError GeoJSON.read("""{"type":"Point","bbox":[$value,0,1,1]}"""; numbertype=Int)
    end
    for bad in ("[01,2]", "[1.,2]", "[+1,2]")
        @test_throws ArgumentError GeoJSON.read("""{"type":"Point","coordinates":$bad}""")
        @test_throws ArgumentError GeoJSON.read("""{"type":"Point","coordinates":[NaN,0],"ignored":$bad}""")
    end
    for bad in ("""{"type":"Feature","properties":{"s":"raw\ncontrol"}}""",
                """{"type":"Point","coordinates":[NaN,0],"ignored":"raw\tcontrol"}""",
                """{"type":"Point","coordinates":[NaN,0]} trailing""")
        @test_throws ArgumentError GeoJSON.read(bad)
    end
    for (token, value) in (("NaN", NaN), ("Inf", Inf), ("-Inf", -Inf), ("Infinity", Inf), ("-Infinity", -Inf))
        for T in (Float32, Float64)
            source = """{"type":"Feature","id":9007199254740993,
                "geometry":{"type":"Point","coordinates":[$token,0],"bbox":[$token,0,1,1]},
                "properties":{"special":$token,"int":7,"float":7.0,"zero":-0.0,
                    "big":123456789012345678901234567890,"nested":{"exact":12345678901234567}}}"""
            f = GeoJSON.read(source; numbertype=T)
            @test isequal(first(GeoJSON.coordinates(f)), T(value))
            @test isequal(first(GeoJSON.bbox(GeoJSON.geometry(f))), T(value))
            props = GeoJSON.properties(f)
            @test isequal(props[:special], value) && props[:special] isa Float64
            @test props[:int] === 7 && props[:float] === 7.0 && signbit(props[:zero])
            @test props[:big] isa BigInt && props[:nested]["exact"] === 12345678901234567
            @test GeoJSON.id(f) === 9007199254740993
            @test_throws ArgumentError GeoJSON.write(f)
        end
    end
    @test_throws ArgumentError("position has 4 components; ndim=3") GeoJSON.read(
        """{"type":"Point","coordinates":[1,2,3,4]}""")
    @test_throws ArgumentError("position has 2 components; ndim=3") GeoJSON.read(
        """{"type":"LineString","coordinates":[[1,2,3],[1,2]]}""")
    mktempdir() do dir
        cd(dir) do
            for name in ("[point].json", "{point}.json")
                Base.write(name, """{"type":"Point","coordinates":[1,2]}""")
                @test GeoJSON.read(name).coordinates === (1f0,2f0)
            end
        end
    end
    for T in (Float16, BigFloat)
        setprecision(BigFloat, 512) do
            x = T === Float16 ? nextfloat(Float16(1)) : nextfloat(BigFloat(1))
            p = GeoJSON.Point(coordinates=(x, T(0.125)))
            restored = GeoJSON.read(GeoJSON.write(p); numbertype=T)
            @test restored isa GeoJSON.Point{2,T}
            @test restored.coordinates == p.coordinates
            source = """{"type":"Point","coordinates":[$x,NaN],"bbox":[$x,0,1,1]}"""
            q = GeoJSON.read(source; numbertype=T)
            @test q.coordinates[1] == x && isnan(q.coordinates[2])
            @test GeoJSON.bbox(q)[1] == x
        end
    end
    @test GeoJSON.read("""{"type":"Point","coordinates":[1.0004882812500000000000000000001,0]}"""; numbertype=Float16).coordinates[1] === nextfloat(Float16(1))
    gc = GeoJSON.read("""{"type":"GeometryCollection","geometries":[{"type":"Point","coordinates":[1.25,2.25]}]}""")
    pretty = JSON.json(gc; pretty=true)
    @test occursin("\n    {\n", pretty)
    @test JSON.parse(pretty) == JSON.parse(JSON.json(gc))
    @test JSON.parse(JSON.json(gc; float_style=:fixed, float_precision=1))["geometries"][1]["coordinates"] == [1.2,2.2]
end

@testset "Round 2 regressions" begin
    for text in ("{\"type\":1}", "{\"type\":\"Unknown\"}", "{\"type\":\"Point\",\"bbox\":[true]}")
        expected = try
            JSON.parse(text, GeoJSON.GeoJSONT{2,Float32}; dicttype=Dict{String,Any})
        catch e
            e
        end
        actual = try GeoJSON.read(text) catch e; e end
        @test actual isa ArgumentError
        @test sprint(showerror, actual) == sprint(showerror, expected)
        @test !occursin("NonFiniteStyle", sprint(showerror, actual))
        @test_throws ArgumentError GeoJSON.read(Vector{UInt8}(text))
    end
    for bad in ("-NaN", "+Inf", "nan", "inf")
        @test_throws ArgumentError GeoJSON.read("""{"type":"Point","coordinates":[$bad,0]}""")
    end
    for crs in ("1", "[]", "{}", "{\"type\":1,\"properties\":{}}", "{\"type\":\"name\",\"properties\":[]}")
        @test_throws ArgumentError GeoJSON.read("""{"type":"FeatureCollection","bbox":[NaN,0,1,1],"features":[],"crs":$crs}""")
    end
    @test isnan(first(GeoJSON.read(codeunits("""{"type":"Point","coordinates":[NaN,0]}""")).coordinates))
    f = GeoJSON.read("""{"type":"Feature","id":1e400,"properties":{"x":NaN}}""")
    @test GeoJSON.id(f) === Inf
    @test_throws ArgumentError GeoJSON.read("{\"type\":\"Point\",\"ignored\":\"\0\"}")
    source = """{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"x":NaN}}]}"""
    lazy = GeoJSON.read(source; lazyfc=true)
    @test occursin("NaN", GeoJSON.write(lazy))
    @test isnan(GeoJSON.properties(lazy[1])[:x])
    @test_throws ArgumentError GeoJSON.write(lazy[1])
end

@testset "Round 4 input and retry regressions" begin
    source = """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[1,2]},"properties":{"s":"owned"}}]}"""
    expected = collect(GeoJSON.read(source))
    padded = " " * source * " "
    @test collect(GeoJSON.read(SubString(padded, 2, lastindex(padded)-1))) == expected
    @test collect(GeoJSON.read(IOBuffer(source))) == expected
    bytes = Vector{UInt8}(source)
    @test collect(GeoJSON.read(bytes)) == expected
    @test bytes == Vector{UInt8}(source)
    io_bytes = Vector{UInt8}(source)
    io_feature = collect(GeoJSON.read(IOBuffer(io_bytes)))
    @test io_bytes == Vector{UInt8}(source)
    fill!(io_bytes, UInt8(' '))
    @test io_feature == expected
    lazy = GeoJSON.read(bytes; lazyfc=true)
    @test bytes == Vector{UInt8}(source)
    eager = collect(GeoJSON.read(bytes))
    fill!(bytes, UInt8(' '))
    @test eager == expected
    @test collect(lazy) == expected
    mktempdir() do dir
        path = joinpath(dir, "features.json")
        Base.write(path, source)
        @test collect(GeoJSON.read(path)) == expected
        @test collect(GeoJSON.read(SubString(path, firstindex(path)))) == expected
    end
    # Quoted words, keys, escaped quotes and apparent value prefixes in strings
    # must retain the original trailing-content error, not the retry's error.
    for property in ("\"s\":\"Information\"", "\"NaN\":1", "\"s\":\"NaN\"",
                     "\"s\":\":Inf\"", "\"s\":\"x\\\" :NaN\"")
        text = """{"type":"Feature","properties":{$property}} x"""
        original = try JSON.parse(text, GeoJSON.GeoJSONT{2,Float32}; dicttype=Dict{String,Any}) catch e; e end
        actual = try GeoJSON.read(text) catch e; e end
        @test actual isa ArgumentError
        @test sprint(showerror, actual) == sprint(showerror, original)
        @test !occursin("NonFiniteStyle", sprint(showerror, actual))
    end
    for (token, value) in (("NaN", NaN), ("Inf", Inf), ("-Infinity", -Inf))
        text = """{"type":"Feature","properties":{"s":"Information","x": \t$token},"geometry":{"type":"Point","coordinates":[ \n$token,0]}}"""
        bytes = Vector{UInt8}(text)
        feature = GeoJSON.read(bytes)
        @test isequal(first(GeoJSON.coordinates(feature)), Float32(value))
        @test isequal(GeoJSON.properties(feature)[:x], value)
        @test bytes == Vector{UInt8}(text)
    end
end

@testset "Round 5 byte-view ownership" begin
    source = """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[1,2]},"properties":{"s":"owned"}}]}"""
    expected = collect(GeoJSON.read(source))
    text = " " * source * " "
    for bytes in (codeunits(source), codeunits(SubString(text, 2, lastindex(text)-1)))
        before = collect(bytes)
        @test collect(GeoJSON.read(bytes)) == expected
        lazy = GeoJSON.read(bytes; lazyfc=true)
        @test collect(lazy) == expected
        @test collect(bytes) == before
    end
    parent = vcat(UInt8(' '), Vector{UInt8}(source), UInt8(' '))
    bytes = @view parent[2:end-1]
    before = copy(parent)
    eager = collect(GeoJSON.read(bytes))
    lazy = GeoJSON.read(bytes; lazyfc=true)
    @test eager == expected
    @test collect(lazy) == expected
    @test parent == before
    fill!(parent, UInt8(' '))
    @test eager == expected
    @test collect(lazy) == expected
    # The exceptional parser also leaves a caller's byte view untouched.
    special = """{"type":"Feature","properties":{"x":NaN}}"""
    parent = Vector{UInt8}(special)
    bytes = @view parent[:]
    f = GeoJSON.read(bytes)
    @test isnan(GeoJSON.properties(f)[:x])
    @test parent == Vector{UInt8}(special)
end

@testset "Filesystem probe length boundaries" begin
    for n in (254, 255, 256, 257, 1024, 4096), slash in (false, true)
        prefix = slash ? "{\"type\":\"Point\",\"coordinates\":[1,2],\"note\":\"/\"" :
                         "{\"type\":\"Point\",\"coordinates\":[1,2]"
        source = prefix * " "^(n - ncodeunits(prefix) - 1) * "}"
        @test ncodeunits(source) == n
        @test GeoJSON.read(source).coordinates == (1f0, 2f0)
        @test GeoJSON.read(SubString(" " * source, 2)).coordinates == (1f0, 2f0)
    end
    @test GeoJSON.read("{\"type\":\"Point\",\"coordinates\":[1,2]" * " "^220 * "}").coordinates == (1f0, 2f0)
end
