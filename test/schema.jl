@testset "Schema reads preserve the default API" begin
    P = NamedTuple{(:name, :count),Tuple{String,Union{Missing,Int}}}
    G = Union{GeoJSON.Point{2,Float64},GeoJSON.LineString{2,Float64}}
    F = GeoJSON.Feature{2,Float64,G,P}
    FC = GeoJSON.FeatureCollection{2,Float64,G,P}
    point = """{"type":"Point","coordinates":[1,2]}"""
    feature = """{"type":"Feature","id":"one","geometry":$point,"properties":{"name":"café"}}"""
    collection = """{"type":"FeatureCollection","features":[$feature]}"""
    for input in (collection, Vector{UInt8}(collection), IOBuffer(collection))
        fc = @inferred GeoJSON.read(input, FC)
        @test eltype(fc) === F
        @test GeoJSON.id(fc[1]) == "one"
        @test isequal(GeoJSON.properties(fc[1]), (name="café", count=missing))
        @test GeoJSON.geometry(fc[1]) isa GeoJSON.Point{2,Float64}
        @test isequal(GeoJSON.properties(GeoJSON.read(GeoJSON.write(fc), FC)[1]), GeoJSON.properties(fc[1]))
        @test Set(propertynames(fc)) == Set((:geometry, :name, :count))
        @test fc.names === propertynames(fc)
        @test Set(Tables.schema(fc).names) == Set((:geometry, :name, :count))
    end
    f = @inferred GeoJSON.read(feature, F)
    @test GeoJSON.geometry(f) == GeoJSON.Point(coordinates=(1.0,2.0))
    @test GeoJSON.read(point, GeoJSON.Point{2,Float64}) == GeoJSON.geometry(f)
    @test_throws ArgumentError GeoJSON.read(point, F)
    @test_throws ArgumentError GeoJSON.read(feature, FC)
    @test_throws ArgumentError GeoJSON.read(point, GeoJSON.Polygon{2,Float64})
    @test_throws GeoJSON.CoordinateDimensionError GeoJSON.read(replace(point, "[1,2]"=>"[1,2,3]"), GeoJSON.Point{2,Float64})
    old = GeoJSON.read(collection)
    @test GeoJSON.properties(old[1]) isa Dict{Symbol,Any}
    @test GeoJSON.geometry(old[1]) isa GeoJSON.Point{2,Float32}
    @test GeoJSON.Feature{2,Float32}("one",nothing,GeoJSON.geometry(old[1]),Dict(:name=>"café")) == old[1]
    @test GeoJSON.FeatureCollection{2,Float32}(nothing,GeoJSON.features(old),nothing).features == old.features
    @test GeoJSON.FeatureCollection(features=GeoJSON.features(old)).features == old.features
    @test GeoJSON.FeatureCollection{2,Float32}().features == []
    fs = GeoJSON.Feature{2,Float32}[old[1]]
    @test GeoJSON.FeatureCollection{2,Float32}(features=fs)[1] == old[1]
    @test collect(GeoJSON.read(collection; lazyfc=true)) == collect(old)
    crs = """{"type":"name","properties":{"name":"urn:ogc:def:crs:OGC:1.3:CRS84"}}"""
    withcrs = replace(collection, "\"features\":" => "\"crs\":$crs,\"features\":")
    for obj in (GeoJSON.read(withcrs), GeoJSON.read(withcrs, FC))
        @test JSON.parse(GeoJSON.write(obj))["crs"]["properties"]["name"] == "urn:ogc:def:crs:OGC:1.3:CRS84"
    end
end

@testset "Writer compatibility" begin
    p = GeoJSON.Point(coordinates=(1.0,2.0))
    for value in (nothing, missing, "", Dict(), [])
        f = GeoJSON.Feature(geometry=p, id=value, properties=Dict{Symbol,Any}())
        @test !haskey(JSON.parse(GeoJSON.write(f)), "id")
    end
    props = Dict{Symbol,Any}(:z=>1, :a=>2, :m=>3)
    f = GeoJSON.Feature(geometry=p, properties=props)
    text = GeoJSON.write(f)
    order = [findfirst("\"$k\":", text).start for k in keys(props)]
    @test issorted(order)
    # Ordinary writes still allow custom JSON values in Any-valued properties.
    @test JSON.parse(GeoJSON.write(GeoJSON.Feature(geometry=p, properties=Dict(:x=>(a=1,)))))["properties"]["x"]["a"] == 1
end

@testset "Schema properties use JSON value types" begin
    P = NamedTuple{(:active, :count),Tuple{Bool,Int}}
    F = GeoJSON.Feature{2,Float64,GeoJSON.Point{2,Float64},P}
    text = """{"type":"Feature","geometry":null,"properties":{"active":true,"count":2}}"""
    @test GeoJSON.properties(GeoJSON.read(text, F)) === (active=true, count=2)
    @test_throws ArgumentError GeoJSON.read(replace(text, "\"type\":\"Feature\""=>"\"type\":1"), F)
    FC = GeoJSON.FeatureCollection{2,Float64,GeoJSON.Point{2,Float64},P}
    @test_throws ArgumentError GeoJSON.read("""{"type":true,"features":[]}""", FC)
end

@testset "Collection schema is discovered once on demand" begin
    text = """{"type":"FeatureCollection","features":[
        {"type":"Feature","geometry":null,"properties":{"value":1}},
        {"type":"Feature","geometry":null,"properties":{"value":null,"extra":"x"}}
    ]}"""
    for access in (propertynames, Tables.schema, fc -> fc.names, fc -> fc.types)
        fc = GeoJSON.read(text)
        # Reading, indexing, iterating and writing do not discover the schema.
        @test length(collect(fc)) == 2
        @test JSON.parse(GeoJSON.write(fc))["features"][1]["properties"]["value"] == 1
        GeoJSON.properties(fc[1])[:before] = true
        access(fc)
        @test :before in fc.names
        @test fc.types[:before] === Union{Missing,Bool}
        @test fc.types[:value] === Union{Missing,Int64}
        @test fc.types[:extra] === Union{Missing,String}
        # As before, an already discovered schema is a snapshot, not a live view.
        GeoJSON.properties(fc[1])[:after] = 1
        @test :after ∉ propertynames(fc)
        @test fc.names === propertynames(fc)
        @test fc.types === fc.types
    end
    fc = GeoJSON.read(text)
    fc = GeoJSON.FeatureCollection(features=repeat(GeoJSON.features(fc), 1000))
    schemas = fetch.([Threads.@spawn propertynames(fc) for _ in 1:16])
    @test all(names -> names === first(schemas), schemas)
    @test length(fc.names) == 3
    empty = GeoJSON.FeatureCollection{2,Float32}()
    @test isempty(propertynames(empty))
    @test isempty(Tables.schema(empty).names)
    @test empty.names === propertynames(empty)
    push!(GeoJSON.features(empty), GeoJSON.read(text)[1])
    @test isempty(propertynames(empty))
    # New cache storage must not shadow a feature property of the same name.
    GeoJSON.properties(fc[1])[:schema_ready] = true
    @test isequal(fc.schema_ready[1:2], [true, missing])
end
