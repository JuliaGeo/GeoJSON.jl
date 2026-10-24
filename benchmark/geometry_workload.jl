# A user calculation that narrows geometry kinds before calling GeoInterface.
function geometry_score(g)
    if g isa GeoJSON.Point
        return Float64(GI.x(g))
    elseif g isa GeoJSON.LineString || g isa GeoJSON.Polygon
        return Float64(GI.ngeom(g))
    end
    0.0
end
feature_score(f) = geometry_score(GI.geometry(f))
function collection_score(fc)
    total = 0.0
    for f in fc
        total += feature_score(f)
    end
    total
end
