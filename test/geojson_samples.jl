# Examples from https://github.com/frewsxcv/python-geojson/tree/master/tests

a = """{
    "properties": {
        "Ã": "Ã"
    },
    "type": "Feature",
    "geometry": null,
    "crs": {
        "type": "link",
        "properties": {
            "href": "data.crs",
            "type": "ogcwkt"
        }
    }
}"""

b = """{"type": "Feature",
    "geometry": {"coordinates": [[-155.52, 19.61], [-156.22, 20.74], [-157.97, 21.46]], "type": "MultiPoint"},
    "id": 1,
    "properties": {"type": "é"}
}"""

c = """{"type": "Feature",
    "geometry": null,
    "id": 1,
    "properties": {"type": "meow"},
    "crs": {"properties": {"name": "urn:ogc:def:crs:EPSG::3785"},
            "type": "name"}
}"""

d = """{
    "type": "Feature",
    "id": "1",
    "bbox": [-180.0, -90.0, 180.0, 90.0],
    "geometry": {"type": "MultiLineString", "coordinates": [[[3.75, 9.25], [-130.95, 1.52]], [[23.15, -34.25], [-1.35, -4.65], [3.45, 77.95]]]},
    "properties": {"title": "Dict 1"}
}"""

e = """{"geometry": {"coordinates": [53, -4],
                     "type": "Point",
                     "crs": {
                         "type": "link",
                         "properties": {
                           "href": "http://example.com/crs/42",
                           "type": "proj4"
                           }
                     }},
    "id": "1",
    "properties": {"link": "http://example.org/features/1",
                   "summary": "The first feature",
                   "title": "Feature 1"},
    "type": "Feature"
}"""

f = """{"geometry": null, "id": 12, "properties": {"foo": "bar"}, "type": "Feature"}"""

# Self-Added for test coverage

g = """{
    "type": "FeatureCollection",
    "features": [{
        "type": "Feature",
        "properties": {
            "cartodb_id": 46,
            "addr1": "18150 E. Pathfinder Rd.",
            "addr2": "Rowland Heights",
            "park": "Pathfinder Park"
        },
        "geometry": {
            "type":"MultiPolygon",
            "coordinates": [[[ [-117.913883,33.96657], [-117.907767,33.967747], [-117.912919,33.96445], [-117.913883,33.96657] ]]]
        }
    }],
    "bbox": [100.0, 0.0, 105.0, 1.0],
    "crs": {"properties": {"name": "urn:ogc:def:crs:EPSG::3785"},
            "type": "name"}
}"""

h = """{
    "type": "Feature",
    "geometry": {"type": "MultiLineString", "coordinates": [[[3.75, 9.25], [-130.95, 1.52]], [[23.15, -34.25], [-1.35, -4.65], [3.45, 77.95]]]},
    "properties": {"title": "Dict 1", "bbox": [-180.0, -90.0, 180.0, 90.0]}
}"""

# Examples from https://datatracker.ietf.org/doc/html/rfc7946#section-1.3

multi = """
{
    "type": "MultiPolygon",
    "coordinates": [
        [
            [
                [180.0, 40.0], [180.0, 50.0], [170.0, 50.0],
                [170.0, 40.0], [180.0, 40.0]
            ]
        ],
        [
            [
                [-170.0, 40.0], [-170.0, 50.0], [-180.0, 50.0],
                [-180.0, 40.0], [-170.0, 40.0]
            ]
        ]
    ]
}
"""

geom_bbox = """
{"type":"LineString","coordinates":[[-35.1,-6.6],[8.1,3.8]],"bbox":[-35.1,-6.6,8.1,3.8]}
"""

# Examples from https://github.com/Esri/geojson-utils/blob/master/tests/geojson.js

multipolygon = """{
    "type": "FeatureCollection",
    "features": [{
        "type": "Feature",
        "bbox": [100.0, 0.0, 105.0, 1.0],
        "properties": {
            "cartodb_id": 46,
            "addr1": "18150 E. Pathfinder Rd.",
            "addr2": "Rowland Heights",
            "park": "Pathfinder Park"
        },
        "geometry": {
            "type":"MultiPolygon",
            "coordinates": [[[ [-117.913883,33.96657], [-117.907767,33.967747], [-117.912919,33.96445], [-117.913883,33.96657] ]]]
        }
    }]
}"""

