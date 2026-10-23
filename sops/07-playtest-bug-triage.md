# SOP-07: Turning playtest reports into reproduced, tested fixes

Status: draft
Owner: Brett Whitty
Applies to: any interactive project with a UI; written from a game project (input, rendering, scene changes)
Last reviewed: 2026-10-23
Related SOPs: SOP-01 (01-parallel-agents-worktrees.md: one sub-agent per independent item, in its own worktree); SOP-08 (08-session-hygiene-tracking.md: filing leftovers, closing issues, commits)

## 1. Purpose

Turn short, informal playtest reports (for example, being stuck in a strange area, or the main character rendering as a blob) into fixes that are located in the source, reproduced before they are changed, fixed at the root for every instance of the same class, and held in place by a test that drives the same input the player used. Visual bugs are verified on real rendered frames, not inferred from headless runs.

## 2. When to use / when not to

Use when:
- The author or a tester reports something in their own words after playing a build.
- A report describes a symptom (stuck, wrong look, confusing choice, unreadable text), not a cause.
- Several reports arrive at once and need to be split, ordered and closed one by one.

Do not use when:
- The report already names the cause and a failing test exists. Fix it under the normal TDD loop.
- The report is a design request (new feature, new content). File it as an issue; this SOP is for defects.
- No runnable build exists for the reporter's version. Get the exact build first.

## 3. Inputs and prerequisites

- The report text, kept verbatim. Do not paraphrase before mapping it to source; the exact words are the search keys.
- A checkout of the build the reporter played (commit hash or branch).
- A way to run the project headless for tests, and a way to run it on a real display for screenshots (on WSL, a WSLg display; on CI, a virtual framebuffer or GPU runner).
- A test runner that can load one scene, inject real input events through the viewport and step frames.
- An issue tracker for leftovers.

## 4. Roles and tools

- Author / tester: plays the build, writes the report in plain words, answers clarifying questions about where they were and what they clicked, replays the original path on the fixed build, and accepts the fix or reopens the item (step 13).
- Controller agent: splits the report into items, maps each to source, reproduces, fixes, writes tests, takes screenshots, files leftovers, and reports with evidence. Does not mark an item fixed without a test result or a screenshot.
- Sub-agents: optional, one per independent item (for example one on an input bug, one on a font-size bug) when items touch different files. Never two agents editing the same scene or script.
- Tools:
  - `grep` / `rg` over data and scene files for the reporter's quoted words.
  - The engine's headless runner for tests (Godot: `godot --headless --path {project} -s {test_script}`).
  - The engine on a real display for screenshots (Godot: `godot --path {project} -s {screenshot_script} -- {out_dir} {prefix}`).
  - The project's issue tracker for leftovers and acceptance records (beads example: `bd create`, `bd close`, `bd list --status open`).
  - `git` for before/after builds (`git worktree` at the pre-fix commit; `git stash` only while the fix is uncommitted).

## 5. Procedure

1. Split the report into one item per symptom. Keep each item's verbatim text.
   Check: every sentence of the report belongs to exactly one item.

2. Map each item to source. Grep the reporter's distinctive words (a line of on-screen text, a button label, a place name) in data files first, then follow the data key to the scene or script that shows it.
   Check: you can name the file and node or data key the reporter was looking at. If the reporter's name for the place differs from the source's, note both.

3. Reproduce before changing anything. Check out the reporter's commit (or confirm HEAD matches it) and record the hash in the item record. Run the build and drive the same input the player used: a real mouse click or key event pushed through the viewport, not a direct call to the handler. For visual items, render a real frame on a display and save it.
   Check: the item record names the commit you reproduced on, and you have seen the failure yourself (a click that does nothing, a screenshot showing the wrong thing). If you cannot reproduce, ask the reporter for the exact steps; do not fix by guess.

4. Find the root cause. Trace from the input to the node that ate it, or from the frame to the resource that drew it. Name the mechanism in one sentence.
   Check: the sentence explains the symptom exactly, and a minimal change based on it makes the repro pass.

5. Search for the class. Look for every other instance of the same mechanism across the project (every map, every menu, every scene with the same node pattern).
   Check: you have a list of affected files, and it includes the ones the reporter never visited.

