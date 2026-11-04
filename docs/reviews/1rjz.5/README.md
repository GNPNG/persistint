# Canon hair placement and face-region correction

Bead `persistint-game-1rjz.5`, branch `codex/1rjz.5`, base main `21558aa`.
Task 4's branch remains unchanged. The coordinator withdrew the old crown ground truth:
its high IoU compared two equally low placements, so it is no longer an acceptance gate.

The regenerated rig protects measured eye blobs with a 10 px circular dilation, clipped
to the visible face. The face is an inset ellipse between the ears, below the hairline,
measured from eye spacing, brow and chin. Side hair at the temples is labelled head,
not eye_band or face. `regions-overlay.png` shows the result; both eyes, their immediate
surround, nose and mouth remain protected. The underlying body art is unchanged.

Hair fitting fixes x at the body's centre and fixes scale at the sheet scale. It searches
from 80 px above to 20 px below the old face-opening seed, in 1 px increments, scoring
cranium coverage, eye overlap, face overlap above the existing 3% limit, and clipping.
Measurements use 2 px sampling, matching the QA's half-scale intent. A fit does not
silently become approved: measurements are recorded in fit.hair_qa and all legacy output
still requires review. An impossible shape retains measured failures.

For white-backed wigs only, the largest enclosed near-white component is the face opening.
Substantial enclosed near-white components beside its lower half and above its bottom are
treated as ear gaps. Tiny/top highlights and below-chin white content are preserved. The
selected gaps use the existing white unmix algorithm for their inner boundary, rather than
leaving an opaque pale ring. Dress white is untouched. Ear identification is geometric;
the actual canon contact sheet still needs review.

## Evidence

- `synthetic-fit.txt`: a deliberately 35 px-low seed moves up 23 px, without x drift or
  scale change; cranium coverage 100%, eye overlap zero, face overlap 2.9233%.
- Synthetic tests protect both eyes and mouth, allow temple locks, retain impossible-fit
  diagnostics, clear both ear gaps, and preserve highlights/white garments.
- Rig regeneration, existing legacy-sheet integration and matte tests pass.
- Asset gate: 1023 assets, zero failures.

These measurements describe synthetic fixtures, not the encrypted canon sheet.

## Coordinator commands

The registration command no longer needs or evaluates an independent crown reference:

```sh
node tools/doll/check_canon_registration.mjs DECRYPTED_SHEET 482x778+57+250 .cache/task5-canon
node tools/doll/run_qa_review.mjs .cache/task5-canon TASK4_GIT_REF
```

Use a locally available task 4 ref for `TASK4_GIT_REF` (default
`origin/codex/1rjz.4`, delivered commit `ce007847a36b56e06e576a53cc5106281630b967`).
The second command extracts task 4's checker and thresholds into the isolated output;
it does not modify or merge either branch. It checks Godot exit status and script errors.
Results are `.cache/task5-canon/pixel-qa.txt`, `.cache/doll_qa/report.json` and contact.png
inside that output root. `canon-qa-contact.png` also shows all four full-size composites
in pigtails, crown, braids, short order. Body KNOWN exceptions remain owned by task 7;
canon hair must pass outright. Please review placement, ear gaps and fringe visually too.

After merging with task 4, retain its rig.qa thresholds when resolving rig JSON/generator
changes and regenerate the rig with both changes present. No task 4 exception or threshold
has been changed here. No canon wearables or Daughter wearables were regenerated into
production in this branch.

The old task 3 rectangular-ring smoke geometry is intentionally not an anatomical fit:
the new registration checker rejects its uncovered cranium/clipping, and the isolated
pixel-QA helper returns exit 1 for its binary edges. This verifies that the new review
path reports failures rather than treating the withdrawn IoU check as approval.
