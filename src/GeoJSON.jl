__precompile__()

module GeoJSON

    using JSON, Compat

    export
        Point,
        MultiPoint,
        LineString,
        MultiLineString,
        Polygon,
        MultiPolygon,
        GeometryCollection,
        Feature,
        FeatureCollection,
        geojson

    include("types.jl")
    include("parser.jl")
end
