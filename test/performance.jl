using Random

# Exercise the same make methods with the scanner disabled, using only the
# public JSON.parse/StructUtils APIs. This also covers a future failed guard.
publicread(s, T=Float64, D=2; kw...) = publicread(s, GeoJSON.Point{D,T}; kw...)
publicread(s, ::Type{G}; kw...) where {G<:GeoJSON.GeoJSONT} = JSON.parse(s, G;
    dicttype=Dict{String,Any}, style=GeoJSON.PublicCoordinateStyle(), kw...)

@testset "Coordinate fast paths and fallback" begin
    rng = MersenneTwister(34)
    # Random positions need one representative geometry, not the full
    # dimension/type/depth product. The literals below cover both float types,
    # every nesting depth, malformed numbers and the public fallback.
    G = GeoJSON.LineString{2,Float64}
    for n in (0, 3, 15)
        coords = [(randn(rng) * 180, randn(rng) * 180) for _ in 1:n]
        text = JSON.json((type="LineString", coordinates=coords))
        fast = JSON.parse(text, G)
        slow = publicread(text, G)
        @test isequal(GeoJSON.coordinates(fast), GeoJSON.coordinates(slow))
        @test GeoJSON.write(fast) == JSON.json(slow; sort_keys=false)
        @test GeoJSON.write(JSON.parse(GeoJSON.write(fast), G)) == GeoJSON.write(fast)
    end
    for T in (Float32, Float64), token in ("-0", "-0.0", "0e0", "1E+2", "1e-400", "1e400",
        "1.000000059604644775390625000001", "123456789012345678901234567890", "-1.7976931348623157e308")
        s = """{"type":"Point","coordinates":[ \n$token,\t0 ],"bbox":[$token,0,1,1]}"""
        a = JSON.parse(s, GeoJSON.Point{2,T}); b = publicread(s, T)
        @test isequal(a.coordinates, b.coordinates)
        bytes = codeunits("[$token,0]")
        @test isequal(GeoJSON.scancoordinates(NTuple{2,T}, bytes, 1, length(bytes), 0, 512)[1], b.coordinates)
        @test isequal(GeoJSON.bbox(a), GeoJSON.bbox(b))
    end
    for bad in ("01", "1.", ".5", "+1", "1e", "1e+", "--1", "true", "null", "\"1\"", "NaN", "Inf", "-NaN")
        s = """{"type":"Point","coordinates":[$bad,0]}"""
        @test_throws ArgumentError JSON.parse(s, GeoJSON.Point{2,Float64})
        @test_throws ArgumentError publicread(s)
    end
    for bad in ("[1,]", "[1 2]", "[,1]", "[1,2", "[1,2,,3]", "[1,2]x")
        s = """{"type":"Point","coordinates":$bad}"""
        @test_throws ArgumentError JSON.parse(s, GeoJSON.Point{2,Float64})
        @test_throws ArgumentError publicread(s)
    end
    if GeoJSON.COORDINATE_SCANNER_AVAILABLE
    for (kind, coords, depth) in (("Point", "[1,2]", 2), ("LineString", "[[1,2]]", 3),
            ("Polygon", "[[[1,2]]]", 4), ("MultiPolygon", "[[[[1,2]]]]", 5))
        s = """{"type":"$kind","coordinates":$coords}"""
        G = getfield(GeoJSON, Symbol(kind)){2,Float64}
        for maxdepth in (depth-1, depth)
            if maxdepth < depth
                @test_throws ArgumentError JSON.parse(s, G; maxdepth)
                @test_throws ArgumentError publicread(s, G; maxdepth)
            else
                @test GeoJSON.coordinates(JSON.parse(s, G; maxdepth)) == GeoJSON.coordinates(publicread(s, G; maxdepth))
            end
        end
    end
    end
    diagnostic(f) = try f(); nothing catch e; (typeof(e), sprint(showerror, e)) end
    for T in (Float32, Float64), value in (T(NaN), T(Inf), T(-Inf))
        expected = diagnostic(() -> JSON.json(value))
        @test first(expected) === ArgumentError
        for g in (GeoJSON.Point(coordinates=(value, T(0))),
                  GeoJSON.Polygon(coordinates=[[(T(0), value)]]),
                  GeoJSON.Point{2,T}(T[value, 0, 1, 1], (T(0), T(0))),
                  GeoJSON.Feature{2,T}(properties=Dict{Symbol,Any}(:value => value)))
            @test diagnostic(() -> GeoJSON.write(g)) == expected
        end
    end
    for T in (Float32, Float64)
        values = T[0, -0.0, 1, -1, floatmin(T), nextfloat(T(0)), floatmax(T), 1e-5, 1e6]
        points = [(x, y) for x in values for y in values]
        U = T === Float32 ? UInt32 : UInt64
        for _ in 1:1000
            x = reinterpret(T, rand(rng, U))
            isfinite(x) && push!(points, (x, zero(T)))
        end
        @test GeoJSON.coordtext(points, Val(false)) == JSON.json(points)
        if GeoJSON.STRING_VECTOR_AVAILABLE
            @test GeoJSON.coordtext(points, Val(true)) == GeoJSON.coordtext(points, Val(false))
        end
        g = GeoJSON.LineString(coordinates=points)
        @test GeoJSON.write(g) == JSON.json(g; sort_keys=false)
    end
    for T in (Float32, Float64)
        for g in (GeoJSON.Point{0,T}(nothing, ()), GeoJSON.LineString{0,T}(nothing, [(), ()]))
            @test GeoJSON.write(g) == JSON.json(g; sort_keys=false)
        end
    end
    warning = "Failed to parse GeoJSON as 2D, trying 3D. Set `ndim` to 3 to avoid this warning."
    @test_logs (:warn, warning) @test_throws ArgumentError GeoJSON.read(
        """{"type":"Point","coordinates":[1,2,true]}""")
    # One non-native scalar type exercises the shared public fallback without
    # compiling every geometry and writer for several uncommon number types.
    s = """{"type":"LineString","coordinates":[[1,2],[3,4]]}"""
    G = GeoJSON.LineString{2,Int}
    g = JSON.parse(s, G)
    @test g.coordinates == publicread(s, G).coordinates
    @test GeoJSON.write(g) == JSON.json(g; sort_keys=false)
