using Random

# Exercise the same make methods with the scanner disabled, using only the
# public JSON.parse/StructUtils APIs. This also covers a future failed guard.
publicread(s, T=Float64, D=2; kw...) = JSON.parse(s, GeoJSON.GeoJSONT{D,T};
    dicttype=Dict{String,Any}, style=GeoJSON.PublicCoordinateStyle(), kw...)

@testset "Coordinate fast paths and fallback" begin
    rng = MersenneTwister(34)
    for T in (Float32, Float64), D in (2, 3), depth in 0:3
        for _ in 1:12
            points = [ntuple(_ -> T(randn(rng) * 180), D) for _ in 1:rand(rng, 0:15)]
            c = depth == 0 ? ntuple(_ -> T(randn(rng)), D) : points
            for _ in 2:depth; c = [c, typeof(c)()]; end
            kind = ("Point", "LineString", "Polygon", "MultiPolygon")[depth+1]
            text = JSON.json((type=kind, coordinates=c))
            fast = GeoJSON.read(text; numbertype=T, ndim=D)
            slow = publicread(text, T, D)
            @test isequal(GeoJSON.coordinates(fast), GeoJSON.coordinates(slow))
            @test GeoJSON.write(fast) == JSON.json(slow; sort_keys=false)
            @test GeoJSON.write(GeoJSON.read(GeoJSON.write(fast); numbertype=T, ndim=D)) == GeoJSON.write(fast)
        end
    end
    for T in (Float32, Float64), token in ("-0", "-0.0", "0e0", "1E+2", "1e-400", "1e400",
        "1.000000059604644775390625000001", "123456789012345678901234567890", "-1.7976931348623157e308")
        s = """{"type":"Point","coordinates":[ \n$token,\t0 ],"bbox":[$token,0,1,1]}"""
        a = GeoJSON.read(s; numbertype=T); b = publicread(s, T)
        @test isequal(a.coordinates, b.coordinates)
        bytes = codeunits("[$token,0]")
        @test isequal(GeoJSON.scancoordinates(NTuple{2,T}, bytes, 1, length(bytes), 0, 512)[1], b.coordinates)
        @test isequal(GeoJSON.bbox(a), GeoJSON.bbox(b))
    end
    for bad in ("01", "1.", ".5", "+1", "1e", "1e+", "--1", "true", "null", "\"1\"", "NaN", "Inf", "-NaN")
        s = """{"type":"Point","coordinates":[$bad,0]}"""
        @test_throws ArgumentError JSON.parse(s, GeoJSON.GeoJSONT{2,Float64})
        @test_throws ArgumentError publicread(s)
    end
    for bad in ("[1,]", "[1 2]", "[,1]", "[1,2", "[1,2,,3]", "[1,2]x")
        s = """{"type":"Point","coordinates":$bad}"""
        @test_throws ArgumentError JSON.parse(s, GeoJSON.GeoJSONT{2,Float64})
        @test_throws ArgumentError publicread(s)
    end
    if GeoJSON.COORDINATE_SCANNER_AVAILABLE
    for (kind, coords, depth) in (("Point", "[1,2]", 2), ("LineString", "[[1,2]]", 3),
            ("Polygon", "[[[1,2]]]", 4), ("MultiPolygon", "[[[[1,2]]]]", 5))
        s = """{"type":"$kind","coordinates":$coords}"""
        for maxdepth in (depth-1, depth)
            if maxdepth < depth
                @test_throws ArgumentError JSON.parse(s, GeoJSON.GeoJSONT{2,Float64}; maxdepth)
                @test_throws ArgumentError publicread(s; maxdepth)
            else
                @test GeoJSON.coordinates(JSON.parse(s, GeoJSON.GeoJSONT{2,Float64}; maxdepth)) == GeoJSON.coordinates(publicread(s; maxdepth))
            end
        end
    end
    end
    for T in (Float32, Float64), value in (T(NaN), T(Inf), T(-Inf))
        @test_throws ArgumentError GeoJSON.write(GeoJSON.Point(coordinates=(value, T(0))))
        @test_throws ArgumentError GeoJSON.write(GeoJSON.Polygon(coordinates=[[(T(0), value)]]))
    end
    for T in (Float32, Float64)
        values = T[0, -0.0, 1, -1, floatmin(T), nextfloat(T(0)), floatmax(T), 1e-5, 1e6]
        points = [(x, y) for x in values for y in values]
        g = GeoJSON.LineString(coordinates=points)
        @test GeoJSON.write(g) == JSON.json(g; sort_keys=false)
    end
    for T in (Int, Float16, BigFloat)
        s = """{"type":"LineString","coordinates":[[1,2],[3,4]]}"""
        g = GeoJSON.read(s; numbertype=T)
        @test g.coordinates == publicread(s, T).coordinates
        @test GeoJSON.write(g) == JSON.json(g; sort_keys=false)
    end
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
                props[k] = rand(rng, (nothing, missing, 1, 1.0, true, "text", [1,2]))
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
