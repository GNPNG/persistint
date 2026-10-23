# Asset register

One row per game asset: id, path, the generator that writes it, frame layout for rigged
sheets, and the prompts/ render it stands in for (if any). Re-run the generator to reproduce
the file. Sorted by path.

| Path | Id | Generator | Frame layout | Stands in for |
|---|---|---|---|---|
| project/assets/florida/bg_florida_aquarium.png | bg_florida_aquarium | tools/gen_florida_art.py | still | - |
| project/assets/florida/bg_florida_beach.png | bg_florida_beach | tools/gen_florida_art.py | still | - |
| project/assets/florida/bg_florida_garden.png | bg_florida_garden | tools/gen_florida_art.py | still | - |
| project/assets/florida/bg_florida_stable.png | bg_florida_stable | tools/gen_florida_art.py | still | - |
| project/assets/florida/crab.png (+ crab.tres) | crab | tools/gen_florida_critters.py | 24x18; row 0 idle, row 1 walk, 4 cols; .tres idle/walk | - |
| project/assets/florida/craft_bench.png | craft_bench | tools/gen_florida_art.py | still | - |
| project/assets/florida/dolphin.png (+ dolphin.tres) | dolphin | tools/gen_florida_critters.py | 48x32; row 0 idle, row 1 walk (swim), 4 cols; .tres idle/walk | - |
| project/assets/florida/fish.png (+ fish.tres) | fish | tools/gen_florida_art.py | 16x12; rows coral/mango/lilac, cols 0-2 swim, 3 wave; .tres swim_*/wave_* | - |
| project/assets/florida/gull.png (+ gull.tres) | gull | tools/gen_florida_critters.py | 24x24; row 0 idle, row 1 walk (hop), 4 cols; .tres idle/walk | - |
| project/assets/florida/mermaid.png (+ mermaid.tres) | mermaid | tools/gen_florida_cast.py (on the canon body turnaround, sheet ekiw) | 36x50; row 0 idle, row 1 walk (swim), 4 cols; .tres idle/walk | - |
| project/assets/florida/npc_daughter.png (+ npc_daughter.tres) | npc_daughter | tools/gen_florida_cast.py (on the canon body turnaround, sheet ekiw) | 32x52; rows front/side/back, 4 idle cols; .tres idle_front/side/back | - |
| project/assets/florida/npc_father.png (+ npc_father.tres) | npc_father | tools/gen_florida_cast.py (on the canon body turnaround, sheet ekiw) | 36x62; rows front/side/back, 4 idle cols; .tres idle_front/side/back | - |
| project/assets/florida/npc_stable_friend.png (+ npc_stable_friend.tres) | npc_stable_friend | tools/gen_florida_cast.py (on the canon body turnaround, sheet ekiw) | 32x52; rows front/side/back, 4 idle cols; .tres idle_front/side/back | - |
| project/assets/florida/plot_empty.png | plot_empty | tools/gen_florida_art.py | still | - |
| project/assets/florida/plot_growing.png | plot_growing | tools/gen_florida_art.py | still | - |
| project/assets/florida/plot_ready_bougainvillea.png | plot_ready_bougainvillea | tools/gen_florida_art.py | still | - |
| project/assets/florida/plot_ready_coconut.png | plot_ready_coconut | tools/gen_florida_art.py | still | - |
| project/assets/florida/plot_ready_guava.png | plot_ready_guava | tools/gen_florida_art.py | still | - |
| project/assets/florida/plot_ready_hibiscus.png | plot_ready_hibiscus | tools/gen_florida_art.py | still | - |
| project/assets/florida/plot_ready_key_lime.png | plot_ready_key_lime | tools/gen_florida_art.py | still | - |
| project/assets/florida/plot_ready_mango.png | plot_ready_mango | tools/gen_florida_art.py | still | - |
| project/assets/florida/plot_ready_plumeria.png | plot_ready_plumeria | tools/gen_florida_art.py | still | - |
| project/assets/florida/plot_ready_sea_grape.png | plot_ready_sea_grape | tools/gen_florida_art.py | still | - |
| project/assets/florida/pony_acc_blanket.png | pony_acc_blanket | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_acc_bow.png | pony_acc_bow | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_acc_flower_crown.png | pony_acc_flower_crown | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_acc_hibiscus.png | pony_acc_hibiscus | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_body_cloud.png | pony_body_cloud | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_body_honey.png | pony_body_honey | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_body_lilac.png | pony_body_lilac | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_body_mint.png | pony_body_mint | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_body_peach.png | pony_body_peach | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_braids_lavender.png | pony_mane_braids_lavender | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_braids_rose.png | pony_mane_braids_rose | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_braids_sky.png | pony_mane_braids_sky | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_braids_sunshine.png | pony_mane_braids_sunshine | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_curly_lavender.png | pony_mane_curly_lavender | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_curly_rose.png | pony_mane_curly_rose | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_curly_sky.png | pony_mane_curly_sky | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_curly_sunshine.png | pony_mane_curly_sunshine | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_flowing_lavender.png | pony_mane_flowing_lavender | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_flowing_rose.png | pony_mane_flowing_rose | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_flowing_sky.png | pony_mane_flowing_sky | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_flowing_sunshine.png | pony_mane_flowing_sunshine | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_sparkle.png | pony_sparkle | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_spots.png | pony_spots | tools/gen_pony_sprites.py | 64x52; 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/prop_aquarium.png | prop_aquarium | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_barn.png | prop_barn | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_bench.png | prop_bench | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_birdbath.png | prop_birdbath | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_bush_bougainvillea.png | prop_bush_bougainvillea | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_bush_hibiscus.png | prop_bush_hibiscus | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_dune_grass.png | prop_dune_grass | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_fence_paddock.png | prop_fence_paddock | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_fence_picket.png | prop_fence_picket | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_garden_arch.png | prop_garden_arch | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_hay.png | prop_hay | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_house.png | prop_house | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_palm_a.png | prop_palm_a | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_palm_b.png | prop_palm_b | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_palm_potted.png | prop_palm_potted | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_rowboat.png | prop_rowboat | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_sandcastle.png | prop_sandcastle | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_sign_stable.png | prop_sign_stable | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_tree_key_lime.png | prop_tree_key_lime | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_tree_mango.png | prop_tree_mango | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_trough.png | prop_trough | tools/gen_florida_art.py | still | - |
| project/assets/florida/prop_umbrella.png | prop_umbrella | tools/gen_florida_art.py | still | - |
| project/assets/florida/seed_bag.png | seed_bag | tools/gen_florida_art.py | still | - |
| project/assets/florida/shell_conch.png | shell_conch | tools/cut_island_props.py project/data/florida_canon.json (canon tide scroll, sheet 481b) | still | - |
| project/assets/florida/shell_scallop.png | shell_scallop | tools/cut_island_props.py project/data/florida_canon.json (canon tide scroll, sheet 481b) | still | - |
| project/assets/florida/shell_spiral.png | shell_spiral | tools/cut_island_props.py project/data/florida_canon.json (canon tide scroll, sheet 481b) | still | - |
