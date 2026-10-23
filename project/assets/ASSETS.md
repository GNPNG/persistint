# Asset register

One row per game asset: id, path, the generator that writes it, frame layout for rigged
sheets, and the prompts/ render it stands in for (if any). Re-run the generator to reproduce
the file. Sorted by path.

| Path | Id | Generator | Frame layout | Stands in for |
|---|---|---|---|---|
| project/assets/canon/acc_bow.png | acc_bow | tools/cut_paperdoll.py art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| project/assets/canon/body_base.png | body_base | tools/cut_paperdoll.py art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| project/assets/canon/dress_robe.png | dress_robe | tools/cut_paperdoll.py art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| project/assets/canon/dress_uniform.png | dress_uniform | tools/cut_paperdoll.py art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| project/assets/canon/dress_white.png | dress_white | tools/cut_paperdoll.py art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| project/assets/canon/hair_braids.png | hair_braids | tools/cut_paperdoll.py art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| project/assets/canon/hair_crown.png | hair_crown | tools/cut_paperdoll.py art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| project/assets/canon/hair_pigtails.png | hair_pigtails | tools/cut_paperdoll.py art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| project/assets/canon/hair_short.png | hair_short | tools/cut_paperdoll.py art/canon/gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg (project/data/paperdoll_parts.json) | still, 721x760 shared paper-doll frame (sheet resolution) | - |
| project/assets/florida/acc_bougainvillea_wreath.png | acc_bougainvillea_wreath | tools/gen_florida_wearables.py (on the canon paper-doll frame) | still, 721x760 canon paper-doll frame (sheet resolution) | - |
| project/assets/florida/acc_flower_crown.png | acc_flower_crown | tools/gen_florida_wearables.py (on the canon paper-doll frame) | still, 721x760 canon paper-doll frame (sheet resolution) | - |
| project/assets/florida/acc_plumeria_lei.png | acc_plumeria_lei | tools/gen_florida_wearables.py (on the canon paper-doll frame) | still, 721x760 canon paper-doll frame (sheet resolution) | - |
| project/assets/florida/acc_shell_garland.png | acc_shell_garland | tools/gen_florida_wearables.py (on the canon paper-doll frame) | still, 721x760 canon paper-doll frame (sheet resolution) | - |
| project/assets/florida/bg_florida_aquarium.png | bg_florida_aquarium | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/bg_florida_beach.png | bg_florida_beach | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/bg_florida_garden.png | bg_florida_garden | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/bg_florida_stable.png | bg_florida_stable | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/crab.png (+ crab.tres) | crab | tools/gen_florida_critters.py | 24x18 world px (96x72 texture); row 0 idle, row 1 walk, 4 cols; .tres idle/walk; .tres metadata display_scale 0.25 | - |
| project/assets/florida/craft_bench.png | craft_bench | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/dolphin.png (+ dolphin.tres) | dolphin | tools/gen_florida_critters.py | 48x32 world px (192x128 texture); row 0 idle, row 1 walk (swim), 4 cols; .tres idle/walk; .tres metadata display_scale 0.25 | - |
| project/assets/florida/fish.png (+ fish.tres) | fish | tools/gen_florida_art.py | 16x12 world px (64x48 texture); rows coral/mango/lilac, cols 0-2 swim, 3 wave; .tres swim_*/wave_*; .tres metadata display_scale 0.25 | - |
| project/assets/florida/gull.png (+ gull.tres) | gull | tools/gen_florida_critters.py | 24x24 world px (96x96 texture); row 0 idle, row 1 walk (hop), 4 cols; .tres idle/walk; .tres metadata display_scale 0.25 | - |
| project/assets/florida/mermaid.png (+ mermaid.tres) | mermaid | tools/gen_florida_cast.py (on the canon body turnaround, sheet ekiw) | 36x50 world px (144x200 texture); row 0 idle, row 1 walk (swim), 4 cols; .tres idle/walk; .tres metadata display_scale 0.25 | - |
| project/assets/florida/npc_daughter.png (+ npc_daughter.tres) | npc_daughter | tools/gen_florida_cast.py (on the canon body turnaround, sheet ekiw) | 32x52 world px (128x208 texture); rows front/side/back, 4 idle cols; .tres idle_front/side/back; .tres metadata display_scale 0.25 | - |
| project/assets/florida/npc_father.png (+ npc_father.tres) | npc_father | tools/gen_florida_cast.py (on the canon body turnaround, sheet ekiw) | 36x62 world px (144x248 texture); rows front/side/back, 4 idle cols; .tres idle_front/side/back; .tres metadata display_scale 0.25 | - |
| project/assets/florida/npc_stable_friend.png (+ npc_stable_friend.tres) | npc_stable_friend | tools/gen_florida_cast.py (on the canon body turnaround, sheet ekiw) | 32x52 world px (128x208 texture); rows front/side/back, 4 idle cols; .tres idle_front/side/back; .tres metadata display_scale 0.25 | - |
| project/assets/florida/plot_empty.png | plot_empty | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/plot_growing.png | plot_growing | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/plot_ready_bougainvillea.png | plot_ready_bougainvillea | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/plot_ready_coconut.png | plot_ready_coconut | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/plot_ready_guava.png | plot_ready_guava | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/plot_ready_hibiscus.png | plot_ready_hibiscus | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/plot_ready_key_lime.png | plot_ready_key_lime | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/plot_ready_mango.png | plot_ready_mango | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/plot_ready_plumeria.png | plot_ready_plumeria | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/plot_ready_sea_grape.png | plot_ready_sea_grape | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/pony_acc_blanket.png | pony_acc_blanket | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_acc_bow.png | pony_acc_bow | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_acc_flower_crown.png | pony_acc_flower_crown | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_acc_hibiscus.png | pony_acc_hibiscus | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_body_cloud.png | pony_body_cloud | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_body_honey.png | pony_body_honey | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_body_lilac.png | pony_body_lilac | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_body_mint.png | pony_body_mint | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_body_peach.png | pony_body_peach | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_braids_lavender.png | pony_mane_braids_lavender | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_braids_rose.png | pony_mane_braids_rose | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_braids_sky.png | pony_mane_braids_sky | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_braids_sunshine.png | pony_mane_braids_sunshine | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_curly_lavender.png | pony_mane_curly_lavender | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_curly_rose.png | pony_mane_curly_rose | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_curly_sky.png | pony_mane_curly_sky | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_curly_sunshine.png | pony_mane_curly_sunshine | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_flowing_lavender.png | pony_mane_flowing_lavender | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_flowing_rose.png | pony_mane_flowing_rose | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_flowing_sky.png | pony_mane_flowing_sky | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_mane_flowing_sunshine.png | pony_mane_flowing_sunshine | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_sparkle.png | pony_sparkle | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/pony_spots.png | pony_spots | tools/gen_pony_sprites.py | 64x52 world px (256x208 texture); 4 cols x 2 rows: row 0 idle, row 1 walk (PonyDoll AnimationPlayer) | - |
| project/assets/florida/prop_aquarium.png | prop_aquarium | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_barn.png | prop_barn | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_bench.png | prop_bench | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_birdbath.png | prop_birdbath | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_bush_bougainvillea.png | prop_bush_bougainvillea | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_bush_hibiscus.png | prop_bush_hibiscus | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_dune_grass.png | prop_dune_grass | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_fence_paddock.png | prop_fence_paddock | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_fence_picket.png | prop_fence_picket | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_garden_arch.png | prop_garden_arch | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_hay.png | prop_hay | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_house.png | prop_house | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_palm_a.png | prop_palm_a | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_palm_b.png | prop_palm_b | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_palm_potted.png | prop_palm_potted | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_rowboat.png | prop_rowboat | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_sandcastle.png | prop_sandcastle | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_sign_stable.png | prop_sign_stable | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_tree_key_lime.png | prop_tree_key_lime | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_tree_mango.png | prop_tree_mango | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_trough.png | prop_trough | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/prop_umbrella.png | prop_umbrella | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/seed_bag.png | seed_bag | tools/gen_florida_art.py | still, 4 texture px per world px; scenes scale 0.25 | - |
| project/assets/florida/shell_conch.png | shell_conch | tools/cut_island_props.py project/data/florida_canon.json (canon tide scroll, sheet 481b) | still, canon sheet resolution; shown 11 world px tall | - |
| project/assets/florida/shell_scallop.png | shell_scallop | tools/cut_island_props.py project/data/florida_canon.json (canon tide scroll, sheet 481b) | still, canon sheet resolution; shown 11 world px tall | - |
| project/assets/florida/shell_spiral.png | shell_spiral | tools/cut_island_props.py project/data/florida_canon.json (canon tide scroll, sheet 481b) | still, canon sheet resolution; shown 11 world px tall | - |
