# Florida walking-state check (a294)

The original test sampled the NPC after four process frames. The NPC's tween changes
position after node processing, and `npc.gd::_process` selects animation using the
position change on a later frame. Four process frames are not a state guarantee.
Father's current sheet has no walk animation: his moving pose is `idle_side`, not
`walk_side`. A movement-only wait can still catch `idle_front` before that update.

The test now waits at most five real seconds for a visible, leaving, moving NPC with
walk art, or its side-facing idle fallback when the sheet has no walk frames. It fails
clearly if that state never appears or the NPC disappears first. The existing direction,
flip, walk-frame, interaction, elapsed-time and destination assertions remain unchanged.
Only test code changes; no game-code defect or game-code change is claimed.

## Loaded trials

| Version | Pass | Fail |
|---|---:|---:|
| Original at 9a6dbf8 | 20 | 0 |
| Final revision | 20 | 0 |

Each batch ran with two continuously busy Python CPU worker processes and two concurrent
Godot test processes, on five available CPUs. Every Godot process used a distinct
`XDG_DATA_HOME`, avoiding shared save/settings interference. The worker load was a repeated
`sum(i*i for i in range(100000))`; workers were stopped after each batch. Each trial ran
`godot --headless --path project -s <test script>` with a 180-second timeout. The baseline
script was frozen before edits, at a path containing `tests/` so the game's test-save
mode stayed enabled. The final batch used `res://tests/test_florida.gd`.

[Per-run exit codes, durations and source hashes](load-results.json).
The natural intermittent failure did not reproduce in the original 20-run batch.
These counts support stability under this workload, not a measured reduction in failure
rate or proof against every scheduling condition.
