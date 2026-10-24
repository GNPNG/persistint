# Asset register

One row per art asset: where it lives, what draws it, how an animated sheet is laid out, and the
`prompts/` entry it stands in for (if a Gemini render will replace it at that same path). Every
generator runs as `python3 -I tools/<generator>` from the repo root and reproduces its files.
Rows are sorted by path.

| id | path | generator | frame layout | stands in for |
|---|---|---|---|---|
| deco_flowers | project/assets/canon/deco_flowers.png | tools/gen_island_deco.py | single 144x88 (4x of 36x22 world px), foot at bottom | - |
| deco_heart | project/assets/canon/deco_heart.png | tools/cut_island_props.py (dev/art PERSISTINT overview, crop in project/data/island_props.json) | single 39x39 at source resolution, shown 14 px tall, foot at bottom | - |
| deco_sparkle | project/assets/canon/deco_sparkle.png | tools/cut_island_props.py (dev/art PERSISTINT overview, crop in project/data/island_props.json) | single 37x41 at source resolution, shown 14 px tall, foot at bottom | - |
| deco_tree_a | project/assets/canon/deco_tree_a.png | tools/gen_island_deco.py | single 160x208 (4x of 40x52 world px), foot at bottom | - |
| deco_tree_b | project/assets/canon/deco_tree_b.png | tools/gen_island_deco.py | single 160x208 (4x of 40x52 world px), foot at bottom | - |
| deco_tree_c | project/assets/canon/deco_tree_c.png | tools/gen_island_deco.py | single 160x208 (4x of 40x52 world px), foot at bottom | - |
| prop_bunker | project/assets/canon/prop_bunker.png | tools/cut_island_props.py (canon sheet i7kl, crop in project/data/island_props.json) | single 890x790 at source resolution, shown 120 px tall, foot at bottom | - |
| prop_calendar | project/assets/canon/prop_calendar.png | tools/cut_island_props.py (canon sheet 481b, crop in project/data/island_props.json) | single 764x669 at source resolution, shown 40 px tall, foot at bottom | - |
| prop_fence_a | project/assets/canon/prop_fence_a.png | tools/cut_island_props.py (canon sheet i7kl, crop in project/data/island_props.json) | single 619x374 at source resolution, shown 34 px tall, foot at bottom | - |
| prop_fence_b | project/assets/canon/prop_fence_b.png | tools/cut_island_props.py (canon sheet i7kl, crop in project/data/island_props.json) | single 612x364 at source resolution, shown 34 px tall, foot at bottom | - |
| prop_icon_queen_mother | project/assets/canon/prop_icon_queen_mother.png | tools/cut_island_props.py (dev/art PERSISTINT overview, crop in project/data/island_props.json) | single 269x293 at source resolution, shown 72 px tall, foot at bottom | - |
| prop_pillar_orb | project/assets/canon/prop_pillar_orb.png | tools/cut_island_props.py (dev/art PERSISTINT overview, crop in project/data/island_props.json) | single 153x280 at source resolution, shown 64 px tall, foot at bottom | - |
| prop_seal_o | project/assets/canon/prop_seal_o.png | tools/cut_island_props.py (dev/art PERSISTINT overview, crop in project/data/island_props.json) | single 180x170 at source resolution, shown 36 px tall, foot at bottom | - |
| prop_ship | project/assets/canon/prop_ship.png | tools/cut_island_props.py (canon sheet i7kl, crop in project/data/island_props.json) | single 1305x871 at source resolution, shown 150 px tall, foot at bottom | - |
| prop_sign_a | project/assets/canon/prop_sign_a.png | tools/cut_island_props.py (canon sheet i7kl, crop in project/data/island_props.json) | single 433x510 at source resolution, shown 48 px tall, foot at bottom | - |
| prop_sign_b | project/assets/canon/prop_sign_b.png | tools/cut_island_props.py (canon sheet i7kl, crop in project/data/island_props.json) | single 391x516 at source resolution, shown 48 px tall, foot at bottom | - |
| prop_skull_altar | project/assets/canon/prop_skull_altar.png | tools/cut_island_props.py (dev/art PERSISTINT overview, crop in project/data/island_props.json) | single 171x216 at source resolution, shown 48 px tall, foot at bottom | - |
| prop_tag_x | project/assets/canon/prop_tag_x.png | tools/cut_island_props.py (canon sheet 481b, crop in project/data/island_props.json) | single 510x672 at source resolution, shown 36 px tall, foot at bottom | - |
| npc_barren_rig | project/assets/characters/npc_barren_rig.png | tools/gen_npc_rigs.py (from the full-resolution canon cuts) | 8x3 frames of 294x478 (32x52 world px, feet at 50/52); rows down / left / up; cols 0-3 idle, 4-7 walk | - |
| npc_drone_rig | project/assets/characters/npc_drone_rig.png | tools/gen_npc_rigs.py (from the full-resolution canon cuts) | 8x3 frames of 306x497 (32x52 world px, feet at 50/52); rows down / left / up; cols 0-3 idle, 4-7 walk | - |
| npc_initiate_rig | project/assets/characters/npc_initiate_rig.png | tools/gen_npc_rigs.py (from the full-resolution canon cuts) | 8x3 frames of 294x478 (32x52 world px, feet at 50/52); rows down / left / up; cols 0-3 idle, 4-7 walk | - |
| npc_mother_rig | project/assets/characters/npc_mother_rig.png | tools/gen_npc_rigs.py (from the full-resolution canon cuts) | 8x3 frames of 295x480 (32x52 world px, feet at 50/52); rows down / left / up; cols 0-3 idle, 4-7 walk | - |
| npc_priestess_rig | project/assets/characters/npc_priestess_rig.png | tools/gen_npc_rigs.py (from the full-resolution canon cuts) | 8x3 frames of 294x478 (32x52 world px, feet at 50/52); rows down / left / up; cols 0-3 idle, 4-7 walk | - |
| door_marker | project/assets/common/door_marker.png | tools/gen_door_marker.py | 160x192 frames (40x48 world px at 4x), mat centre (80, 144); row 0 open x 8 (arrow bob), row 1 locked x 1 | - |
| mirror | project/assets/island/mirror.png | tools/gen_village_props.py | single 104x160 (26x40 world px at 4x), foot y 148 | - |
| temple_pavilion | project/assets/island/temple_pavilion.png | tools/gen_village_props.py | single 600x560 (150x140 world px at 4x), foot y 544, door at x 300 | - |
| temple_candles | project/assets/temple/temple_candles.png | tools/gen_temple_props.py | 96x176 frames (24x44 world px at 4x), foot (48, 168); row 0 idle x 4 (flicker); SpriteFrames temple_candles.tres | - |
| temple_cushion | project/assets/temple/temple_cushion.png | tools/gen_temple_props.py | single 120x80 (30x20 world px at 4x), foot y 72 | - |
| temple_plinth | project/assets/temple/temple_plinth.png | tools/gen_temple_props.py | single 128x56 (32x14 world px at 4x), pillar foot y 36 | - |
| temple_shadow | project/assets/temple/temple_shadow.png | tools/gen_temple_props.py | single 96x32 (24x8 world px at 4x) | - |
| temple_twinkle | project/assets/temple/temple_twinkle.png | tools/gen_temple_props.py | 48x48 frames (12x12 world px at 4x), centred; row 0 idle x 6; SpriteFrames temple_twinkle.tres | - |
| temple_urn | project/assets/temple/temple_urn.png | tools/gen_temple_props.py | single 112x144 (28x36 world px at 4x), foot y 136 | - |
| island_tiles | project/assets/tiles/island_tiles.png (+ island_tiles.json index) | tools/gen_island_tiles.py; TileSet island_tileset.tres by tools/build_island_maps.gd | 128x128 cells (32 px map cells at 4x, layers scaled 0.25); row 0 walkable, row 1 blocked + solid, rows 2-3 water / shallows x 4 animation frames, rows 4-8 dual-grid edge overlays (shallows, shore, grass_edge, path_edge, paving_edge) by corner mask 0-15 | - |
