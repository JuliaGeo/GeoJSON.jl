using Test
using GeoJSON
using GeoInterface
using Extents
using Tables
using DataAPI
using DataFrames
import GeoInterface as GI

@testset "Tables" begin
    point(x, y) = GeoJSON.Point{2,Float64}(nothing, (x, y))
    feature(g, ps...) = GeoJSON.Feature{2,Float64}(; geometry=g, properties=GeoJSON.Properties(ps...))

    p1, p2 = point(1.0, 2.0), point(3.0, 4.0)
    f1 = feature(p1, "name" => "a", "n" => 1)
    f2 = feature(p2, "name" => "b", "n" => 2, "extra" => true)
    f3 = feature(nothing, "name" => "c", "n" => nothing)
    fc = GeoJSON.FeatureCollection{2,Float64}(; features=[f1, f2, f3])

    @testset "interface" begin
        @test Tables.istable(fc)
        @test Tables.istable(typeof(fc))
        @test Tables.rowaccess(typeof(fc))
        @test Tables.rows(fc) === fc
        @test length(Tables.rows(fc)) == 3
        @test Tables.columns(fc) isa Tables.CopiedColumns
        @test Tables.rowtable(fc) isa Vector{<:NamedTuple}
        @test Tables.columntable(fc) isa NamedTuple
    end

    @testset "schema" begin
        schema = Tables.schema(fc)
        @test schema.names == (:name, :n, :extra, :geometry)
        @test schema.types == (
            String,
            Union{Missing,Int64},
            Union{Missing,Bool},
            Union{Missing,GeoJSON.Point{2,Float64}},
        )
        @test last(schema.names) === :geometry
    end

    @testset "widening" begin
        allnothing = GeoJSON.FeatureCollection{2,Float64}(; features=[
            feature(p1, "a" => 1, "b" => nothing),
            feature(p2, "a" => nothing, "b" => nothing),
        ])
        schema = Tables.schema(allnothing)
        @test schema.names == (:a, :b, :geometry)
        @test schema.types == (Union{Missing,Int64}, Missing, GeoJSON.Point{2,Float64})
        @test allnothing.b isa Vector{Missing}

        late = GeoJSON.FeatureCollection{2,Float64}(; features=[
            feature(p1, "a" => 1),
            feature(p2, "a" => 2, "late" => "here"),
        ])
        @test Tables.schema(late).names == (:a, :late, :geometry)
        @test Tables.schema(late).types == (Int64, Union{Missing,String}, GeoJSON.Point{2,Float64})
        @test all(late.late .=== [missing, "here"])

        mixed = GeoJSON.FeatureCollection{2,Float64}(; features=[
            feature(p1, "a" => 1),
            feature(p2, "a" => "two"),
        ])
        @test Tables.schema(mixed).types == (Union{Int64,String}, GeoJSON.Point{2,Float64})
    end

    @testset "columns" begin
        @test propertynames(fc) == [:name, :n, :extra, :geometry]
        @test propertynames(fc) == Tables.columnnames(fc)
        @test fc.name isa Vector{String}
        @test fc.name == ["a", "b", "c"]
        @test fc.n isa Vector{Union{Missing,Int64}}
        @test isequal(fc.n, [1, 2, missing])
        @test fc.extra isa Vector{Union{Missing,Bool}}
        @test isequal(fc.extra, [missing, true, missing])
        @test fc.geometry isa Vector{Union{Missing,GeoJSON.Point{2,Float64}}}
        @test isequal(fc.geometry, [p1, p2, missing])
        @test fc.bbox === nothing
        @test fc.features == [f1, f2, f3]

        columns = Tables.columntable(fc)
        @test keys(columns) == (:name, :n, :extra, :geometry)
        @test columns.name == ["a", "b", "c"]
        @test isequal(columns.n, [1, 2, missing])
        @test keys(first(Tables.rowtable(fc))) == (:name, :n, :extra, :geometry)
    end

    @testset "rows" begin
        @test fc[1] === f1
        @test fc[2:3] == [f2, f3]
        @test collect(fc) == [f1, f2, f3]
        @test propertynames(f1) == (:geometry, :name, :n)
        @test Tables.getcolumn(f1, :name) == "a"
        @test Tables.getcolumn(f1, :geometry) === p1
        @test Tables.getcolumn(f3, :geometry) === missing
        @test ismissing(Tables.getcolumn(f1, :extra))
        @test ismissing(Tables.getcolumn(f3, :n))
        @test Tables.getcolumn(f1, 1) === Tables.getcolumn(f1, propertynames(f1)[1])
        @test Tables.getcolumn(f1, 2) === Tables.getcolumn(f1, propertynames(f1)[2])
    end

    @testset "schema on demand" begin
        growing = feature(p1, "a" => 1)
        growingfc = GeoJSON.FeatureCollection{2,Float64}(; features=[growing])
        @test Tables.schema(growingfc).names == (:a, :geometry)
        GeoJSON.properties(growing)["b"] = "later"
        @test Tables.schema(growingfc).names == (:a, :b, :geometry)
        @test growingfc.b == ["later"]
    end

    @testset "getproperty on features" begin
        @test f1.name == "a"
        @test f1.n === 1
        @test f1.geometry === p1
        @test f1.nonexistent === missing
        @test f3.n === missing
        @test f3.geometry === missing
        @test GeoJSON.geometry(f3) === nothing
        @test f1.bbox === missing
        @test GeoJSON.bbox(f1) === nothing
        @test f1.id === missing
        @test GeoJSON.id(f1) === nothing
    end

    @testset "property named geometry" begin
        shadowed = feature(p1, "geometry" => "not a geometry", "a" => 1)
        shadowedfc = GeoJSON.FeatureCollection{2,Float64}(; features=[shadowed])
        @test propertynames(shadowed) == (:geometry, :a)
        @test shadowed.geometry == "not a geometry"
        @test GeoJSON.geometry(shadowed) === p1
        @test Tables.getcolumn(shadowed, :geometry) === p1
        @test Tables.schema(shadowedfc).names == (:a, :geometry)
        @test Tables.schema(shadowedfc).types == (Int64, GeoJSON.Point{2,Float64})
        @test shadowedfc.geometry == [p1]
        @test Tables.columntable(shadowedfc).geometry == [p1]
    end

    @testset "NamedTuple properties" begin
        NT = NamedTuple{(:a, :b),Tuple{Int64,String}}
        F = GeoJSON.Feature{2,Float64,GeoJSON.Point{2,Float64},NT}
        nt1 = F(; geometry=p1, properties=(a=1, b="x"))
        nt2 = F(; geometry=p2, properties=(a=2, b="y"))
        ntfc = GeoJSON.FeatureCollection(features=[nt1, nt2])
        @test ntfc isa GeoJSON.FeatureCollection{2,Float64,GeoJSON.Point{2,Float64},NT}
        @test GeoJSON.properties(nt1) === (a=1, b="x")
        @test propertynames(nt1) == (:geometry, :a, :b)
        @test nt1.a === 1
        @test Tables.schema(ntfc).names == (:a, :b, :geometry)
        @test Tables.schema(ntfc).types == (Int64, String, GeoJSON.Point{2,Float64})
        @test ntfc.a == [1, 2]
        @test ntfc.a isa Vector{Int64}
        @test Tables.columntable(ntfc).b == ["x", "y"]
        @test DataFrame(ntfc) isa DataFrame
        @test size(DataFrame(ntfc)) == (2, 3)
    end

    @testset "Nothing properties" begin
        F = GeoJSON.Feature{2,Float64,GeoJSON.Point{2,Float64},Nothing}
        nf = GeoJSON.FeatureCollection(features=[F(; geometry=p1, properties=nothing)])
        @test GeoJSON.properties(nf[1]) === nothing
        @test propertynames(nf[1]) == (:geometry,)
        @test Tables.schema(nf).names == (:geometry,)
        @test Tables.schema(nf).types == (GeoJSON.Point{2,Float64},)
        @test nf.geometry == [p1]
        @test Tables.columntable(nf) == (; geometry=[p1])
        @test size(DataFrame(nf)) == (1, 1)
    end

    @testset "empty collection" begin
        empty = GeoJSON.FeatureCollection{2,Float64}()
        @test length(empty) == 0
        @test isempty(collect(empty))
        @test Tables.istable(empty)
        @test Tables.schema(empty).names == (:geometry,)
        @test Tables.schema(empty).types == (GeoJSON.AnyGeometry{2,Float64},)
        @test propertynames(empty) == [:geometry]
        @test isempty(empty.geometry)
        @test isempty(Tables.rowtable(empty))
        @test size(DataFrame(empty)) == (0, 1)
    end

    @testset "DataFrame" begin
        df = DataFrame(fc)
        @test size(df) == (3, 4)
        @test names(df) == ["name", "n", "extra", "geometry"]
        @test df.name == ["a", "b", "c"]
        @test isequal(df.n, [1, 2, missing])
        @test isequal(df.extra, [missing, true, missing])
        @test isequal(df.geometry, [p1, p2, missing])
        @test eltype(df.n) == Union{Missing,Int64}

        @testset "metadata" begin
            m = DataFrames.metadata(df)
            @test isempty(setdiff(keys(m), (GI.GEOINTERFACE_CRS_KEY, GI.GEOINTERFACE_GEOMETRYCOLUMNS_KEY)))
            @test m[GI.GEOINTERFACE_CRS_KEY] == GI.crs(fc)
            @test m[GI.GEOINTERFACE_GEOMETRYCOLUMNS_KEY] == (:geometry,)
            @test DataFrames.metadata(df, GI.GEOINTERFACE_CRS_KEY; style=true) ==
                  (GI.crs(fc), :note)
        end
    end

    @testset "type stability" begin
        @test @inferred(fc[1]) === f1
        @test @inferred(first(fc)) === f1
        concrete = GeoJSON.Feature{2,Float64,GeoJSON.Point{2,Float64},GeoJSON.Properties}(;
            geometry=p1, properties=GeoJSON.Properties("a" => 1))
        @test @inferred(Union{Nothing,GeoJSON.Point{2,Float64}}, GeoJSON.geometry(concrete)) === p1
        @test only(Base.return_types(GeoJSON.geometry, Tuple{typeof(concrete)})) ==
              Union{Nothing,GeoJSON.Point{2,Float64}}
        @test only(Base.return_types(getindex, Tuple{typeof(fc),Int})) == eltype(fc)
    end
end
