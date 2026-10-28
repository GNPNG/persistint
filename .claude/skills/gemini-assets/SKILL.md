---
name: gemini-assets
description: Make PERSISTINT art with Gemini (paper-doll wardrobe sheets, character sheets, temple and other level props, backdrops). Holds the asset specs (canvas sizes, flat chroma green, paper-doll frame and anchors, spacing, style keywords), the iterate-with-Gemini loop (send, check, critique, ask how to help, re-render, keep only passes) and the post-steps (drop, sync, chroma key, cut, paper bake, import, tests). Use whenever writing or rendering a prompt under prompts/image/ or bringing a Gemini render into project/.
---

# Gemini assets

The prompts live in `prompts/image/` (one file per asset or sheet; format in `prompts/README.md`,
style rules in the git-crypt `dev/STYLE.md`, sections 4, 7, 11 and 12). Every `## Prompt` is
pre-compiled and pasted as is; the web pipeline (`tools/web_render/`, `web-render.config.json`)
puts `@persistint-asset-prompts` in front of it. Epic: bd `persistint-game-lg5w`.

## 1. Specs

### Style keywords (every image prompt)

Kawaii pixel art defined as a clean sticker illustration read at low resolution: even warm-brown
outlines (never black; `#8a5a5a` on island art, plum `#5a4a5e` in the clone lab), flat pastel fills
with one soft highlight, round pink blush, dot eyes, small smiles, faces on buildings, trees and
props, big round shapes readable at 640×360, hearts and four-point sparkles, soft antialiased
edges, no pixel stair-steps, no dithering, no 3D, no photorealism, no text. "Cute on the surface
with something faintly wrong underneath", except Florida: "Pure carefree joy, nothing wrong
anywhere." Chibi people: head about half the height, stubby limbs; Covenant women share one small
calm smile.

### Rules `tools/check_prompts.py` enforces on prompt files (whole file, Notes included)

- No hex codes with a hash: write the chroma colour as "hex 00FF00: red 0, green 255, blue 0".
- No three-letter capitals in `## Prompt` (lettering check), so no colour-model or file-type acronyms.
- Banned words: the stacking word for game spaces or doll parts (say "slot", "part", "stack order"),
  "white robe", "zombie", "colony", "cottage", "paradise", and other listed words.
- No real-person name tokens anywhere in the file, including first names shared with real people
  (the Initiate's cast name is one: call her "the Initiate").
- The six preamble and negative markers verbatim, "no text", `assets/.gitkeep` beside the file,
  `drop: <dir>/assets/<id>.png`, `game: project/.../<id>.png`, unique ids and paths.

Run `python3 -I -B tools/check_prompts.py` after every edit; it must print 0 failures.

### Canvas and background

| Asset | Render | Background | Final size in the game |
|---|---|---|---|
| Wardrobe sheet | 16:9 (canon sheet 2752×1536) | flat chroma green | parts on the 721×760 doll frame |
| Character sheet | 16:9 | flat chroma green | reference; rigs are 32×52 world px frames |
| Single prop | aspect of the file it replaces (1:1, 3:4, 4:5, 9:16, 3:2, 21:9) | flat chroma green | the current file's size (in the prompt's Notes) |
| Backdrop, key art | 16:9 | full-frame art, no key | 2560×1440 backdrops, 1920×1080 key art |

Chroma: one flat pure green, hex `#00FF00`, edge to edge: no shadows, no gradient, no texture, no
floor line, no glow, no green spill. Nothing in an item may be green, lime or mint (it would key
out); plants turn lavender, pink or butter. Turquoise survives the key but loses some green in the
despill, so check it. Every item keeps its full warm-brown outline.

White space: plain green between all items, at least half an item's width between neighbours and
from every edge; nothing touches, overlaps or is cropped.

### Paper-doll frame, stack order and anchors (from the code)

- Slots and stack order: `project/scripts/systems/paper_doll.gd` lists `body, dress, hair,
  accessory`, drawn in that order. These four are the only slots. Tops, bottoms and shoes need new
  slots (slot list, `project/scenes/ui/wardrobe.tscn` rows, `project/scripts/ui/wardrobe.gd`, a
  placement rule in `tools/cut_paperdoll.py`, `tools/gen_player_rig.py`, `tools/bake_paper.sh`).
- Wardrobe options: `project/data/outfits.json` (`hair`, `dress`, `accessory`).
- Cut placement: `project/data/paperdoll_parts.json` (crop `WxH+X+Y` on one sheet) read by
  `tools/cut_paperdoll.py`; the part's prefix before the first `_` picks the rule:
  - `body_*` as drawn; it fixes the frame. `project/assets/canon/body_base.png` is 721×760: head top
    y 61, head widest at about y 220 (x 200 to 535), ears about y 280 to 345, chin about y 400, neck
    narrowest about y 410 (x 319 to 410), hands about y 540 to 575 (x 163 to 564), legs x 273 to 455,
    soles y 758; head centre x about 367.
  - `dress_*` scaled from the collar (neck minus 14 px, about y 396) to the soles, centred on the
    body: an outfit includes its legwear and shoes.
  - `hair_*`: the largest enclosed background region is the face opening; the wig is scaled so the
    opening matches the body's face width (`face_fill` 0.86) and its bottom sits on the chin. Every
    wig needs a fully enclosed, empty face opening.
  - `acc_*`: placed by `anchor` (px from head centre x and head top) and `scale` (acc_bow:
    `[-120, 40]`, 0.6). Hats are `acc_hat_*` until a hat slot exists.
