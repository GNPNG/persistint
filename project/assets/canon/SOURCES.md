# Sources: project/assets/canon

Where every sprite in this folder comes from (release checklist LP-04, sops/09). Each one is a
cut from a canon sheet, made by the tool named in its row from the sheet and crop given there,
or drawn in code by a generator. The tools are deterministic: rerunning one reproduces these
sprites pixel for pixel (checked 2026-10-27 for tools/cut_island_props.py: all 14 props
identical; the PNG bytes can differ with the Pillow/scipy builds in tools/requirements-art.txt).

## Canon sheets

Kept encrypted in the repository's `dev/` tree (git-crypt); added by Brett Whitty on
2026-10-23 (commit ca64631, first under `art/canon/`, moved to `dev/art/canon-gemini/`).

| Sheet | File | Made with | What the cuts use it for |
|---|---|---|---|
| `Gemini_Generated_Image_4bzs` | `dev/art/canon-gemini/Gemini_Generated_Image_4bzs3l4bzs3l4bzs.jpg` | Google Gemini app (file named by its download) | caste NPC turnaround: front, side, back |
| `Gemini_Generated_Image_481b` | `dev/art/canon-gemini/Gemini_Generated_Image_481bj2481bj2481b.jpg` | Google Gemini app | forbidden instruments: scroll, calendar, tag |
| `Gemini_Generated_Image_i7kl` | `dev/art/canon-gemini/Gemini_Generated_Image_i7klpci7klpci7kl.jpg` | Google Gemini app | island props: ship, bunker, fences, signs |
| `Gemini_Generated_Image_ktfw` | `dev/art/canon-gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg` | Google Gemini app | paper-doll body, hair, dresses, bow |
| `PERSISTINT` | `dev/art/PERSISTINT_Novel_World-Building_Overview.png` | not recorded | icons, seal, pillar orb, skull altar, heart, sparkle |

The other three sheets in `dev/art/canon-gemini/` (`6lod`, `8uph`, `ekiw`) feed the Florida art
and the player rig (`project/data/florida_canon.json`, `tools/gen_player_rig.py`), not this
folder.

Not recorded in the repository, for the author to add: the Gemini model and the prompt behind
each sheet, and how the world-building overview was made.

## Layered sheets

A character drawn as separate layers on one sheet (the character's own bald body first, then the hair,
clothes and shoes), keyed to white in `project/assets/sheets/` (staging, not shipped);
`project/data/paperdoll_parts.json` names the sheet under "sheets" and each cut in the Sprites table
names it and its crop.

| Sheet | Made with | Prompt | Keyed copy the cutter reads |
|---|---|---|---|
| `barren_susan` | Codex image_gen (render commit c24c327, bd uowd) | none (requested on a bead); drop `prompts/image/characters/assets/char_barren_susan_layers.png` | `project/assets/sheets/characters/char_barren_susan_layers_white.png` |
| `daughter` | Codex image_gen (render commit dd7de65, bd uowd) | none (requested on a bead); drop `prompts/image/characters/assets/char_daughter_layers.png` | `project/assets/sheets/characters/char_daughter_layers_white.png` |
| `drone_bruce` | Codex image_gen (render commit aaa9dc0, bd uowd) | none (requested on a bead); drop `prompts/image/characters/assets/char_drone_bruce_layers.png` | `project/assets/sheets/characters/char_drone_bruce_layers_white.png` |
| `father` | Codex image_gen (render commit 30adeb6, bd uowd) | none (requested on a bead); drop `prompts/image/characters/assets/char_father_layers.png` | `project/assets/sheets/characters/char_father_layers_white.png` |
| `initiate` | Codex image_gen (render commit 9ef4bc7, bd uowd) | none (requested on a bead); drop `prompts/image/characters/assets/char_initiate_layers.png` | `project/assets/sheets/characters/char_initiate_layers_white.png` |
| `mother` | Codex image_gen (render commit 0b61ff7, bd uowd) | none (requested on a bead); drop `prompts/image/characters/assets/char_mother_layers.png` | `project/assets/sheets/characters/char_mother_layers_white.png` |

## Sprites

