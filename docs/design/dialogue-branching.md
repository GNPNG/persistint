# Branching dialogue from sourced quotes

A design for Fallout-style branching dialogue for every celebrity (bead persistint-game-c0e):
each celebrity's lines come only from their verified quotes in `project/data/quotes/<id>.json`,
and the player's reply options are proposed and flagged for the author. This is a design
document; it changes no code, and no Godot run was performed for it (the bead's rule).

Grounding: `docs/DESIGN.md` is a stub; the real design document lives git-crypt encrypted at
`dev/DESIGN.md` and could not be read (`docs/DESIGN.md` says so). Where repo comments cite
DESIGN.md (for example "DESIGN.md §2" in `project/scripts/minigames/next_top_comic.gd`), this
document cites the comment as observable repo behavior, not the encrypted file. Every other
claim cites the file it comes from.

## 1. The tree format: one JSON file per celebrity, rendered through a shared skeleton

Proposal: each celebrity's conversation tree is a JSON data file at
`project/data/dialogue/<id>.json` (a new directory; `<id>` is the cast id from
`project/data/cast.json`, for example `hillary_clinton` for "Hillary Clinton"). One shared
Dialogue Manager skeleton, a single thin `.dialogue` file with a fixed set of response slots,
renders any tree; one shared GDScript node loads the JSON, serves the slots and holds the game
state. This is the pattern the repo already uses twice:

- `project/dialogue/interview.dialogue` + `project/scripts/minigames/interview.gd`: Oprah's
  intro and prompts come from `project/data/interview.json`; the `.dialogue` file holds fixed
  answer slots whose text is interpolated from the script, with `hide_failed_responses = true`
  so only filled slots show.
- `project/dialogue/next_top_comic.dialogue` + `project/scripts/minigames/next_top_comic.gd`:
  40 fixed response slots (`MAX_SLOTS := 40`) filled from a shuffled data pool, with the same
  `hide_failed_responses` setting.

The alternative, extending `.dialogue` syntax with data references, was weighed and rejected:

- A forked addon. Dialogue Manager 3.10.4 is vendored under `project/addons/dialogue_manager/`
  (MIT; README.md, "Credits and provenance"). New syntax means maintaining a fork of the addon;
  the hybrid pattern needs no addon change.
- The quote gate. `project/tests/test_quotes_vv.gd` gates each consumer by loading its data and
  checking every line against the quote store's usable set (Oprah's interview lines, the emcee's
  intros, the comic pool, the clone children's pools). JSON nodes name their quote by key, so
  the same per-line check extends to dialogue trees exactly; lines written inline in `.dialogue`
  text could only be found by string search (the test's leak search already scans
  `dialogue/*.dialogue` for unverified text, but the positive per-line gate is per consumer).
- One source of wording. Quote text in JSON stays next to its key; SOP-06 step 6
  (`sops/06-quote-sourcing-vv.md`) replaces wording store-wide on correction and records the old
  wording in `was`, and the test treats `was` text as never allowed in game. Inline `.dialogue`
  copies would have to be re-edited by hand per correction.
- Precedent for content as JSON. The repo already keeps content in JSON: barks
  (`project/data/barks.json`), the interview (`project/data/interview.json`), emcee intros
  (`project/data/emcee.json`), Name It beats (`project/data/name_it.json`).

Hand-written `.dialogue` remains the right tool for the fictional island NPCs: their lines are
original writing (the SOP-06 section 2 scope-out, section 3 below) and their files are small
and flag-driven (`project/dialogue/offering.dialogue`, `project/dialogue/priestess.dialogue`).
The JSON tree is for the real people, whose lines must stay quote-gated.

### Node schema

```json
{
  "celebrity": "hillary_clinton",
  "quotes": "hillary",
  "hub": "hub",
  "nodes": { "<node id>": { "...": "..." } }
}
```

Each node has a `type` of `hub`, `branch` or `return` (section 4), plus:

- `first_lines` (hub only): the celebrity's lines the first time the hub opens, in the same
  `{"quote", "text"}` line shape as `lines`; the runner plays them only before it sets the
  `dlg_<celebrity>_met` flag, then plays `lines` on every later open (the re-entry rules in
  section 4).
- `lines`: the celebrity's lines when the node is entered, in order. A line is
  `{"quote": "<key>", "text": "<verbatim store text>"}` (section 2), or
  `{"narration": "[stage direction]"}` for a bracketed narrator line not attributed to the
  celebrity; the precedent is `next_top_comic.gd`, whose `audience_laugh()` returns
  "[audience laughs riotously]".
- `options` (hub and branch nodes): player replies,
  `{"to": "<node id>", "text": "...", "tone": "...", "source": "...", "if": {...}, "when": {...}, "repeat": true}`;
  `if`, `when` and `repeat` are optional.
- `effects`: run when the node completes. Two kinds, both existing mechanisms:
  `{"set": {"<flag>": <value>}}` writes a WorldState flag (the `do WorldState.set_flag(...)`
  mutations in offering.dialogue and priestess.dialogue), and `{"name_it": "<beat_id>"}` calls
  `NameIt.start("<beat_id>")` (priestess.dialogue, the `do NameIt.start("priestess_easy_girl")`
  line). Journal entries are not a separate effect: named tactics reach the journal through
  Name It itself, when `NameIt.record()` writes the WorldState flag `journal`
  (`project/scripts/autoload/name_it.gd`), displayed in the journal's "Named" section
  (`project/scripts/ui/journal.gd`).
- `return`: where control goes when the node ends: `"hub"` loops back to the hub, `"END"`
  closes the conversation (Dialogue Manager's `=> END`, as in offering.dialogue).

Conditions reuse the existing vocabulary verbatim:

- `if` is a WorldState flag-equality block: every key's flag must equal the given value
  (`WorldState.matches()` in `project/scripts/autoload/world_state.gd`: "True only if every key
  in conditions matches the current flag state").
- `when` is a GameClock block: `GameClock.matches_when()` in
  `project/scripts/autoload/game_clock.gd` supports exactly `festival` (bool), `cycle_day`
  (int), `cycle_day_min`, `cycle_day_max` (int bounds), `cycle` (int), `cycle_min` (int),
  `phase` (String) and `days_until_festival` (int); every key must match, and an unknown key
  never matches. These are the same two blocks barks use today (`project/data/barks.json`;
  `project/scripts/npc.gd` `current_bark()`).

The one engine touchpoint the format needs: `npc.gd` `interact()` calls
`DialogueManager.show_dialogue_balloon(load(dialogue_path), dialogue_title)` with no extra
state (`project/scripts/npc.gd` lines 325-332; `dialogue_title` defaults to "start"), while the
minigames pass their game state as `[self]` (interview.gd, next_top_comic.gd). The tree runner
needs the JSON path handed to the skeleton the same way, for example an exported data path on
the NPC passed as extra state. Everything else (slot interpolation, conditional slots, response
menus) is what the two existing skeletons already do.

## 2. A celebrity's node set: verified lines only

The quote store is one JSON file per person under `project/data/quotes/`, 14 files for the 14
public figures (README.md, "Credits and provenance"; docs/CLASSROOM.md's real-people row lists
the fourteen). Today's per-quote fields, from `project/data/quotes/hillary.json`'s
`_verification.fields` and the checks in `project/tests/test_quotes_vv.gd`:

- `text`: the exact wording checked against the source.
- `source`, `url`: what the line is and where it was found.
- `aggregator`: true when the url is a quote-collection site, not the original (SOP-06 section 5,
  procedure step 2).
- `verified`: true only for lines checked word for word against the source page; hillary.json's
  `_verification.rule` reads "Only quotes with verified=true may be used in game
  (tests/test_quotes_vv.gd)".
- `checked_url`: the page the wording was matched on; `primary_source` when that differs from
  `url`.
- `note`: attribution caveat or comparison method.
- `was`: the original text when a correction changed the wording; the test treats `was` strings
  as never allowed in game.
- `about_others`: a line said about other people; `_verification.fields` says "the clone
  children say it when another clone is near".
- `excluded_from_game`: the Handmaid's Tale content rule; the test fails Handmaid's Tale
  content that is not flagged, and keeps flagged content out of the usable set.

The rule for the tree: a celebrity speaks a line only if its entry has `verified: true` and not
`excluded_from_game: true`. That is the test's "usable" set (`test_quotes_vv.gd`:
`q.get("verified") == true and q.get("excluded_from_game") != true`), the same set the clone
children's pools are checked against. Lines tagged `about_others: true` pass that gate but stay
out of the speaker's own tree: they are reserved for the clone children per the tag's own
definition (hillary.json's basket-of-deplorables entry says so in its note).

A quote becomes a node line as `{"quote": "<key>", "text": "<verbatim>"}`: the key says which
store entry the line is, the text carries the wording so the tree file reads on its own, and
the gate test asserts the pair matches a usable store entry. `if` and `when` attach to nodes
and options as in section 1; effects attach to nodes.

Quote entries have no key or id field today: the `quotes` arrays in `project/data/quotes/*.json`
are anonymous, and the test keys its usable set by text. The tree format needs a stable key,
and how it is minted is Decision needed D1:

- (a) Add a `key` field per quote entry: a short slug, unique within the person's file, minted
  once by the controller agent who owns the quote store (SOP-06 section 4, roles table) and
  never renumbered; a wording correction keeps the key and moves the old text to `was`.
- (b) Use array indices. Fragile: inserting a quote renumbers every later entry.
- (c) Use the text itself as the key, as the test already does internally. No schema change,
  but a correction silently breaks every reference, and keys become unreadable in tree files.

Recommendation: (a). It makes tree lines auditable at a glance and keeps references stable
across the SOP-06 correction flow; the gate test can then check key existence as well as
wording.

## 3. Where the player's reply options come from (Decision needed D2)

The open question. Real people's lines are settled (section 2); the player's side of the
conversation is not. The player character is fictional: each chapter has its own player
character (`world_state.gd`, "The player's name"), and the two places the game constrains
invention both scope it to real people: SOP-06 section 2 ("Do not use when: The lines are
original writing for a fictional character with no real-world counterpart") and
docs/CLASSROOM.md ("Nothing about a real person is invented"). Player menu lines today are
author-written: "Of course.", "Why does everyone have to contribute?", "No, thank you." in
offering.dialogue.

Options:

- (a) Author-written player lines. Plain fictional-character writing, scoped out of the quote
  V&V by SOP-06 section 2. Full control of tone and of what each branch asks; the cost is
  author time, and the author's open questions already include who writes the Name It text
  (CLASSROOM.md, "Open questions for the author").
- (b) Tone-tagged options in Fallout's style: two to four replies per node tagged by stance
  (for example earnest, skeptical, deflect), still author-written text, with the tag shown so
  the player reads the stance before the words. This is (a) with a UI contract that keeps
  options honest and short.
- (c) Player lines drawn from `project/data/empowerment_lines.json`: 41 sourced slogans
  (Women's March 2017 sign slogans from two lists; Sheryl Sandberg's Lean In; Brené Brown;
  Laurel Thatcher Ulrich), verbatim from the pages in their `url` per the file's `_note`, which
  adds "cruise dialogue is lifted almost verbatim from mass-media feminist literature". Nothing
  loads this file today (a grep of `project/` and `tools/` finds no reference to it). Its
  entries carry no per-line `verified` field, and it sits outside the quote-store gate, which
  reads only `data/quotes/*.json` (`QUOTES_DIR` in test_quotes_vv.gd). CLASSROOM.md's content
  table already counts the file ("hell" twice in the empowerment lines).

Recommendation: a hybrid of (b) and (c). Every option carries a tone tag; the text comes from
empowerment_lines.json where a slogan fits and is author-written where none does. The reason is
the game's own joke. The cruise is the judged-performance world (README.md, "The premise":
passengers are "made over, judged and 'empowered'"), and Next Top Comic already has the player
perform other people's lines and get judged on the performance, boos and docked points included
(README.md, "What's playable now"; `next_top_comic.gd` `_judge()`). A passenger answering
Hillary Clinton with Women's March slogans is the same mechanic at conversation scale:
empowerment-speak performed back at the woman whose own speeches are the genre. It also keeps
even the player's voice sourced rather than invented, and it gives the orphan file its job.
Because the passenger is fictional, SOP-06 does not gate these lines either way, but adopting
(c) has a precondition: empowerment_lines.json must first pass the same per-line verification
the quote store enforces. Its entries carry only `text`, `source` and `url`; there is no
`verified` field, and 4 of the 41 entries are Goodreads-hosted, which in the quote store marks
a line aggregator-only and unverified until a primary source is found (SOP-06 section 5,
procedure steps 2 and 4; hillary.json's It Takes a Village line is the store's own worked case
of that rule, section 6). Recommending the file for the player before that pass would hold the
player's voice to a lower standard than section 2 holds the celebrity's. Until the pass runs,
the example's two empowerment-sourced options are illustrations of the hybrid, not shipped
lines; (b) alone carries no such precondition.

## 4. Hub, branch, return: the Fallout shape

One hub node per celebrity; every conversation opens at the hub. Branches are topics; a branch
returns to the hub (`"return": "hub"`) or ends the conversation at a return node
(`"return": "END"`). The hub shape, schematic, using the existing flags and clock keys from
section 1 (`quest_offering_accepted` is the flag offering.dialogue sets):

```json
"hub": {
  "type": "hub",
  "first_lines": [ {"quote": "...", "text": "..."} ],
  "lines": [ {"quote": "...", "text": "..."} ],
  "options": [
    {"to": "offerings", "text": "...", "if": {"quest_offering_accepted": true}},
    {"to": "festival_eve", "text": "...", "when": {"days_until_festival": 1}},
    {"to": "goodbye", "text": "..."}
  ]
}
```

Re-entry rules:

- The runner sets `dlg_<celebrity>_met` the first time a hub opens. `first_lines` play only
  before that flag; `lines` play on every later open. A re-opened conversation therefore greets
  differently, the way priestess.dialogue and offering.dialogue pick their start-title branch
  on `WorldState.has_flag(...)`, and clicking the NPC again re-opens the balloon (`npc.gd`
  `interact()`).
- When a branch completes, its effects set `dlg_<celebrity>_<branch>_done`. The hub hides
  options to done branches unless the option has `"repeat": true` (Fallout's asked-and-answered
  greying), so a re-opened conversation rotates to what is left; repeatable branches stay.
- All conversation state lives in WorldState flags, so it saves with the game
  (`WorldState.set_flag()` saves; world_state.gd) and conditions can read it anywhere, the way
  barks read quest flags today (barks.json entries with `if` on `refused_offering`,
  `questioned_ritual`, `offering_delivered`).

A return node plays optional parting lines and ends the conversation; the hub's leave option
points at one.

## 5. Barks, Name It and Next Top Comic: how the tree fits what exists

Barks stay the ambient layer. `project/data/barks.json` holds one-liners per NPC with `when`
and `if` conditions; `npc.gd` `current_bark()` returns the first entry whose
`WorldState.matches(entry.if)` and `GameClock.matches_when(entry.when)` both hold, walk-by
proximity barks fire only when no dialogue balloon is open, and `_show_bubble` voices them
(`project/scripts/npc.gd`). The tree is the clicked-conversation layer: `npc.gd` `interact()`
already prefers a Dialogue Manager balloon when the NPC has `dialogue_path` set and falls back
to the bark bubble otherwise (lines 325-332). A celebrity with a tree gets the balloon; the
barks underneath keep reacting to the calendar and to what the player has done. The trees
attach anywhere a celebrity NPC stands with `dialogue_path` set; README.md notes "There is no
cruise hub map yet", and the format does not depend on one.

Name It hangs off branches. The effect `{"name_it": "<beat_id>"}` is the existing
`do NameIt.start("priestess_easy_girl")` mutation (priestess.dialogue) in JSON form;
`hottest_of_the_hot.gd` (line 136) and `next_top_comic.gd` `finish()` trigger beats the same
way. `NameIt.start()` runs the two-step panel only when the beat exists and its author has set
`hook` and `answer`, and only once per beat (`project/scripts/autoload/name_it.gd`); a correct
pick calls `NameIt.record()`, which writes the tactic and its quoted hook lines into the
WorldState flag `journal`, shown in the journal's "Named" section
(`project/scripts/ui/journal.gd`). The content is the author's: `project/data/name_it.json`'s
`_note` says "hook and answer are the author's to set", every shipped beat has both null, and
README.md's Name It row reads "Built; its moments are waiting on the author's answers, so none
appear in the game yet". This design wires the trigger; it does not write the beat (Decision
needed D4).

Next Top Comic is the proof this works. A data-driven celebrity conversation built only from
verified quotes already ships: `next_top_comic.gd` builds its pool from `data/quotes/<id>.json`
jokes with `if joke.get("verified") != true: continue`, the 40-slot
`next_top_comic.dialogue` skeleton renders the pool with `hide_failed_responses`, and
test_quotes_vv.gd asserts the pool is exactly the verified jokes of its source comics. The tree
format is the same skeleton-and-data pattern with hub, branch and return in place of setup and
punchline.

## 6. Worked example: Hillary Clinton

Source: `project/data/quotes/hillary.json`, 45 entries: 44 verified, 1 unverified
(`_verification`: verified 44, unverified 1, total 45). Of the 44, one is tagged
`about_others: true` and reserved for the clone children, leaving 43 lines Hillary can say in
her own tree. Quote keys below are the slugs proposed in D1; they do not exist in the file yet.
Every text is verbatim from the store, including its punctuation and capitalization (several
entries are mid-sentence extracts and begin lowercase; see the notes after the tree).

```json
{
  "_note": "Worked example for docs/design/dialogue-branching.md. Every Hillary Clinton line is verbatim from project/data/quotes/hillary.json (verified entries only), cited by the quote keys proposed in Decision needed D1; those keys do not exist in the quote file yet. Player option text with source 'empowerment' is verbatim from project/data/empowerment_lines.json; source 'author' marks placeholder text the author would write or approve (Decision needed D2).",
  "celebrity": "hillary_clinton",
  "quotes": "hillary",
  "hub": "hub",
  "nodes": {
    "hub": {
      "type": "hub",
      "first_lines": [
        {
          "quote": "dnc-stronger-together",
          "text": "Our founders embraced the enduring truth that we are stronger together."
        }
      ],
      "lines": [
        {
          "quote": "dnc-your-cause",
          "text": "Your cause is our cause."
        }
      ],
      "options": [
        {
          "to": "beijing",
          "text": "Ask about Beijing, 1995.",
          "tone": "earnest",
          "source": "author"
        },
        {
          "to": "glass_ceiling",
          "text": "Ask about the glass ceiling.",
          "tone": "earnest",
          "source": "author"
        },
        {
          "to": "concession",
          "text": "When they go low we go high",
          "tone": "solemn",
          "source": "empowerment"
        },
        {
          "to": "campaign",
          "text": "Ask what she is running for.",
          "tone": "earnest",
          "source": "author"
        },
        {
          "to": "goodbye",
          "text": "Excuse me.",
          "tone": "leave",
          "source": "author"
        }
      ]
    },
    "beijing": {
      "type": "branch",
      "lines": [
        {
          "quote": "beijing-no-longer-acceptable",
          "text": "It is time for us to say here in Beijing, and the world to hear, that it is no longer acceptable to discuss women's rights as separate from human rights."
        },
        {
          "quote": "beijing-once-and-for-all",
          "text": "human rights are women's rights and women's rights are human rights, once and for all."
        },
        {
          "quote": "beijing-speak-freely",
          "text": "Let us not forget that among those rights are the right to speak freely. And the right to be heard."
        }
      ],
      "options": [
        {
          "to": "beijing_potential",
          "text": "Girls just want to have FUNdamental human rights.",
          "tone": "earnest",
          "source": "empowerment"
        },
        {
          "to": "hub",
          "text": "Back to other topics.",
          "tone": "neutral",
          "source": "author"
        }
      ],
      "effects": [
        {
          "set": {
            "dlg_hillary_clinton_beijing_done": true
          }
        }
      ],
      "return": "hub"
    },
    "beijing_potential": {
      "type": "branch",
      "lines": [
        {
          "quote": "beijing-god-given-potential",
          "text": "Every woman deserves the chance to realize her God-given potential."
        },
        {
          "quote": "beijing-no-one-formula",
          "text": "We need to understand that there is no one formula for how women should lead their lives."
        }
      ],
      "effects": [
        {
          "set": {
            "dlg_hillary_clinton_beijing_potential_done": true
          }
        }
      ],
      "return": "hub"
    },
    "glass_ceiling": {
      "type": "branch",
      "lines": [
        {
          "quote": "glass-ceiling-this-time",
          "text": "Although we weren't able to shatter that highest, hardest glass ceiling this time"
        },
        {
          "quote": "cracks-18-million",
          "text": "it's got about 18 million cracks in it."
        }
      ],
      "effects": [
        {
          "set": {
            "dlg_hillary_clinton_glass_ceiling_done": true
          }
        },
        {
          "name_it": "hillary_glass_ceiling"
        }
      ],
      "return": "hub"
    },
    "concession": {
      "type": "branch",
      "lines": [
        {
          "quote": "concession-disappointed",
          "text": "I know how disappointed you feel, because I feel it, too."
        },
        {
          "quote": "concession-little-girls",
          "text": "And to all the little girls who are watching this, never doubt that you are valuable and powerful and deserving of every chance and opportunity in the world to pursue and achieve your own dreams."
        },
        {
          "quote": "concession-never-stop-believing",
          "text": "please never stop believing that fighting for what’s right is worth it."
        }
      ],
      "effects": [
        {
          "set": {
            "dlg_hillary_clinton_concession_done": true
          }
        }
      ],
      "return": "hub"
    },
    "campaign": {
      "type": "branch",
      "lines": [
        {
          "quote": "launch-economy-work",
          "text": "I'm running to make our economy work for you and for every American."
        },
        {
          "quote": "launch-her-champion",
          "text": "I want to be her champion and your champion."
        },
        {
          "quote": "launch-knocked-down",
          "text": "For everyone who's ever been knocked down, but refused to be knocked out."
        },
        {
          "quote": "ny-get-back-up",
          "text": "But remember, it's not whether you get knocked down, it's whether you get back up."
        }
      ],
      "effects": [
        {
          "set": {
            "dlg_hillary_clinton_campaign_done": true
          }
        }
      ],
      "return": "hub"
    },
    "goodbye": {
      "type": "return",
      "lines": [
        {
          "quote": "dnc-no-ceilings",
          "text": "When there are no ceilings, the sky's the limit."
        }
      ],
      "return": "END"
    }
  }
}
```

The Name It beat the glass-ceiling branch triggers, in name_it.json's shape (`speaker`,
`lines`, `hook`, `answer`):

```json
{
  "hillary_glass_ceiling": {
    "speaker": "hillary_clinton",
    "lines": [
      "Although we weren't able to shatter that highest, hardest glass ceiling this time",
      "it's got about 18 million cracks in it."
    ],
    "hook": null,
    "answer": null
  }
}
```

`hook` and `answer` are null: which line hides the hook, and which of the three tactics
(name_it.json: negging, concern-trolling, in-group gatekeeping) answers it, are the author's to
set; until then the beat stays off (`name_it.gd` `start()`).

Notes on the lines:

- Fragments. `cracks-18-million` ("it's got about 18 million cracks in it.") is a lowercase
  fragment: it reads as dialogue only after its setup, which the store carries as the previous
  half of the same 2008 concession sentence, `glass-ceiling-this-time` ("Although we weren't
  able to shatter that highest, hardest glass ceiling this time", stored with no closing
  punctuation). The branch plays them in order, restoring the sentence. Other entries are
  fragments whose setup the store does not carry, for example "the art of making what appears
  to be impossible possible" (Wellesley 1969); how to present those is Decision needed D3.
  Several more entries begin lowercase as mid-sentence extracts (`beijing-once-and-for-all`,
  `concession-never-stop-believing`); the tree keeps the store's capitalization verbatim rather
  than silently repairing it.
- Not usable. Two of the 45 entries stay out of the tree:
  - "Home is a child's first and most important classroom." (It Takes a Village, 1996):
    `verified: false`, `aggregator: true` (a Goodreads quote page); its note says no primary
    source was found and "Do not use in game until verified."
  - The basket-of-deplorables line from the LGBT for Hillary gala (9 Sep 2016): verified, but
    `about_others: true`; its note reserves it for the clone children ("a clone says it to the
    other clones"), so it is not a line Hillary says to the player.
- Player options in the example show the D2 hybrid: the two `source: "empowerment"` options are
  verbatim from `project/data/empowerment_lines.json`, pending that file's verification pass
  (section 3); the `source: "author"` options are placeholders standing in for the author's
  lines.

## Decision needed

- D1, quote keys (section 2): (a) a slug `key` field added to each quote entry by the
  controller agent who owns the quote store [recommend]; (b) array indices; (c) text-as-key.
- D2, player reply options (section 3): (a) author-written lines; (b) tone-tagged
  author-written options; (c) lines from empowerment_lines.json. Recommendation: the (b)+(c)
  hybrid, with (c) conditional on the file passing a per-line verification pass first
  (section 3); (b) alone ships without that precondition.
- D3, fragment quotes (section 6): (a) skip fragments; (b) play a fragment after its setup
  entry when the store has both, and give fragments without a setup a bracketed narration
  context line (the "[audience laughs riotously]" precedent in next_top_comic.gd) [recommend];
  (c) author-written setup lines. Recommendation: (b), because it adds no words to any real
  person's mouth.
- D4, Name It beat content and timing (sections 5 and 6): what goes in `hook` and `answer` for
  `hillary_glass_ceiling` (and every new beat) is the author's to set, alongside the existing
  open question "Who writes the Name It text, and when?" (CLASSROOM.md); this document makes no
  content recommendation, because picking a hook line or a tactic would invent author content.
  The process options are: (a) the author sets each beat's `hook` and `answer` before any tree
  that triggers it ships [recommend: the wire is ready, and a beat set early fires the first
  time the player reaches its branch]; (b) trees ship first with dormant beats, which is safe
  in the engine because `NameIt.start()` returns without opening the panel when a beat is
  missing or its `hook` or `answer` is unset (`name_it.gd` `start()`: "A beat runs only once
  its author has set the hook line and the answer."), and the beat still fires on a later visit
  once the author fills it, since a dormant trigger writes no `named_` flag.

## Not verified

- `dev/DESIGN.md` is git-crypt encrypted and could not be read; `docs/DESIGN.md` is a stub that
  says so. Repo comments that cite DESIGN.md (for example "DESIGN.md §2" in next_top_comic.gd,
  "DESIGN.md: pedagogy loop" in name_it.json's `_note`) are cited as comments, not as the
  document.
- SOP-06 section 9 ("Reference implementation in persistint") describes an earlier repo state:
  it says no verified-flag gate exists and test_quotes_vv.gd is only planned. The current files
  say otherwise (test_quotes_vv.gd exists and gates), so current files are cited throughout
  instead.
- No Godot run was performed (the bead's rule for a design deliverable); nothing in this
  document was executed.
- Dialogue Manager internals were not read beyond the addon's presence and version (README.md
  credits: Dialogue Manager 3.10.4, MIT, in `project/addons/dialogue_manager/`) and the usage
  the repo's own files show (npc.gd, the minigame scripts, the `.dialogue` files).
- The proposed quote keys (D1) do not exist in the quote files; they are illustrative.
- empowerment_lines.json's `_note` claims its lines were checked verbatim on 2026-10-23, but
  its entries carry no `verified` field and no test gates them; the claim is taken from the
  file's own note, not re-verified. The 41-line count is from the file itself.

## Follow-ups for the team

- Extend `project/tests/test_quotes_vv.gd` so it also loads `data/dialogue/*.json` and asserts
  every `{"quote", "text"}` pair matches a usable store entry. Its leak search already covers
  `data/*.json`, so unverified text there fails today; the positive per-line gate is the
  missing half.
- Add the standalone checker SOP-06 calls `{checker}` under `tools/` (for example
  `tools/verify_quotes.py`), so the gate runs outside Godot too.
- Run empowerment_lines.json through the quote store's per-line verification (the precondition
  for D2 option (c), section 3): add a per-entry `verified` field, find primary sources for the
  4 Goodreads-hosted entries, and extend the gate test to cover the file.
- Voice clips for tree lines only from verified text, per SOP-05 and SOP-06 (SOP-06's header:
  SOP-05 generates voice clips only from quote text SOP-06 marks verified).
