# Chibi rig kit — 1rjz.1

Build: `node tools/doll/rig.mjs`. Check: `node tools/doll/test_rig.mjs`.
Requires Node and ImageMagick 7; no Python or npm dependencies. `--root PATH` supports
isolated builds. The canonical source is currently **project/assets/canon/body_base.png**,
not project/assets/doll/body_base.png. The tool prefers the latter if it exists in a future
migration. It does not alter or relocate either source.

![Measured region overlay](regions_overlay.png)

![1024×1536 front template](template_chibi_front.png)

The template is the existing body resampled once with Lanczos onto pure #00FF00,
with frame scale 1.6 and origin (-75.2,160). Its SHA-1 is recorded in
`project/data/doll/rig_chibi.json`, together with the body's path and hash. The copy
here is byte-identical to `prompts/image/doll/template_chibi_front.png`.

## Measurements and acceptance

| Landmark | Measured frame pixels |
|---|---|
| Head top / centre | (367,61) / x367 |
| Eyes | (293,293), (440,293) |
| Brow / eye band | 236 / y236–316 |
| Chin / neck | 399 / 406 |
| Shoulders | (304,417), (424,417) |
| Wrists / hands | (217,540), (511,540) / (205,558), (522,558) |
| Waist / hip / crotch | 567 / 591 / 622 |
| Knees / ankles / soles | 673 / 724 / 758 |

Head top, soles and centre pass the ±1 px reference limits; chin and neck pass ±3 px.
The 19 labels are nonempty and cover every nontransparent body pixel exactly once,
with no labels outside the silhouette. Both eye centres carry the eye-band label.
The actual green template mapped back onto the frame has **IoU 0.998193**, above 0.99.
A translated source fixture moves measured silhouette and eye landmarks by the same
offset, guarding against fixed-coordinate output. Regeneration is deterministic and
matches the checked-in artifacts; the body remains unchanged.

Landmarks come from silhouette row spans, the neck-width minimum, the lower-jaw taper,
dark connected components for eyes/brows, separated arm/torso spans, the waist outline,
and leg widths. Secondary limb bands are geometric estimates derived from those features,
not an anatomical model. The overlay was visually checked: ears, eye band, neck, torso,
arm segments, hands, hips, legs and feet are separated; no stray hand strips along the hips.
They remain subject to coordinator art review before downstream wardrobe QA relies on them.
L/R explicitly means image left/right. Region PNG channels R=G=B contain integer IDs,
with alpha 255 on the body and 0 outside; the overlay uses distinct review colors.

The JSON includes the specified stack, slot restrictions, a measured forehead skin seed,
and template placement. The skin seed is not a complete skin classifier. No wardrobe
registration, new body painting, fringe correction, runtime changes or in-game outfit
review is included. Those belong to subsequent pipeline tasks. Cross-platform image
encoder equivalence was not checked.

The provenance scanner now descends into tools/ subdirectories so this generator is
recorded for chibi_regions.png. Node acceptance tests enter the full suite in task 2,
as specified in the design; this task runs test_rig.mjs directly.

Full suite initially reported 65/67: provenance could not find the nested generator,
and `test_quotes_vv` cannot read the encrypted private design text here. The recursive
provenance fix and regeneration pass the asset gate (1018 assets, zero failures), leaving
66/67 checks passing. The encrypted-design failure is the coordinator-acknowledged
local limitation. [Direct Node acceptance output](test-output.txt) is included.
