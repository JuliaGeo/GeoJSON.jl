# Examples from https://github.com/frewsxcv/python-geojson/tree/master/tests

a = """{
    "properties": {
        "Ã": "Ã"
    },
    "type": "Feature",
    "geometry": null
}"""

b = """{"type": "Feature",
    "geometry": null,
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
    "geometry": {"type": "Point", "coordinates": [53, -4]},
    "properties": {"title": "Dict 1"}
}"""

e = """{"geometry": {"coordinates": [53, -4],
    "type": "Point"},
    "id": "1",
    "properties": {"link": "http://example.org/features/1",
                   "summary": "The first feature",
                   "title": "Feature 1"},
    "type": "Feature"
}"""

f = """{"geometry": null, "id": 12, "properties": {"foo": "bar"}, "type": "Feature"}"""

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
}"""
