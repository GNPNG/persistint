# Task 4 — headless pixel QA

Bead: `persistint-game-1rjz.4`. Base: `61ca83d`. No production artwork changed.

`DollComposer` composes RGBA layers on the CPU and measures full-resolution borders,
alpha levels, light outline fringe, green residue, skin colours and disconnected parts.
Coverage, forbidden overlap and overhang use half-resolution labels. Thresholds live in
`rig_chibi.json` and are reproduced by the rig generator. Hair front masks never excuse
an eye-band overlap. Legacy items must supply fit scale and sheet scale; missing evidence
fails instead of silently assuming a ratio of one.

`test_doll_qa.gd` checks every item and relevant changed pairs. Optional
`project/data/doll/qa_baseline.json` is the `fingerprints` object from an **approved**
report; the test never approves or updates it automatically. Fingerprints include layer
bytes, item metadata, rig, body and region-map bytes. No baseline means every pair is
changed. `DOLL_QA_FULL=1` ignores that optimization. Both modes write contact.png and
report.json under `.cache/doll_qa/`; tile order matches report order.

## Exceptions explicitly requested by the coordinator

On 2026-11-04 the coordinator deferred the body rematte to task 7. The sole
`EXPECTED_FAILURES` entry names body_base fringe and boundary_alpha_levels, owner task 7
Canon migration (`persistint-game-1rjz`). Every run prints KNOWN and the measurements:
361/2515 light-ring pixels (14.3539%), 2 boundary alpha levels. Task 7 must empty this
list. No threshold was relaxed. New body failure kinds still fail.

The existing Daughter `needs_review` findings and fractional sandal border alpha are
reported, not repaired. `REVIEW_FINDINGS` enumerates the measured findings by item;
`needs_review` alone cannot excuse any new finding or newly added item. These entries
are not a claim of approved art or passing canon hair. The current contact sheet also
shows the pre-existing small detached red fragment beside the Daughter dress.

Measured default audit: 5606 ms; full: 5393 ms. Both exit 0 with
the explicit known/review entries above. Unit fixtures and scope assertions pass.

## Reproduce

```sh
tools/run_tests.sh --no-import --timeout=60 test_doll_qa test_doll_qa_unit
DOLL_QA_FULL=1 godot --headless --path project --script res://tests/test_doll_qa.gd
DOLL_QA_HISTORY=1 node tools/doll/test_qa_scope.mjs
node --test tools/doll/test_rig.mjs
```

The scope integration check verifies default unchanged-pair skipping, full-mode inclusion,
rejection of an unlisted needs_review item, and the named historical defects. Historical
fixtures use `git show 45269f5:...` and LFS smudge into `.cache/doll_qa/historical` only;
no old art is checked out into production. Historical hair_crown ratio 1.26638 is an
explicit raster estimate from opening width / coordinator's 229 px source opening;
other historical items without fit provenance additionally report legacy_scale_missing.

```sh
node tools/doll/export_qa_history.mjs
DOLL_QA_ROOT="$PWD/.cache/doll_qa/historical" godot --headless --path project --script res://tests/test_doll_qa.gd
```

This historical run must exit 1. Reports name crown scale/front torso overlap, short-hair
front neck overlap, uniform skin leak, and pigtail/body fringe. Reports and contact sheets
in this directory retain exact measurements. The synthetic four-wig registration smoke
from f63958a is carried in this branch and passes with the coordinator's hair-anchor fix.

## Team-side encrypted-source check still required

Run the existing task 3 registration command against the decrypted sheet and independent
crown reference, using this branch's rig (which now includes QA thresholds):

```sh
node tools/doll/check_canon_registration.mjs DECRYPTED_SHEET 482x778+57+250 .cache/task4-canon INDEPENDENT_CROWN_FRAME.png
DOLL_QA_ROOT="$PWD/.cache/task4-canon" DOLL_QA_FULL=1 godot --headless --path project --script res://tests/test_doll_qa.gd
```

The hair must pass without exceptions. Only the unchanged body has the task 7 exception.
This checkout cannot decrypt that source, so actual canon-hair pixel acceptance is not
claimed. Synthetic registration is not a substitute for it.

## Measurement limits

Overhang uses an eight-neighbour chamfer distance at half scale; diagonal distances are
an approximation. Garment composite skin-leak checks inspect the stacked garment pixels
without the body's naturally visible skin. Region coverage separately checks missing
coverage over the body. Pixel rules are diagnostics, not aesthetic approval. No in-game
screenshots or task 5 comparisons were run in this task.
