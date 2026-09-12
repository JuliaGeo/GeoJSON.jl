using PrecompileTools: @setup_workload, @compile_workload

@setup_workload begin
    # One feature per geometry kind, a null geometry, foreign members, and every id/property scalar.
    doc = """{"type":"FeatureCollection","bbox":[0,0,3,3],"crs":{"type":"name","properties":{"name":"EPSG:4326"}},"features":[
    {"type":"Feature","id":1,"geometry":{"type":"Point","coordinates":[1,2]},"properties":{"name":"a","n":1,"x":1.5,"b":true,"z":null}},
    {"type":"Feature","id":"b","bbox":[0,0,1,1],"geometry":{"type":"LineString","coordinates":[[0,0],[1,1]]},"properties":{"name":"b"}},
    {"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,0]]]},"properties":{"name":"c"}},
    {"type":"Feature","geometry":{"type":"MultiPoint","coordinates":[[0,0],[1,1]]},"properties":null},
    {"type":"Feature","geometry":{"type":"MultiLineString","coordinates":[[[0,0],[1,1]]]},"properties":{}},
    {"type":"Feature","geometry":{"type":"MultiPolygon","coordinates":[[[[0,0],[1,0],[1,1],[0,0]]]]},"properties":{}},
    {"type":"Feature","geometry":{"type":"GeometryCollection","geometries":[{"type":"Point","coordinates":[1,2]}]},"properties":{}},
    {"type":"Feature","geometry":null,"properties":{"name":"d"},"foreign":[1,"two",null]}
    ]}"""
    doc3 = replace(doc, r"\[(-?\d+),(-?\d+)\]" => s"[\1,\2,0]", "[0,0,3,3]" => "[0,0,0,3,3,0]", "[0,0,1,1]" => "[0,0,0,1,1,0]")
    @compile_workload begin
        for d in (doc, doc3)
            fc = read(d)
            write(fc)
            read(d; properties=false)
            lfc = read(d; lazy=true)
            lfc[1]
            collect(lfc)
        end
        read(Vector{UInt8}(codeunits(doc)))
        read(doc3; ndim=3)
    end
end
