using PrecompileTools: @setup_workload, @compile_workload

@setup_workload let
    geometries = [
        """{"type":"Point","coordinates":[1,2]}""",
        """{"type":"LineString","coordinates":[[1,2],[3,4]]}""",
        """{"type":"Polygon","bbox":[0,0,1,1],"coordinates":[[[0,0],[1,0],[1,1],[0,0]]]}""",
        """{"type":"MultiPoint","coordinates":[[1,2]]}""",
        """{"type":"MultiLineString","coordinates":[[[1,2],[3,4]]]}""",
        """{"type":"MultiPolygon","coordinates":[[[[0,0],[1,0],[1,1],[0,0]]]]}""",
        """{"type":"GeometryCollection","geometries":[{"type":"GeometryCollection","geometries":[{"type":"Point","coordinates":[1,2]}]}]}""",
    ]
    features = join(["""{"type":"Feature","id":$i,"geometry":$g,"properties":{"a":1,"b":"x","c":[1,{"d":null}],"e":1.5,"f":true}}""" for (i, g) in enumerate(geometries)], ',')
    fc = """{"type":"FeatureCollection","features":[$features,{"type":"Feature","id":"null","geometry":null,"properties":null}],"crs":{"type":"name","properties":{"name":"EPSG:4326"}}}"""
    @compile_workload begin
        # These literal calls compile the default keyword entrypoints too.
        # Keep NaN/Inf inputs out: their invokelatest retry compiles on demand.
        write(read(fc))
        write(read(fc; numbertype=Float64))
        write(read(fc, FeatureCollection{2,Float64}); style=StrictStyle())
        # Compile the wrapper entrypoints; all share JSON's String parser.
        read(Vector{UInt8}(fc))
        read(SubString(fc, firstindex(fc)))
        read(IOBuffer(fc))
        read(codeunits(fc))
        bytes = Vector{UInt8}(fc)
        read(view(bytes, 1:length(bytes)))
        for T in (Float32, Float64)
            x = read(fc; numbertype=T); write(x); Tables.schema(x)
            for g in geometries; write(read(g; numbertype=T)); end
            read("""{"type":"Point","coordinates":[1,2,3]}"""; ndim=3, numbertype=T)
            lazy = read(fc; numbertype=T, lazyfc=true)
            write(lazy); write(lazy[1])
        end
    end
end
