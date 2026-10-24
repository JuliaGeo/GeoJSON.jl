@testset "Feature constructors bind dimensions from geometry or explicit parameters" begin
    @test !applicable(GeoJSON.FeatureSink, nothing, nothing, nothing, nothing, nothing, false)
    for (D, T) in ((2, Float32), (3, Float64))
        p = GeoJSON.Point{D,T}(coordinates=ntuple(i -> T(i), D))
        props = (name="one",)
        f = GeoJSON.Feature("id", nothing, p, props)
        @test f isa GeoJSON.Feature{D,T,typeof(props)}
        @test GeoJSON.geometry(f) === p
        @test GeoJSON.properties(f) === props
        bb = T[ntuple(_ -> 0, D)..., ntuple(_ -> 1, D)...]
        @test GeoJSON.bbox(GeoJSON.Feature("id", bb, p, props)) === bb
        for bbox in (nothing, bb)
            @test !applicable(GeoJSON.Feature, "id", bbox, nothing, props)
            empty = GeoJSON.Feature{D,T}("id", bbox, nothing, pairs(props))
            @test GeoJSON.geometry(empty) === nothing
            @test GeoJSON.bbox(empty) === bbox
            @test GeoJSON.properties(empty) == Dict(:name=>"one")
            typed = GeoJSON.Feature{D,T,typeof(props)}("id", bbox, nothing, props)
            @test GeoJSON.properties(typed) === props
        end
    end
end