6. Write the test before or alongside the fix. The test drives real input through the viewport and asserts the player-visible outcome (scene changed, target spawn reached, no immediate bounce back, button visible or hidden). Cover every instance from step 5, not just the reported one.
   Check: run the test on the unfixed code and see it fail for the reported reason.

7. Fix the root cause in every instance from step 5.
   Check: the test passes. If any part depends on timing, threads or async engine state, run it repeatedly: at least 15 runs, and at least twice the run count that first showed a flake.

8. For visual items, take after screenshots with the same tool, scenes and viewport size as the before shots.
   Check: before/after PNGs side by side show the change at the target resolution. Headless tests do not count as visual evidence; headless runs do not render.

9. If any test is flaky, root-cause it before calling the work done. Count failures over N runs, find the async or ordering assumption, and make the test wait on the actual condition (not on a fixed number of frames).
   Check: N/N passes after the change, with N at least 15 and at least twice the run count that first showed the flake (a flake seen in 8 runs needs 16/16).

10. Run the full test suite.
    Check: every test passes; nothing the fix touched regressed.

11. File leftovers. Anything seen but not fixed (a second placeholder, a related polish item) becomes an issue with the reporter's words and the file path.
    Check: list open issues in the project's tracker and confirm each leftover is there (beads: `bd list --status open`).

12. Report back per item: the reporter's words, the file it mapped to, the cause in one sentence, the fix, the test name and result, and the screenshots for visual items. Commit with a message that names the symptom in the reporter's terms and the cause.
    Check: the reporter can match every original sentence to a line of the report.

13. Close the loop with the reporter. Send the per-item report and screenshots, and have the reporter replay their original path on the fixed build. Record acceptance, or reopen the item, in the issue.
    Check: every item's issue records the reporter's acceptance (with the build or commit they played) or is reopened with their new observation.

## 6. Acceptance checks

- Each item has a reproduced failure recorded (test output on the old code, or a before screenshot).
- Every test exits non-zero on failure (it may also print one summary line, but the checks below use the exit code). Below, `{test_cmd}` is the command that runs one test.
- Each input or flow item has a test that drives real input and fails on the pre-fix commit. Run the new test against the pre-fix code in a separate worktree, copying in only the test:
  ```bash
  git worktree add ../prefix {pre_fix_commit}
  cp {test_script} ../prefix/{test_script}
  (cd ../prefix && {test_cmd}); echo "exit $?"   # expect non-zero
  {test_cmd}; echo "exit $?"                      # on the fix: expect 0
  git worktree remove ../prefix
  ```
  Godot example for `{test_cmd}`: `godot --headless --path {project} -s {test_script}`.
  `git stash` works only while the fix is still uncommitted, and the test files must not be stashed with it (stash the fix paths only, e.g. `git stash push -- {fix_paths}`). Once the fix is committed, stash does nothing and the "expect failure" run passes.
- Timing-sensitive tests pass repeatedly (N at least 15 and at least twice the run count that first showed a flake):
  ```bash
  for i in $(seq 1 {N}); do {test_cmd} >/dev/null 2>&1 && echo PASS || echo FAIL; done | sort | uniq -c
  ```
- Visual items have before/after PNGs from a real display (Godot example):
  ```bash
  godot --path {project} -s {screenshot_script} -- {out_dir} before_
  # apply fix
  godot --path {project} -s {screenshot_script} -- {out_dir} after_
  ```
- The full suite passes.
- Leftovers are filed; none are left only in chat.
- Each item's issue records the reporter's acceptance on the fixed build, or the item is reopened.

## 7. Failure modes and recovery

