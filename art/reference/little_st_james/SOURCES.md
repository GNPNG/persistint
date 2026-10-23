# Little Saint James reference data

Used to trace the island map (tools/project_osm_island.py -> tools/island_layout.json).

| File | Source | Licence |
|---|---|---|
| osm_raw.json | OpenStreetMap, Overpass API (mirror https://overpass.kumi.systems/api/interpreter), query `way(18.294,-64.832,18.305,-64.820); out geom;`, data timestamp 2026-05-31T22:37:44Z | ODbL 1.0, (c) OpenStreetMap contributors, https://www.openstreetmap.org/copyright |
| lsj_aerial_dji0360.jpg | Wikimedia Commons, "File:DJI 0360 - Little Saint James (United States Virgin Islands) (cropped).jpg", https://commons.wikimedia.org/wiki/File:DJI_0360_-_Little_Saint_James_(United_States_Virgin_Islands)_(cropped).jpg | Public domain (produced by the U.S. Virgin Islands government) |
| lsj_usvi_map_drone.jpg | Wikimedia Commons, "File:USVI Map of area LSJ - Aerial view of the St James Islands ... drone shot.jpg", https://commons.wikimedia.org/wiki/File:USVI_Map_of_area_LSJ_-_Aerial_view_of_the_St_James_Islands_with_Great_St_James_and_Little_St_James_clearly_marked_captured_from_a_drone_shot.jpg | Public domain (produced by the U.S. Virgin Islands government) |

The two Commons photos are oblique, so they are visual reference only (green hilly island, beach on the
south shore); positions come from OpenStreetMap. NOAA NGS 2017 hurricane imagery and USGS orthoimagery were not fetched.
