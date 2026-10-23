# Assets

Every art file the game loads, the generator that writes it and how it is laid out. Re-run the
generator to reproduce a file; a Gemini render synced to a prompt's `game:` path replaces the
stand-in there with no code change.

| Path | Id | Generator | Frame layout | Stands in for prompt |
|---|---|---|---|---|
| `project/assets/canon/clone_bill_clinton.png` | clone_bill_clinton | `tools/gen_clone_children.py` | 48x68 frames; rows front/side(right)/back; cols 0-1 idle, 2-5 walk; scale 0.5 | - |
| `project/assets/canon/clone_bill_gates.png` | clone_bill_gates | `tools/gen_clone_children.py` | 48x68 frames; rows front/side(right)/back; cols 0-1 idle, 2-5 walk; scale 0.5 | - |
| `project/assets/canon/clone_epstein.png` | clone_epstein | `tools/gen_clone_children.py` | 48x68 frames; rows front/side(right)/back; cols 0-1 idle, 2-5 walk; scale 0.5 | - |
| `project/assets/canon/clone_hillary_clinton.png` | clone_hillary_clinton | `tools/gen_clone_children.py` | 48x68 frames; rows front/side(right)/back; cols 0-1 idle, 2-5 walk; scale 0.5 | - |
| `project/assets/canon/clone_polar_bear.png` | clone_polar_bear | `tools/gen_clone_children.py` | 48x44 frames; rows front/side/back (cols 0-1 idle, 2-5 walk), row3 smeared idle 0-1 + chomp 2-3, row4 nap 0-1; scale 0.5 | - |
| `project/assets/canon/gore_bone.png` | gore_bone | `tools/gen_clone_children.py` | 24x12 still, scale 0.75 | - |
| `project/assets/canon/gore_chunk.png` | gore_chunk | `tools/gen_clone_children.py` | 20x20 still, scale 0.75 | - |
| `project/assets/canon/gore_puddle.png` | gore_puddle | `tools/gen_clone_children.py` | 64x28 still, scale 0.75 | - |
| `project/assets/canon/prop_scroll.png` | prop_scroll | `tools/cut_island_props.py (data/island_props.json, canon sheet 481b)` | 49x40 canon cut, scale 0.5 as a pickup icon | - |
| `project/assets/ruins/glow.png` | glow | `tools/gen_ruins_art.py` | 64x64 pickup glow | - |
| `project/assets/ruins/icon_appendix.png` | icon_appendix | `tools/gen_ruins_art.py` | 40x40 Forbidden Knowledge pickup icon, scale 0.5 | - |
| `project/assets/ruins/icon_board.png` | icon_board | `tools/gen_ruins_art.py` | 40x40 Forbidden Knowledge pickup icon, scale 0.5 | - |
| `project/assets/ruins/icon_book.png` | icon_book | `tools/gen_ruins_art.py` | 40x40 Forbidden Knowledge pickup icon, scale 0.5 | - |
| `project/assets/ruins/icon_calendar.png` | icon_calendar | `tools/gen_ruins_art.py` | 40x40 Forbidden Knowledge pickup icon, scale 0.5 | - |
| `project/assets/ruins/icon_chart.png` | icon_chart | `tools/gen_ruins_art.py` | 40x40 Forbidden Knowledge pickup icon, scale 0.5 | - |
| `project/assets/ruins/icon_ledger.png` | icon_ledger | `tools/gen_ruins_art.py` | 40x40 Forbidden Knowledge pickup icon, scale 0.5 | - |
| `project/assets/ruins/icon_paper.png` | icon_paper | `tools/gen_ruins_art.py` | 40x40 Forbidden Knowledge pickup icon, scale 0.5 | - |
| `project/assets/ruins/icon_proposal.png` | icon_proposal | `tools/gen_ruins_art.py` | 40x40 Forbidden Knowledge pickup icon, scale 0.5 | - |
| `project/assets/ruins/icon_thermometer.png` | icon_thermometer | `tools/gen_ruins_art.py` | 40x40 Forbidden Knowledge pickup icon, scale 0.5 | - |
| `project/assets/ruins/ruins_altar_desk.png` | ruins_altar_desk | `tools/gen_ruins_art.py` | 180x104 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_barrel.png` | ruins_barrel | `tools/gen_ruins_art.py` | 56x76 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_binders_a.png` | ruins_binders_a | `tools/gen_ruins_art.py` | 248x168 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_binders_b.png` | ruins_binders_b | `tools/gen_ruins_art.py` | 248x168 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_binders_c.png` | ruins_binders_c | `tools/gen_ruins_art.py` | 248x168 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_buffet.png` | ruins_buffet | `tools/gen_ruins_art.py` | 168x88 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_bunting.png` | ruins_bunting | `tools/gen_ruins_art.py` | 240x40 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_cables.png` | ruins_cables | `tools/gen_ruins_art.py` | 140x40 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_candles.png` | ruins_candles | `tools/gen_ruins_art.py` | 92x64 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_centrifuge.png` | ruins_centrifuge | `tools/gen_ruins_art.py` | 96x84 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_chair_tipped.png` | ruins_chair_tipped | `tools/gen_ruins_art.py` | 80x48 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_coat_hooks.png` | ruins_coat_hooks | `tools/gen_ruins_art.py` | 168x100 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_crates.png` | ruins_crates | `tools/gen_ruins_art.py` | 112x88 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_crew_sign.png` | ruins_crew_sign | `tools/gen_ruins_art.py` | 144x44 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_cub_basket.png` | ruins_cub_basket | `tools/gen_ruins_art.py` | 120x60 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_deck_chairs.png` | ruins_deck_chairs | `tools/gen_ruins_art.py` | 152x80 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_desk_lamp.png` | ruins_desk_lamp | `tools/gen_ruins_art.py` | 156x108 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_failed_drawer.png` | ruins_failed_drawer | `tools/gen_ruins_art.py` | 132x84 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_filing_cabinet.png` | ruins_filing_cabinet | `tools/gen_ruins_art.py` | 88x144 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_floor_hatch.png` | ruins_floor_hatch | `tools/gen_ruins_art.py` | 104x56 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_freezer.png` | ruins_freezer | `tools/gen_ruins_art.py` | 92x136 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_gift_shop.png` | ruins_gift_shop | `tools/gen_ruins_art.py` | 248x172 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_hazard_band.png` | ruins_hazard_band | `tools/gen_ruins_art.py` | 208x52 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_ice_swan.png` | ruins_ice_swan | `tools/gen_ruins_art.py` | 112x88 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_incubator.png` | ruins_incubator | `tools/gen_ruins_art.py` | 132x104 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_intercom.png` | ruins_intercom | `tools/gen_ruins_art.py` | 76x84 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_lab_cart.png` | ruins_lab_cart | `tools/gen_ruins_art.py` | 88x80 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_life_ring.png` | ruins_life_ring | `tools/gen_ruins_art.py` | 60x60 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_lifeboat.png` | ruins_lifeboat | `tools/gen_ruins_art.py` | 232x112 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_lift_cage.png` | ruins_lift_cage | `tools/gen_ruins_art.py` | 160x200 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_mop_bucket.png` | ruins_mop_bucket | `tools/gen_ruins_art.py` | 60x68 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_offering.png` | ruins_offering | `tools/gen_ruins_art.py` | 68x40 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_papers.png` | ruins_papers | `tools/gen_ruins_art.py` | 88x44 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_pipes.png` | ruins_pipes | `tools/gen_ruins_art.py` | 600x48 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_pipes_striped.png` | ruins_pipes_striped | `tools/gen_ruins_art.py` | 520x48 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_plant.png` | ruins_plant | `tools/gen_ruins_art.py` | 60x88 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_porthole.png` | ruins_porthole | `tools/gen_ruins_art.py` | 60x60 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_portrait.png` | ruins_portrait | `tools/gen_ruins_art.py` | 88x104 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_poster.png` | ruins_poster | `tools/gen_ruins_art.py` | 68x88 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_prep_bench.png` | ruins_prep_bench | `tools/gen_ruins_art.py` | 200x80 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_puddle.png` | ruins_puddle | `tools/gen_ruins_art.py` | 80x32 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_runner.png` | ruins_runner | `tools/gen_ruins_art.py` | 400x44 still, scale 0.5, painted flat on the floor | - |
| `project/assets/ruins/ruins_sequencer.png` | ruins_sequencer | `tools/gen_ruins_art.py` | 112x92 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_server_rack.png` | ruins_server_rack | `tools/gen_ruins_art.py` | 104x172 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_slots.png` | ruins_slots | `tools/gen_ruins_art.py` | 168x140 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_stationery.png` | ruins_stationery | `tools/gen_ruins_art.py` | 112x92 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_tank.png` | ruins_tank | `tools/gen_ruins_art.py` | 1 row x 4 frames of 88x172 (bubbles, blinking light), 6 fps, scale 0.5 | - |
| `project/assets/ruins/ruins_tank_duck.png` | ruins_tank_duck | `tools/gen_ruins_art.py` | 1 row x 4 frames of 88x172 (bubbles, blinking light), 6 fps, scale 0.5 | - |
| `project/assets/ruins/ruins_tiles.png` | ruins_tiles | `tools/gen_ruins_art.py` | atlas 7x6 of 32x32: row0 floors deck/grate/plate/concrete/lab/carpet+void, row1 floor details+lip, row2 wall caps hull/service/core/bunker/lab/archive+edge shadow, row3 panels+hazard, row4 accent stripe, row5 skirting | - |
| `project/assets/ruins/ruins_tileset.tres` | ruins_tileset | `tools/gen_ruins_art.py` | TileSet: one atlas source over ruins_tiles.png, every cell a tile | - |
| `project/assets/ruins/ruins_towel_trolley.png` | ruins_towel_trolley | `tools/gen_ruins_art.py` | 104x88 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/ruins_vending.png` | ruins_vending | `tools/gen_ruins_art.py` | 96x148 still, scale 0.5, feet at bottom centre | - |
| `project/assets/ruins/shadow.png` | shadow | `tools/gen_ruins_art.py` | 48x16 contact shadow | - |
| `project/assets/ruins/vignette.png` | vignette | `tools/gen_ruins_art.py` | 640x360 screen overlay, linear filter | - |
