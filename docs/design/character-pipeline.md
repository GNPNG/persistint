# Character pipeline: paper-doll bodies and layers

Status: proposal, 2026-11-02. Author: claude-cli. Not committed.

This document covers how a PERSISTINT paper-doll character is made: a body plus separately drawn,
swappable layers (hair, top, bottom, dress, shoes, hat, accessory) stacked at one origin, in the
flat kawaii chibi sticker style. It describes the pipeline as built, where it fails, what it
should be instead, the tools to build it with, the data format, how existing assets move over,
and an ordered task list. Open questions are at the end; nothing here waits on an answer to
start the first three tasks.

Constraints taken as given: Python is not approved for new work on org machines, so the Python
tools are retired rather than patched; new tools are Node (`.mjs`, as the repo already uses) or
Godot (GDScript tool scripts, tests and editor plugins). Nothing under `dev/` is edited.

## 1. Summary

The current tools try to recover registration after the fact. Image agents draw items at their
own scale and position on a 16:9 sheet; `tools/cut_paperdoll.py` then guesses where each item
belongs from row-width heuristics and per-prefix rules, keys a white background it created by
throwing away the green key's alpha, and resamples each part at its own scale. The result has a
light fringe on every outline, a hard-edged body, hair stacked over the torso, garments with
their own drawn legs and hands showing beside the body's, and no notion that different
characters have differently shaped bodies.

The proposal inverts this. Registration is fixed before drawing: the image agent edits a
template image that already holds the canonical body, and returns the item drawn on that body
(the proof) plus the item alone on the same canvas. The pipeline registers by fitting the
proof's body to the template, applies that transform to the item, and rejects the item when the
correction or the residual is out of tolerance. Matting is a soft chroma unmix that keeps alpha
from the green key instead of thresholding white. Every assembled outfit is checked in Godot:
pixel checks on image data headless, and in-game screenshots through the existing Xvfb shot walk.

Stack, in three lines:

1. Node 24 `.mjs` tools, no new npm dependencies (ImageMagick 7, already required by the repo, for
   PNG I/O and resampling): intake, matting, segmentation, registration, landing.
2. Godot 4.6 GDScript: the runtime `PaperDoll` (catalog-driven, with a back-hair layer under the
   body), headless pixel QA in `tools/run_tests.sh`, a "Doll Bench" editor plugin for review and
   nudges, and in-game screenshots through `tools/shot_walk.sh` under Xvfb.
3. Optional and only on approval: `onnxruntime-node` with the MIT-licensed ToonOut BiRefNet ONNX
   export as an ML matting fallback for renders that arrive without a clean key. Go is not used.

### 1.1 First acceptance case: the live wardrobe (v0.4.0, 45269f5)

The owner's screenshot of the live build shows the Wardrobe dialog with the player doll wearing
`hair_crown` and `dress_white`. The blonde hair is drawn so large that it covers the sides of the
face and the whole body down to the dress hem; the doll reads as a mass of hair. The dialog
offers three unlabelled rows (Crown, White, None). Behind it, the HUD icon column overlaps a
building and the world is not dimmed. The causes are in 3.0.

The design is accepted only when this case passes, automatically:

- **A1.1 Scale.** `hair_crown` is registered at the scale of the sheet it was drawn on: the canon
  sheet draws the body and the wigs at one scale and the body is cut unscaled, so the wig's fitted
  scale relative to that sheet is 1.00 ± 0.02 (today 1.26). Ground truth: the wig placed over the
  body on the canon sheet itself, at sheet scale, overlaps the registered layer at IoU 0.97 or
  better.
- **A1.2 Registration.** The eye band is fully uncovered; the hair covers at most 3% of the face
  (brow to chin); hair below the chin is in `hair_back`, under the body, so the dress shows from
  collar to hem except where back hair shows beside it.
- **A1.3 In-game screenshot.** Shot `wardrobe-player-crown-white` (`tools/shots/doll.json`, run
  by `tools/shot_walk.sh` under Xvfb) opens `scenes/ui/wardrobe.tscn` with `outfit_hair` set to
  `hair_crown` and `outfit_dress` to `dress_white`. The preview rectangle cropped from the
  screenshot matches the `DollComposer` composite of the same outfit at the same size within the
  set RMSE, and matches the approved baseline. Run against the assets of 45269f5, the same shot
  fails A1.1 and A1.2 (the test proves it can see the defect).
- **A1.4 Every slot.** The wardrobe shows one labelled row per slot: body, hair, top, bottom,
  dress, shoes, hat, accessory, always (a slot with nothing to choose shows its one option with
  the arrows disabled, rather than disappearing). A GDScript test checks the eight rows and their
  labels; the A1.3 screenshot shows them.
- **A1.5 Dialog backdrop.** The world behind the dialog is dimmed while the wardrobe is open. The
  HUD icon column overlapping the scene is a HUD layout defect outside this pipeline; it is
  recorded here because it is in the same screenshot (open question 13).

Tasks 1, 2, 3, 4, 5, 6 and 7 (section 9) close A1, in that order; A1 is the first shot in task 5's
shot list.

## 2. The current pipeline, as built

| Step | Tool | What it does |
|---|---|---|
| Prompt | `prompts/image/wardrobe/*.md`, `prompts/image/characters/*.md` | Asks for a 16:9 sheet (Notes: 2752×1536 to match the canon sheet) on pure 00FF00 green: a bald reference doll at the far left, items to the right "at her scale" and at the height of the body part they belong to. |
| Render | Gemini originally; now Codex (ChatGPT image generation) and Grok (gnomatix/cloud-persistint issue #1) | Delivers a PNG to the prompt's `drop:` path plus `done/<id>.json` provenance. Codex's tool has no numeric size control: layered sheets arrive at 1678×937, reference sheets at 1672×941. |
| Measure | by hand | `prompts/image/wardrobe/<id>.parts.json`: a `WxH+X+Y` crop for the doll and for every item; `anchor` and `scale` for hats and accessories (`tools/land_wardrobe.mjs` L18-24). |
| Key | `tools/land_wardrobe.mjs` L401 | `magick -fuzz 12% -fill white -opaque '#00FF00'` plus a green despill: the green background becomes white. |
| Cut | `tools/cut_paperdoll.py` (numpy, scipy, Pillow), spawned at `land_wardrobe.mjs` L430 | Keys the white back out, finds body landmarks from row widths, places each part by its name prefix, resamples with LANCZOS, writes every part as a 721×760 RGBA PNG on one shared frame in `project/assets/canon/`. |
| Register | `land_wardrobe.mjs` L237-276 | Writes `project/data/paperdoll_parts.json`, `project/data/outfits.json`, `project/assets/canon/SOURCES.md`. |
| Rig | `tools/gen_player_rig.py` | Builds one 8×3 sheet of 364×384 frames per part (idle and walk; down, left, up). The side and back views are derived from the front art. |
| Bake, import | `tools/bake_paper.sh characters`, `godot --headless --import`, `tools/set_texture_imports.mjs`, `tools/gen_sources.mjs` | Paper rings, imports, source tables. |
| Show | `project/scripts/systems/paper_doll.gd` (wardrobe preview and minigames at `display_height` 192 of the 640×360 viewport), `project/scripts/player.gd` (rig sheets, 48 world px tall) | One full-rect `TextureRect` per slot, stacked in `LAYERS` order. |

Good parts worth keeping: the shared 721×760 frame (the game already stacks any equal-size frame
correctly), the slot vocabulary and stack order, `outfits.json` as the wardrobe's option list,
the `done/*.json` provenance, and `land_wardrobe.mjs`'s shape (one command, `--dry-run`,
idempotent writes, a per-sheet summary, nonzero exit on any error).

## 3. Where it fails

Each item below names the file and line, and the evidence. The measurements were taken on the
committed files at 8691683 (the doll assets and tools are the same at 45269f5); the commands to
reproduce them are in 3.6.

### 3.0 The oversized hair and the missing rows in the live wardrobe