- Fixing the reported room only. The same mechanism existed in the sibling rooms built from the same template. Recovery: step 5 is mandatory; the test must iterate over every scene of the kind, not a fixed list of the one reported.
- Testing by calling the handler directly. A test that calls the door's handler directly passes while a full-screen background control swallows every real click. Recovery: inject `InputEventMouseButton` (or the engine equivalent) through the viewport so input routing is part of what is tested.
- Trusting headless runs for visual bugs. Headless mode does not render, so wrong art, wrong scale and oversized fonts are invisible to it. Recovery: render on a real display and look at the PNG.
- Flaky test blamed on "timing" and retried. Recovery: count the failure rate, read the engine's threading model for the subsystem involved, and wait on the real readiness signal. Example class: navigation maps that sync on worker threads answer queries before the new region is merged.
- Fixing the surface of a symptom without asking what the player expected. Renaming a confusing control, or nudging one sprite, leaves the underlying mismatch in place. Recovery: write down what the player expected to happen or see, fix toward that expectation, and confirm it with the reporter in step 13.
- Fixing one instance of a visual bug part by part. Each part looks right alone, but the parts disagree with each other (different sources, different native sizes). Recovery: find the rule that should hold for the whole thing (one source, one target size) and apply it in one place.
- Accepting a visual fix without viewing it at the shipped resolution and scaling. A change that looks right in an editor or at desktop size can still be wrong in the real viewport. Recovery: take the after screenshot with the shipped viewport size, stretch mode and camera zoom, and compare it with the before shot.
- Reporter's place name does not match the source. Recovery: grep the on-screen text they quoted, not the place name.

## 8. Artifacts and templates

Item record (one per symptom, kept in the issue or the commit body):

```
Report:   "{verbatim words}"
Build:    {reporter's commit hash, the one reproduced on}
Mapped:   {data_file}:{key} -> {scene_or_script}:{node}
Repro:    {input driven} -> {observed failure}
Cause:    {one sentence}
Class:    {list of all affected files}
Test:     {test_script} ({FAIL on pre-fix commit, PASS after; N/N runs if timing-sensitive})
Visual:   {out_dir}/before_{scene}.png, {out_dir}/after_{scene}.png
Leftover: {issue id or "none"}
Accepted: {reporter, build or commit played, date} or "reopened: {new observation}"
```

Real-input exit test skeleton (Godot 4, run as a SceneTree script):

```gdscript
extends SceneTree
## For every map in {DIRS}: load it, place the player a short walk from each door,
## click the door through the viewport, step physics until the scene changes,
## then check target scene, arrival spawn and that the player is not inside a door.
## Run: godot --headless --path {project} -s tests/{test_exits}.gd

## A left click on a world position, pushed through the viewport like a real mouse.
func _click(world: Vector2) -> void:
	var screen: Vector2 = root.get_canvas_transform() * world
	var mm := InputEventMouseMotion.new()
	mm.position = screen
	mm.global_position = screen
	root.push_input(mm, true)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = screen
	ev.global_position = screen
	root.push_input(ev, true)
	var up := ev.duplicate() as InputEventMouseButton
	up.pressed = false
	root.push_input(up, true)
```

Navigation readiness wait (replaces a fixed frame count):

```gdscript
func nav_ready(region: NavigationRegion2D) -> void:
	var map := region.get_navigation_map()
	var probe: Vector2 = {a point inside the region's first polygon, in global space}
	for i in 600:
		if NavigationServer2D.region_get_iteration_id(region.get_rid()) > 0 \
				and NavigationServer2D.map_get_iteration_id(map) > 0 \
				and NavigationServer2D.map_get_closest_point(map, probe).distance_to(probe) < 1.0:
			return
		await physics_frame
```

Screenshot tool shape: a SceneTree script with a list of `[name, scene_path, mode]` entries; for each, load the scene, wait a few frames, save `get_viewport().get_texture().get_image()` to `{out_dir}/{prefix}{name}.png`. Must run without `--headless`.

Full-screen background controls in world scenes: set `mouse_filter = MOUSE_FILTER_IGNORE` (2 in `.tscn`) on any `ColorRect` or `TextureRect` used as a backdrop. Recommended, not yet in the reference implementation: a static test check that no full-viewport Control in a map has the default `STOP`.

## 9. Reference implementation in persistint

Reports (author, verbatim): stuck "in a weird area of the temple where it says something about deck chair and facing a sunset"; main character renders as a blob/back of head; two start buttons "play"/"new game"; fonts too large for the portal view.