end

# Retain A's exact schema algorithm as a differential oracle, including its
# unusual field-named properties and Set/Dict ordering.
function schema_A(features)
    # Otherwise find the shared names
    names = Set{Symbol}()
    types = Dict{Symbol,Type}()
    for feature in features
        props = GeoJSON.properties(feature)
        isnothing(props) && continue
        if isempty(names)
            for k in keys(props)
                k === :geometry && continue
                push!(names, k)
                types[k] = GeoJSON.missT(typeof(props[k]))
            end
            push!(names, :geometry)
            types[:geometry] = GeoJSON.missT(typeof(GeoJSON.geometry(feature)))
        else
            for nm in names
                T = types[nm]
                if haskey(props, nm)
                    v = props[nm]
                    if !(GeoJSON.missT(typeof(v)) <: T)
                        types[nm] = Union{T,GeoJSON.missT(typeof(v))}
                    end
                elseif hasfield(typeof(feature), nm)
                    v = getfield(feature, nm)
                    if !(GeoJSON.missT(typeof(v)) <: T)
                        types[nm] = Union{T,GeoJSON.missT(typeof(v))}
                    end
                elseif !(T isa Union && T.a === Missing)
                    types[nm] = Union{Missing,types[nm]}
                end
            end
            for (k, v) in pairs(props)
                k === :geometry && continue
                if !(k in names)
                    push!(names, k)
                    types[k] = Union{Missing,GeoJSON.missT(typeof(v))}
                end
            end
        end
    end
    return collect(names), types
end
@testset "Eager schema matches A" begin
    rng = MersenneTwister(145)
    for _ in 1:80
        features = GeoJSON.Feature{2,Float32}[]
        for i in 1:rand(rng, 0:20)
            props = Dict{Symbol,Any}()
            for k in (:a, :b, :c, :id, :bbox, :properties, :geometry)
                rand(rng, Bool) || continue
                props[k] = rand(rng, (nothing, missing, 1, 1.0, true, "text", [1,2], Int, Vector, Union{Missing,Int}))
            end
            g = rand(rng, Bool) ? nothing : GeoJSON.Point(coordinates=(1f0,2f0))
            push!(features, GeoJSON.Feature{2,Float32}(i, nothing, g, props))
        end
        names, types = schema_A(features)
        actual_names, actual_types = GeoJSON.property_schema(features)
        @test actual_names == names
        @test collect(actual_types) == collect(types)
        fc = GeoJSON.FeatureCollection(features=features)
        @test getfield(fc, :names) == names && getfield(fc, :types) == types
    end