**Exact cause of the oversized hair: `tools/cut_paperdoll.py` L153, fed by L127.** L127 sets the
target face width to the body's skull width at 45% of the way from head top to chin, times
`face_fill` 0.86: row 213 of `body_base.png` is 336 px wide, so `face_w` = 288.96 (the same figure
Codex measured). L153 then scales every wig so that its face opening is exactly `face_w` wide:
`scale = lm["face_w"] / (hx1 - hx0)`. The canon wigs are drawn with openings narrower than that,
because a wig's side hair covers the sides of the skull: measured on the canon sheet, the
openings are 229 px (`hair_crown`), 251 (`hair_pigtails`), 259 (`hair_short`) and 261
(`hair_braids`), 68% to 78% of the skull width. So the rule enlarges every canon wig by 11% to 26%:
`hair_crown` by 288.96 / 229 = 1.26, which is exactly its measured enlargement on the frame (crop
402 px wide on the sheet, 509 px on the frame). The canon sheet draws the body and the wigs at one
scale, and the body is cut unscaled (L137-139), so the correct scale for every canon wig is 1.0.
L155 then puts the bottom of the opening on the guessed chin (neck minus 8, L123), so the
enlargement grows downward: `hair_crown` already reaches the hips on the sheet, and on the frame
its lowest row is y 647, 111 px above the soles. Because the wig is one layer stacked over the
dress (`project/scripts/systems/paper_doll.gd` L13; 3.3), everything below the chin covers the
torso and the dress. Together these produce the blob in the screenshot.

**Why the wardrobe shows only three rows.** `project/scripts/ui/wardrobe.gd` L35-40 never gives
the body a row; L48 hides any row with fewer than two options; `project/data/outfits.json` lists
only `"none"` for top, bottom, shoes and hat, because no wardrobe sheet has been rendered and
landed. That leaves hair, dress and accessory. The rows in `scenes/ui/wardrobe.tscn` carry only a
value label (`Hair/Value`, ...) and no slot name, which is why they read "Crown, White, None". The
scene is a `CanvasLayer` (layer 10) holding a `Panel` and nothing behind it, so the world is not
dimmed.

### 3.1 Matting

- **The green key's alpha is discarded.** `land_wardrobe.mjs` L401 fills everything within 12%
  of 00FF00 with white. The edge pixels where the warm-brown outline was antialiased into green
  are either turned white (inside the fuzz) or kept as greenish brown (outside it); the soft
  coverage information is gone before the cutter sees the sheet.
- **White is then treated as background.** `cut_paperdoll.py` L68 marks every pixel whose minimum
  channel exceeds `white_threshold` (232, L205) as white, L69-71 clears the white connected to the
  crop border, and L72 grows the cleared area one pixel into anything above 192. Light garment
  edges (white dresses, cream, butter yellow) that touch the outline's antialiasing are eaten, and
  the light antialiased pixels that survive form a speckled light fringe. Measured on the
  outermost opaque ring of each part (where an outlined drawing has only outline colour), the
  share of light pixels (grey above 70%) is 14.4% on `body_base.png` (361 of 2515), 27.1% on
  `hair_pigtails.png` (780 of 2882), 14.3% on `dress_uniform.png` (181 of 1270) and 7.3% on
  `dress_white.png` (83 of 1130). On a dark background the fringe is visible as a dotted light
  edge around the doll.
- **Alpha is binary.** L79 writes alpha 0 or 255. The body is placed at scale 1.0 (L137-139), so
  `body_base.png` has exactly 2 alpha levels: a stair-stepped edge. The other parts have 240-256
  levels only because LANCZOS resampling (L177) blurred a binary mask, which is not antialiasing.
- **Enclosed background stays opaque white except in hair.** L80 and L147-151 clear the face
  opening and gaps of 200 px or more, but only for `hair_*`. A garment with an enclosed opening
  keeps it as opaque white: the delivered `char_mother_layers.png` gown has an enclosed green
  V-neck, which this path turns into a white patch.
