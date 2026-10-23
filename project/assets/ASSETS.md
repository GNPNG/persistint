# Asset register

One row per art asset: where it lives, what draws it, how an animated sheet is laid out, and the
`prompts/` entry it stands in for (if a Gemini render will replace it at that same path). Every
generator runs as `python3 -I tools/<generator>` from the repo root and reproduces its files.
Rows are sorted by path.

| id | path | generator | frame layout | stands in for |
|---|---|---|---|---|
| prop_calendar | project/assets/canon/prop_calendar.png | tools/cut_island_props.py (canon sheet 481b, crop in project/data/island_props.json) | single 46x40, foot at bottom | - |
| npc_barren_rig | project/assets/characters/npc_barren_rig.png | tools/gen_npc_rigs.py (from the canon cuts) | 32x52 frames, feet y 50; rows down / left / up; cols 0-3 idle, 4-7 walk | - |
| npc_drone_rig | project/assets/characters/npc_drone_rig.png | tools/gen_npc_rigs.py (from the canon cuts) | as npc_barren_rig | - |
| npc_initiate_rig | project/assets/characters/npc_initiate_rig.png | tools/gen_npc_rigs.py (from the canon cuts) | as npc_barren_rig | - |
| npc_mother_rig | project/assets/characters/npc_mother_rig.png | tools/gen_npc_rigs.py (from the canon cuts) | as npc_barren_rig | - |
| npc_priestess_rig | project/assets/characters/npc_priestess_rig.png | tools/gen_npc_rigs.py (from the canon cuts) | as npc_barren_rig | - |
| door_marker | project/assets/common/door_marker.png | tools/gen_door_marker.py | 40x48 frames, mat centre (20, 36); row 0 open x 8 (arrow bob), row 1 locked x 1 | - |
| mirror | project/assets/island/mirror.png | tools/gen_village_props.py | single 26x40, foot y 37 | - |
| temple_pavilion | project/assets/island/temple_pavilion.png | tools/gen_village_props.py | single 150x140, foot y 136, door at x 75 | - |
| temple_candles | project/assets/temple/temple_candles.png | tools/gen_temple_props.py | 24x44 frames, foot (12, 42); row 0 idle x 4 (flicker); SpriteFrames temple_candles.tres | - |
| temple_cushion | project/assets/temple/temple_cushion.png | tools/gen_temple_props.py | single 30x20, foot y 18 | - |
| temple_plinth | project/assets/temple/temple_plinth.png | tools/gen_temple_props.py | single 32x14, pillar foot y 9 | - |
| temple_shadow | project/assets/temple/temple_shadow.png | tools/gen_temple_props.py | single 24x8 | - |
| temple_twinkle | project/assets/temple/temple_twinkle.png | tools/gen_temple_props.py | 12x12 frames, centred; row 0 idle x 6; SpriteFrames temple_twinkle.tres | - |
| temple_urn | project/assets/temple/temple_urn.png | tools/gen_temple_props.py | single 28x36, foot y 34 | - |
| island_tiles | project/assets/tiles/island_tiles.png (+ island_tiles.json index) | tools/gen_island_tiles.py; TileSet island_tileset.tres by tools/build_island_maps.gd | 32x32 cells; row 0 walkable, row 1 blocked + solid, rows 2-3 water / shallows x 4 animation frames, rows 4-6 dual-grid edge overlays (shallows, shore, grass_edge) by corner mask 0-15 | - |
