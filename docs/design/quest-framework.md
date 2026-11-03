# Quest framework: Easter-egg scenarios, replay and sharp things

A design for multi-step Easter-egg scenarios that trigger a scene, with reset for replay and a
blocked-replay flag the player lifts in fiction (bead persistint-game-91a: multi-step
Easter-egg scenarios that trigger a scene, with a reset for replay, or a flag that blocks
replay, shown in the world as the thing being tied down with ropes, until the player cuts the
ropes with a sharp object such as a knife, a sea star or a sharp rock: an item and interaction
concept for sharp things). This is a design document; it changes no code, and no Godot run was
performed for it (the bead's rule).

Grounding: `docs/DESIGN.md` is a stub; the real design document lives git-crypt encrypted at
`dev/DESIGN.md` and could not be read (`docs/DESIGN.md` says so). The author's own note on
bead 91a is kept in the encrypted dev log and could not be read either, so this design
proceeds from the bead plus the repository; the coordinator checked it against the note
(bd persistint-game-c03l). Every claim about the game cites the file it comes
from. Every invented line, label, flag value or story beat is marked as a draft for the author;
the precedent is the `_draft` note in `project/data/florida.json`'s `gifts`: "Every line and
button label under gifts is draft text for the author's approval." Where this document reuses
the conventions of the sibling design, `docs/design/dialogue-branching.md` (bd c0e), it says
so; that design landed on main while this one was being written (commit 8961ad2; its mirror PR
#3 was open at delegation time).

## 1. What the game already has that is quest-like

Everything the framework needs exists in the repo as a one-off. The framework is the
generalization of these precedents, cited one by one.

**The Offering: flags set by dialogue, barks that react.** The island's one branching quest
today is the Offering. The Initiate's conversation (`project/dialogue/offering.dialogue`) sets
WorldState flags through dialogue mutations: `do WorldState.set_flag("quest_offering_accepted",
true)` on the accepting branch, `questioned_ritual` and `refused_offering` on the others. The
Priestess's conversation (`project/dialogue/priestess.dialogue`) sets `offering_delivered`.
Ambient one-liners in `project/data/barks.json` then react to those flags through `if` blocks:
the Initiate's "You just... said no. Politely. I keep thinking about it." on
`refused_offering`, the Priestess's "The obedient simply glow, don't you think?" on
`offering_delivered`, the Barren's on `puzzle_ritual_done`. `npc.gd` `current_bark()` answers
an ask-around hint first when one is set (`_ask_around_hint()`, npc.gd), and otherwise returns
the first entry whose `WorldState.matches(entry.if)` and `GameClock.matches_when(entry.when)`
both hold. A quest here is already: flags written by interactions, the world reacting to flags.

**The ritual puzzle: a door to a mini-game, replayable forever.** The temple's RitualTable
(`project/scenes/maps/temple.tscn`, node RitualTable) is an Area2D running `project/scripts/
door.gd` with `target_scene` `res://scenes/minigames/ritual_puzzle.tscn` and the exit label
"The Ritual Table"; door.gd's header says "Also used for mini-game entrances (a mini-game is
just another scene)". Completion writes `puzzle_ritual_done`
(`project/scripts/minigames/ritual_puzzle.gd` `_win()`), and the player leaves through
`SceneRouter.goto_map(RETURN_MAP, "spawn_from_puzzle")` (`_leave()`; temple.tscn has the
`spawn_from_puzzle` Marker2D). Replay is unlimited: `_ready()` reshuffles the grid every visit
(`while grid == target: grid.shuffle()`) and nothing gates re-entry.

**Forbidden Knowledge: one-time pickups, never replayed.** The ruins hold 14 pieces of
Forbidden Knowledge (`project/data/ruins.json` "knowledge", 14 entries). A recovered piece
never reappears: `project/scripts/ruins/knowledge_pickup.gd` calls `queue_free()` in `_ready()`
when `ForbiddenKnowledge.has(piece_id)`. The WorldState flag `forbidden_knowledge` is an Array
of piece ids in recovery order (`project/scripts/ruins/forbidden_knowledge.gd`). Pieces unlock
cruise flashbacks (`project/data/flashbacks.json` "requires"; `project/scripts/chapters/
flashbacks.gd`), and a played flashback is marked with a `flashback_seen_<id>` flag
(flashbacks.gd). This is the no-replay precedent.

**Shell pickups: a daily reset.** A beach shell (`project/scripts/florida/shell_pickup.gd`,
header "the beach has more tomorrow") writes `WorldState.set_flag("fl_shell_%s" % name,
GameClock.day)` on pickup and hides; `_ready()` hides it again while the stored day equals
`GameClock.day`, and `GameClock.day_changed` re-shows it. The pickup grants the item through
`Florida.add_item("shell")` and floats "+1 %s" over the spot (`clickable.gd` `float_text`).
This is the reset-for-replay precedent, at day cadence.

**Locked doors: the in-fiction refusal.** door.gd exports `locked` and `locked_bark` (default
"It is sealed."); `interact()` on a locked door shows the bark instead of going through. A
refusal delivered in fiction, at the interacted thing itself, is the precedent for the
blocked-replay answer.

**Name It: dormant beats and named_ flags.** `project/data/name_it.json` holds beats whose
`hook` and `answer` are null and whose `_note` says they are "the author's to set";
`project/scripts/autoload/name_it.gd` `start()` returns without opening the panel until both
are set, and no-ops once `named_<beat_id>` is set; `record()` writes the WorldState flag
`journal`. README.md's Name It row: "Built; its moments are waiting on the author's answers, so
none appear in the game yet". A trigger wired before its content exists is safe here.

**NPC presence by flag, and the calendar.** `project/scripts/npc.gd` exports `show_if_flag`,
`hide_if_flag` and `leave_to` (its comment's example: the Daughter leaves the beach for the
stable after inviting you to the horses), and `scheduled` for the Covenant cast, whose spots
come from `project/data/calendar.json` "schedules" and "places" through
`GameClock.schedule_for` / `location_for` (`project/scripts/autoload/game_clock.gd`).
`schedule_hold` keeps the Initiate in the village until `quest_offering_accepted` or
`refused_offering` is set ("so she keeps the village (her home spot) whatever the schedule
says", game_clock.gd). Where an NPC stands is already flag-driven.

**Items: counts in a flag, labels in data, no inventory screen.** There is no general
inventory UI. Florida items are counts in the WorldState flag `fl_inventory`
(`project/scripts/systems/florida.gd` `inventory()` / `count()` / `add_item()`); the counts
show only in context (the craft bench lists what the player carries, `project/scripts/florida/
craft_bench.gd`; the gift panels list giftable items, `critter.gd` and `stable_panel.gd`).
Display labels live in `project/data/florida.json` under `plants`, `recipes` and `items`
("label"; `Florida.label()`; florida.gd: "ids never show; bd ke5"). `items` today holds only
`shell`. Recipes have `needs` (consumed by `craft()`) and four of the nine have `wear`
(`{slot, part}`; `Florida.wear()` writes `outfit_<slot>`, the wardrobe's flags,
`project/scripts/ui/wardrobe.gd`); recipes without `wear` are gifts (florida.json `gifts`;
`give()` takes one item, `add_item(item, -1)`).

## 2. The framework data format: project/data/quests.json

Proposal: one new JSON data file, `project/data/quests.json`, keyed by scenario id, opened by a
`_note` header. The precedent is one file per system in `project/data/`: barks
(`barks.json`), Name It beats (`name_it.json`), flashbacks (`flashbacks.json`), chapters
(`chapters.json`). The quote store's split into one file per person
(`project/data/quotes/<id>.json`) does not apply: that split exists because each person's
wording is sourced and verified on its own schedule through SOP-06 (the sibling design,
`docs/design/dialogue-branching.md` (bd c0e), gives the same reason for one dialogue-tree file
per celebrity), while scenarios are one system's content with one owner, like barks. No
`quests.json` exists today; `project/data/` holds one file per system and none for quests.

```json
{
  "_note": "Easter-egg quest scenarios (bead persistint-game-91a). One entry per scenario, keyed by scenario id. Steps play in order; the runner keeps quest_<id>_step (int, per-run working state, reset to 0 at each completion and never touched mid-run), sets quest_<id>_done at completion, stores the completion day or cycle in quest_<id>_day / quest_<id>_cycle for the daily and cycle replay modes, and keeps one named flag per block reason. 'if' blocks are WorldState flag equality (WorldState.matches), 'when' blocks are GameClock conditions (GameClock.matches_when): the same two blocks barks use (data/barks.json). A condition block may also carry runner-side keys the quest runner evaluates itself (the third condition kind; the proposed first key is 'has_sharp', Decision needed D1 in docs/design/quest-framework.md), and a key the runner does not know never matches. Every line, label and flag value in a scenario is the author's; the worked examples in docs/design/quest-framework.md mark theirs as drafts.",
  "scenarios": {
    "<scenario id>": {
      "label": "The Buried Box (draft)",
      "steps": [
        {
          "id": "<step id>",
          "target": { "prop": "<node name>", "map": "res://scenes/maps/<map>.tscn" },
          "if": { "<flag>": "<value>" },
          "when": { "phase": "morning" },
          "do": [
            { "line": "A line shown at the target. (draft)" },
            { "set": { "quest_<scenario id>_step": 1 } },
            { "item": "shell", "n": 1 },
            { "name_it": "<beat id>" }
          ]
        }
      ],
      "done": { "if": { "quest_<scenario id>_step": 2 } },
      "on_done": [
        { "set": { "quest_<scenario id>_done": true } }
      ],
      "scene": { "path": "res://scenes/minigames/<scene>.tscn", "spawn": "spawn_default" },
      "replay": { "mode": "daily" }
    }
  }
}
```

A scenario has:

- `label`: the author's name for it. Labels never show raw ids, the florida.gd rule ("ids
  never show; bd ke5").
- `steps`: ordered. A step answers only when the runner's progress flag `quest_<id>_step`
  equals its index (unset reads as 0) and its own `if` and `when` hold. `target` names an
  existing placed prop or node (`prop` + `map`) or an NPC (`npc` + npc_id). `do` effects, all
  existing mechanisms: `set` writes a WorldState flag (the `do WorldState.set_flag(...)`
  mutations in offering.dialogue and priestess.dialogue); `line` shows a line at the target
  (`float_text` for a prop, the clickable.gd precedent; the bark bubble for an NPC, npc.gd
  `_show_bubble`); `item` grants or consumes through `Florida.add_item` (florida.gd);
  `name_it` calls `NameIt.start("<beat_id>")` (priestess.dialogue's
  `do NameIt.start("priestess_easy_girl")`). The daily and cycle replay modes' completion
  marks are runner behavior, not `do` effects; section 3 covers them. A `scene` effect is also
  allowed mid-quest: it sends the player to a scene and the scene reports back by writing a
  flag a later step's `if` reads, which is exactly the ritual puzzle's shape (the door enters,
  `_win()` writes `puzzle_ritual_done`).
- `done`: the completion condition, an `if`/`when` block. When it first holds, the runner sets
  `quest_<id>_done`, runs `on_done` effects once per completion (not once ever: a daily
  scenario grants its reward again each day), resets the per-run working flag
  `quest_<id>_step` to 0 for the next run, and fires the scenario's scene trigger.
  `quest_<id>_step` is touched at no other time: an abandoned run keeps its progress across
  day and cycle boundaries, because a replay mode's mark gates re-entry after completion, never
  mid-run progress.
- `scene`: the scene trigger: a scene path plus a spawn, through `SceneRouter.goto_map(path,
  spawn)` (`project/scripts/autoload/scene_router.gd`), the RitualTable door precedent (door.gd
  `_go()` calls the same function). An optional `card` block in flashbacks.json's shape
  (`heading`, `lines`, `prompt`) shows a full-screen card first, the
  `project/scenes/chapters/flashback_card.tscn` precedent (flashbacks.gd shows the card, then
  starts `entry_scene`). `goto_map` writes the `_location` flag only for scenes under `/maps/`
  (scene_router.gd), so a scenario scene under `scenes/minigames/` leaves the saved location
  alone, as the ritual puzzle does today. Recommendation, no decision needed: scenario scenes
  live in `project/scenes/minigames/` with their scripts in `project/scripts/minigames/`, where
  `ritual_puzzle.tscn` / `ritual_puzzle.gd` and the cruise mini-games live today.
- `replay`: section 3.

Flag conventions, consistent with what exists: `quest_<id>_step` (int progress),
`quest_<id>_done` (bool), `quest_<id>_day` / `quest_<id>_cycle` (the completion mark the runner
stores at each completion for the daily and cycle replay modes; the shell pickup's
`fl_shell_<name> = GameClock.day` shape), and one named flag per block reason (section 3), in
the style of
`quest_offering_accepted` (offering.dialogue), `puzzle_ritual_done` (ritual_puzzle.gd),
`named_<beat_id>` (name_it.gd), `flashback_seen_<id>` (flashbacks.gd) and the sibling design's
`dlg_<celebrity>_*` (`docs/design/dialogue-branching.md`, bd c0e, now on main). All scenario
state lives in WorldState flags, so it saves with the game (`WorldState.set_flag()` saves;
world_state.gd) and barks can read it anywhere, the way barks read quest flags today
(barks.json).

Conditions reuse the two existing vocabularies verbatim, the same two blocks barks use
(`project/data/barks.json`; `project/scripts/npc.gd` `current_bark()`), plus one named third
kind, runner-side keys:

- `if` is a WorldState flag-equality block: every key's flag must equal the given value
  (`WorldState.matches()` in `project/scripts/autoload/world_state.gd`: "True only if every key
  in conditions matches the current flag state").
- `when` is a GameClock block: `GameClock.matches_when()` in
  `project/scripts/autoload/game_clock.gd` supports exactly `festival` (bool), `cycle_day`
  (int), `cycle_day_min`, `cycle_day_max` (int bounds), `cycle` (int), `cycle_min` (int),
  `phase` (String: morning, midday, evening, night) and `days_until_festival` (int); every key
  must match, and an unknown key never matches.
- Runner-side keys are evaluated by the quest runner itself, not by WorldState or GameClock.
  `has_sharp` (does `fl_inventory` hold at least one item whose data entry is `"sharp": true`;
  section 4) is the proposed first key and the only one this document uses, in worked example
  B's `clear_if`; its evaluation mechanism is Decision needed D1. The `when` rule holds here
  too: a key the runner does not know never matches.

The one engine touchpoint the format needs: prop steps need an interactable Area2D at the
target node. The pattern exists three times: click on the Area2D, `player.approach(self)`,
`interact()` on arrival (`project/scripts/florida/clickable.gd`, the base;
`project/scripts/ruins/knowledge_pickup.gd`; `project/scripts/door.gd`), and the E key walks to
the nearest Area2D with `interact()` (`project/scripts/player.gd` `interact_nearest()`). A thin
QuestProp script (new, proposed) sits on such an Area2D and answers for its scenario from
quests.json; static props today (Tag_Yard in village.tscn, RitualAltar in temple.tscn) are
plain Sprite2D nodes with no collision, so each gains the Area2D wrapper. NPC steps need
nothing new: dialogue do-mutations already write flags (offering.dialogue, priestess.dialogue)
and barks already read them (barks.json).

## 3. The replay model

The repo has three replay precedents, one per answer:

- **Again, always.** The ritual puzzle reshuffles on every `_ready()` and nothing gates
  re-entry (ritual_puzzle.gd); `puzzle_ritual_done` stays set and the puzzle still plays.
- **Daily reset.** The shell pickup stores `GameClock.day` in `fl_shell_<name>` and hides
  while it equals `GameClock.day`; `GameClock.day_changed` re-shows it (shell_pickup.gd). "The
  beach has more tomorrow."
- **Once, never again.** The knowledge pickup `queue_free()`s itself once the piece is in the
  `forbidden_knowledge` array flag (knowledge_pickup.gd, forbidden_knowledge.gd).

Proposal: a per-scenario `replay` block with five modes. `again` is the puzzle precedent:
nothing further is tracked and the start interaction always answers. For `daily` and `cycle`
the runner stores the completion day or cycle at each completion, in the conventional flags
`quest_<id>_day` / `quest_<id>_cycle` (the shell flag's exact shape,
`fl_shell_<name> = GameClock.day`), and the start interaction answers the scenario's
`reset_line` (draft text for the author) while the stored value still equals `GameClock.day` or
`GameClock.cycle_number()`; the reset can also be read through the `when` vocabulary, since
`cycle_day`, `cycle` and `cycle_min` are clock keys (game_clock.gd). The mark is runner
behavior, not a `do` effect, so a scenario cannot forget it, and the flag name is the
convention, not a per-scenario choice. `once` is the knowledge precedent: after
`quest_<id>_done` the start interaction goes inert, or the prop hides itself (the
`queue_free()` precedent) when the fiction wants the thing gone. `blocked` is the bead title's
pattern: at first completion the runner sets a named block flag with an in-fiction reason (the
ropes example), and the start interaction answers with the refusal line, shown at the thing
itself the way a locked door shows `locked_bark` ("It is sealed.", door.gd), until a `clear_if`
condition lifts the block.

How the block lifts. `clear_if` is a condition block evaluated when the player interacts with
the block's own target (the ropes, in the bead title's pattern). Cutting the ropes is a
`clear_if` that needs the sharp-things check of section 4; every other lift is a plain `if` /
`when` condition (a flag set elsewhere, a cycle boundary). When `clear_if` holds, the runner
clears the block flag and the scenario's replay continues per a nested mode (`then`), so a
freed scenario can become a daily one. One named flag per block reason keeps the flag list
readable: `quest_<id>_tied_down` in the worked example, alongside `quest_<id>_done`.

The default when a scenario declares no `replay` block is Decision needed D4; the
recommendation there is `once`: every scenario in this framework triggers a scene, an
accidentally re-triggered story scene reads as a bug, and a missed replay is recoverable by
declaring the block, while the knowledge precedent, the only other story-shaped content, is
`once` (knowledge_pickup.gd).

## 4. Sharp things: the item/interaction concept

How items exist today (section 1's survey): counts in the WorldState flag `fl_inventory`
(florida.gd), labels in `project/data/florida.json` under `plants`, `recipes` and `items`, no
general inventory screen, `items` holding only `shell` today, crafting `needs` consumed and
`wear` pieces written to `outfit_<slot>` (florida.gd `craft()` / `wear()`), gift recipes taken
one at a time by `give()`.

Proposal: `sharp` as a data property on an item entry: `"sharp": true` on an entry in
florida.json's `items` (or on a recipe). Nothing else changes about how the item exists: it is
found, counted in `fl_inventory`, labelled in data. At interaction time the check is "does the
inventory hold at least one item whose data entry is sharp". The condition mechanism is
Decision needed D1:

- (a) a runner-side condition key (`has_sharp`) evaluated through `Florida.count` plus the
  data property: no new flags, no new UI, and the inventory already saves with the game
  (florida.gd's header: "Everything lives in WorldState flags (fl_*) so it saves with the
  game") [recommend];
- (b) mirror WorldState flags written when a sharp item enters or leaves the inventory:
  duplicates state, and every writer of `fl_inventory` must maintain the mirror;
- (c) per-item flags (`has_sea_star`): the condition vocabulary stays flag-equality only, but
  flags multiply per item and per scenario that asks.

The bead's three examples, fitted to the existing item models:

- **Sea star, sharp rock**: found items on the beach, entries in florida.json's `items` next to
  `shell`, picked up the shell pickup's way (shell_pickup.gd; beach.tscn places Shell1 to
  Shell3 today). Recommendation: the beach's daily cadence, "the beach has more tomorrow"
  (shell_pickup.gd's header), so the player who used or skipped one finds another. No sea star,
  sharp rock or knife exists in the repo today (a search for them finds only unrelated uses of
  "sharp" in tooling docs), so all three entries are new data rows, their labels draft text for
  the author.
- **Knife**: the fiction home is Decision needed D2. Options: (a) omit the knife for now and
  let the sea star and the sharp rock carry the concept [recommend]; (b) a ruins found item
  (the Forbidden Knowledge pickup precedent, knowledge_pickup.gd, but ruins pickups are
  one-time and story-flavored); (c) a crafted recipe with `needs` (florida.json `recipes`),
  which puts a knife on the craft bench next to the key lime pie.

One thing said plainly: sharp things here are interaction tools for cutting ropes, never
weapons. There is no combat anywhere (README.md: "There is **no combat** anywhere. Influence,
not violence."; docs/CLASSROOM.md's content table: "No combat anywhere"), and the tropical
Florida Keys, where the sea star and the sharp rock would wash up, is the innocent-play world
(README.md's premise table: "Innocent play"). The check opens an interaction; it never starts
a fight.

Whether using a sharp thing consumes it is Decision needed D3. Recommendation: keep it.
Nothing consumes found items today except crafting `needs` and gifts (florida.gd `craft()`
subtracts `needs`; `give()` takes one item), and a kept tool matches the sandbox's rule
(florida.gd's header: "Nothing is scored and nothing can be done wrong.").

## 5. How the framework serves bead 0w3

Bead persistint-game-0w3 is the framework's first consumer: "[epic] The Margaret Atwood skull:
secret quest from the temple pedestal to the vats (Sisterhood chase, village reaction, drone
shield, the bunker wakes, Atwood pops out and lectures, the handmaid dress-up fleet, Chapter
One, the revolt, the Queen returns the skull)" (the bead tracker's title for
persistint-game-0w3). 0w3 is its own bead and its author notes are encrypted the same way 91a's
are, so the title is all there is to go on. This section shows the framework fits the chain; it
does not design 0w3, and every step reading is an illustration for the author.

| Beat (from the 0w3 title) | What exists today | What the framework still needs |
|---|---|---|
| the temple pedestal | The skull altar `prop_skull_altar` (`project/data/island_props.json`) is placed in the temple as the RitualAltar Sprite2D, beside the RitualTable door (`project/scenes/maps/temple.tscn`; `tools/build_island_maps.gd` places it there). It is static and non-interactive. | The section 2 touchpoint: an interactable Area2D wrapper, making the altar the first step's target. |
| to the vats; the bunker wakes | The ruins' clone lab (`project/scripts/ruins/clone_lab.gd`; `project/scripts/ruins/zombie_child.gd`; ruins.json `clone_children`, whose `_note` says "Nobody fights: the player only watches."). | Step targets on lab props; the waking plays as watched events and flags, not combat. |
| Sisterhood chase | NPC presence by flag (npc.gd `show_if_flag` / `hide_if_flag` / `leave_to`) and calendar scheduling (npc.gd `scheduled`; calendar.json `schedules` / `places`; `GameClock.location_for`). | A staged chase needs movement beyond today's schedules; flagged as new to build. |
| village reaction | barks.json entries conditioned on flags, the Offering precedent (offering.dialogue sets `quest_offering_accepted` / `refused_offering` / `questioned_ritual`; the initiate, priestess, drone and barren entries react). | Nothing new: `if`-conditioned barks on the scenario's flags. |
| drone shield | The drone is an existing cast member (`project/data/cast.json` drone, "Bruce") with barks (barks.json drone entries). | Scenario steps targeting the drone; content is the author's. |
| Atwood pops out and lectures | cast.json `atwood` = {"name": "Margaret Atwood", "short": "Margaret"}; `project/data/quotes/atwood.json`, 40 entries, 21 usable (verified=true, not excluded_from_game, not about_others; the `project/tests/test_quotes_vv.gd` gate). The lecture's delivery is the sibling design, `docs/design/dialogue-branching.md` (bd c0e, now on main). A Name It beat can hang off it (the `name_it` effect; name_it.gd), its content the author's (name_it.json `_note`). | An Atwood NPC node (presence by flag exists) and her tree per the sibling design; quote keys are that design's open D1. |
| the handmaid dress-up fleet | The wardrobe writes `outfit_<slot>` flags (wardrobe.gd); crafted wearables write them too (florida.gd `wear()`); chapters.json archives the `outfit_` and `player_` flag prefixes across chapter jumps. | Outfit parts (art and data). Note the quote gate keeps Handmaid's Tale content out of spoken lines (atwood.json's `excluded_from_game` entries; test_quotes_vv.gd's header: "Handmaid's Tale content: author rule"), so this beat reads as costume, not quotation. |
| Chapter One; the revolt; the Queen returns the skull | The scene trigger with the `card` variant (flashback_card.tscn precedent; chapters.json and `project/scenes/chapters/` run chapter transitions with a full-screen card). | The scenes themselves. The revolt plays as watched events and bark reactions: "Nobody fights: the player only watches." (ruins.json) and "no combat anywhere" (README.md). |

The lecture beat's lines come only from the usable set of atwood.json. Two verbatim examples,
illustrating sourcing only (which lines the lecture uses is the author's choice):

```json
{
  "_note": "Illustration for docs/design/quest-framework.md section 5: how the lecture beat of bead persistint-game-0w3 would source its lines. Both strings are verbatim from project/data/quotes/atwood.json entries that are verified=true, not excluded_from_game and not about_others (the usable set gated by project/tests/test_quotes_vv.gd). This block proposes no wording choice; that choice is the author's.",
  "atwood_verbatim": [
    "In times of extremes, extremists win.",
    "The aim of ideology is to eliminate ambiguity."
  ]
}
```

## 6. Worked example: the buried box, two ways

The bead title's own ropes pattern, twice: variant A resets for replay, variant B blocks replay
until the ropes are cut. Both build on real, cited things: the X-marks-the-spot prop
`prop_tag_x` (`project/data/island_props.json`), which two scenes place today (the village's
Tag_Yard and the temple's Tag_Ruins, both static Sprite2D nodes: village.tscn, temple.tscn;
`tools/build_island_maps.gd` places both); the beach map
(`project/scenes/florida/beach.tscn`); the gulls' gift unlock, where a good-friend gull brings
one Shell a day (florida.json `gifts`, gull unlock id "shell"; florida.gd `gull_shell()`), the
precedent for a small daily reward; an `fl_inventory` item grant on completion
(`Florida.add_item`); and the shell pickup's daily reset. The triggered scene is a proposed new
file (`res://scenes/minigames/buried_box.tscn`): no treasure-dig scene exists today, and the
mechanism is `SceneRouter.goto_map`, the RitualTable precedent. Every invented line, label and
flag value below is marked as a draft for the author.

Variant A, reset for replay:

```json
{
  "_note": "Worked example A for docs/design/quest-framework.md (bead persistint-game-91a): the bead title's ropes pattern as a reset-for-replay scenario. Every label, line, flag value and scene path in this scenario is an illustrative draft for the author (the gifts._draft precedent in project/data/florida.json). Tag_Yard is the prop_tag_x sprite placed in project/scenes/maps/village.tscn; the beach is project/scenes/florida/beach.tscn. The dig-spot prop and the scene are proposed new files ('new': true).",
  "scenarios": {
    "buried_box_a": {
      "label": "The Buried Box (draft)",
      "steps": [
        {
          "id": "spot_the_tag",
          "target": { "prop": "Tag_Yard", "map": "res://scenes/maps/village.tscn" },
          "do": [
            { "line": "An X cut into the dirt of the yard. Something was buried here, once. (draft)" },
            { "set": { "quest_buried_box_a_step": 1 } }
          ]
        },
        {
          "id": "dig_on_the_beach",
          "target": { "prop": "DigSpot_Beach", "map": "res://scenes/florida/beach.tscn", "new": true },
          "if": { "quest_buried_box_a_step": 1 },
          "do": [
            { "line": "The sand here is softer than it looks. (draft)" },
            { "set": { "quest_buried_box_a_step": 2 } }
          ]
        }
      ],
      "done": { "if": { "quest_buried_box_a_step": 2 } },
      "on_done": [
        { "item": "shell", "n": 3 },
        { "set": { "quest_buried_box_a_done": true } }
      ],
      "scene": { "path": "res://scenes/minigames/buried_box.tscn", "spawn": "spawn_default", "new": true },
      "replay": {
        "mode": "daily",
        "reset_line": "Nothing new buried today. The beach has more tomorrow. (draft)"
      }
    }
  }
}
```

What the player sees, and every flag read and written:

1. In the village, the player clicks the X tag in the yard (Tag_Yard, village.tscn, wrapped in
   the proposed QuestProp Area2D). The runner reads `quest_buried_box_a_step` (unset, so 0):
   step one answers. The float line "An X cut into the dirt of the yard. Something was buried
   here, once. (draft)" rises over the tag (clickable.gd `float_text`), and the runner writes
   `quest_buried_box_a_step` = 1 (`WorldState.set_flag`, which saves, world_state.gd).
2. On the beach, the dig spot (proposed new prop) answers because its
   `if {"quest_buried_box_a_step": 1}` holds (`WorldState.matches`). Clicking it floats "The
   sand here is softer than it looks. (draft)" and the runner writes
   `quest_buried_box_a_step` = 2.
3. `done {"if": {"quest_buried_box_a_step": 2}}` now holds. The runner grants three Shells
   (`Florida.add_item("shell", 3)`, which reads and rewrites the `fl_inventory` flag,
   florida.gd) and sets `quest_buried_box_a_done` = true; the mode being daily, the runner also
   stores the completion day in `quest_buried_box_a_day` (the shell pickup's
   `fl_shell_<name> = GameClock.day` shape) and resets the per-run flag
   `quest_buried_box_a_step` to 0. Then it fires the scene trigger: `SceneRouter.goto_map("res://scenes/minigames/
   buried_box.tscn", "spawn_default")`. The little scene (proposed new file) plays the dig and
   the reveal; its leave button returns to the beach the ritual puzzle's way
   (`SceneRouter.goto_map` back, ritual_puzzle.gd `_leave()`). Because the scene is not under
   `/maps/`, `goto_map` writes no `_location` flag (scene_router.gd); the saved location stays
   the beach.
4. Later the same day, clicking the tag again: `replay.mode` daily compares
   `quest_buried_box_a_day` with `GameClock.day`; they are equal, so the interaction answers
   "Nothing new buried today. The beach has more tomorrow. (draft)", shown at the tag the way a
   locked door shows `locked_bark` (door.gd).
5. When `GameClock.day_changed` fires (game_clock.gd), the comparison with
   `quest_buried_box_a_day` fails and the scenario is live from step 1 again; the working flag
   `quest_buried_box_a_step` was already reset at completion, so nothing is wiped at midnight.
   Had the player walked away mid-run instead, the flag would have kept its value across the
   day boundary and the run would resume where it stopped. `quest_buried_box_a_done` stays set:
   the player did it once, and barks can know (the barks.json precedent of reacting to
   `puzzle_ritual_done`).

Variant B, blocked replay: the same shape, but first completion ties it down with ropes.

```json
{
  "_note": "Worked example B for docs/design/quest-framework.md (bead persistint-game-91a): the same Easter egg with blocked replay. First completion ties it down with ropes; the block lifts when the player cuts them with a sharp thing. Every label, line, flag value and scene path in this scenario is an illustrative draft for the author; the author words the final refusal line. The ropes prop and the scene are proposed new files ('new': true); 'has_sharp' is the condition key proposed in Decision needed D1.",
  "scenarios": {
    "buried_box_b": {
      "label": "The Buried Box, tied down (draft)",
      "steps": [
        {
          "id": "spot_the_tag",
          "target": { "prop": "Tag_Yard", "map": "res://scenes/maps/village.tscn" },
          "do": [
            { "line": "An X cut into the dirt of the yard. Something was buried here, once. (draft)" },
            { "set": { "quest_buried_box_b_step": 1 } }
          ]
        },
        {
          "id": "dig_on_the_beach",
          "target": { "prop": "DigSpot_Beach", "map": "res://scenes/florida/beach.tscn", "new": true },
          "if": { "quest_buried_box_b_step": 1 },
          "do": [
            { "line": "The sand here is softer than it looks. (draft)" },
            { "set": { "quest_buried_box_b_step": 2 } }
          ]
        }
      ],
      "done": { "if": { "quest_buried_box_b_step": 2 } },
      "on_done": [
        { "item": "shell", "n": 3 },
        { "set": { "quest_buried_box_b_done": true } }
      ],
      "scene": { "path": "res://scenes/minigames/buried_box.tscn", "spawn": "spawn_default", "new": true },
      "replay": {
        "mode": "blocked",
        "block_flag": "quest_buried_box_b_tied_down",
        "block_reason": "the village tied the box down with ropes (draft)",
        "block_target": { "prop": "BuriedBox_Ropes", "map": "res://scenes/florida/beach.tscn", "new": true },
        "block_line": "Somebody tied this down with ropes. (draft; the author words the final line)",
        "blocked_sharpless_line": "The knots are tight. You need something with an edge. (draft)",
        "clear_if": { "has_sharp": true },
        "clear_line": "The ropes part under the edge. The box is free again. (draft)",
        "then": {
          "mode": "daily",
          "reset_line": "Nothing new buried today. The beach has more tomorrow. (draft)"
        }
      }
    }
  }
}
```

What the player sees, and every flag read and written:

1. The first playthrough is variant A's, steps 1 to 3: `quest_buried_box_b_step` goes 1 then 2,
   three Shells enter `fl_inventory`, `quest_buried_box_b_done` is set, and the proposed scene
   plays.
2. At completion the runner also sets the named block flag `quest_buried_box_b_tied_down` =
   true, with the in-fiction reason "the village tied the box down with ropes (draft)", and
   resets the per-run flag `quest_buried_box_b_step` to 0, as at every completion.
3. Clicking the tag now answers the refusal: "Somebody tied this down with ropes. (draft; the
   author words the final line)". It shows at the tag the way door.gd shows "It is sealed."
   for a locked door.
4. The block lifts in fiction. The player picks up a sea star or a sharp rock on the beach
   (section 4; both are proposed new `items` entries with `"sharp": true`, granted the shell
   pickup's way). Clicking the ropes prop on the beach (BuriedBox_Ropes, proposed new prop)
   evaluates `clear_if {"has_sharp": true}`: the D1(a) runner key, counting sharp-tagged items
   in `fl_inventory` through `Florida.count` plus the data property. Holding none, the player
   hears "The knots are tight. You need something with an edge. (draft)". Holding one, the
   runner floats "The ropes part under the edge. The box is free again. (draft)" and sets
   `quest_buried_box_b_tied_down` = false.
5. From then on replay follows variant A's reset: the nested `then` mode is daily, so the
   runner stores each completion's day in the conventional mark flag `quest_buried_box_b_day`
   and the tag answers the reset line until tomorrow.

## Decision needed

- D1, the `has_sharp` condition mechanism (section 4): (a) a runner-side condition key
  evaluated through `Florida.count` plus the `"sharp": true` data property (no new flags, no
  new UI; the inventory already saves) [recommend]; (b) mirror WorldState flags written when a
  sharp item enters or leaves the inventory; (c) per-item flags.
- D2, the knife's fiction home (section 4): (a) omit the knife for now and let the sea star and
  the sharp rock carry the concept [recommend: the Florida Keys are the innocent-play world
  (README.md's premise table), and a knife reads as a weapon before it reads as a tool in a
  game with no combat]; (b) a ruins found item (the Forbidden Knowledge precedent); (c) a
  crafted recipe with `needs`.
- D3, consume or keep sharp items on use (section 4): (a) keep [recommend: nothing consumes
  found items today except crafting `needs` and gifts (florida.gd), and "Nothing is scored and
  nothing can be done wrong" (florida.gd's header)]; (b) consume on use.
- D4, the default replay mode when a scenario declares no `replay` block (section 3): (a)
  `once` [recommend: every scenario here triggers a scene, an accidentally re-triggered story
  scene reads as a bug, and a missed replay is recoverable by declaring the block; the
  Forbidden Knowledge precedent is `once` (knowledge_pickup.gd)]; (b) `again` (the puzzle
  precedent, ritual_puzzle.gd); (c) no default: the runner rejects a scenario with no `replay`
  block, forcing the author to choose.

Coordinator's check against the author's note (bd persistint-game-c03l, 2026-11-03): the design
covers what the note asks for (scenarios that trigger a scene, a reset for replay, a flag that
blocks replay shown as something tied down with ropes, cutting the ropes with a sharp thing, a
general concept of sharp objects), and the Atwood skull quest (bd 0w3) is the note's first
example. One difference: the note names a knife among the sharp things, so D2's option (a)
drops something the author listed; options (b) and (c) keep it. D1 to D4 are the author's.

## Not verified

- `dev/DESIGN.md` is git-crypt encrypted and could not be read; `docs/DESIGN.md` is a stub that
  says so. The real design document's intent for quests, replay or items is unknown to this
  document.
- The author's full comment on bead 91a could not be read: it moved to the encrypted dev log
  (`dev/author-log/beads-comments-2026-11-02.md`). Only the first lines quoted in the
  grounding paragraph were read, before the move; the rest of the note, including how "th..."
  continues, is unknown.
- Bead persistint-game-0w3's author notes are encrypted the same way; section 5 works from its
  tracker title only and designs nothing for it.
- No Godot run was performed (the bead's rule for a design deliverable); nothing in this
  document was executed, and the proposed JSON was checked only as data (it parses), not loaded
  by any runner, which does not exist.
- The sibling design referenced throughout (`docs/design/dialogue-branching.md`, bd c0e) landed
  on main during this task (commit 8961ad2; its mirror PR #3 was open at delegation time). Its
  own Decision needed items (quote keys, player reply sourcing, fragment quotes, Name It beat
  content) remain the author's to settle, and this document's proposals that build on its
  conventions (the `dlg_<celebrity>_*` flag style, the tree as the lecture's delivery) inherit
  that.
- Everything invented here is marked draft for the author: every scenario label, step line,
  reset line, block line, clear line, flag value (`quest_buried_box_a_*`, `quest_buried_box_b_*`),
  item entry (sea star, sharp rock, knife), prop (DigSpot_Beach, BuriedBox_Ropes) and the scene
  `res://scenes/minigames/buried_box.tscn`. The D1 to D4 decisions are the author's to make.