realmultipolygon = """{
        "type":"FeatureCollection",
        "features":[
        {
            "type":"Feature",
            "properties":{
                "cartodb_id":46,
                "addr1":"18150 E. Pathfinder Rd.",
                "addr2":"Rowland Heights",
                "park":"Pathfinder Park"
            },
            "geometry":{
                "type":"MultiPolygon",
                "coordinates": [
                    [[[102.0, 2.0], [103.0, 2.0], [103.0, 3.0], [102.0, 3.0], [102.0, 2.0]]],
                [[[100.0, 0.0], [101.0, 0.0], [101.0, 1.0], [100.0, 1.0], [100.0, 0.0]],
                [[100.2, 0.2], [100.8, 0.2], [100.8, 0.8], [100.2, 0.8], [100.2, 0.2]]]
                    ]
            }
        }
        ]
    }"""

polyline = """{
        "next_feature" : "1",
        "type" : "FeatureCollection",
        "start" : 0,
        "features" : [{
            "type" : "Feature",
            "id" : "a73ws67n775q",
            "geometry" : {
                "type" : "LineString",
                "coordinates" : [[-89, 43], [-88, 44], [-88, 45]]
            },
            "properties" : {
                "InLine_FID" : 0,
                "SimLnFLag" : 0
            }
        }],
        "sort" : null,
        "page" : 0,
        "count" : 2073,
        "limit" : 1
    }"""

point = """{
        "next_feature" : "1",
        "type" : "FeatureCollection",
        "start" : 0,
        "features" : [{
            "type" : "Feature",
            "id" : "a7vs0i9rnyyx",
            "geometry" : {
                "type" : "Point",
                "coordinates" : [-89, 44]
            },
            "properties" : {
                "fax" : "305-571-8347",
                "phone" : "305-571-8345"
            }
        }],
        "sort" : null,
        "page" : 0,
        "count" : 236,
        "limit" : 1
    }"""

pointnull = """{
        "next_feature" : "1",
        "type" : "FeatureCollection",
        "start" : 0,
        "features" : [{
            "type" : "Feature",
            "id" : "a7vs0i9rnyyx",
            "geometry" : null,
            "properties" : {
                "fax" : "305-571-8347",
                "phone" : "305-571-8345"
            }
        }],
        "sort" : null,
        "page" : 0,
        "count" : 236,
        "limit" : 1
    }"""

poly = """{
        "next_feature" : "1",
        "type" : "FeatureCollection",
        "start" : 0,
        "features" : [{
            "type" : "Feature",
            "id" : "a7ws7wldxold",
            "geometry" : {
                "type" : "Polygon",
                "coordinates" : [[[-89, 42], [-89, 50], [-80, 50], [-80, 42], [-89, 42]]]
            },
            "properties" : {
                "DIST_NUM" : 7.0,
                "LOCATION" : "Bustleton Ave. & Bowler St",
                "PHONE" : "686-3070",
                "DIST_NUMC" : "07",
                "DIV_CODE" : "NEPD",
                "AREA_SQMI" : 12.41643
            }
        }],
        "sort" : null,
        "page" : 0,
        "count" : 25,
        "limit" : 1
    }"""

polyhole = """{
        "next_feature" : "1",
        "type" : "FeatureCollection",
        "start" : 0,
        "features" : [{
            "type" : "Feature",
            "id" : "a7ws7wldxold",
            "geometry" : {
                "type" : "Polygon",
                "coordinates" : [[[-89, 42], [-89, 50], [-80, 50], [-80, 42], [-89, 42]], [[-87, 44], [-82, 44], [-82, 48], [-87, 48], [-87, 44]]]
            },
            "properties" : {
                "DIST_NUM" : 7.0,
                "LOCATION" : "Bustleton Ave. & Bowler St",
                "PHONE" : "686-3070",
                "DIST_NUMC" : "07",
                "DIV_CODE" : "NEPD",
                "AREA_SQMI" : 12.41643
            }
        }],
        "sort" : null,
        "page" : 0,
        "count" : 25,
        "limit" : 1
    }"""