end

coordinate_read_allocations(s, style) = @allocated JSON.parse(s, GeoJSON.GeoJSONT{2,Float64}; style)
@testset "Coordinate read allocations" begin
    s = JSON.json((type="LineString", coordinates=[(Float64(i), Float64(-i)) for i in 1:5000]))
    fast = GeoJSON.StructUtils.DefaultStyle()
    slow = GeoJSON.PublicCoordinateStyle()
    coordinate_read_allocations(s, fast); coordinate_read_allocations(s, slow)
    # Removing the per-position sinks should save at least 100 kB here. Use a
    # relative, warmed measurement so this survives Julia allocator changes.
    if GeoJSON.COORDINATE_SCANNER_AVAILABLE
        @test coordinate_read_allocations(s, fast) + 100_000 < coordinate_read_allocations(s, slow)
    end
    bytes = codeunits("[[1.5,2.5],[3.5,4.5]]")
    @test (@inferred GeoJSON.scancoordinates(Vector{NTuple{2,Float64}}, bytes, 1, length(bytes), 0, 512))[1] == [(1.5,2.5),(3.5,4.5)]
end


schema_allocations(features) = @allocated GeoJSON.property_schema(features)
@testset "Eager schema allocations" begin
    p = GeoJSON.Point(coordinates=(1f0,2f0))
    features = [GeoJSON.Feature(geometry=p, properties=Dict{Symbol,Any}(:a=>1, :b=>"text")) for _ in 1:4000]
    schema_allocations(features); schema_allocations(features)
    # Per-property type callbacks/iterator boxes add megabytes on this input.
    # The eager pass should allocate mainly its small per-column state.
    @test schema_allocations(features) < 200_000
end


@testset "Guarded outer buffer hint and public fallback" begin
    for T in (Float32, Float64)
        g = GeoJSON.LineString(coordinates=[(T(1.25), T(-2.5)), (T(3.125), T(4.75))])
        f = GeoJSON.Feature(geometry=g, properties=Dict{Symbol,Any}(:object=>"value", :capacity=>7))
        fc = GeoJSON.FeatureCollection(features=fill(f, 300))
        @test GeoJSON.write(fc) == GeoJSON.writejson(fc, Val(false)) == JSON.json(fc; sort_keys=false)
    end
end


@testset "Strided byte input ownership" begin
    source = """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[1.25,2.5]},"properties":{"s":"owned"}}]}"""
    parent = zeros(UInt8, 2 * sizeof(source))
    parent[1:2:end] = codeunits(source)
    before = copy(parent)
    bytes = view(parent, 1:2:length(parent))
    expected = collect(GeoJSON.read(source))
    eager = collect(GeoJSON.read(bytes))
    lazy = GeoJSON.read(bytes; lazyfc=true)
    @test eager == collect(lazy) == expected
    @test parent == before
    fill!(parent, 0x20)
    @test eager == collect(lazy) == expected
end


@testset "Bounded input normalization" begin
    source = """{"type":"Point","coordinates":[1.25,2.5]}"""
    text = "not JSON: " * source * " trailing garbage"
    fragment = SubString(text, 11, 10 + sizeof(source))
    @test GeoJSON.read(fragment) == GeoJSON.read(source)
    parent = Vector{UInt8}(text)
    fragment = view(parent, 11:10+sizeof(source))
    @test GeoJSON.read(fragment) == GeoJSON.read(source)
    @test (@inferred codeunit(GeoJSON.inputtext(fragment), 1)) == UInt8('{')
    @test GeoJSON.read(codeunits(source)).coordinates == (1.25f0,2.5f0)
    for invalid in (source * " x", "{\"type\":\"Point\"} x", source[1:end-1])
        diagnostic(f) = try f(); nothing catch e; (typeof(e), sprint(showerror, e)) end
        expected = diagnostic(() -> JSON.parse(invalid, GeoJSON.GeoJSONT{2,Float32}; dicttype=Dict{String,Any}))
        text = "prefix" * invalid * "suffix"
        for input in (invalid, SubString(text, 7, 6 + sizeof(invalid)), view(Vector{UInt8}(text), 7:6+sizeof(invalid)))
            @test diagnostic(() -> GeoJSON.read(input)) == expected
            @test sizeof(GeoJSON.inputtext(input)) == sizeof(invalid)
        end
    end
