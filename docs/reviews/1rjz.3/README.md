# Registration preflight — task 3 draft

This is an incomplete task 3 implementation, provided for coordinator review of a
measured acceptance mismatch before producing wearable layers. No production items,
body images, item catalog or game runtime are changed.

Implemented: exact Euclidean distance fields; uniform scale/translation outline
matching; eye/sole landmark initialization; body component isolation; proof/item
cross-check; correction gates; single-resample item mapping; chin-based front/back
split. The proof fixture covers the top slot, same-frame and shifted/scaled inputs.
The reference body is sampled through the same grids for the proof difference check,
avoiding false garment differences from Lanczos changes at the body's own edges.

## Daughter preflight needs coordinator direction

Run from the repository root:

```sh
node tools/doll/register.mjs \
  prompts/image/characters/assets/char_daughter_layers.png \
  484x795+38+82 project/assets/canon/body_base.png .cache/1rjz3-daughter
```

This returns exit 1 with `outline-residual`. Two independent seeds (eye/sole landmarks
and silhouette bounds) converge to about **5.494 frame pixels**, against the required
**1.5**. Scale is approximately **0.86541**; offset is relative to the supplied crop.
The residual is the mean of both directed mean Euclidean outline distances at alpha>127,
computed in frame pixels. Local optimization is not a proof of a global optimum.
Neighbouring hair pixels inside the body's bounding box are explicitly excluded.

![Daughter fit differences](daughter-fit-difference.png)

Grey is overlapping silhouettes; blue is canon only; pink is Daughter only.
The comparison shows differences at head proportions, ears, hands and feet.
The rendered binary mask IoU is approximately **0.91356**. The residual limit has not
been relaxed, and the rejected fit has not been put into production.

Question for the coordinator: is the intended <=1.5 metric the whole-outline mean
specified here, or a different explicitly defined subset/metric? If whole-outline
is intended, should this sheet be returned for a canon-matched proof render? No
rerender assignment has been chosen independently.

## Validation and remaining work

Known transforms of the canon body recover scale within0.3% and translation within
0.5px;6% scale correction rejects. Shifted/scaled proof and item pass the IoU gate;
a changed item rejects. Chin split preserves every source pixel in exactly one layer
and leaves no unmasked front pixels below the chin. Tests are in test_register.mjs
and discovered by the existing Godot runner.

Pending: complete legacy slot-anchor/coverage refinement; Daughter wearable layers
and composite accepted at the specified body residual; canonical wig scale/ground-truth
checks (team-run encrypted source); item-catalog writes and front-mask workflow.
The current CLI is body preflight only. Arbitrary slot/proof combinations and unequal
B canvases still need broader fixtures; this is not a complete registration delivery.
