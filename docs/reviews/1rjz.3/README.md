# Registration and legacy Daughter layers — task 3

Branch codex/1rjz.3; bead persistint-game-1rjz.3. All legacy items remain marked
needs_review for the Doll Bench. Existing canon assets and game runtime are unchanged.

## Daughter fallback

![Daughter over the canon body](daughter-composite.png)

Generate the hair front/back, dress, and two separate sandals with:

```sh
node tools/doll/legacy.mjs tools/doll/manifests/daughter.json . docs/reviews/1rjz.3/daughter-composite.png
```

Outputs are 721x760 RGBA under project/assets/doll/, with records in
project/data/doll/items.json. The manifest identifies sheet crops and explicitly
selects the hair component, excluding the neighbouring body's pixels in its crop.
Hair uses its face-opening centre and chin at sheet scale, then splits below chin.
The dress uses the upper neck-opening plane; each sandal uses its own sole landmark.
Coverage refinement is bounded to four pixels and two percent scale (inside the
spec's eight-percent search limit); wigs retain sheet scale. Sole height remains
anchored after refinement. User nudges and front-mask paths can be recorded explicitly.

The Daughter body residual is about5.494 frame pixels, scale0.86541. Per the
coordinator's November4 decision, a legacy residual above1.5 is a review flag, not a
rejection: every item records needs_review: body differs from the rig, residual X px.
The proof gate stays1.5. Section5.7 documents that distinction in two added sentences.
The earlier whole-outline comparison remains in daughter-fit-difference.png (grey
intersection, blue canon-only, pink Daughter-only), with both fit seeds in its JSON.

Visual review: separate sandals, clean face opening and no front hair below the chin.
The default body's white undershirt is visible at the neckline; wardrobe pixel QA and
Bench approval remain separate steps. Low-opacity cyan source-backing noise was found
while compositing: green matting now clears near-key noise and coverage below0.1 before
unmixing amplifies it. Synthetic mean alpha error is0.005530, within2/255; opaque palette
colours remain exact. Matting is performed on the whole sheet before cropping so an
item touching its crop border cannot corrupt the measured backing colour.

## Proof path

Core registerProof measures eyes/soles, refines uniform scale/translation using visible
outline regions, tests rotation and scale/translation/residual corrections, cross-checks
the proof/item difference at IoU>=0.9, and maps the item to the frame once. The bare-body
comparison reference is sampled through the same grids to account for Lanczos edge
changes. Different-sized item canvases align to the proof difference silhouette.

```sh
node tools/doll/proof.mjs MANIFEST.json [ROOT]
```

Manifest fields: id, slot, proof, item, optional brief/provenance, expectedScale,
expectedOffset and frontMask. Rejections write a report and no layers/catalog entry.
Accepted registration writes full-frame layers and catalog entries marked for subsequent
pixel QA/review. A proof drawn in the1024x1536 template uses expectedScale0.625 and
expectedOffset[47,-100] to express the template-to-frame transform.

## Encrypted canon acceptance — team command

The source remains encrypted here. The coordinator runs:

```sh
node tools/doll/check_canon_registration.mjs \
  /path/to/decrypted-sheet.jpg 482x778+57+250 \
  /tmp/canon-registration-review /path/to/independent-crown-frame.png
```

The last image must be an independently prepared721x760 crown ground truth at sheet
scale, not this tool's generated output. The command copies rig inputs into the isolated
output root, places all four canon wigs, enforces body scale1+/-0.01 and relative wig
scale1+/-0.02, checks crown IoU>=0.97 against that reference, and checks every front alpha
below chin is zero. It saves report JSON, registered crown, layers and catalog for review.
Neither the encrypted source nor its ground truth was fabricated or decrypted here.
Actual canon wig measurements remain team-run acceptance; no local pass is claimed.

## Validation and limits

Tests cover known transforms within0.5px/0.3%, rejection of6% correction and changed
items, shifted/scaled proof agreement, exact chin split, synthetic closed-face wig at
sheet scale, independent shoe anchors, full-frame output, body-residual review flags,
zero opaque frame-edge contact on Daughter layers, proof CLI persistence and refusal to
write rejected items. Every tools/doll/test_*.mjs runs in test_doll_tools.

The whole-outline solver is local optimization, not a proof of a global optimum.
Arbitrary heavily occluded proofs may fail eye detection and should be returned for a
clearer proof, not silently accepted. Skin recolouring is outside this task. General
outfit combinations and runtime integration belong to subsequent tasks; this delivery
is reviewable source layers/catalog, not a switch of the live outfit definitions.

Final validation: test_doll_tools passes all five Node files in20seconds, including
synthetic visibility checks for all seven slots and accepted/rejected proof CLI runs.
The full run initially returned65/68 (provenance, the new legacy path test, and the
known encrypted-design quote failure). Corrected provenance and legacy tests pass
on targeted reruns: asset gate1023 assets/0 failures and the complete doll wrapper
passes. This leaves67/68 checks passing; the full suite was not repeated after those
localized fixes. Canon source/ground-truth acceptance remains the coordinator's run.

Review caveat: the sandals have no opaque pixels on the frame border, but Lanczos
leaves fractional alpha in the last row (left26 pixels, maximum55/255; right10,
maximum12/255). The stricter any-alpha frame-border QA in task4 will flag these;
no pixels were silently cleared to hide that result. Both items remain needs_review.

## White-sheet wig revision

For opaque white-backed legacy sheets only, the hair path now clears the largest
opaque near-white component that does not touch the crop edge, after white matting
and before detecting the face opening. Near-white means all RGB channels >=232 with
channel spread <=24. Other enclosed white components (small highlights), edge-touching
white, and every non-hair slot retain their pixels. The generic white matte is unchanged.

Regression fixtures include an enclosed near-white wig opening, a white dress panel,
a smaller white highlight, edge-connected white, and non-white-backed hair. An isolated
full-sheet build also places the white-backed wig and preserves the dress panel.
The canonical opening measurement/IoU still runs on the team's decrypted sheet; the
independent crown reference is sheet scale, opening bottom at chin_y399, centre_x367.

White-sheet revision validation: all five Node files PASS through test_doll_tools
in41seconds; asset gate1023/0. Full game suite not repeated for this slot-specific fix.

## Complete canon-command synthetic smoke check

While the source-art review is pending, the complete check_canon_registration command
was exercised with four white-backed synthetic wigs in the canon crop positions.
The crown opening is229px wide, its independently calculated reference offset is
(167,-10), and the reference is built directly from the fixture geometry without
calling the production anchor or warp functions. Result: body scale1.0001226224,
all four relative wig scales1, crown IoU1, and the below-chin split check passes.
This validates the command path, not the encrypted artwork. Reproduce from the repo
root with node docs/reviews/1rjz.3/synthetic-canon-smoke.mjs; outputs stay in .cache/.
