# GeoJSON write functions

# write an array, using JSON3 to write elements such as points
function _write_vector_json(io::IO, v::AbstractVector; usepoints::Bool=false)
    n = length(v)
    for (i, x) in enumerate(v)
        if usepoints
            x = x.points
        end
        JSON3.write(io, x)
        i == n || Base.Base.write(io, ',')
    end
    nothing
end

# write elements with GeoJSON.write
function _write_vector_geojson(io::IO, v::AbstractVector)
    n = length(v)
    for (i, x) in enumerate(v)
        write(io, x)
        i == n || Base.Base.write(io, ',')
    end
    nothing
end

function _write_polygon_coordinates(io::IO, g::Polygon)
    JSON3.write(io, g.exterior.points)
    for interior in g.interiors
        Base.write(io, ',')
        JSON3.write(io, interior.points)
    end
end

"Write a Point to GeoJSON"
function write(io::IO, g::StaticVector{N, <:Real} where N)
    Base.write(io, """{"type":"Point","coordinates":""")
    JSON3.write(io, g)
    Base.write(io, '}')
    nothing
end

"Write a LineString to GeoJSON"
function write(io::IO, g::LineString)
    Base.write(io, """{"type":"LineString","coordinates":""")
    JSON3.write(io, g.points)
    Base.write(io, '}')
    nothing
end

"Write a Polygon to GeoJSON"
function write(io::IO, g::Polygon)
    Base.write(io, """{"type":"Polygon","coordinates":[""")
    _write_polygon_coordinates(io, g)
    Base.write(io, "]}")
    nothing
end

"Write a MultiPoint to GeoJSON"
function write(io::IO, g::Vector{<:StaticVector{N, <:Real} where N})
    Base.write(io, """{"type":"MultiPoint","coordinates":[""")
    _write_vector_json(io, g)
    Base.write(io, "]}")
    nothing
end

"Write a MultiLineString to GeoJSON"
function write(io::IO, g::Vector{<:LineString})
    Base.write(io, """{"type":"MultiLineString","coordinates":[""")
    _write_vector_json(io, g, usepoints=true)
    Base.write(io, "]}")
    nothing
end

"Write a MultiPolygon to GeoJSON"
function write(io::IO, g::Vector{<:Polygon})
    Base.write(io, """{"type":"MultiPolygon","coordinates":[""")
    n = length(g)
    for (i, x) in enumerate(g)
        Base.write(io, '[')
        _write_polygon_coordinates(io, x)
        Base.write(io, ']')
        i == n || Base.write(io, ',')
    end
    Base.write(io, "]}")
    nothing
end

"Write a GeometryCollection to GeoJSON"
function write(io::IO, g::GeometryCollection)
    Base.write(io, """{"type":"GeometryCollection","geometries":[""")
    _write_vector_geojson(io, g)
    if g.bbox === nothing
        Base.write(io, "]}")
    else
        Base.write(io, """],"bbox":""")
        JSON3.write(io, g.bbox.bounds)
        Base.write(io, '}')
    end
    nothing
end

"Write a Feature to GeoJSON"
function write(io::IO, f::Feature)
    Base.write(io, """{"type":"Feature","geometry":""")
    write(io, f.geometry)
    Base.write(io, ""","properties":""")
    JSON3.write(io, f.properties)
    if f.id !== nothing
        Base.write(io, ""","id":""")
        JSON3.write(io, f.id)
    end
    if f.bbox !== nothing
        Base.write(io, ""","bbox":""")
        JSON3.write(io, f.bbox.bounds)
    end
    Base.write(io, '}')
    nothing
end

"Write a FeatureCollection to GeoJSON"
function write(io::IO, fcol::FeatureCollection)
    Base.write(io, """{"type":"FeatureCollection","features":[""")
    _write_vector_geojson(io, fcol)
    if fcol.bbox === nothing
        Base.write(io, "]}")
    else
        Base.write(io, """],"bbox":""")
        JSON3.write(io, fcol.bbox.bounds)
        Base.write(io, '}')
    end
    nothing
end

"""
    write(obj)

Create a GeoJSON string from an object that implements the GeoInterface, either
`AbstractGeometry`, `AbstractFeature` or `AbstractFeatureCollection`.

# Examples
```julia
julia> GeoJSON.write(Point([30.0, 10.0]))
\"{\"coordinates\":[30.0,10.0],\"type\":\"Point\"}\"
```
"""
function write(g)
    io = IOBuffer()
    write(io, g)
    String(take!(io))
end