end

function owned_input_text(source)
    prefix = "é🙂"
    text = prefix * source * " trailing garbage"
    start = ncodeunits(prefix) + 1
    GeoJSON.inputtext(SubString(text, start, start + ncodeunits(source) - 1))
end
@testset "Normalized input owns its backing store" begin
    source = """{"type":"Point","coordinates":[1.25,2.5]}"""
    text = owned_input_text(source)
    GC.gc()
    @test GeoJSON._parse(text, GeoJSON.GeoJSONT{2,Float32}).coordinates == (1.25f0,2.5f0)
    GC.gc()
    @test text == source
    @test GeoJSON.inputtext(source) === source
    for bytes in (Vector{UInt8}(source), view(Vector{UInt8}(source), 1:sizeof(source)))
        normalized = GeoJSON.inputtext(bytes)
        fill!(bytes, UInt8(' '))
        @test normalized == source
    end
    @test GeoJSON.inputtext(UInt8[]) == ""
    @test GeoJSON.inputtext(view(UInt8[], 1:0)) == ""
end

@testset "Concrete parser and always-defined public fallback" begin
    for text in vcat(Samples.featurecollections, Samples.features, Samples.geometries)
        T = typeof(GeoJSON.read(text))
        public = GeoJSON.parsegeojson(text, T, Val(false))
        @test GeoJSON.write(public) == GeoJSON.write(GeoJSON.read(text, T))
        if GeoJSON.CONCRETE_READ_AVAILABLE
            @test GeoJSON.write(GeoJSON.parsegeojson(text, T, Val(true))) == GeoJSON.write(public)
        end
    end
    for text in ("{", "{\"type\":\"Point\",\"coordinates\":[1,2]} trailing")
        @test_throws ArgumentError GeoJSON.parsegeojson(text, GeoJSON.Point{2,Float64}, Val(false))
        @test_throws ArgumentError GeoJSON.parsegeojson(text, GeoJSON.Point{2,Float64})
    end
end

@testset "General coordinate arities and writer values" begin
    # Arity 2/3 has generated code; other arities use the general scanner.
    # Compare both implementations through the typed JSON API, including its
    # exact dimension errors, rather than testing scanner internals alone.
    for T in (Float32, Float64), D in (1, 4)
        G = GeoJSON.Point{D,T}
        values = collect(1:D)
        text = JSON.json((type="Point", coordinates=values))
        fast = JSON.parse(text, G)
        @test fast.coordinates === Tuple(T.(values))
        @test fast.coordinates === publicread(text, G).coordinates
        @test JSON.parse(GeoJSON.write(fast), G).coordinates === fast.coordinates
        for coordinates in (Int[], values[1:end-1])
            short = JSON.json((type="Point", coordinates))
            @test_throws ArgumentError JSON.parse(short, G)
            @test_throws ArgumentError publicread(short, G)
        end
        long = JSON.json((type="Point", coordinates=[values; D+1]))
        @test_throws GeoJSON.DimensionError JSON.parse(long, G)
        @test_throws GeoJSON.DimensionError publicread(long, G)
        for bad in ("[1 2]", "[1,]", "[1,2", "[true,2,3,4]")
            @test_throws ArgumentError JSON.parse("""{"type":"Point","coordinates":$bad}""", G)
        end
    end
    p = GeoJSON.Point(coordinates=(1.0, 2.0))
    for id in (1.25, big(typemax(Int64)) + 1, "float-id")
        feature = GeoJSON.Feature(; id, geometry=p, properties=Dict{Symbol,Any}())
        @test JSON.parse(GeoJSON.write(feature))["id"] == id
    end
    # The exceptional nonfinite reader also carries optional collection CRS.
    for crs in (nothing, Dict("type" => "name", "properties" => Dict("name" => "EPSG:4326")))
        text = JSON.json((type="FeatureCollection", crs, features=[
            (type="Feature", geometry=(type="Point", coordinates=[NaN, 2.0]), properties=nothing)]); allownan=true)
        fc = GeoJSON.read(text)
        @test isnan(first(fc).geometry.coordinates[1])
        @test (getfield(fc, :crs) === nothing) == (crs === nothing)
    end
end