- **Small parts are deleted.** L74-78 drop every component smaller than 10% of the largest one in
  the crop. Codex measured the Daughter's sandals at 10.48% and 10.33% of the dress area
  (issue #1, 11:08 UTC): one smaller shoe and it would silently vanish.
- **The canon source is a JPEG on white.** `DEFAULT_SHEET` (L53) is
  `dev/art/canon-gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg`; every canon part carries
  JPEG ringing at its outline into the white threshold.

### 3.2 Placement

- **Landmarks are guessed from row widths.** `landmarks()` (L114-129) takes the widest row in the
  top 60% as the head, the narrowest row below it as the neck, the chin as the neck minus a
  constant 8 frame px (`chin_above_neck`, L123), and the face width as the head width at 45% of
  head top to chin times 0.86 (`face_fill`, L127). These constants were tuned on one body.
- **Dresses are stretched to the soles.** L140-146 scale every `dress_*` so its own bounding box
  runs from the collar (neck minus 14) to the feet. A knee-length dress delivered without shoes
  (the Daughter's sundress, with the sandals as separate items) is stretched to floor length. The
  rule only works when the crop holds dress and shoes together, which is exactly where the 10%
  component drop (3.1) bites. Centring is by bounding-box centre (L145), so an asymmetric garment
  (a bow on one side) is pushed off the body's centre line.
- **Hair is fitted by one width.** L149-155 scale a wig so its face-opening bounding box equals
  the guessed face width, bottom on the guessed chin. Nothing checks the head width, the
  hairline, the ears, or the scale of the sheet the wig was drawn on. This is the cause of the
  oversized hair in the live wardrobe (3.0).
- **Hats and accessories are hand-placed numbers.** L156-161 use a hand-measured `anchor` and
  `scale` per item (`acc_bow`: `[-120, 40]`, 0.6, `paperdoll_parts.json` L10), relative to the
  bald head. The anchor does not follow the hair the item is worn with.
- **Tops, bottoms and shoes trust the renderer's layout.** L162-169 put an item at the height on
  the frame where it stood beside the reference doll on the sheet. Image models do not place
  elements precisely in layout-sensitive compositions (OpenAI's own guide says so, section 4.2).
  Both shoes are one item centred on the body; there is no per-foot placement (Codex had to
  re-render the Daughter's sandals to fix their spacing, issue #1, 09:40 UTC).
- **Every part is resampled at its own scale.** L176-177 resize each part by its own factor; the
  rig then resizes every frame again to 364×384 (`gen_player_rig.py` L218). Two lossy resamples
  per pixel, at different factors per layer.
- **Clipping is a warning.** `on_frame()` (L181-193) prints how many pixels fell off the frame
  and writes the part anyway.
- **The frame has no headroom.** The frame is the union of the canon parts' boxes (L237-240), so
  the tallest part defines its top: `hair_crown.png` spans frame x 121-630 and touches row 0. A
  hat worn over that hair has nowhere to go above it and would be clipped, with only the warning
  above.

### 3.3 Layering

- **Hair is one layer above the dress.** `paper_doll.gd` L13 stacks `hair` after `dress`, and
  every wig is cut as one image. Any hair below the chin covers the neck and torso. In a
  composite of the committed parts, `hair_short` covers the chin and neck like a beard, and
  `hair_crown` over `dress_robe` covers the torso and most of the dress.
- **Garments carry their own limbs.** `dress_uniform.png` contains drawn legs, socks and hands.
  Stacked on `body_base`, its socks are narrower than the body's legs, so the body's legs show on
  both sides of them, and the body's hands show beside the uniform's own hands at the cuffs.
  Nothing in the pipeline detects skin inside a garment.
- **The body never changes shape, but characters do.** Commit 8691683 (`cut_paperdoll.py`
  L273-290) fits a layered sheet's own body to the canon body's height, head top and centre, and
  fits that sheet's items to it. But the game has one frame, wardrobe items are fitted to
  `body_base`, and `paper_doll.gd` has no body type. Measured after the same height fit, the
  Daughter's body overlaps the canon body at IoU 0.90 (head about 10% wider) and the Mother's at
  IoU 0.83 (head 8% narrower, neck 27 px higher, hands 34 px higher, on a 698 px tall body). A top
  fitted to `body_base` would sit 27 px low on the Mother's neck.

### 3.4 Rigs

`gen_player_rig.py` derives the side view by squeezing the front art horizontally (`narrow()`,
L92-100) and the side face by cutting an ellipse out of the hair (L143-155). The back view of
every garment and accessory is the front art unchanged (L213, L215), so a tee's front print shows
on her back. The back of the hair is the front hair with its openings filled in its median
colour (L103-128).

### 3.5 Process

- Every item needs hand-measured crops before anything runs (`land_wardrobe.mjs` L18-24).
- Landing needs a Python environment with numpy, scipy and Pillow (L364-371, L430, L493).
- The prompts' Notes promise a 2752×1536 sheet and a 721×760 frame contract that the current
  render agents cannot meet (no size control; 1678×937 and 1672×941 delivered).
- The tests (`tools/test_paperdoll_tools.py`) check the placement rules on synthetic shapes, not
  the quality of an assembled outfit. Nobody sees an assembled outfit until a screenshot is taken
  by hand.

### 3.6 Reproducing the evidence

From `project/assets/canon/` (ImageMagick 7):

```bash
O=../../../.cache/doll_qa; mkdir -p $O   # the repo's .cache/ (gitignored)
# Composite defects: hair over torso, double legs and hands, the fringe on dark blue.
magick body_base.png hair_short.png -composite -background '#334466' -flatten $O/x1.png
magick body_base.png dress_robe.png -composite hair_crown.png -composite acc_bow.png -composite -background '#334466' -flatten $O/x2.png
magick body_base.png dress_uniform.png -composite hair_pigtails.png -composite -background '#334466' -flatten $O/x3.png
# Alpha levels of a part (2 for body_base).
magick body_base.png -alpha extract -format %k info:
# Light pixels on the outermost opaque ring.
magick body_base.png -alpha extract -threshold 50% -morphology EdgeIn Diamond:1 $O/band.png
magick body_base.png -alpha off -colorspace Gray -threshold 70% $O/light.png
magick $O/band.png $O/light.png -compose Multiply -composite -format '%[fx:round(mean*w*h)]' info:
magick $O/band.png -format '%[fx:round(mean*w*h)]' info:
# 3.0: the skull width L127 measures (row 213: 336 px), and a wig's face opening on the canon
# sheet (the enclosed white component not touching the crop edge; hair_crown: 229 px wide).
magick body_base.png -alpha extract -threshold 50% -crop 721x1+0+213 +repage -format '%@\n' info:
magick ../../../dev/art/canon-gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg -crop 402x511+1095+81 +repage \
  -channel RGB -separate -evaluate-sequence min -threshold 91% \
  -define connected-components:verbose=true -define connected-components:area-threshold=2000 \
  -connected-components 4 null:
```

The body IoU figures came from keying the bodies off `char_daughter_layers.png` and
`char_mother_layers.png` (gnomatix/cloud-persistint `drop/prompts/image/characters/assets/`),
keeping the largest component, scaling to 698 px tall, aligning head tops and centres with
`body_base`, and comparing masks.

## 4. What the research says

### 4.1 How dress-up and cutout games register layers

- **Same canvas for every item, one origin.** Picrew, the most widely used layered avatar maker,
  requires every item image of a part to be the same size, because every image is placed from
  the upper-left corner; items exported at their own size come out misaligned
  (https://support.picrew.me/en/create_imagemaker/create_first_image). This is what the 721×760
  frame already is. The frame is right; what is missing is a way to get items drawn on it.
- **Skins and slots (Spine).** Spine models mix-and-match clothing as skins: a skin is a set of
  attachments active while it is visible, several skins can be combined at runtime into one, and
  each attachment is positioned through bones, so swapped items line up
  (https://en.esotericsoftware.com/spine-skins). The vocabulary (slot, skin, placeholder, one
  attachment per slot per skin) is worth mirroring in our data; the tool is not needed for a
  front-facing doll with two-frame idles. Spine is a paid editor, and the spine-godot runtime is
  built per Godot version (https://esotericsoftware.com/spine-godot).
- **Godot Skeleton2D and Polygon2D.** Godot's own cutout path binds each Polygon2D to one
  Skeleton2D, weights its points per bone, and orders layers by node order; several layers can
  share one skeleton (https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html).
  This is the route if the doll ever needs real deformation (a walk that bends sleeves). It needs
  each layer meshed and weighted, so it is not part of this proposal.
- **Layered files.** OpenRaster stores a canvas size and a stack of PNG layers with x/y offsets in
  a zip (`stack.xml`, https://www.openraster.org/baseline/layer-stack-spec.html); Krita and GIMP
  read and write it, and Godot can open a zip with `ZIPReader`
  (https://docs.godotengine.org/en/4.2/classes/class_zipreader.html). PSD importers for Godot found
  in this search either flatten the file or shell out to Python's psd-tools
  (https://github.com/nklbdev/godot-4-importality/wiki/importing-psd-with-psd-tools-(en)), so PSD
  is not a fit. ORA is a candidate for a hand-fix round trip (task 13), not for intake.

### 4.2 Getting image models to draw registered layers

- **OpenAI image generation.** Editing takes one or more input images; a mask applies to the first
  image; masking is entirely prompt-based and the model may not follow the mask's exact shape; the
  model may have difficulty placing elements precisely in structured or layout-sensitive
  compositions; output can have a transparent background (PNG or WebP); custom sizes are
  multiples of 16 between 1:3 and 3:1, with 1024×1536 among the recommended sizes
  (https://developers.openai.com/api/docs/guides/image-generation). Consequence: an input
  template steers the drawing onto the body, but the pipeline must measure and correct, and must
  be able to reject.
- **Gemini image models.** Up to 14 reference images per request (Nano Banana 2.1: up to 10
  object and 4 character images), editing by text prompt, 1K/2K/4K output; the guide does not
  describe masks, precise placement or alpha output
  (https://aistudio.google.com/docs/image-generation).
- **Grok.** No page on docs.x.ai was retrieved. Third-party wrappers describe a Grok image-edit
  endpoint that takes 1 to 3 reference images as URLs or base64 in a JSON body
  (https://docs.oxen.ai/inference-api/reference/models/xai-grok-imagine-image-edit.md,
  https://www.atlascloud.ai/it/blog/case-studies/grok-xai-image-editing-capabilities). Unverified;
  see the open questions.
- **Layer decomposition models.** Qwen-Image-Layered splits one image into RGBA layers
  (Apache-2.0), but runs on Python, diffusers and CUDA, and is not designed to control what each
  layer contains (https://github.com/QwenLM/Qwen-Image-Layered). Not usable here (no GPU, no
  Python), and it would not produce slot-specific layers anyway.

### 4.3 Matting without Python

- **Chroma keying done properly.** On a known flat backing colour, alpha and the foreground colour
  can be solved per pixel (Smith and Blinn, Blue Screen Matting, SIGGRAPH 1996,
  https://www.alvyray.com/Papers/CG/blusig96.pdf). For warm-brown outlines on pure 00FF00 the
  green excess `G - max(R, B)` is a clean coverage signal; the antialiased edge colour can be
  unmixed from the known green instead of thresholded. This is deterministic, needs no model and
  is the main matting tier below.
- **BiRefNet in Node.** ToonOut is BiRefNet fine-tuned for anime characters; an ONNX export with
  an fp16 file and an onnxruntime-node example exists (input `image` 1×3×1024×1024 float32 with
  ImageNet normalization, output `mask` 1×1×1024×1024), MIT licensed
  (https://huggingface.co/sprited/birefnet-toonout-onnx). Suitable as a fallback tier.
- **RMBG-2.0 is non-commercial.** Its weights are CC BY-NC 4.0; commercial use needs an agreement
  with BRIA (https://huggingface.co/briaai/RMBG-2.0). Excluded.
- **Go.** onnxruntime_go wraps ONNX Runtime from Go with cgo and a matching shared library
  (https://github.com/yalue/onnxruntime_go). It works, but adds a second toolchain for no gain over
  onnxruntime-node.
- **sharp** (libvips) composites with Porter-Duff blends and raw pixel buffers
  (https://sharp.pixelplumbing.com/api-composite). It would be the npm choice if ImageMagick were
  not already a repo requirement; it is not needed.

### 4.4 Automated QA for assembled outfits

- Godot 4's `--headless` uses the dummy rendering server and cannot render or read viewport
  pixels (https://forum.godotengine.org/150510/godot-headless-not-same-godot-window-cant-render-the-backend).
  Godot's `Image` class is CPU-side and works headless: `load_from_file`, `blend_rect`,
  `blit_rect_mask`, `get_used_rect`, `resize` with `INTERPOLATE_LANCZOS`, `get_pixel`,
  `save_png`, and `compute_image_metrics` (max, mean, RMS, PSNR between two images)
  (https://docs.godotengine.org/en/stable/classes/class_image.html). So pixel checks run headless;
  screenshots of the real game need a display.
- The repo already renders real screenshots: `tools/shot_walk.sh` runs Godot under
  `xvfb-run -s "-screen 0 1280x720x24"` with the OpenGL renderer, one process per shot, from a
  JSON shot list (`project/scripts/test/shot_walk.gd`). That is the proven path for in-game QA.

## 5. The proposed pipeline

### 5.1 Principles

1. **Register before drawing, verify after.** The image agent draws on the canonical body; the
   pipeline measures how far the agent drifted, corrects small drift, and rejects large drift.
   No placement rule guesses where an item belongs.
2. **One rig per body type.** A rig is the canonical body, its landmarks, its regions and its
   template. Every wardrobe item is drawn for a rig and fits every character on that rig.
   Characters on a rig differ by skin tone, face, hair and outfit (recommendation; see open
   question 1).
3. **Keep the alpha.** Matte once, softly, at the source resolution; resample once, in
   premultiplied alpha, to the frame.
4. **Nothing silent.** No component is dropped by an area rule, no part is clipped with a warning,
   no art set falls back as a whole. Every rejection names the item, the check and the number.
5. **What is tested is what ships.** Pixel QA composes layers by the same manifest the game reads,
   and the in-game screenshot is compared against that composite.

### 5.2 The rig

The first rig is `chibi`, defined on the existing 721×760 frame so the game does not change:

- **Body:** `body_base` (the canon body; re-matted in migration, section 8).
- **Landmarks** (frame px, measured by tool from the body mask and the face, then checked by eye):
  head top (367, 61), head centre x 367, eye centres, brow line, chin y about 398, neck y about
  406, shoulders, wrists, hands (about y 540-575, x 163-564), waist, hip, crotch, knees, ankles,
  soles y 758, legs x 273-455. The values already in `.claude/skills/gemini-assets/SKILL.md`
  and Codex's 12:03 measurement are the starting point.
- **Regions:** a label image on the frame, one label per body pixel: head (the skull above the
  brow line), face (the skin from the brow line to the chin inside the head outline), eye band
  (eyes and brows, carved out of the face), ears, neck, torso, upper arm L/R, forearm L/R,
  hand L/R, hips, thigh L/R, shin L/R, foot L/R. Derived from the landmarks (horizontal bands at
  landmark rows, arms split from the torso by the armpit columns) and the body mask, written as a
  PNG for review, hand-touched if a band cuts badly.
- **Template:** a 1024×1536 portrait PNG (an OpenAI-recommended size, a multiple of 16) with the
  body on pure 00FF00 at a documented placement: frame scale 1.6, so the body is about 1117 px
  tall, head centre at template x 512, frame origin at template (-75.2, 160). The template covers
  frame x 47-687 and frame y -100 to 860: narrower than the frame (the widest current part,
  `hair_crown`, spans frame x 121-630, so everything fits) and 100 px taller above it, so hats are
  drawn with headroom the current frame lacks (open question 10). The body in the template is the
  rig body upscaled once with Lanczos, or a
  high-resolution redraw if approved (open question 2). A back-view template is added only if
  back views are rendered rather than derived (open question 5).
- **Slot rules:** per slot, the regions an item must cover, may cover and must never cover, an
  overhang allowance beyond the body outline, and its layer(s) in the stack. These drive both the
  render brief and the QA (5.10).

| Slot | Must cover | Never covers | Layers |
|---|---|---|---|
| top | torso | face, eye band, hands | top |
| bottom | hips | face, torso above waist | bottom |
| dress | torso, hips | face, eye band, hands | dress |
| shoes | foot L, foot R (each foot is placed and checked separately) | anything above the shins | shoes |
| hair | (hairline above the brow) | eye band; more than 3% of the face (side locks may overlap the cheek edge); in the front layer, neck and torso unless the item's front mask allows | hair_back (under the body), hair (front) |
| hat | head top | eye band | hat |
| accessory | declared per item | eye band unless declared (glasses) | accessory |

Stack order becomes `hair_back, body, shoes, bottom, top, dress, hair, hat, accessory`: the
current `PaperDoll.LAYERS` with one layer added under the body.

### 5.3 The render brief and template given to image agents

Per item (or per outfit, when pieces belong together), the agent receives:

1. The rig template PNG.
2. The style block every prompt already carries (`.claude/skills/gemini-assets/SKILL.md`, style
   keywords), unchanged.
3. The item: id, slot, description, palette.
4. The slot rules in words, generated from the rig's slot table: what the item covers on this doll,
   that it follows her pose exactly (arms angled down about thirty degrees, sleeves following the
   arms and ending at the wrists, hands left bare), and what it must not contain: no skin, hands,
   feet, legs or face inside a garment; nothing green, lime or mint; complete warm-brown outline.
   For hair: the face left bare from the brow down; locks that fall behind the shoulders drawn as
   hanging behind. For a hat or accessory: worn where it belongs on this doll, with the hair named
   in the brief when it matters.
5. The output protocol:
   - **A, the proof** (`<id>.proof.png`): the template edited so the doll wears the item. The
     doll, her pose, size and position, the canvas and the green background are unchanged.
   - **B, the item** (`<id>.item.png`): the same canvas with the doll removed: only the item,
     exactly where it is in A. Transparent background if the agent's tool offers transparent
     output; otherwise pure 00FF00.
   - **C, provenance** (`done/<id>.json`): the existing format, plus the native sizes of A and B,
     the tool, and whether B is transparent.

A brief is a file like the current prompts, `prompts/image/doll/<id>.md`, with front matter
(`id`, `slot`, `rig`, `template` and its SHA-1, `drop` paths for A and B) and the text above. It is
generated from the catalog entry by `tools/doll/brief.mjs`, so the slot rules in every brief match
the rig's numbers.

The agent's own pass/fail check stays (issue #1 shows Codex already reports components, openings
and clipping). The pipeline's intake report is posted back on the same thread: pass, or the
failed check with its number.

**Legacy layered sheets** (the delivered `char_daughter_layers.png`, `char_mother_layers.png`,
`host_oprah_garments.png`, and any sheet still made in the old format) have no proof. They go
through the fallback registration in 5.7 and are reviewed in the Doll Bench before landing.

### 5.4 Intake

`tools/doll/intake.mjs` reads a drop (A, B, C, or a legacy sheet) and writes a JSON report beside
it plus a one-line verdict:

- Files present, PNG, provenance JSON valid, SHA-1 recorded.
- Native size noted; no size is required (registration handles scale).
- Background: the share of border pixels within a small distance of the measured green, and the
  spread of the background colour across the image (gradient, shadow or vignette fail).
- Green inside items: opaque pixels with green excess above a threshold that are not on an edge.
- Components: count, sizes, bounding boxes, edge contact, minimum gap between items. The brief
  says how many pieces to expect; a mismatch fails with the list of what was found. No
  component is ever dropped for being small; specks far from any item are listed.
- For a proof pair: B's item must appear in A (5.7 checks it numerically).

### 5.5 Matting

Three tiers, tried in order:

1. **Transparent output from the generator.** Where the agent's tool returns B with real alpha,
   use it. The intake still checks for a halo (the outer-ring light-pixel ratio) and for
   semi-transparent interior pixels.
2. **Chroma unmix on pure green** (the default, `tools/doll/lib/matte.mjs`). Measure the backing
   colour K from the border. Per pixel, coverage from the green excess `e = G - max(R, B)`
   between two thresholds calibrated on K and on the outline colour; foreground colour recovered
   as `F = (C - (1 - a) K) / a`, then despilled (green clamped to `max(R, B)`, as the current
   command does). Enclosed green (face openings, the Mother's V-neck) becomes transparent with no
   flood fill; white and cream garments are untouched because they have no green excess.
   For legacy white-background sources (the canon JPEG), the same unmix runs against white, but
   only in a band a few pixels wide along the outer boundary found by flood fill from the border,
   because inside an outlined drawing white is content.
3. **ML matte, optional** (`onnxruntime-node` with the ToonOut BiRefNet fp16 export). Used only
   when intake reports a background that is not flat (shadow, gradient), or as a cross-check: if
   the chroma matte and the ML matte disagree by more than a set IoU, the item is flagged. Needs a
   `package.json` and the model file, so it waits for approval (open question 9) and for a render
   that needs it.

Matting runs at the source resolution. Resampling to the frame happens once, after registration,
with alpha weighting: ImageMagick 7 already resizes RGBA this way (checked here: a fully
transparent green neighbour does not tint the edge colour of a resized opaque area). Lanczos
overshoots alpha slightly past 0 and 1 in the HDRI build, so alpha is clamped before writing.

### 5.6 Segmentation

Connected components on the matte with a small merge distance (so a pair of earrings or a hat's
separate flower stays with its item when the brief says so). For a proof pair there is one item
per B, or the outfit's pieces, assigned by region: the component over foot L is shoe L, and so on.
For a legacy sheet, items are assigned left to right in the order the brief lists them, the body
first. The expected count comes from the brief; the 10% rule is gone.

### 5.7 Registration to the rig

**Proof path (new renders).**

1. Fit A to the template. The transform is translation plus uniform scale (rotation is checked to
   be under 1 degree and otherwise rejected). Seed it from the two eye centres (dark compact blobs
   inside the template's face window, which every proof shows) and the soles; refine by chamfer
   matching the outline of A's opaque silhouette against the template body's outline, using only
   the regions the item's slot never covers (head and legs for a top; torso and feet for a hat).
   The residual is the mean outline distance in frame px.
2. Align B to A. If B has A's size and the item sits at the same place (the usual case), the
   transform is the identity; otherwise chamfer-match B's item outline against A's edges. Cross
   check: the difference between A and the template (after step 1) must cover B's item with IoU of
   at least 0.9, which catches an item that changed between the two images.
3. Compose the transforms, map B's matte to the frame, resample once.
4. Gates (starting values, tuned in the pilot): reject when the correction exceeds 4% scale or 2%
   of the canvas size in translation, when the residual exceeds 1.5 frame px, or when the
   cross-check fails. A rejected item goes back to the agent with the numbers, not to a hand fix.

**Fallback path (legacy layered sheets, no proof).**

1. Fit the sheet's body to the rig body the same way (eyes, soles, chamfer on the whole outline).
   This gives the sheet's scale and the body's position. The body residual is recorded and flagged for review above 1.5 px, not used as a fallback rejection gate. The Daughter pilot measures about 5.49 px because her drawn head, ears, hands and feet differ from the rig, which uniform registration cannot remove.
2. Place each item from that scale by a slot anchor: the neck opening's centre on the neck
   landmark for tops and dresses, the waistband on the waist for bottoms, each shoe's sole on its
   own sole landmark, the face opening on the face region (centre and width) for hair, the head
   top for hats.
3. Refine translation within a small window (and scale within 8%) by maximizing the slot's coverage
   score against the rig regions (5.10). Hair keeps the sheet scale and horizontal centre fixed, but searches vertically from 80 px
   above to 20 px below the face-opening/chin seed. Fit the cranium while protecting the dilated
   eye blobs and the visible face (at most 3% overlap); record uncovered cranium, overlap and
   clipping failures. The former crown reference is withdrawn: it compared two equally low
   placements (bd 1rjz.5). Pixel QA and the contact sheet are the acceptance.
4. Show the result in the Doll Bench; a person accepts, nudges, or sends it back for a proof
   render. The nudge is recorded in the item record.

The fallback replaces `landmarks()`, the per-prefix rules, the hand-measured crops and the
hand-measured hat and accessory anchors. It is expected to be the minority path once briefs move
to the proof protocol.

### 5.8 Layer derivation

- **Hair split.** A wig becomes `hair_back` (under the body) and `hair` (front). Default rule:
  hair pixels below the rig's chin line go to the back layer, the rest to the front. A per-item
  front mask (painted in the Doll Bench) keeps locks that should fall over the chest in front,
  such as the canon braids. This fixes the beard and torso cover seen in 3.3.
- **Skin tones.** Per character, the rig body is recoloured in its skin region (the face and
  limbs, not the outline, eyes, blush or underwear) to the character's tone, written as
  `body_base__<tone>.png`. Offline, so the game needs no shader.
- **Full-frame output.** Every layer is written as a 721×760 RGBA PNG, as now. The game's equal
  frame assumption holds and the player rig generator keeps working during migration.

### 5.9 Assembly in Godot

- `PaperDoll` reads layers from the catalog (section 7) instead of inferring them from file names:
  each worn item contributes one or two layers, inserted in stack order; `hair_back` sits under
  `body`.
- A character record (rig, body, skin tone, default outfit) replaces the hard-coded
  `DEFAULT_OUTFIT` (`paper_doll.gd` L21-22) as the source of what the player and NPC dolls wear.
- A missing part shows that slot empty and logs an error, instead of switching the whole doll to
  the placeholder set (`art_dir_for`, L73-83).
- The wardrobe shows one labelled row per slot, the body included, whether or not the slot has a
  choice yet (A1.4), over a dimming backdrop (A1.5). The body row lists the rig's bodies (skin
  tones). Which items each row offers still comes from `outfits.json`.
- A small `DollComposer` GDScript class composes the same layer list into an `Image` with
  `blend_rect`, for tests and thumbnails, so the game and the checks share the stacking code.
- Player rigs: the current generator is regenerated from the full-frame output until it is ported
  (task 12). The port reads the catalog, keeps `rig_walk`'s motion, and changes the back view of
  printed garments (open question 5).

### 5.10 QA

**Pixel checks, headless** (`project/tests/test_doll_qa.gd`, run by `tools/run_tests.sh`; reads the
catalog and the rig, composes with `DollComposer`):

Per item:

- Nothing on the frame border (alpha above zero in the outermost row or column fails: a touching
  item may have been clipped). Today `hair_crown` fails this by construction of the frame (3.2).
- Antialiased edge: at least 32 distinct alpha levels on the item's boundary.
- Fringe: light pixels on the outermost opaque ring at most 2% (today 14-27%, section 3.1).
- Green residue: no pixel with alpha above 0.1 and green excess above 24.
- Skin leak (garments only): pixels within a small colour distance of the rig's skin palette at
  most 0.5% of the item's area. This is the check that catches `dress_uniform`'s drawn legs and
  hands.
- Stray components: none smaller than 0.1% of the item farther than 8 px from the item, unless
  the item declares them.

Per item worn on the body (body plus item, in stack order):

- Coverage: body pixels left visible inside each region the slot must cover, at most 0.5% (for
  example the torso under a top).
- Forbidden overlap: item pixels inside regions the slot never covers, within the slot table's
  limits (hair or a hat over the eye band fails; front-layer hair over the neck or torso outside
  its front mask fails, which is the check that catches today's single-layer wigs).
- Overhang: item pixels farther outside the body outline than the slot's allowance.

Per combination (hair with hat, hair with dress or top, top with bottom):

- Eye band clear, skin leak on the composite, and the hat-over-hair rule (a hat must cover the top
  of the hair it sits on, so no hair shows through above the crown).
- A contact sheet PNG of the combinations checked, written to `.cache/doll_qa/`, for review.

Scope, so the test stays fast as the wardrobe grows: the per-pixel counts are GDScript loops over
a 548k-pixel frame, so the default run checks every item alone plus the pairs that involve an item
changed since the last approved baseline (each changed item against every item of the paired
slots). The full matrix (every pair) runs behind an explicit flag (`DOLL_QA_FULL=1`) before a
release. Region counts run on the label map and the composite at half scale; the frame-border,
fringe and alpha-level checks run at full scale.

**In-game screenshots** (`tools/shots/doll.json`, run with `tools/shot_walk.sh` under Xvfb): open
`scenes/ui/wardrobe.tscn` with `outfit_*` flags set per outfit and snap the preview; snap a stage
figure at 192 px; snap the player at 48 world px with the rig frames. Each game shot is compared
with the `DollComposer` composite of the same outfit at the same size with
`Image.compute_image_metrics` (or `magick compare -metric RMSE`), which proves the game stacks
what the checks checked. Approved contact sheets are kept as baselines; a change to any item
shows up as a diff image.

**Review loop.** The landing summary links the contact sheet; the coordinator posts it on the
render thread, as is already done by hand. The Doll Bench (task 11) shows any item on the rig with
the regions and the failing pixels overlaid.

### 5.11 Landing

`tools/doll/land.mjs` replaces the key, cut and register steps of `land_wardrobe.mjs` and keeps its
shape: one command, `--dry-run`, `--root` for tests, idempotent writes, a per-item summary
(LANDED, UNCHANGED, REJECTED with the reason, MISSING), exit 0 only when nothing failed. Steps per
item: intake, matte, segment, register, derive, write PNGs to `project/assets/doll/`, write the
catalog and `SOURCES.md` rows, then once: rig, bake, import, QA.

## 6. Stack choice

| Choice | Used for | Why |
|---|---|---|
| Node 24, `.mjs`, built-ins only | intake, matting, segmentation, registration, brief generation, landing | The repo's tools are already Node (`land_wardrobe.mjs`, `lib_paths.mjs`, `set_texture_imports.mjs`, `gen_sources.mjs`, their `test_*.mjs`), Node is in mise, and typed-array loops are fast enough for 1-2 megapixel images (chamfer matching on outline points against a distance transform is a few hundred million operations at worst). No `package.json` exists today and none is needed for the core. |
| ImageMagick 7 | PNG decode/encode as raw RGBA streams (`magick in.png -depth 8 rgba:-`), alpha-weighted resampling | Already required (`land_wardrobe.mjs` L401, `tools/bake_paper.sh`). Avoids adding a PNG codec or sharp. |
| Godot 4.6, GDScript | runtime `PaperDoll` and `DollComposer`; headless pixel QA tests; Doll Bench editor plugin; in-game screenshots | The game's own stacking is the thing to test. `Image` works headless for pixel checks; screenshots use the existing Xvfb shot walk. An editor plugin shows exactly what the game shows. |
| onnxruntime-node + ToonOut BiRefNet ONNX (optional) | ML matting fallback | Runs in Node without Python; MIT licence; tuned for anime-style characters. Only behind approval, a `package.json` and a model file kept outside Git (open question 9). |

Not chosen:

- **Python** (the current cutter and rig generator): not approved for new work. Retired, not patched.
- **Go**: a second toolchain with cgo for ONNX; no speed problem to solve at these sizes.
- **sharp**: a native npm dependency doing what ImageMagick already does here.
- **Spine, DragonBones**: built for animated cutout skeletons; the doll is a front-facing static
  stack. Spine's vocabulary is borrowed, the tool is not.
- **Skeleton2D and Polygon2D**: the right path only if layers must deform; listed as a later option.
- **PSD import**: available importers flatten or need Python.
- **RMBG-2.0**: non-commercial licence.
- **Mask inpainting with an open diffusion model** (exact masks): needs Python and a GPU here.

## 7. Data format

Three JSON files under `project/data/doll/`, written by the tools and read by the game. Layer
images are 721×760 RGBA PNGs in `project/assets/doll/`. Sources (briefs, proofs, items,
provenance) stay outside `project/` under `prompts/image/doll/`, as drops do today.

### 7.1 The rig: `project/data/doll/rig_chibi.json`

```json
{
  "id": "chibi",
  "frame": [721, 760],
  "body": "body_base",
  "layers": ["hair_back", "body", "shoes", "bottom", "top", "dress", "hair", "hat", "accessory"],
  "landmarks": {
    "head_top": [367, 61], "centre_x": 367,
    "eye_l": [0, 0], "eye_r": [0, 0], "brow_y": 0,
    "chin_y": 398, "neck_y": 406, "shoulder_y": 0, "waist_y": 0, "hip_y": 0, "crotch_y": 0,
    "wrist_l": [0, 0], "wrist_r": [0, 0], "knee_y": 0, "ankle_y": 0,
    "sole_l": [0, 758], "sole_r": [0, 758]
  },
  "regions": {
    "file": "project/assets/doll/rig/chibi_regions.png",
    "labels": {"head": 1, "face": 2, "eye_band": 3, "ears": 4, "neck": 5, "torso": 6,
               "upper_arm_l": 7, "upper_arm_r": 8, "forearm_l": 9, "forearm_r": 10,
               "hand_l": 11, "hand_r": 12, "hips": 13, "thigh_l": 14, "thigh_r": 15,
               "shin_l": 16, "shin_r": 17, "foot_l": 18, "foot_r": 19}
  },
  "slots": {
    "top":       {"covers": ["torso"], "never": ["face", "eye_band", "hand_l", "hand_r"], "overhang_px": 16, "layers": ["top"]},
    "bottom":    {"covers": ["hips"], "never": ["face", "torso"], "overhang_px": 24, "layers": ["bottom"]},
    "dress":     {"covers": ["torso", "hips"], "never": ["face", "eye_band", "hand_l", "hand_r"], "overhang_px": null, "layers": ["dress"]},
    "shoes":     {"covers": ["foot_l", "foot_r"], "per_side": true, "never": ["thigh_l", "thigh_r"], "overhang_px": 12, "layers": ["shoes"]},
    "hair":      {"covers": [], "never": ["eye_band"], "max_share": {"face": 0.03}, "front_never": ["neck", "torso"], "split": "chin_y", "layers": ["hair_back", "hair"]},
    "hat":       {"covers": [], "anchor": "head_top", "never": ["eye_band"], "layers": ["hat"]},
    "accessory": {"covers": [], "never": ["eye_band"], "layers": ["accessory"]}
  },
  "skin": {"base": [[0, 0, 0]], "tones": {}},
  "template": {
    "file": "prompts/image/doll/template_chibi_front.png",
    "size": [1024, 1536], "frame_scale": 1.6, "frame_origin": [-75.2, 160],
    "sha1": ""
  }
}
```

Zeros are placeholders that task 1 measures. Slot names equal `PaperDoll.LAYERS` plus
`hair_back`, so the slot rule of `PaperDoll.slot_of` (prefix before the first underscore, `acc`
for the accessory) still names an item's slot.

### 7.2 Items: `project/data/doll/items.json`

One entry per wearable item, keyed by id (the id keeps its slot prefix):

```json
{
  "top_tee_heart": {
    "slot": "top",
    "rig": "chibi",
    "layers": [{"layer": "top", "file": "res://assets/doll/top_tee_heart.png", "bbox": [215, 392, 290, 160]}],
    "covers": ["torso", "upper_arm_l", "upper_arm_r"],
    "source": {
      "method": "proof",
      "brief": "prompts/image/doll/top_tee_heart.md",
      "proof": "prompts/image/doll/assets/top_tee_heart.proof.png",
      "item": "prompts/image/doll/assets/top_tee_heart.item.png",
      "provenance": "done/top_tee_heart.json",
      "agent": "codex",
      "sha1": {"proof": "", "item": ""}
    },
    "fit": {"scale": 0.0, "offset": [0.0, 0.0], "residual_px": 0.0,
            "correction": {"scale_pct": 0.0, "shift_px": 0.0}, "nudge": [0, 0]},
    "qa": {"status": "pass", "checked": "", "failures": []}
  },
  "hair_braids": {
    "slot": "hair",
    "rig": "chibi",
    "layers": [
      {"layer": "hair_back", "file": "res://assets/doll/hair_braids__back.png"},
      {"layer": "hair", "file": "res://assets/doll/hair_braids.png"}
    ],
    "split": {"rule": "chin_y", "front_mask": "prompts/image/doll/masks/hair_braids.front.png"},
    "source": {"method": "legacy-sheet", "sheet": "dev/art/canon-gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg", "crop": "534x512+1530+99"},
    "fit": {"scale": 1.0, "offset": [0, 0], "residual_px": 0.0, "nudge": [0, 0]},
    "qa": {"status": "pass", "checked": "", "failures": []}
  }
}
```

`covers` may widen the slot's `covers` (long sleeves add the forearms) but never narrow it.
`method` is `proof`, `legacy-sheet` or `frame` (an item already drawn on the frame, such as the
Florida wearables). `fit.nudge` is the only hand-entered placement value, set from the Doll Bench.

### 7.3 Characters: `project/data/doll/characters.json`

```json
{
  "player":   {"rig": "chibi", "body": "body_base", "tone": null,
               "outfit": {"dress": "dress_white", "hair": "hair_braids"}},
  "daughter": {"rig": "chibi", "body": "body_base__warm2", "tone": "warm2",
               "outfit": {"hair": "hair_pigtails_brown", "dress": "dress_sundress_plumeria",
                          "shoes": "shoes_sandals_pink", "hat": "hat_straw_hibiscus"},
               "reference": "prompts/image/characters/assets/char_daughter.png"}
}
```

`outfits.json` keeps its role (which items the wardrobe offers per slot, `"none"` first) and lists
catalog ids. `paperdoll_parts.json` is kept, generated, only while `gen_player_rig.py` still reads
part names from it; it is deleted with the Python tools (task 14).

## 8. Migration of existing assets

| Asset | Today | Migration |
|---|---|---|
| `body_base` | cut from the canon JPEG on white; binary alpha; 14% fringe | Re-matte from the JPEG with the white boundary unmix; register the new cut to the current `body_base.png` (identity expected); replace in place. It becomes the `chibi` rig body. |
| `hair_pigtails`, `hair_crown`, `hair_braids`, `hair_short` | canon cuts, enlarged 11-26% by L153 (3.0) | Re-matte from the JPEG; register with the fallback path using the canon sheet itself as the fiducial: the sheet's body maps to the rig at scale 1.0, so each wig keeps scale 1.0 and is only translated (face opening centred on the face region, refined by coverage). Do not register to the current frame PNGs: that would keep the wrong scale. Split into back and front (`hair_braids` gets a front mask keeping the braids over the chest). `hair_crown` closes A1. |
| `dress_uniform` | carries its own legs and hands | Fails the skin-leak check. Re-render on the template through the proof protocol (preferred), or mask out its drawn legs and hands in the Doll Bench and accept the socks over the body's legs. |
| `dress_robe`, `dress_white` | canon cuts, rescaled by the collar-to-soles rule (L140-146) although drawn at the body's scale on the canon sheet | Re-matte; register at sheet scale 1.0 like the wigs (neck opening on the neck landmark, refined by coverage); QA. |
| `acc_bow` | hand anchor relative to the bald head | Re-matte; register at sheet scale 1.0; position checked against each wig by the combination check, since the wigs it sat beside change size in this migration. |
| `project/assets/florida/acc_*.png` (4) | generated on the frame | Import as `method: frame` items; QA only. |
| `char_daughter_layers.png`, `char_mother_layers.png`, `host_oprah_garments.png` | delivered in gnomatix/cloud-persistint `drop/`, not landed | Pilot the fallback path on the Daughter (body to rig, hair, dress, sandals), then the Mother (crown, earrings, infant as accessories). Their bodies supply the skin tone; whether each character keeps its own body is open question 1. |
| The 10 `char_*.png` reference sheets | NPC turnaround references | Unchanged; they are references, not doll layers. |
| The 11 wardrobe prompts in `prompts/image/wardrobe/` | not rendered | Rewritten as proof-protocol briefs by `tools/doll/brief.mjs` before they are rendered. |
| The layered-sheet queue (Father, Initiate, Priestess Betty, Barren Susan, Drone Bruce, the hosts) | assigned in the old format | Switched to proof briefs per item once task 9 lands; until then delivered sheets use the fallback path. |
| `project/assets/characters/player/*_rig.png` | from `gen_player_rig.py` | Regenerated from the full-frame output after each landing; regenerated by the Node port after task 12. |

Order: the A1 case first (section 1.1): the QA that sees the defect, the back hair layer and the
wardrobe rows, then the canon parts re-matted and re-registered at sheet scale. Then the Daughter
end to end as the first legacy sheet, then new renders only through proofs, then the rig port and
the retirement of the Python tools and `land_wardrobe.mjs`.

## 9. Tasks

Each task is sized for one implementer and ends with an acceptance test that someone else can
run. Tasks 1 to 7 close the first acceptance case A1 (section 1.1) in order. Tasks 1 to 3 have no
dependency on open questions. Task 9 (briefs and the proof pilot) needs only task 1 and can run in
parallel with tasks 2 to 8.

**1. Rig kit and render template.**
`tools/doll/rig.mjs` measures the landmarks from `body_base.png` (silhouette rows, eye blobs in the
face window), derives the region label map, and writes `project/data/doll/rig_chibi.json`,
`project/assets/doll/rig/chibi_regions.png`, a region overlay for review, and the 1024×1536
template `prompts/image/doll/template_chibi_front.png` with its SHA-1 recorded in the rig.
Acceptance: `node tools/doll/test_rig.mjs` passes: head top 61, soles 758 and centre x 367 within
1 px; chin and neck within 3 px of 398 and 406; every opaque body pixel carries exactly one label;
the eye centres lie in the eye band; the template's body mapped back to the frame overlaps
`body_base` at IoU 0.99 or better. The overlay PNG is posted for review.

**2. Image I/O, matting and intake.**
`tools/doll/lib/image.mjs` (raw RGBA through ImageMagick, alpha-weighted resample),
`tools/doll/lib/matte.mjs` (green unmix; white boundary unmix for white sources), and
`tools/doll/intake.mjs` (the checks of 5.4, JSON report, segmentation of 5.6 with expected counts).
This task also adds `project/tests/test_doll_tools.gd`, a runner that executes every
`tools/doll/test_*.mjs` and passes only if all of them pass (as `project/tests/test_paperdoll_tools.gd`
runs the Python test today), so the Node tests gate releases through `tools/run_tests.sh` from the
start.
Acceptance: `node tools/doll/test_matte.mjs` on synthetic fixtures (an antialiased warm-brown
outlined shape on 00FF00 with known coverage; a white garment with an enclosed green hole; a cream
body; turquoise and sky-blue swatches, the colours closest to the key that the palette uses):
mean alpha error at most 2/255, enclosed holes fully transparent, white, cream, turquoise and
sky-blue interiors fully opaque with their colour within ΔE 2 of the input, no pixel with alpha
above 0.1 and green excess above 24. On the delivered sheets: Daughter 5 components (body, hair,
dress, two sandals, none dropped), Mother 7, Oprah garments 4; synthetic failures (gradient
background, touching items, a green leaf, an item on the edge) each fail with the right reason.
`body_base` re-matted from the canon JPEG has a fringe ratio of at most 2% (from 14.4%) and at
least 64 alpha levels. `tools/run_tests.sh test_doll_tools` passes.

**3. Registration.**
`tools/doll/register.mjs`: the proof path and the fallback path of 5.7, the hair split of 5.8,
full-frame PNG output to `project/assets/doll/`, and the item record of 7.2 written to
`project/data/doll/items.json`.
Acceptance: `node tools/doll/test_register.mjs`: a synthetic proof made by scaling and shifting the
template by known amounts is recovered within 0.5 px and 0.3%; a proof with a 6% scale error or a
changed item between A and B is rejected with the reason. On the canon sheet (A1.1): the sheet's
body maps to the rig at scale 1.00 ± 0.01, and each canon wig is fitted at 1.00 ± 0.02 of the
sheet scale (today 1.11 to 1.26); `hair_crown` registered overlaps the ground truth (the wig over
the body on the canon sheet at sheet scale) at IoU 0.97 or better, and its split puts every pixel
below the chin into `hair_back`. On the Daughter's sheet: the body fits the rig with a residual of
at most 1.5 px, and her hair, dress and two sandals (each sandal on its own foot) are written as
frame layers and posted as a composite for review.

**4. Headless pixel QA.**
`project/scripts/systems/doll_composer.gd` and `project/tests/test_doll_qa.gd` (5.10, thresholds
read from the rig; for a legacy-sheet item drawn on the same sheet as the body, the fit scale must
be within 2% of the sheet scale).
Acceptance: on the parts as committed at 45269f5 the test fails and names `hair_crown` (scale
1.26; front hair over the neck and torso, which is the A1 defect), `hair_short` (front hair over the
chin and neck), `dress_uniform` (skin leak), and the fringe ratio of `body_base` and
`hair_pigtails`; on the parts from task 3 it passes for the hair and body; the default scope (items
alone plus pairs involving changed items, 5.10) runs inside `tools/run_tests.sh` in under 60
seconds; the full matrix runs with `DOLL_QA_FULL=1` with no time limit; both write the contact
sheet to `.cache/doll_qa/`.

**5. In-game screenshots and baselines.**
`tools/shots/doll.json` for `tools/shot_walk.sh`, first shot `wardrobe-player-crown-white` (A1.3),
then the wardrobe preview per outfit, a stage figure at 192 px and the player at 48 world px; a
comparison step that crops the doll preview from each shot and compares it with the
`DollComposer` composite of the same outfit at the same size, and with the approved baseline.
Acceptance: the shot list renders every listed outfit; run on the assets of 45269f5, the A1 shot
fails (hair scale and hair over the torso detected); a layer deliberately offset by 3 px in a
scratch copy is reported; after task 7 every shot matches its composite within the set RMSE.

**6. PaperDoll, player and wardrobe on the catalog.**
`paper_doll.gd` and `player.gd` read layers from `items.json`, put `hair_back` under the body, take
the default outfit from `characters.json`, and empty a missing slot instead of swapping art sets.
`wardrobe.gd` and `scenes/ui/wardrobe.tscn` show one labelled row per slot, body included, always
(A1.4: a slot with one option shows it with the arrows disabled; the body row lists the bodies of
the rig: `body_base` now, skin tones after task 10), and a dimming backdrop behind the panel while
it is open (A1.5).
Acceptance: a GDScript test checks the stack order (hair_back before body, hat after hair), that a
character's default outfit loads, that a missing part empties only its slot, and that the wardrobe
has eight visible rows labelled body, hair, top, bottom, dress, shoes, hat, accessory; the task 5
shots show the eight rows, the dimmed world and long hair behind the torso.

**7. Canon migration (closes A1).**
Re-matte, register at sheet scale and split the nine canon parts, and import the four Florida
wearables, as in section 8; fix or re-render `dress_uniform`. Until task 12, the full (unsplit)
wigs are also written to `project/assets/canon/` under their current names so
`gen_player_rig.py` keeps producing complete player rigs.
Acceptance: A1.1 to A1.5 pass: task 4 passes on all nine parts, the A1 shot (task 5) matches its
composite and the new baseline, and the before and after contact sheets and the A1 screenshot are
posted on issue #1; `gen_player_rig.py` output regenerated without errors.

**8. Catalog and landing.**
`tools/doll/land.mjs` (5.11) runs intake, matte, registration, derivation, `items.json`,
`characters.json`, `SOURCES.md` rows, the generated `paperdoll_parts.json` part list and
`outfits.json` entries, then rig, bake, import and QA.
Acceptance: `node tools/doll/test_land.mjs` lands the Daughter's items into a temp tree with
`--root`; a second run reports UNCHANGED and writes nothing; `--dry-run` writes nothing;
`tools/run_tests.sh` passes on the real tree after landing.

**9. Render briefs and the proof pilot.**
`tools/doll/brief.mjs` writes `prompts/image/doll/<id>.md` from a catalog stub; the 11 wardrobe
prompts are regenerated in the proof format; pilot briefs go to a render agent on issue #1 for one
item in each slot that is empty today (a top, a bottom, shoes, a hat), plus a hair and a dress.
Acceptance: the briefs pass a Node prompt check (front matter complete, template SHA-1 matches the
rig, no green words in item descriptions); the pilot renders pass intake and registration inside
the gates, the correction each needed is recorded, and once landed (task 8) every wardrobe row has
at least two options. If an agent's tool cannot keep the doll in place within the gates, that
result and the measured drift are reported on the thread.

**10. Legacy sheets and skin tones: Daughter and Mother.**
`tools/doll/tones.mjs` recolours the rig body's skin region per tone (5.8); the Daughter's and the
Mother's sheets land through the fallback path with their tones (or own bodies, per open
question 1).
Acceptance: both characters pass task 4; the wardrobe body row cycles the tones; their wardrobe
shots (task 5) are posted on issue #1 for the quality gate.

**11. Doll Bench editor plugin.**
`project/addons/doll_bench/`: a dock showing the rig with any item's layers, region overlay, QA
failures as red pixels, onion skin against the proof, arrow-key nudges and front-mask painting for
hair, saving `fit.nudge` and masks into the catalog.
Acceptance: a nudge saved in the dock appears in `items.json` and moves the layer by exactly that
many frame px on the next landing; the plugin loads with no errors in the editor log.

**12. Player rig port.**
Port `gen_player_rig.py` and the doll use of `rig_walk.py` to Node, reading the catalog (back hair
included); same frame grid (8×3 of 364×384), same motion; back view of printed garments per open
question 5.
Acceptance: for the canon parts the Node rigs match the current rigs frame by frame within a small
RMSE except where the hair split and the back-view rule changed them; `bake_paper.sh characters`
and the game run on them.

**13. ORA round trip (optional).**
Export an item with the rig body as an OpenRaster file for a hand fix in Krita, and re-import it.
Acceptance: export then import with no edit reproduces the layer PNGs exactly.

**14. Retire the old path.**
Delete `cut_paperdoll.py`, `test_paperdoll_tools.py` and its runner
`project/tests/test_paperdoll_tools.gd`, `land_wardrobe.mjs`, `test_land_wardrobe.mjs`,
`paperdoll_parts.json`, `gen_player_rig.py` and the compatibility copies in
`project/assets/canon/`; update `.claude/skills/gemini-assets/SKILL.md` (paper-doll section and
post-steps) and the prompts' Notes to the new protocol.
Acceptance: `tools/run_tests.sh` and `node tools/check_assets.mjs` pass; no tool or doc in the repo
references the deleted files.

**15. ML matte tier (optional, on approval).**
`package.json` with `onnxruntime-node`; the ToonOut fp16 model fetched to `~/.cache/persistint/`
with its SHA-256 checked; used by intake when the background check fails.
Acceptance: on a render with a soft shadow the ML tier produces a matte that passes task 4's edge
and fringe checks; on clean renders the chroma and ML mattes agree at IoU 0.98 or better.

## 10. Open questions

1. **One body per rig, or each character's own body?** The pipeline recommends one rig body with
   skin tones, because then every wardrobe item fits every character (the measured shape
   differences in 3.3 mean items fitted to one body do not fit the others). The coordinator's
   current direction on issue #1 is a `body_<character>` per layered sheet. If characters keep
   their own bodies, each body needs its own rig and every wardrobe item needs a fit per rig.
2. **May the canon body be redrawn at higher resolution on green?** A clean high-resolution redraw
   makes a better template and removes the JPEG source. Only if it matches the canon silhouette
   (IoU 0.97 or better) and the owner accepts the look.
3. **Which image tools do the render agents actually have?** Whether Codex's tool and Grok accept an
   input image to edit, keep its size and placement, and return transparent PNGs; whether a direct
   API route (OpenAI image edits, Gemini, xAI) may be called by the pipeline instead of only through
   agents, and at what budget.
4. **Grok's edit endpoint.** No official xAI documentation was retrieved; the reference-image limit
   and parameters are from third-party pages.
5. **Side and back views.** Keep deriving them (and decide what the back of a printed garment shows),
   or render them on side and back templates through the same proof protocol.
6. **Faces.** Keep the face drawn on the body, or make it a layer (expressions, per-character faces).
7. **Non-standard bodies.** The mermaid, the polar bear cub and the clone children: their own rigs,
   or NPC sprites only.
8. **Dress against top and bottom.** Are they mutually exclusive in the wardrobe, or may a dress be
   worn over a top?
9. **Dependencies.** Adding a `package.json` (for the optional ML tier only) and where model weights
   live (not in Git; a cache path or an LFS object) need approval.
10. **Frame size.** The 721×760 frame holds up to about 1440p at the 192-of-360 preview size, but
    it has no headroom above `hair_crown` (3.2), so a tall hat over that hair cannot fit. Whether
    to grow the frame (upward headroom now; a larger master for 4K or close-ups later) is a game
    change: every layer PNG and the player rig frame size change with it.
11. **Host characters.** The four cruise hosts depend on a renderer that accepts them; the pipeline
    does not depend on which renderer draws an item.
12. **Where the shot-list check runs.** `tools/shot_walk.sh` checks a list with
    `tools/check_shots.py` (Python) before running; the doll shot list either uses that existing
    check or a Node port of it.
13. **HUD overlap in the wardrobe screenshot.** The HUD icon column overlaps the scene building on
    the right of the owner's screenshot. It is a HUD layout defect, not part of the character
    pipeline; it needs its own tracked item, and A1.5 covers only the dialog backdrop.

## 11. Sources

- Picrew, creating images for image makers: https://support.picrew.me/en/create_imagemaker/create_first_image
- Spine skins: https://en.esotericsoftware.com/spine-skins
- spine-godot runtime: https://esotericsoftware.com/spine-godot
- Godot 2D skeletons: https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html
- Godot Image class: https://docs.godotengine.org/en/stable/classes/class_image.html
- Godot ZIPReader: https://docs.godotengine.org/en/4.2/classes/class_zipreader.html
- Godot headless has no renderer: https://forum.godotengine.org/150510/godot-headless-not-same-godot-window-cant-render-the-backend
- OpenRaster layer stack: https://www.openraster.org/baseline/layer-stack-spec.html
- Importality PSD guide: https://github.com/nklbdev/godot-4-importality/wiki/importing-psd-with-psd-tools-(en)
- OpenAI image generation guide: https://developers.openai.com/api/docs/guides/image-generation
- Gemini image generation: https://aistudio.google.com/docs/image-generation
- Grok image edit (third party): https://docs.oxen.ai/inference-api/reference/models/xai-grok-imagine-image-edit.md, https://www.atlascloud.ai/it/blog/case-studies/grok-xai-image-editing-capabilities
- Qwen-Image-Layered: https://github.com/QwenLM/Qwen-Image-Layered
- Smith and Blinn, Blue Screen Matting (1996): https://www.alvyray.com/Papers/CG/blusig96.pdf
- ToonOut BiRefNet ONNX: https://huggingface.co/sprited/birefnet-toonout-onnx
- RMBG-2.0 licence: https://huggingface.co/briaai/RMBG-2.0
- onnxruntime_go: https://github.com/yalue/onnxruntime_go
- sharp composite: https://sharp.pixelplumbing.com/api-composite
- Render thread: gnomatix/cloud-persistint issue #1 (comments of 2026-11-02, 09:28-17:23 UTC)
