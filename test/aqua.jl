using Test
using GeoJSON
using Aqua

@testset "Aqua" begin
    Aqua.test_all(GeoJSON)
end
