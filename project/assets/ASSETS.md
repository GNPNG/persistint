# Assets

Every art file the game loads, the generator that writes it and how it is laid out. Re-run the
generator to reproduce a file; a Gemini render synced to a prompt's `game:` path replaces the
stand-in there with no code change.

| Path | Id | Generator | Frame layout | Stands in for prompt |
|---|---|---|---|---|
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
| `project/assets/canon/prop_scroll.png` | prop_scroll | `tools/cut_canon_sprites.sh` (canon sheet 481b) | 792x651 canon cut at source resolution, shown 18 world px tall as a pickup icon | - |
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