| Sprite | Tool | Sheet | Crop (WxH+X+Y on the sheet) |
|---|---|---|---|
| `acc_bow.png` | `tools/cut_paperdoll.py` | `Gemini_Generated_Image_ktfw` | 209x141+664+594 |
| `body_barren_susan.png` | `tools/cut_paperdoll.py` | `barren_susan` | 376x700+68+115 |
| `body_base.png` | `tools/cut_paperdoll.py` | `Gemini_Generated_Image_ktfw` | 402x698+97+300 |
| `body_daughter.png` | `tools/cut_paperdoll.py` | `daughter` | 484x795+38+82 |
| `body_drone_bruce.png` | `tools/cut_paperdoll.py` | `drone_bruce` | 383x708+68+128 |
| `body_father.png` | `tools/cut_paperdoll.py` | `father` | 392x687+53+112 |
| `body_initiate.png` | `tools/cut_paperdoll.py` | `initiate` | 381x741+55+115 |
| `body_mother.png` | `tools/cut_paperdoll.py` | `mother` | 374x678+57+128 |
| `bottom_father.png` | `tools/cut_paperdoll.py` | `father` | 230x84+919+598 |
| `deco_flowers.png` | `tools/gen_island_deco.py` | (drawn in code) | - |
| `deco_heart.png` | `tools/cut_island_props.py` | `PERSISTINT` | 46x46+61+96 |
| `deco_sparkle.png` | `tools/cut_island_props.py` | `PERSISTINT` | 46x50+1742+175 |
| `deco_tree_a.png` | `tools/gen_island_deco.py` | (drawn in code) | - |
| `deco_tree_b.png` | `tools/gen_island_deco.py` | (drawn in code) | - |
| `deco_tree_c.png` | `tools/gen_island_deco.py` | (drawn in code) | - |
| `dress_barren_susan.png` | `tools/cut_paperdoll.py` | `barren_susan` | 297x397+891+418 |
| `dress_daughter.png` | `tools/cut_paperdoll.py` | `daughter` | 430x319+1179+458 |
| `dress_drone_bruce.png` | `tools/cut_paperdoll.py` | `drone_bruce` | 288x412+1017+427 |
| `dress_initiate.png` | `tools/cut_paperdoll.py` | `initiate` | 281x289+997+400 |
| `dress_mother.png` | `tools/cut_paperdoll.py` | `mother` | 431x411+936+411 |
| `dress_robe.png` | `tools/cut_paperdoll.py` | `Gemini_Generated_Image_ktfw` | 534x400+1530+600 |
| `dress_uniform.png` | `tools/cut_paperdoll.py` | `Gemini_Generated_Image_ktfw` | 309x371+980+628 |
| `dress_white.png` | `tools/cut_paperdoll.py` | `Gemini_Generated_Image_ktfw` | 409x432+2105+569 |
| `hair_barren_susan.png` | `tools/cut_paperdoll.py` | `barren_susan` | 356x366+470+114 |
| `hair_braids.png` | `tools/cut_paperdoll.py` | `Gemini_Generated_Image_ktfw` | 534x512+1530+99 |
| `hair_crown.png` | `tools/cut_paperdoll.py` | `Gemini_Generated_Image_ktfw` | 402x511+1095+81 |
| `hair_daughter.png` | `tools/cut_paperdoll.py` | `daughter` | 681x515+512+61 |
| `hair_drone_bruce.png` | `tools/cut_paperdoll.py` | `drone_bruce` | 487x401+481+112 |
| `hair_father.png` | `tools/cut_paperdoll.py` | `father` | 386x322+465+138 |
| `hair_initiate.png` | `tools/cut_paperdoll.py` | `initiate` | 507x326+459+115 |
| `hair_mother.png` | `tools/cut_paperdoll.py` | `mother` | 453x539+461+128 |
| `hair_pigtails.png` | `tools/cut_paperdoll.py` | `Gemini_Generated_Image_ktfw` | 379x419+595+89 |
| `hair_short.png` | `tools/cut_paperdoll.py` | `Gemini_Generated_Image_ktfw` | 423x374+2199+90 |
| `npc_barren.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | copy of npc_barren_front |
| `npc_barren_back.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | 263x441+2404+1059 |
| `npc_barren_front.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | 265x442+1903+1058 |
| `npc_barren_side.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | 236x441+2180+1061 |
| `npc_drone.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | copy of npc_drone_front |
| `npc_drone_back.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | 207x455+2445+548 |
| `npc_drone_front.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | 208x459+1903+547 |
| `npc_drone_side.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | 208x455+2171+551 |
| `npc_initiate.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | copy of npc_initiate_front |
| `npc_initiate_back.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | 227x440+1562+557 |
| `npc_initiate_front.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | 226x441+1001+556 |
| `npc_initiate_side.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | 194x440+1300+558 |
| `npc_mother.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | copy of npc_mother_front |
| `npc_mother_back.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | 250x442+653+58 |
| `npc_mother_front.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | 261x442+88+58 |
| `npc_mother_side.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | 210x443+407+56 |
| `npc_priestess.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | copy of npc_priestess_front |
| `npc_priestess_back.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | 224x441+1565+60 |
| `npc_priestess_front.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | 216x438+1004+60 |
| `npc_priestess_side.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_4bzs` | 207x439+1304+59 |
| `prop_bunker.png` | `tools/cut_island_props.py` | `Gemini_Generated_Image_i7kl` | 950x900+1700+40 |
| `prop_calendar.png` | render of `prompts/image/levels/temple/prop_calendar.md` (codex, 2026-11-02), keyed and fitted by hand (`.claude/skills/gemini-assets/SKILL.md` step 3) | `prompts/image/levels/temple/assets/prop_calendar.png` | replaces the cut of `Gemini_Generated_Image_481b` 820x720+880+740 |
| `prop_fence_a.png` | `tools/cut_island_props.py` | `Gemini_Generated_Image_i7kl` | 680x400+85+1040 |
| `prop_fence_b.png` | `tools/cut_island_props.py` | `Gemini_Generated_Image_i7kl` | 680x400+850+1040 |
| `prop_icon_queen_mother.png` | render of `prompts/image/levels/temple/prop_icon_queen_mother.md` (codex, 2026-11-02), keyed and fitted by hand (`.claude/skills/gemini-assets/SKILL.md` step 3) | `prompts/image/levels/temple/assets/prop_icon_queen_mother.png` | replaces the cut of `PERSISTINT` 272x310+982+745 |
| `prop_pillar_orb.png` | `tools/cut_island_props.py` | `PERSISTINT` | 190x310+1290+1010 |
| `prop_scroll.png` | `tools/cut_canon_sprites.sh` | `Gemini_Generated_Image_481b` | 820x680+1850+765 |
| `prop_seal_o.png` | render of `prompts/image/levels/temple/prop_seal_o.md` (codex, 2026-11-03), keyed and fitted by hand (`.claude/skills/gemini-assets/SKILL.md` step 3) | `prompts/image/levels/temple/assets/prop_seal_o.png` | replaces the `tools/cut_island_props.py` cut of `PERSISTINT` 180x170+1585+790 |
| `prop_ship.png` | `tools/cut_island_props.py` | `Gemini_Generated_Image_i7kl` | 1380x1000+100+60 |
| `prop_sign_a.png` | `tools/cut_island_props.py` | `Gemini_Generated_Image_i7kl` | 460x520+1640+910 |
| `prop_sign_b.png` | `tools/cut_island_props.py` | `Gemini_Generated_Image_i7kl` | 400x520+2230+910 |
| `prop_skull_altar.png` | render of `prompts/image/levels/temple/prop_skull_altar.md` (codex, 2026-11-03), keyed and fitted by hand (`.claude/skills/gemini-assets/SKILL.md` step 3) | `prompts/image/levels/temple/assets/prop_skull_altar.png` | replaces the cut of `PERSISTINT` 230x230+1040+1100 |
| `prop_tag_x.png` | `tools/cut_island_props.py` | `Gemini_Generated_Image_481b` | 520x680+140+760 |
| `shoes_daughter.png` | `tools/cut_paperdoll.py` | `daughter` | 257x109+1267+777 |
| `shoes_father.png` | `tools/cut_paperdoll.py` | `father` | 274x80+894+718 |
| `shoes_initiate.png` | `tools/cut_paperdoll.py` | `initiate` | 205x169+1034+689 |
| `top_father.png` | `tools/cut_paperdoll.py` | `father` | 307x138+881+460 |

`tools/gen_island_deco.py` draws its trees and flowers from code (palette from dev/STYLE.md, no
randomness, no model). `npc_<caste>.png` is the front view, copied by
`tools/cut_canon_sprites.sh`, which the game loads by default.