- Every wardrobe sheet carries the bald reference doll at the far left, front view, arms angled
  down about thirty degrees, feet on one baseline; items are drawn at its scale, front view only
  (the side and back views are derived by `tools/gen_player_rig.py`).
- Player rig: `project/assets/characters/player/<part>_rig.png`, 8×3 frames of 364×384 (the doll
  frame at 384/760, 8 px per world px, shown 48 world px tall), rows down / left / up.

## 2. The iterate loop (Gemini web UI or `tools/web_render`)

1. Send the file's `## Prompt` exactly as written (render: `node tools/web_render/render.mjs
   --render --kind image`, or `--assist` to drive each generation and save it yourself).
2. Check the result against the checklist below, item by item, and write down every miss.
3. If anything misses, reply in the same Gemini conversation. Say exactly what is wrong, with
   where and how much ("the background has a soft grey shadow under each shoe; it must be one flat
   pure green", "the ponytail wig has no face opening; leave an empty face-shaped hole the size of
   the doll's face", "items 2 and 3 touch; leave half an item's width between them", "outline is
   black; make it warm brown"), then ask: "How can I help you do this better?" Use its answer: if
   it asks for fewer items per image, a reference, or a simpler wording, give it that.
4. Re-render and check again. Keep going until a render passes everything. Three misses in a row on
   the same point: change the prompt (fewer items, one item per image, plainer words), fix the
   prompt file and rerun the checker.
5. Save only a passing render, to the prompt's `drop:` path. Never save a near miss "to fix later".
   If the prompt changed, commit the improved prompt so the next render starts from it.

### Checklist

- [ ] Background is one flat pure green: no shadow, gradient, texture, floor line, glow or spill.
- [ ] Nothing in any item is green, lime or mint.
- [ ] Every item has a complete warm-brown outline (not black), flat pastel fills, one highlight.
- [ ] Generous green space between items and from the edges; nothing touches or is cut off.
- [ ] No text, letters, numbers, logos or watermarks anywhere.
- [ ] The look matches the shipped art (sticker kawaii, soft edges, no stair-steps, no 3D).
- [ ] Wardrobe: reference doll at the far left, front view, bald, arms angled down, feet level.
- [ ] Wardrobe: every item at the doll's scale and pose, front view, no body or face inside it;
      dresses run collar to soles with shoes; wigs have an enclosed empty face opening.
- [ ] Characters: turnaround views all the same height on one baseline; the side view faces left;
      the same face and outfit in every view and bust; the expressions asked for.
- [ ] Props: one prop, upright, centred, base flat at the bottom, the asked aspect.
- [ ] No real-person likeness; nothing scary; the world's must-never items absent.

## 3. Post-steps

Run from the repo root. Commit with `mise x --env claude-cli -- git ...`, staging by path.

1. **Drop**: the passing render at the prompt's `drop:` path (PNG; convert a JPEG download with
   `magick in.jpg out.png`, which keeps the JPEG's edge noise, so key with fuzz).
2. **Sync**: `python3 tools/sync_rendered_assets.py` copies every drop to its `game:` path and lists
   what is still missing. Sheets land in `project/assets/sheets/...` (staging); single props and
   backdrops land on the live file. `project/assets/sheets/` needs a `.gdignore` or an export exclude
   (`project/export_presets.cfg` ships all resources) before the first sheet is committed: raise it
   with the lead, it is a config change.
3. **Chroma key** (props and anything shown with transparency), in place at the `game:` path:

   ```bash
   magick IN.png -fuzz 12% -transparent '#00FF00' \
     -channel G -fx 'min(u.g,max(u.r,u.b))' +channel -trim +repage OUT.png
   ```

   The `-fx` despill clamps green to the larger of red and blue, which removes green fringes (and
   would grey any green left in an item). Then resize to the current file's size and feet line
   given in the prompt's Notes, e.g. `magick OUT.png -resize x144 -background none -gravity south
   -extent 112x144 OUT.png`. Sync leaves a game copy newer than its drop alone.
   For wardrobe sheets the cutter keys white, not green, so key the sheet to white instead:
   `magick SHEET.png -fuzz 12% -fill white -opaque '#00FF00' -channel G -fx 'min(u.g,max(u.r,u.b))' +channel SHEET_white.png`.
4. **Cut** (wardrobe and character sheets): add each part's crop to a parts file and run
   `python3 -I tools/cut_paperdoll.py SHEET_white.png` (it reads `project/data/paperdoll_parts.json`
   and takes one sheet per run; a second sheet needs its own parts file or a cutter change). Add the
   parts to `project/data/outfits.json`, then `python3 -I tools/gen_player_rig.py`.
   Animated temple files (candles, twinkle) and the temple tiles are built from their stills by
   the generator (`tools/gen_temple_props.py`, `tools/gen_island_tiles.py`), a tool change.
5. **Paper bake**: add new parts or props to the lists in `tools/bake_paper.sh`, then
   `tools/bake_paper.sh characters|props|all` (needs ImageMagick 7 and node).
6. **Import**: `godot --headless --path project --import`, then `node tools/set_texture_imports.mjs`
   and `node tools/gen_sources.mjs`; for greenery and props rebuild the maps
   (`tools/build_island_maps.gd`). Update the row in `project/assets/ASSETS.md`.
7. **Tests**: `tools/run_tests.sh` (all; prints one line per test and exits non-zero on a failure),
   and `python3 -I -B tools/check_prompts.py`. Look at the scene (the wardrobe, the temple map) in a
   screenshot before calling it done.
8. Commit the drop, the game files and any prompt fixes; note the render in the bd epic.
