# Pigtail face-opening outline repair

Coordinator decision 2026-11-06 00:04: remove the thin warm-brown face-opening outline below the brow, preserve filled locks, and rerun actual pixel QA. Circlet cleanup at 399d7c1 was accepted on the actual sheet. The remaining lock overlap may go to the author under 1rjz.6; no region/gate change is authorized.

`stripFaceOutline` is an explicit legacy-item option, enabled only for `hair_pigtails` in `check_canon_registration.mjs`. It runs after the original warp and before front/back splitting. Source opening detection, anchor, scale and placement search are unchanged. No production art is regenerated here.

The repair flood-fills the closed transparent face opening from the rig's eye-midpoint centre. It considers warm dark foreground below brow_y only when the face opening and another transparent region are separated by a thin band (Manhattan distance sum <= 9, corresponding to an 8px maximum band). A protected neighbourhood around thicker filled regions retains locks and their junctions; color selection protects pink ties and pale highlights. Fractional-alpha outline samples are cleared too. A missing/opaque seed or an open face returns unchanged with an explicit status, rather than guessing.

This is a conservative geometric/color heuristic, not semantic hair segmentation. In particular, it can retain a few pixels where the outline joins filled hair. Actual-sheet acceptance remains with the coordinator. The source art and derivatives stay in the coordinator scratchpad; no further relay of art is requested.

Synthetic tests cover 4/6px curved outlines, fractional alpha, unchanged full lock/tie rectangles, bangs above the brow, thick filled bands, refusal of an open face, and placement integration. Integration compares the full fit and anchor with repair disabled: identical. `test_face_outline.mjs` is automatically included by the existing `test_doll_tools.gd` discovery.

## Coordinator rerun

Use the existing three-argument `check_canon_registration.mjs` command, then `run_qa_review.mjs` on its output and `inspect_face_overlap.gd` for the new pigtail row counts. The canonical manifest enables this repair automatically. `items.json` and `canon-registration.json` expose `outline_cleanup` / `outlineCleanup` with status, removed-pixel count and y range.

`hairFits` remains the pre-cleanup placement diagnostic (explicitly labelled `hairFitStage`); its old face-overlap flag is not a measurement of the repaired layer. Task 4 pixel QA and the overlap inspector measure the delivered front layer and decide acceptance. The geometry command can therefore still exit 1; run the pixel QA separately even then. No gate is relaxed, and no post-cleanup pass is asserted here.
