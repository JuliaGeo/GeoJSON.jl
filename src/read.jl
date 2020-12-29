# GeoJSON read functions

_readpoint(c::JSON3.Array) = SVector{length(c), Float64}(c)
_readlinestring(c::JSON3.Array) = LineString([SVector{length(p), Float64}(p) for p in c])

function _readpolygon(c::JSON3.Array)
    outerior = LineString([SVector{length(p), Float64}(p) for p in c[1]])
    otype = typeof(outerior)
    interiors = Vector{otype}(undef, length(c) - 1)
    for i in 2:length(c)
        interiors[i-1] = otype([SVector{length(p), Float64}(p) for p in c[i]])
    end
    Polygon(outerior, interiors)
end

function _readregular(t::AbstractString, c::JSON3.Array)
    if t === "Point"
        _readpoint(c)
    elseif t === "LineString"
        _readlinestring(c)
    elseif t === "Polygon"
        _readpolygon(c)
    elseif t === "MultiPoint"
        _readpoint.(c)
    elseif t === "MultiLineString"
        _readlinestring.(c)
    elseif t === "MultiPolygon"
        _readpolygon.(c)
    else
        throw(ArgumentError("Invalid geometry type"))
    end
end

function _bbox(obj::JSON3.Object)
    b = get(obj, :bbox, nothing)
    b === nothing && return b
    n = length(b)
    if n == 4
        BBox{2}(SMatrix{2, 2, Float64}(b))
    elseif n == 6
        BBox{3}(SMatrix{3, 2, Float64}(b))
    else
        throw(ArgumentError("Invalid length bbox"))
    end
end

function _readgeometry(t::String, obj::JSON3.Object)
    if t === "GeometryCollection"
        GeometryCollection(
            [_readregular(geom.type, geom.coordinates) for geom in obj.geometries],
            _bbox(obj)
        )
    else
        _readregular(t, obj.coordinates)
    end
end

function _readfeature(f::JSON3.Object)
    geometry = _readgeometry(f.geometry.type, f.geometry)
    Feature(geometry, f.properties, get(f, :id, nothing), _bbox(f))
end

"""
    read(input::Union{AbstractString, IO, AbstractVector{UInt8}})

Read a GeoJSON string or IO stream into a GeoJSON type.

To read a file, use `GeoJSON.read(read(path))`.

# Examples
```julia
julia> GeoJSON.read("{\"type\": \"Point\", \"coordinates\": [30, 10]}")
2-element StaticArrays.SArray{Tuple{2},Int64,1,2} with indices SOneTo(2):
 30
 10
```
"""
function read(input)
    # use default JSON3 read, check type and send to the right method
    obj = JSON3.read(input)
    t = obj.type
    if t === "FeatureCollection"
        FeatureCollection(_readfeature.(obj.features), _bbox(obj))
    elseif t === "Feature"
        _readfeature(obj)
    else
        _readgeometry(t, obj)
    end
end