collection = """{
        "next_feature" : "1",
        "type" : "FeatureCollection",
        "start" : 0,
        "features" : [{
            "type" : "Feature",
            "id" : "a7xlmuwyjioy",
            "geometry" : {
                "type" : "GeometryCollection",
                "geometries" : [{
                    "type" : "Polygon",
                    "coordinates" : [[[-95, 43], [-95, 50], [-90, 50], [-91, 42], [-95, 43]]]
                }, {
                    "type" : "Polygon",
                    "coordinates" : [[[-89, 42], [-89, 50], [-80, 50], [-80, 42], [-89, 42]]]
                }, {
                    "type" : "Point",
                    "coordinates" : [-94, 46]
                }]
            },
            "properties" : {
                "STATE_ABBR" : "ZZ",
                "STATE_NAME" : "Top"
            }
        }],
        "sort" : null,
        "page" : 0,
        "count" : 3,
        "limit" : 1
    }"""

# Example from osmbuildings.org/examples/GeoJSON.php

osm_buildings = """{
  "type": "FeatureCollection",
  "features": [{
    "type": "Feature",
    "geometry": {
      "type": "Polygon",
      "coordinates": [
        [
          [13.42634, 52.49533],
          [13.42660, 52.49524],
          [13.42619, 52.49483],
          [13.42583, 52.49495],
          [13.42590, 52.49501],
          [13.42611, 52.49494],
          [13.42640, 52.49525],
          [13.42630, 52.49529],
          [13.42634, 52.49533]
        ]
      ]
    },
    "properties": {
      "color": "rgb(255,200,150)",
      "height": 150
    }
  }, {
    "type": "Feature",
    "geometry": {
      "type": "Polygon",
      "coordinates": [
        [
          [13.42706, 52.49535],
          [13.42745, 52.49520],
          [13.42745, 52.49520],
          [13.42741, 52.49516],
          [13.42717, 52.49525],
          [13.42692, 52.49501],
          [13.42714, 52.49494],
          [13.42686, 52.49466],
          [13.42650, 52.49478],
          [13.42657, 52.49486],
          [13.42678, 52.49480],
          [13.42694, 52.49496],
          [13.42675, 52.49503],
          [13.42706, 52.49535]
        ]
      ]
    },
    "properties": {
      "color": "rgb(180,240,180)",
      "height": 130
    }
  }, {
    "type": "Feature",
    "geometry": {
      "type": "MultiPolygon",
      "coordinates": [
        [
          [
            [13.42746, 52.49440],
            [13.42794, 52.49494],
            [13.42799, 52.49492],
            [13.42755, 52.49442],
            [13.42798, 52.49428],
            [13.42846, 52.49480],
            [13.42851, 52.49478],
            [13.42800, 52.49422],
            [13.42746, 52.49440]
          ]
        ],
        [
          [
            [13.42803, 52.49497],
            [13.42800, 52.49493],
            [13.42844, 52.49479],
            [13.42847, 52.49483],
            [13.42803, 52.49497]
          ]
        ]
      ]
    },
    "properties": {
      "color": "rgb(200,200,250)",
      "height": 120
    }
  }, {
    "type": "Feature",
    "geometry": {
      "type": "Polygon",
      "coordinates": [
        [
          [13.42857, 52.49480],
          [13.42918, 52.49465],
          [13.42867, 52.49412],
          [13.42850, 52.49419],
          [13.42896, 52.49465],
          [13.42882, 52.49469],
          [13.42837, 52.49423],
          [13.42821, 52.49428],
          [13.42863, 52.49473],
          [13.42853, 52.49476],
          [13.42857, 52.49480]

        ]
      ]
    },
    "properties": {
      "color": "rgb(150,180,210)",
      "height": 140
    }
  }]
}""";
