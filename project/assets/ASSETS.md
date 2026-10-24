# Assets

Every art file the game loads, the generator that writes it and how it is laid out. Every
generator runs as `python3 -I tools/<generator>` from the repo root and reproduces its files.
A Gemini render synced to a prompt's `game:` path replaces the stand-in there with no code
change. Rows are sorted by path.

| Path | Id | Generator | Frame layout | Stands in for prompt |
|---|---|---|---|---|
| `project/assets/canon/acc_bow.png` | acc_bow | `tools/cut_paperdoll.py` art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| `project/assets/canon/body_base.png` | body_base | `tools/cut_paperdoll.py` art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| `project/assets/canon/deco_flowers.png` | deco_flowers | `tools/gen_island_deco.py` | single 144x88 (4x of 36x22 world px), foot at bottom | - |
| `project/assets/canon/deco_heart.png` | deco_heart | `tools/cut_island_props.py` (dev/art PERSISTINT overview, crop in project/data/island_props.json) | single 39x39 at source resolution, shown 14 px tall, foot at bottom | - |
| `project/assets/canon/deco_sparkle.png` | deco_sparkle | `tools/cut_island_props.py` (dev/art PERSISTINT overview, crop in project/data/island_props.json) | single 37x41 at source resolution, shown 14 px tall, foot at bottom | - |
| `project/assets/canon/deco_tree_a.png` | deco_tree_a | `tools/gen_island_deco.py` | single 160x208 (4x of 40x52 world px), foot at bottom | - |
| `project/assets/canon/deco_tree_b.png` | deco_tree_b | `tools/gen_island_deco.py` | single 160x208 (4x of 40x52 world px), foot at bottom | - |
| `project/assets/canon/deco_tree_c.png` | deco_tree_c | `tools/gen_island_deco.py` | single 160x208 (4x of 40x52 world px), foot at bottom | - |
| `project/assets/canon/dress_robe.png` | dress_robe | `tools/cut_paperdoll.py` art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| `project/assets/canon/dress_uniform.png` | dress_uniform | `tools/cut_paperdoll.py` art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| `project/assets/canon/dress_white.png` | dress_white | `tools/cut_paperdoll.py` art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| `project/assets/canon/hair_braids.png` | hair_braids | `tools/cut_paperdoll.py` art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| `project/assets/canon/hair_crown.png` | hair_crown | `tools/cut_paperdoll.py` art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| `project/assets/canon/hair_pigtails.png` | hair_pigtails | `tools/cut_paperdoll.py` art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| `project/assets/canon/hair_short.png` | hair_short | `tools/cut_paperdoll.py` art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| `project/assets/canon/npc_barren.png` | npc_barren | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 263x441 canon cut at source resolution, barren NPC front view (the default the game loads) | - |
| `project/assets/canon/npc_barren_back.png` | npc_barren_back | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 263x440 canon cut at source resolution, barren NPC back view | - |
| `project/assets/canon/npc_barren_front.png` | npc_barren_front | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 263x441 canon cut at source resolution, barren NPC front view | - |
| `project/assets/canon/npc_barren_side.png` | npc_barren_side | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 236x441 canon cut at source resolution, barren NPC side view | - |
| `project/assets/canon/npc_drone.png` | npc_drone | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 208x459 canon cut at source resolution, drone NPC front view (the default the game loads) | - |
| `project/assets/canon/npc_drone_back.png` | npc_drone_back | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 206x455 canon cut at source resolution, drone NPC back view | - |
| `project/assets/canon/npc_drone_front.png` | npc_drone_front | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 208x459 canon cut at source resolution, drone NPC front view | - |
| `project/assets/canon/npc_drone_side.png` | npc_drone_side | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 208x454 canon cut at source resolution, drone NPC side view | - |
| `project/assets/canon/npc_initiate.png` | npc_initiate | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 226x441 canon cut at source resolution, initiate NPC front view (the default the game loads) | - |
| `project/assets/canon/npc_initiate_back.png` | npc_initiate_back | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 227x440 canon cut at source resolution, initiate NPC back view | - |
| `project/assets/canon/npc_initiate_front.png` | npc_initiate_front | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 226x441 canon cut at source resolution, initiate NPC front view | - |
| `project/assets/canon/npc_initiate_side.png` | npc_initiate_side | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 194x440 canon cut at source resolution, initiate NPC side view | - |
| `project/assets/canon/npc_mother.png` | npc_mother | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 261x442 canon cut at source resolution, mother NPC front view (the default the game loads) | - |
| `project/assets/canon/npc_mother_back.png` | npc_mother_back | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 249x442 canon cut at source resolution, mother NPC back view | - |
| `project/assets/canon/npc_mother_front.png` | npc_mother_front | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 261x442 canon cut at source resolution, mother NPC front view | - |
| `project/assets/canon/npc_mother_side.png` | npc_mother_side | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 210x443 canon cut at source resolution, mother NPC side view | - |
| `project/assets/canon/npc_priestess.png` | npc_priestess | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 216x437 canon cut at source resolution, priestess NPC front view (the default the game loads) | - |
| `project/assets/canon/npc_priestess_back.png` | npc_priestess_back | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 224x441 canon cut at source resolution, priestess NPC back view | - |
| `project/assets/canon/npc_priestess_front.png` | npc_priestess_front | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 216x437 canon cut at source resolution, priestess NPC front view | - |
| `project/assets/canon/npc_priestess_side.png` | npc_priestess_side | `tools/cut_canon_sprites.sh` (canon caste sheet 4bzs) | 207x439 canon cut at source resolution, priestess NPC side view | - |
| `project/assets/canon/prop_bunker.png` | prop_bunker | `tools/cut_island_props.py` (canon sheet i7kl, crop in project/data/island_props.json) | single 890x790 at source resolution, shown 120 px tall, foot at bottom | - |
| `project/assets/canon/prop_calendar.png` | prop_calendar | `tools/cut_island_props.py` (canon sheet 481b, crop in project/data/island_props.json) | single 764x669 at source resolution, shown 40 px tall, foot at bottom | - |
| `project/assets/canon/prop_fence_a.png` | prop_fence_a | `tools/cut_island_props.py` (canon sheet i7kl, crop in project/data/island_props.json) | single 619x374 at source resolution, shown 34 px tall, foot at bottom | - |
| `project/assets/canon/prop_fence_b.png` | prop_fence_b | `tools/cut_island_props.py` (canon sheet i7kl, crop in project/data/island_props.json) | single 612x364 at source resolution, shown 34 px tall, foot at bottom | - |
| `project/assets/canon/prop_icon_queen_mother.png` | prop_icon_queen_mother | `tools/cut_island_props.py` (dev/art PERSISTINT overview, crop in project/data/island_props.json) | single 269x293 at source resolution, shown 72 px tall, foot at bottom | - |
| `project/assets/canon/prop_pillar_orb.png` | prop_pillar_orb | `tools/cut_island_props.py` (dev/art PERSISTINT overview, crop in project/data/island_props.json) | single 153x280 at source resolution, shown 64 px tall, foot at bottom | - |
| `project/assets/canon/prop_scroll.png` | prop_scroll | `tools/cut_canon_sprites.sh` (canon sheet 481b) | 792x651 canon cut at source resolution, shown 18 world px tall as a pickup icon | - |
| `project/assets/canon/prop_seal_o.png` | prop_seal_o | `tools/cut_island_props.py` (dev/art PERSISTINT overview, crop in project/data/island_props.json) | single 180x170 at source resolution, shown 36 px tall, foot at bottom | - |
| `project/assets/canon/prop_ship.png` | prop_ship | `tools/cut_island_props.py` (canon sheet i7kl, crop in project/data/island_props.json) | single 1305x871 at source resolution, shown 150 px tall, foot at bottom | - |
| `project/assets/canon/prop_sign_a.png` | prop_sign_a | `tools/cut_island_props.py` (canon sheet i7kl, crop in project/data/island_props.json) | single 433x510 at source resolution, shown 48 px tall, foot at bottom | - |
| `project/assets/canon/prop_sign_b.png` | prop_sign_b | `tools/cut_island_props.py` (canon sheet i7kl, crop in project/data/island_props.json) | single 391x516 at source resolution, shown 48 px tall, foot at bottom | - |
| `project/assets/canon/prop_skull_altar.png` | prop_skull_altar | `tools/cut_island_props.py` (dev/art PERSISTINT overview, crop in project/data/island_props.json) | single 171x216 at source resolution, shown 48 px tall, foot at bottom | - |
| `project/assets/canon/prop_tag_x.png` | prop_tag_x | `tools/cut_island_props.py` (canon sheet 481b, crop in project/data/island_props.json) | single 510x672 at source resolution, shown 36 px tall, foot at bottom | - |
| `project/assets/characters/npc_barren_rig.png` | npc_barren_rig | `tools/gen_npc_rigs.py` (from the full-resolution canon cuts) | 8x3 frames of 294x478 (32x52 world px, feet at 50/52); rows down / left / up; cols 0-3 idle, 4-7 walk | - |
| `project/assets/characters/npc_drone_rig.png` | npc_drone_rig | `tools/gen_npc_rigs.py` (from the full-resolution canon cuts) | 8x3 frames of 306x497 (32x52 world px, feet at 50/52); rows down / left / up; cols 0-3 idle, 4-7 walk | - |
| `project/assets/characters/npc_initiate_rig.png` | npc_initiate_rig | `tools/gen_npc_rigs.py` (from the full-resolution canon cuts) | 8x3 frames of 294x478 (32x52 world px, feet at 50/52); rows down / left / up; cols 0-3 idle, 4-7 walk | - |
| `project/assets/characters/npc_mother_rig.png` | npc_mother_rig | `tools/gen_npc_rigs.py` (from the full-resolution canon cuts) | 8x3 frames of 295x480 (32x52 world px, feet at 50/52); rows down / left / up; cols 0-3 idle, 4-7 walk | - |
| `project/assets/characters/npc_priestess_rig.png` | npc_priestess_rig | `tools/gen_npc_rigs.py` (from the full-resolution canon cuts) | 8x3 frames of 294x478 (32x52 world px, feet at 50/52); rows down / left / up; cols 0-3 idle, 4-7 walk | - |
| `project/assets/common/door_marker.png` | door_marker | `tools/gen_door_marker.py` | 160x192 frames (40x48 world px at 4x), mat centre (80, 144); row 0 open x 8 (arrow bob), row 1 locked x 1 | - |
| `project/assets/florida/acc_bougainvillea_wreath.png` | acc_bougainvillea_wreath | `tools/gen_florida_wearables.py` (on the canon paper-doll frame) | still, 721x760 canon paper-doll frame (sheet resolution) | - |
| `project/assets/florida/acc_flower_crown.png` | acc_flower_crown | `tools/gen_florida_wearables.py` (on the canon paper-doll frame) | still, 721x760 canon paper-doll frame (sheet resolution) | - |
| `project/assets/florida/acc_plumeria_lei.png` | acc_plumeria_lei | `tools/gen_florida_wearables.py` (on the canon paper-doll frame) | still, 721x760 canon paper-doll frame (sheet resolution) | - |
| `project/assets/florida/acc_shell_garland.png` | acc_shell_garland | `tools/gen_florida_wearables.py` (on the canon paper-doll frame) | still, 721x760 canon paper-doll frame (sheet resolution) | - |
| `project/assets/florida/bg_florida_aquarium.png` | bg_florida_aquarium | `tools/gen_florida_art.py` (pool floor shells: canon shell_scallop/conch/spiral from project/data/florida_canon.json, cut at sheet resolution) | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/bg_florida_beach.png` | bg_florida_beach | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25; the surf on its water line is sea_foam | - |
| `project/assets/florida/bg_florida_garden.png` | bg_florida_garden | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/bg_florida_stable.png` | bg_florida_stable | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/crab.png (+ crab.tres) | crab | `tools/gen_florida_critters.py` | 24x18 world px (96x72 texture); row 0 idle, row 1 walk, 4 cols; .tres idle/walk; .tres metadata display_scale 0.25 | - |
| `project/assets/florida/craft_bench.png` | craft_bench | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/dolphin.png (+ dolphin.tres) | dolphin | `tools/gen_florida_critters.py` | 48x32 world px (192x128 texture); row 0 idle, row 1 walk (swim), 4 cols; .tres idle/walk; .tres metadata display_scale 0.25 | - |
| project/assets/florida/fish.png (+ fish.tres) | fish | `tools/gen_florida_art.py` | 16x12 world px (64x48 texture); rows coral/mango/lilac, cols 0-2 swim, 3 wave; .tres swim_*/wave_*; .tres metadata display_scale 0.25 | - |
| project/assets/florida/gull.png (+ gull.tres) | gull | `tools/gen_florida_critters.py` | 24x24 world px (96x96 texture); row 0 idle, row 1 walk (hop), 4 cols; .tres idle/walk; .tres metadata display_scale 0.25 | - |
| project/assets/florida/mermaid.png (+ mermaid.tres) | mermaid | `tools/gen_florida_cast.py` (on the canon body turnaround, sheet ekiw) | 36x50 world px (144x200 texture); row 0 idle, row 1 walk (swim), 4 cols; .tres idle/walk; .tres metadata display_scale 0.25 | - |
| project/assets/florida/npc_daughter.png (+ npc_daughter.tres) | npc_daughter | `tools/gen_florida_cast.py` (on the canon body turnaround, sheet ekiw) | 32x52 world px (128x208 texture); rows front/side/back, 4 idle cols; .tres idle_front/side/back; .tres metadata display_scale 0.25 | - |
| project/assets/florida/npc_father.png (+ npc_father.tres) | npc_father | `tools/gen_florida_cast.py` (on the canon body turnaround, sheet ekiw) | 36x62 world px (144x248 texture); rows front/side/back, 4 idle cols; .tres idle_front/side/back; .tres metadata display_scale 0.25 | - |
| project/assets/florida/npc_stable_friend.png (+ npc_stable_friend.tres) | npc_stable_friend | `tools/gen_florida_cast.py` (on the canon body turnaround, sheet ekiw) | 32x52 world px (128x208 texture); rows front/side/back, 4 idle cols; .tres idle_front/side/back; .tres metadata display_scale 0.25 | - |
| `project/assets/florida/plot_empty.png` | plot_empty | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/plot_growing.png` | plot_growing | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/plot_ready_bougainvillea.png` | plot_ready_bougainvillea | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/plot_ready_coconut.png` | plot_ready_coconut | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/plot_ready_guava.png` | plot_ready_guava | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/plot_ready_hibiscus.png` | plot_ready_hibiscus | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/plot_ready_key_lime.png` | plot_ready_key_lime | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/plot_ready_mango.png` | plot_ready_mango | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/plot_ready_plumeria.png` | plot_ready_plumeria | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/plot_ready_sea_grape.png` | plot_ready_sea_grape | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/pony_acc_blanket.png` | pony_acc_blanket | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_acc_bow.png` | pony_acc_bow | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_acc_flower_crown.png` | pony_acc_flower_crown | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_acc_hibiscus.png` | pony_acc_hibiscus | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_body_cloud.png` | pony_body_cloud | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_body_honey.png` | pony_body_honey | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_body_lilac.png` | pony_body_lilac | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_body_mint.png` | pony_body_mint | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_body_peach.png` | pony_body_peach | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_mane_braids_lavender.png` | pony_mane_braids_lavender | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_mane_braids_rose.png` | pony_mane_braids_rose | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_mane_braids_sky.png` | pony_mane_braids_sky | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_mane_braids_sunshine.png` | pony_mane_braids_sunshine | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_mane_curly_lavender.png` | pony_mane_curly_lavender | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_mane_curly_rose.png` | pony_mane_curly_rose | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_mane_curly_sky.png` | pony_mane_curly_sky | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_mane_curly_sunshine.png` | pony_mane_curly_sunshine | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_mane_flowing_lavender.png` | pony_mane_flowing_lavender | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_mane_flowing_rose.png` | pony_mane_flowing_rose | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_mane_flowing_sky.png` | pony_mane_flowing_sky | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_mane_flowing_sunshine.png` | pony_mane_flowing_sunshine | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_sparkle.png` | pony_sparkle | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/pony_spots.png` | pony_spots | `tools/gen_pony_sprites.py` | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| `project/assets/florida/prop_aquarium.png` | prop_aquarium | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_barn.png` | prop_barn | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_bench.png` | prop_bench | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_birdbath.png` | prop_birdbath | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_bush_bougainvillea.png` | prop_bush_bougainvillea | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_bush_hibiscus.png` | prop_bush_hibiscus | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_dune_grass.png` | prop_dune_grass | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_fence_paddock.png` | prop_fence_paddock | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_fence_picket.png` | prop_fence_picket | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_garden_arch.png` | prop_garden_arch | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_hay.png` | prop_hay | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_house.png` | prop_house | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_palm_a.png` | prop_palm_a | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_palm_b.png` | prop_palm_b | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_palm_potted.png` | prop_palm_potted | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_rowboat.png` | prop_rowboat | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_sandcastle.png` | prop_sandcastle | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_sign_stable.png` | prop_sign_stable | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_tree_key_lime.png` | prop_tree_key_lime | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_tree_mango.png` | prop_tree_mango | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_trough.png` | prop_trough | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/prop_umbrella.png` | prop_umbrella | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/sea_foam.png (+ sea_foam.tres) | sea_foam | `tools/gen_florida_art.py` | sheet, frame 960x120 world px (3840x480 texture), one frame per row, rows 0-5; .tres lap (rows 0-5 at 5 fps, loop), metadata display_scale 0.25; AnimatedSprite2D at world (0, 180) in beach.tscn, top-left anchor, scale 0.25 | - |
| `project/assets/florida/seed_bag.png` | seed_bag | `tools/gen_florida_art.py` | still, 4 texture px per world px; scenes scale 0.25 | - |
| `project/assets/florida/shell_conch.png` | shell_conch | `tools/cut_island_props.py` project/data/florida_canon.json (canon tide scroll, sheet 481b) | still, canon sheet resolution; shown 11 world px tall | - |
| `project/assets/florida/shell_scallop.png` | shell_scallop | `tools/cut_island_props.py` project/data/florida_canon.json (canon tide scroll, sheet 481b) | still, canon sheet resolution; shown 11 world px tall | - |
| `project/assets/florida/shell_spiral.png` | shell_spiral | `tools/cut_island_props.py` project/data/florida_canon.json (canon tide scroll, sheet 481b) | still, canon sheet resolution; shown 11 world px tall | - |
| `project/assets/island/mirror.png` | mirror | `tools/gen_village_props.py` | single 104x160 (26x40 world px at 4x), foot y 148 | - |
| `project/assets/island/temple_pavilion.png` | temple_pavilion | `tools/gen_village_props.py` | single 600x560 (150x140 world px at 4x), foot y 544, door at x 300 | - |
| `project/assets/ruins/clone_bill_clinton.png` | clone_bill_clinton | `tools/gen_clone_children.py` | 192x272 frames (24x34 world px); rows front/side(right; flip for left)/back; cols 0-1 idle, 2-5 walk; scale 1/8, SpriteFrames via scripts/ruins/sheet_rig.gd | - |
| `project/assets/ruins/clone_bill_gates.png` | clone_bill_gates | `tools/gen_clone_children.py` | 192x272 frames (24x34 world px); rows front/side(right; flip for left)/back; cols 0-1 idle, 2-5 walk; scale 1/8, SpriteFrames via scripts/ruins/sheet_rig.gd | - |
| `project/assets/ruins/clone_epstein.png` | clone_epstein | `tools/gen_clone_children.py` | 192x272 frames (24x34 world px); rows front/side(right; flip for left)/back; cols 0-1 idle, 2-5 walk; scale 1/8, SpriteFrames via scripts/ruins/sheet_rig.gd | - |
| `project/assets/ruins/clone_hillary_clinton.png` | clone_hillary_clinton | `tools/gen_clone_children.py` | 192x272 frames (24x34 world px); rows front/side(right; flip for left)/back; cols 0-1 idle, 2-5 walk; scale 1/8, SpriteFrames via scripts/ruins/sheet_rig.gd | - |
| `project/assets/ruins/clone_polar_bear.png` | clone_polar_bear | `tools/gen_clone_children.py` | 192x176 frames (24x22 world px); rows front/side/back (cols 0-1 idle, 2-5 walk), row3 smeared idle 0-1 + chomp 2-3, row4 nap 0-1; scale 1/8 | - |
| `project/assets/ruins/glow.png` | glow | `tools/gen_ruins_art.py` | 256x256 pickup glow, scale 0.15 | - |
| `project/assets/ruins/gore_bone.png` | gore_bone | `tools/gen_clone_children.py` | 96x48 still, scale 0.1875 | - |
| `project/assets/ruins/gore_chunk.png` | gore_chunk | `tools/gen_clone_children.py` | 80x80 still, scale 0.1875 | - |
| `project/assets/ruins/gore_drop.png` | gore_drop | `tools/gen_clone_children.py` | 48x64 still, splatter droplet, particle texture of the pounce spray (scripts/ruins/clone_lab.gd fits it to ~4 world px) | - |
| `project/assets/ruins/gore_puddle.png` | gore_puddle | `tools/gen_clone_children.py` | 256x112 still, scale 0.1875 | - |
| `project/assets/ruins/gore_puff.png` | gore_puff | `tools/gen_clone_children.py` | 80x72 still, clone-dust puff, particle texture of an eaten clone's poof (scripts/ruins/zombie_child.gd fits it to ~6 world px) | - |
| `project/assets/ruins/icon_appendix.png` | icon_appendix | `tools/gen_ruins_art.py` | 160x160 Forbidden Knowledge pickup icon, scale 1/8 | - |
| `project/assets/ruins/icon_board.png` | icon_board | `tools/gen_ruins_art.py` | 160x160 Forbidden Knowledge pickup icon, scale 1/8 | - |
| `project/assets/ruins/icon_book.png` | icon_book | `tools/gen_ruins_art.py` | 160x160 Forbidden Knowledge pickup icon, scale 1/8 | - |
| `project/assets/ruins/icon_chart.png` | icon_chart | `tools/gen_ruins_art.py` | 160x160 Forbidden Knowledge pickup icon, scale 1/8 | - |
| `project/assets/ruins/icon_ledger.png` | icon_ledger | `tools/gen_ruins_art.py` | 160x160 Forbidden Knowledge pickup icon, scale 1/8 | - |
| `project/assets/ruins/icon_paper.png` | icon_paper | `tools/gen_ruins_art.py` | 160x160 Forbidden Knowledge pickup icon, scale 1/8 | - |
| `project/assets/ruins/icon_proposal.png` | icon_proposal | `tools/gen_ruins_art.py` | 160x160 Forbidden Knowledge pickup icon, scale 1/8 | - |
| `project/assets/ruins/icon_thermometer.png` | icon_thermometer | `tools/gen_ruins_art.py` | 160x160 Forbidden Knowledge pickup icon, scale 1/8 | - |
| `project/assets/ruins/ruins_altar_desk.png` | ruins_altar_desk | `tools/gen_ruins_art.py` | 720x416 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_barrel.png` | ruins_barrel | `tools/gen_ruins_art.py` | 224x304 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_binders_a.png` | ruins_binders_a | `tools/gen_ruins_art.py` | 992x672 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_binders_b.png` | ruins_binders_b | `tools/gen_ruins_art.py` | 992x672 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_binders_c.png` | ruins_binders_c | `tools/gen_ruins_art.py` | 992x672 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_buffet.png` | ruins_buffet | `tools/gen_ruins_art.py` | 672x352 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_bunting.png` | ruins_bunting | `tools/gen_ruins_art.py` | 960x160 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_cables.png` | ruins_cables | `tools/gen_ruins_art.py` | 560x160 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_candles.png` | ruins_candles | `tools/gen_ruins_art.py` | 368x256 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_centrifuge.png` | ruins_centrifuge | `tools/gen_ruins_art.py` | 384x336 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_chair_tipped.png` | ruins_chair_tipped | `tools/gen_ruins_art.py` | 320x192 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_coat_hooks.png` | ruins_coat_hooks | `tools/gen_ruins_art.py` | 672x400 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_crates.png` | ruins_crates | `tools/gen_ruins_art.py` | 448x352 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_crew_sign.png` | ruins_crew_sign | `tools/gen_ruins_art.py` | 576x176 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_cub_basket.png` | ruins_cub_basket | `tools/gen_ruins_art.py` | 480x240 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_deck_chairs.png` | ruins_deck_chairs | `tools/gen_ruins_art.py` | 608x320 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_desk_lamp.png` | ruins_desk_lamp | `tools/gen_ruins_art.py` | 624x432 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_failed_drawer.png` | ruins_failed_drawer | `tools/gen_ruins_art.py` | 528x336 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_filing_cabinet.png` | ruins_filing_cabinet | `tools/gen_ruins_art.py` | 352x576 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_floor_hatch.png` | ruins_floor_hatch | `tools/gen_ruins_art.py` | 416x224 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_freezer.png` | ruins_freezer | `tools/gen_ruins_art.py` | 368x544 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_gift_shop.png` | ruins_gift_shop | `tools/gen_ruins_art.py` | 992x688 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_hazard_band.png` | ruins_hazard_band | `tools/gen_ruins_art.py` | 832x208 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_ice_swan.png` | ruins_ice_swan | `tools/gen_ruins_art.py` | 448x352 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_incubator.png` | ruins_incubator | `tools/gen_ruins_art.py` | 528x416 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_intercom.png` | ruins_intercom | `tools/gen_ruins_art.py` | 304x336 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_lab_cart.png` | ruins_lab_cart | `tools/gen_ruins_art.py` | 352x320 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_life_ring.png` | ruins_life_ring | `tools/gen_ruins_art.py` | 240x240 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_lifeboat.png` | ruins_lifeboat | `tools/gen_ruins_art.py` | 928x448 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_lift_cage.png` | ruins_lift_cage | `tools/gen_ruins_art.py` | 640x800 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_mop_bucket.png` | ruins_mop_bucket | `tools/gen_ruins_art.py` | 240x272 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_offering.png` | ruins_offering | `tools/gen_ruins_art.py` | 272x160 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_papers.png` | ruins_papers | `tools/gen_ruins_art.py` | 352x176 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_pipes.png` | ruins_pipes | `tools/gen_ruins_art.py` | 2400x192 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_pipes_striped.png` | ruins_pipes_striped | `tools/gen_ruins_art.py` | 2080x192 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_plant.png` | ruins_plant | `tools/gen_ruins_art.py` | 240x352 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_porthole.png` | ruins_porthole | `tools/gen_ruins_art.py` | 240x240 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_portrait.png` | ruins_portrait | `tools/gen_ruins_art.py` | 352x416 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_poster.png` | ruins_poster | `tools/gen_ruins_art.py` | 272x352 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_prep_bench.png` | ruins_prep_bench | `tools/gen_ruins_art.py` | 800x320 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_puddle.png` | ruins_puddle | `tools/gen_ruins_art.py` | 320x128 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_runner.png` | ruins_runner | `tools/gen_ruins_art.py` | 1600x176 still, scale 1/8, painted flat on the floor | - |
| `project/assets/ruins/ruins_sequencer.png` | ruins_sequencer | `tools/gen_ruins_art.py` | 448x368 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_server_rack.png` | ruins_server_rack | `tools/gen_ruins_art.py` | 416x688 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_slots.png` | ruins_slots | `tools/gen_ruins_art.py` | 672x560 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_stationery.png` | ruins_stationery | `tools/gen_ruins_art.py` | 448x368 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_tank.png` | ruins_tank | `tools/gen_ruins_art.py` | 1 row x 4 frames of 352x688 (bubbles, blinking light), 6 fps, scale 1/8 | - |
| `project/assets/ruins/ruins_tank_duck.png` | ruins_tank_duck | `tools/gen_ruins_art.py` | 1 row x 4 frames of 352x688 (bubbles, blinking light), 6 fps, scale 1/8 | - |
| `project/assets/ruins/ruins_tiles.png` | ruins_tiles | `tools/gen_ruins_art.py` | atlas 7x6 of 256x256 (32x32 world px, TileMapLayer scale 1/8): row0 floors deck/grate/plate/concrete/lab/carpet+void, row1 floor details+lip, row2 wall caps hull/service/core/bunker/lab/archive+edge shadow, row3 panels+hazard, row4 accent stripe, row5 skirting | - |
| `project/assets/ruins/ruins_tileset.tres` | ruins_tileset | `tools/gen_ruins_art.py` | TileSet: one atlas source over ruins_tiles.png (256x256 cells), every cell a tile | - |
| `project/assets/ruins/ruins_towel_trolley.png` | ruins_towel_trolley | `tools/gen_ruins_art.py` | 416x352 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/ruins_vending.png` | ruins_vending | `tools/gen_ruins_art.py` | 384x592 still, scale 1/8, feet at bottom centre | - |
| `project/assets/ruins/vignette.png` | vignette | `tools/gen_ruins_art.py` | 1280x720 screen overlay, linear filter | - |
| `project/assets/temple/temple_candles.png` | temple_candles | `tools/gen_temple_props.py` | 96x176 frames (24x44 world px at 4x), foot (48, 168); row 0 idle x 4 (flicker); SpriteFrames temple_candles.tres | - |
| `project/assets/temple/temple_cushion.png` | temple_cushion | `tools/gen_temple_props.py` | single 120x80 (30x20 world px at 4x), foot y 72 | - |
| `project/assets/temple/temple_plinth.png` | temple_plinth | `tools/gen_temple_props.py` | single 128x56 (32x14 world px at 4x), pillar foot y 36 | - |
| `project/assets/temple/temple_shadow.png` | temple_shadow | `tools/gen_temple_props.py` | single 96x32 (24x8 world px at 4x) | - |
| `project/assets/temple/temple_twinkle.png` | temple_twinkle | `tools/gen_temple_props.py` | 48x48 frames (12x12 world px at 4x), centred; row 0 idle x 6; SpriteFrames temple_twinkle.tres | - |
| `project/assets/temple/temple_urn.png` | temple_urn | `tools/gen_temple_props.py` | single 112x144 (28x36 world px at 4x), foot y 136 | - |
| project/assets/tiles/island_tiles.png (+ island_tiles.json index) | island_tiles | `tools/gen_island_tiles.py`; TileSet island_tileset.tres by tools/build_island_maps.gd | 4096 px wide (32 columns) of 128x128 cells (32 px map cells at 4x, layers scaled 0.25): walkable cells, then their blocked copies and the solid tiles, then water / foam strips of 4 animation frames, then dual-grid edge overlays (shallows, shore, grass_edge, path_edge, paving_edge) of 16 corner-mask cells each; every position is in the json index | - |
| `project/assets/ui/backdrops/comedy_stage.png` | comedy_stage | `tools/gen_ui_art.py` | static; Next Top Comic backdrop, 2560x1440 (4x the 640x360 viewport) | - |
| `project/assets/ui/backdrops/fog_sea.png` | fog_sea | `tools/gen_ui_art.py` | static; The Landing backdrop, 2560x1440 (4x the 640x360 viewport) | - |
| `project/assets/ui/backdrops/runway.png` | runway | `tools/gen_ui_art.py` | static; Hottest of the HOT backdrop, 2560x1440 (4x the 640x360 viewport) | - |
| `project/assets/ui/backdrops/ship_cabin.png` | ship_cabin | `tools/gen_ui_art.py` | static; get-ready chains backdrop, 2560x1440 (4x the 640x360 viewport) | - |
| `project/assets/ui/backdrops/ship_cutaway.png` | ship_cutaway | `tools/gen_ui_art.py` | static; The Landing station map, 2400x600 (4x its 600x150 on-screen size) | - |
| `project/assets/ui/backdrops/talk_show_set.png` | talk_show_set | `tools/gen_ui_art.py` | static; The Interview backdrop, 2560x1440 (4x the 640x360 viewport) | - |
| `project/assets/ui/backdrops/temple_altar.png` | temple_altar | `tools/gen_ui_art.py` | static; ritual puzzle backdrop, 2560x1440 (4x the 640x360 viewport) (canon prop_pillar_orb) | - |
| `project/assets/ui/brand/boot_splash.png` | boot_splash | `tools/gen_brand_art.py` | static; 1280x720 transparent, the wordmark over a heart on the cream boot splash colour (application/boot_splash/image) | - |
| `project/assets/ui/brand/gnpng_pingpong.png` | gnpng_pingpong | `tools/gen_imprint_mark.py` (the site's G\|P\|G pong badge, art/brand/gnpng-pingpong-badge.svg, in Fredoka) | static; 768x304 still (4x the 192x76 viewBox), the rally at t = 0 | - |
| `project/assets/ui/brand/gnpng_pingpong_sheet.png` | gnpng_pingpong_sheet | `tools/gen_imprint_mark.py` | 6x6 frames of 384x152, 36 frames, animation idle (the rally) 12 fps looping; scripts/ui/imprint_mark.gd | - |
| `project/assets/ui/chapter_cards/chapter_card_before_the_wreck.png` | chapter_card_before_the_wreck | `tools/gen_ui_art.py` (stand-in) | static; 2560x1440 (4x the 640x360 viewport), white gold-trimmed ship low right, clear of the centred lines, behind chapter_end and flashback_card text | `prompts/image/ui/chapter_cards/chapter_card_before_the_wreck.md` |
| `project/assets/ui/chrome/altar_tile_gold.png` | altar_tile_gold | `tools/gen_ui_art.py` | static; ritual puzzle altar tile, gold (9-slice, margin 7) | - |
| `project/assets/ui/chrome/altar_tile_rose.png` | altar_tile_rose | `tools/gen_ui_art.py` | static; ritual puzzle altar tile, rose (9-slice, margin 7) | - |
| `project/assets/ui/chrome/altar_tile_selected.png` | altar_tile_selected | `tools/gen_ui_art.py` | static; ritual puzzle altar tile, selected (9-slice, margin 7) | - |
| `project/assets/ui/chrome/altar_tile_sky.png` | altar_tile_sky | `tools/gen_ui_art.py` | static; ritual puzzle altar tile, sky (9-slice, margin 7) | - |
| `project/assets/ui/chrome/bar_bg.png` | bar_bg | `tools/gen_ui_art.py` | static; ProgressBar background (9-slice, margin 4) | - |
| `project/assets/ui/chrome/bar_fill.png` | bar_fill | `tools/gen_ui_art.py` | static; ProgressBar fill (9-slice, margin 4) | - |
| `project/assets/ui/chrome/bubble.png` | bubble | `tools/gen_ui_art.py` | static; BarkBubble speech bubble (9-slice, margin 6) | - |
| `project/assets/ui/chrome/bubble_tail.png` | bubble_tail | `tools/gen_ui_art.py` | static; speech bubble tail under BarkBubble | - |
| `project/assets/ui/chrome/button_disabled.png` | button_disabled | `tools/gen_ui_art.py` | static; Button disabled (9-slice, margin 5) | - |
| `project/assets/ui/chrome/button_focus.png` | button_focus | `tools/gen_ui_art.py` | static; Button focus ring (9-slice, margin 5) | - |
| `project/assets/ui/chrome/button_hover.png` | button_hover | `tools/gen_ui_art.py` | static; Button hover (9-slice, margin 5) | - |
| `project/assets/ui/chrome/button_normal.png` | button_normal | `tools/gen_ui_art.py` | static; Button normal (9-slice, margin 5) | - |
| `project/assets/ui/chrome/button_pressed.png` | button_pressed | `tools/gen_ui_art.py` | static; Button pressed (9-slice, margin 5) | - |
| `project/assets/ui/chrome/continue_heart.png` | continue_heart | `tools/gen_ui_art.py` | static; dialogue 'more' indicator, bobbed by AnimationPlayer in dialogue_balloon.tscn | - |
| `project/assets/ui/chrome/dialogue.png` | dialogue | `tools/gen_ui_art.py` | static; DialoguePanel box (9-slice, margin 11, tiled) | - |
| `project/assets/ui/chrome/nametag.png` | nametag | `tools/gen_ui_art.py` | static; NameTag speaker tag (9-slice, margin 6) | - |
| `project/assets/ui/chrome/panel.png` | panel | `tools/gen_ui_art.py` | static; Panel / PanelContainer / HudPanel / tooltip (9-slice, margin 7) | - |
| `project/assets/ui/chrome/ribbon.png` | ribbon | `tools/gen_ui_art.py` | static; HeaderLabel ribbon (9-slice, margins 6/4) | - |
| `project/assets/ui/chrome/scroll_bg.png` | scroll_bg | `tools/gen_ui_art.py` | static; VScrollBar track (9-slice, margin 3) | - |
| `project/assets/ui/chrome/scroll_grabber.png` | scroll_grabber | `tools/gen_ui_art.py` | static; VScrollBar grabber (9-slice, margin 3) | - |
| `project/assets/ui/icon/app_icon.png` | app_icon | `tools/gen_brand_art.py` | static; 1024x1024, the striped gold-domed temple on an island under a heart (application/config/icon) | `prompts/image/ui/icon/app_icon.md` |
| `project/assets/ui/title/title_screen.png` | title_screen | `tools/gen_brand_art.py` | static; 2560x1440, title_screen_plain with the wordmark at the top | `prompts/image/ui/title/title_screen.md` |
| `project/assets/ui/title/title_screen_plain.png` | title_screen_plain | `tools/gen_ui_art.py` (stand-in; composes canon prop_ship, prop_bunker, deco_*) | static; 2560x1440 (4x the 640x360 viewport), main menu background | `prompts/image/ui/title/title_screen_plain.md` |
| `project/assets/ui/title/wordmark.png` | wordmark | `tools/gen_brand_art.py` (Fredoka, art/brand/fonts) | static; 1600x270 transparent, PERSISTINT in bubbly pastel letters (STYLE.md 4.8); main menu | - |