- Stuck in the temple area. The quoted text is in `project/data/ruins.json`, room `wreck`, ambient line "A deck chair is still arranged to face a sunset that stopped being scheduled."; that room's scene is `project/scenes/ruins/ruins_wreck.tscn`. The reporter called it the temple: the wreck is entered through the temple's Ruins door, so the source name differs from the reporter's. Repro: a real click pushed through the viewport was swallowed by the full-screen `Background` `ColorRect`, which had the default `mouse_filter` (STOP). Fix in commit `e0574a1`: `mouse_filter = 2` on the backgrounds of all six ruins rooms (`ruins_wreck`, `ruins_corridor`, `ruins_core`, `ruins_records`, `ruins_clone_hall`, `ruins_bunker_lift`), doors pulled inside the navmesh, the wreck exit now returns to `spawn_from_ruins` beside the temple Ruins door, village `spawn_from_ruins` moved out of its door, and `project/scripts/door.gd` gained a doormat marker, a hover/near destination label and click-to-walk. Test: `project/tests/test_exits.gd` clicks every door on all 11 map scenes in `scenes/maps`, `scenes/ruins`, `scenes/florida` and `scenes/chapters` through the viewport, walks the player, and checks target scene, arrival spawn and no arrival bounce; it failed on the old code and passes on the fix.
- Flaky map test. `project/tests/test_island_maps.gd` failed 2 of 8 runs: Godot 4.6 syncs navigation regions and maps on worker threads, so queries could hit a map that had not merged the region. Fixed in `e0574a1` with `nav_ready()`, which waits on region and map iteration ids and a closest-point probe; 15/15 passes after.
- Player as a blob. Placeholder art is 24x32 (`project/assets/placeholder/`); canon paper-doll art is 91x96 (`project/assets/canon/`). Fix in commit `9d48ac0`: `project/scripts/player.gd` resolves one art set for all worn parts through `PaperDoll.art_dir_for` (`project/scripts/systems/paper_doll.gd`; canon first, placeholder only if canon lacks a part) and scales the doll to 48 px, NPC height.
- Two start buttons. The repo's labels were "Begin" and "New Game", not "play"/"new game" as reported; the repo wins on the labels, the complaint stands. Fix in `9d48ac0`: "Begin" renamed "Continue" in `project/scenes/ui/main_menu.tscn`, and `project/scripts/ui/main_menu.gd` shows it only when a save location flag exists.
- Fonts too large. Viewport is 640x360 with `canvas_items` stretch (`project/project.godot`). Fix in commit `4fa8595`: project theme `project/themes/default.tres` with `default_font_size = 9`, compact dialogue balloon, world labels sized for the player camera's 2x zoom (`project/scenes/player/player.tscn`), minigame layouts that wrap. Visual verification: `project/tools/screenshot_scenes.gd` (added in `4fa8595`) rendered before/after PNGs on the WSLg display; it does not run under `--headless`.
- Leftovers filed as beads, for example `persistint-game-dcs` (pastel dialogue box, replace the beach placeholder blob NPC).
- Test convention: `project/tests/test_exits.gd` prints `RESULT: PASS|FAIL (N failures)` and exits 1 on failure, which is what the exit-code checks in Section 6 rely on.
- Item fixes behind the Section 7 process failure modes: the paper-doll art mix (one art set per character, scaled to 48 px), the Begin/New Game pair (Continue shown only when a save exists), and the 640x360 font sizes (theme default font size, world labels sized for the 2x camera zoom). Details in the bullets above.

## 10. Lessons learned

- Grep the player's quoted on-screen words. "Deck chair" and "sunset" led straight to one data key and one scene, even though the player named the wrong area.
- Push real input through the viewport when reproducing. That is what exposed the full-screen `ColorRect` swallowing every click; a direct call to the door handler would have worked and hidden the bug.
- Fix the class, not the instance: every ruins room had the same backdrop, and one test over all 11 maps now covers every door.
- A test that would have passed on the old code proves nothing. `test_exits.gd` was run against the old code and failed before the fix went in.
- Headless tests cannot see rendering. The blob player and the oversized fonts were confirmed on real screenshots.
- A flake is a bug. The 2-in-8 map test failure was Godot 4.6 navigation syncing on worker threads; waiting on the real sync state made it 15/15.
- Mixed placeholder and final art at different native sizes is a rendering bug. Choose one art set per character and scale to a fixed height.
