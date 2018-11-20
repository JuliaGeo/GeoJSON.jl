var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "GeoJSON.jl",
    "title": "GeoJSON.jl",
    "category": "page",
    "text": ""
},

{
    "location": "#GeoJSON.jl-1",
    "page": "GeoJSON.jl",
    "title": "GeoJSON.jl",
    "category": "section",
    "text": ""
},

{
    "location": "#Introduction-1",
    "page": "GeoJSON.jl",
    "title": "Introduction",
    "category": "section",
    "text": "(Image: Build Status) (Image: Build Status) (Image: Coverage Status) (Image: Latest Documentation)This library is developed independently of, but is heavily influenced in design by the python-geojson package. It contains:Functions for encoding and decoding GeoJSON formatted data\na type hierarchy (according to the GeoJSON specification)\nAn implementation of the __geo_interface__, a GeoJSON-like protocol for geo-spatial (GIS) vector data."
},

{
    "location": "#Contents-1",
    "page": "GeoJSON.jl",
    "title": "Contents",
    "category": "section",
    "text": ""
},

{
    "location": "#Installation-1",
    "page": "GeoJSON.jl",
    "title": "Installation",
    "category": "section",
    "text": "The package is registered and can be added using the package manager:pkg> add GeoJSONTo test if it is installed correctly run:pkg> test GeoJSON"
},

{
    "location": "#Basic-Usage-1",
    "page": "GeoJSON.jl",
    "title": "Basic Usage",
    "category": "section",
    "text": "Although we use GeoInterface types for representing GeoJSON objects, it works in tandem  with the JSON.jl package, for parsing and some printing of objects. Here are some examples of its functionality:"
},

{
    "location": "#Parses-a-GeoJSON-String-or-IO-stream-into-a-GeoInterface-object-1",
    "page": "GeoJSON.jl",
    "title": "Parses a GeoJSON String or IO stream into a GeoInterface object",
    "category": "section",
    "text": "using GeoJSON\nosm_buildings = \"\"\"\n{\n    \"type\": \"FeatureCollection\",\n    \"features\": [{\n        \"type\": \"Feature\",\n        \"geometry\": {\n            \"type\": \"Polygon\",\n            \"coordinates\": [\n                [\n                    [13.42634, 52.49533],\n                    [13.42630, 52.49529],\n                    [13.42640, 52.49525],\n                    [13.42611, 52.49494],\n                    [13.42590, 52.49501],\n                    [13.42583, 52.49495],\n                    [13.42619, 52.49483],\n                    [13.42660, 52.49524],\n                    [13.42634, 52.49533]\n                ]\n            ]\n        },\n        \"properties\": {\n            \"color\": \"rgb(255,200,150)\",\n            \"height\": 150\n        }\n    }]\n}\"\"\"\nbuildings = GeoJSON.parse(osm_buildings)\nbuildingsUse GeoJSON.parsefile(\"tech_square.geojson\") to read GeoJSON files from disk."
},

{
    "location": "#Transforms-a-GeoInterface-object-into-a-nested-Array-or-Dict-1",
    "page": "GeoJSON.jl",
    "title": "Transforms a GeoInterface object into a nested Array or Dict",
    "category": "section",
    "text": "dict = geo2dict(buildings) # geo2dict -- GeoInterface object to Dict/Array-representation\ndictusing JSON\nJSON.parse(osm_buildings) # should be comparable (if not the same)"
},

{
    "location": "#Transforms-from-a-nested-Array/Dict-to-a-GeoInterface-object-1",
    "page": "GeoJSON.jl",
    "title": "Transforms from a nested Array/Dict to a GeoInterface object",
    "category": "section",
    "text": "dict2geo(dict)GeoJSON.parse(osm_buildings) # the original object (for comparison)Writing back GeoJSON strings is not yet implemented."
},

{
    "location": "#GeoInterface-1",
    "page": "GeoJSON.jl",
    "title": "GeoInterface",
    "category": "section",
    "text": "This library implements the GeoInterface. For more information on the types that are returned by this package, and the methods that can be used on them, refer to the documentation of the GeoInterface package."
},

{
    "location": "#Functions-1",
    "page": "GeoJSON.jl",
    "title": "Functions",
    "category": "section",
    "text": ""
},

{
    "location": "#GeoJSON.parse",
    "page": "GeoJSON.jl",
    "title": "GeoJSON.parse",
    "category": "function",
    "text": "parse(input::Union{String, IO}, inttype::Type{<:Real}=Int64)\n\nParse a GeoJSON string or IO stream into a GeoInterface object.\n\nSee also: parsefile\n\nExamples\n\njulia> GeoJSON.parse(\"{\"type\": \"Point\", \"coordinates\": [30, 10]}\")\nGeoInterface.Point([30.0, 10.0])\n\n\n\n\n\n"
},

{
    "location": "#GeoJSON.parsefile",
    "page": "GeoJSON.jl",
    "title": "GeoJSON.parsefile",
    "category": "function",
    "text": "parsefile(filename::AbstractString, inttype::Type{<:Real}=Int64)\n\nParse a GeoJSON file into a GeoInterface object.\n\nSee also: parse\n\n\n\n\n\n"
},

{
    "location": "#Input-1",
    "page": "GeoJSON.jl",
    "title": "Input",
    "category": "section",
    "text": "To read in GeoJSON data, use GeoJSON.parse, or to read a file from disk use GeoJSON.parsefile.GeoJSON.parse\nGeoJSON.parsefile"
},

{
    "location": "#GeoJSON.geojson",
    "page": "GeoJSON.jl",
    "title": "GeoJSON.geojson",
    "category": "function",
    "text": "geojson(obj)\n\nCreate a GeoJSON string from an object that implements the GeoInterface, either AbstractGeometry, AbstractFeature or AbstractFeatureCollection.\n\nExamples\n\njulia> geojson(Point([30.0, 10.0]))\n\"{\"coordinates\":[30.0,10.0],\"type\":\"Point\"}\"\n\n\n\n\n\n"
},

{
    "location": "#Output-1",
    "page": "GeoJSON.jl",
    "title": "Output",
    "category": "section",
    "text": "geojson"
},

{
    "location": "#GeoJSON.geo2dict",
    "page": "GeoJSON.jl",
    "title": "GeoJSON.geo2dict",
    "category": "function",
    "text": "geo2dict(obj)\n\nTransform a GeoInterface object to a JSON dictionary.\n\nSee also: dict2geo\n\nExamples\n\njulia> geo2dict(Point([30.0, 10.0]))\nDict{String,Any} with 2 entries:\n  \"coordinates\" => [30.0, 10.0]\n  \"type\"        => \"Point\"\n\n\n\n\n\n"
},

{
    "location": "#GeoJSON.dict2geo",
    "page": "GeoJSON.jl",
    "title": "GeoJSON.dict2geo",
    "category": "function",
    "text": "dict2geo(obj::Dict{String, Any})\n\nTransform a parsed JSON dictionary to a GeoInterface object.\n\nSee also: geo2dict\n\nExamples\n\njulia> dict2geo(Dict(\"type\" => \"Point\", \"coordinates\" => [30.0, 10.0]))\nPoint([30.0, 10.0])\n\n\n\n\n\n"
},

{
    "location": "#Conversion-1",
    "page": "GeoJSON.jl",
    "title": "Conversion",
    "category": "section",
    "text": "For more fine grained control, to construct or deconstruct parts of a GeoJSON, use geo2dict or dict2geo.geo2dict\ndict2geo"
},

{
    "location": "#Index-1",
    "page": "GeoJSON.jl",
    "title": "Index",
    "category": "section",
    "text": ""
},

]}
