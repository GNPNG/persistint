# Mini-games: what was built against what was specified

Bead persistint-game-usl0 (P0), raised by the author on 2026-11-02 at 09:25 UTC. His assessment,
in this report's words: the mini-games are not yet games; the opening text of each one makes a
joke of the plot of his book, which he finds insulting and not funny; he specified the games in
the design notes and the discussion, and the agents that built them worked from a one-line
summary instead of those notes.

This report quotes, per game, (a) what the author specified (dev/DESIGN.md §2, the five design
notes on bead qqx of 2026-10-24, dev/COMEDY-RUBRIC.md), (b) the opening text the player actually
sees today, with the file it comes from, and (c) what the build does, so the gap is on the page.
Nothing here is a proposal for new story text: that is the author's. The fixes it names are
mechanics and the removal of agent-written framing.

The beads the games were built from (3os, bo3, qqx, 9nh) all carry the same one-line description:
"Mechanics only, per docs/DESIGN.md. Any text or content not in the user's source docs is left
as an empty slot for the author." The implementers read the §2 bullet and that line. The five
author notes on qqx (the redesigned comedy game) were filed as a *blocked* follow-up (fwn,
"revisit the joke design with the author") and never built. The card text in
data/flashbacks.json and the station text in data/hottest_chains.json are agent-written
("written in the sources' voice", their own `_note` says), not the author's.

## What the player reads before and inside each game (today, main 0861ec5)

### Chapter end card, island → cruise (data/chapters.json `island.end_card`)
> Before the Wreck
> The ship on the rocks was a cruise once. Lit up, playing music, going somewhere.
> A feminist-themed celebrity cruise. The manifest that became a pantheon.
> Nobody on board knows how it ends. Different passengers. A different you.
> [Board]

### The Interview (data/interview.json; dialogue/interview.dialogue)
Oprah's two intro lines are verified quotes (Golden Globes 2018):
> So I want all the girls watching here, now, to know that a new day is on the horizon!
> Each of us in this room are celebrated because of the stories that we tell, and this year we became the story.

Then the questions. Each prompt is a verified Oprah quote; the five answers under each are
agent-written, e.g. under "You are your possibilities.":
> I am a first-year receptionist with a dental plan. That is the full list.
> Whatever the audience claps for. I can work with that.
> I prefer to read the terms and conditions of my possibilities first.
> Mostly I am the ability to leave a room quickly.
> [Say nothing. Let the silence be a gift to the studio audience.]

### Flashback card, The Landing (data/flashbacks.json)
> Fog. A ship coming in toward an island nobody on board can see yet.
> The lights went out somewhere behind this moment. {kate} isn't exploring. She is trying not to crash a dead ship.
> Systems failing. Chaos on deck. The first mate yelling for the captain.
> [Take your station]

Commands inside (data/landing.json, agent-written): "Reaffirm the Autopilot Affirmation Panel!",
"Rotate the Chart Table Crayons!", …

### Flashback card, Hottest of the HOT (data/flashbacks.json)
> Before the fog there was champagne, panels on motherhood, and an open bar. Every scene of it empowering.
> Tonight {tyra} is judging and {chelsea} will explain how much fun it is. Get ready across the ship first. The makeover is done to you.
> The same behaviour as the island, just with better lighting.
> [Get ready]

Then the get-ready chain (data/hottest_chains.json, agent-written station text), e.g.:
> Open the envelope under your door: the Hottest of the HOT call sheet, with a note that says 'We only want you to feel your best (we noticed)'.
> Put on the complimentary robe. It is one size, which is fine, for most.
> Stand at the mirror the stewards hung a little too low. Find something about yourself that's positive and celebrate it. They will be along to help with the rest.

Then the show (scripts/minigames/hottest_of_the_hot.gd `_introduce`): "Chelsea Clinton: " +
the emcee lines from data/emcee.json `_default` (verified Chelsea quotes, from her children's book *She Persisted*, 2017):
> In her refusal to get up, she persisted in taking a stand for what's right. Remember these women. They persisted and so should you.

### Flashback card, Next Top Comic (data/flashbacks.json)
> Later in the voyage. The entitlement is louder now, and the men on crew are treated worse.
> {silverman} has the mic. The setups are terrible. The women in the audience think they are hilarious.
> Pick your punchline. Whatever you pick, they will laugh, and it will feel like being seen.
> [Step up to the mic]

Then the same Chelsea `_default` lines as the show's first balloon (dialogue/next_top_comic.dialogue
`~ start`: `{{emcee_name()}}: {{emcee_intro()}}`).

**Reading.** The cards and the chain text explain the satire to the player in the author's
analytic voice ("The same behaviour as the island, just with better lighting"; "The makeover is
done to you"; "it will feel like being seen"; "The manifest that became a pantheon"). That is
the book's thesis stated as a wink, before the player has done anything. Chelsea's verified
lines about persistence are placed as the emcee's "how empowering this is" patter, which turns
the real quote into the punchline. None of this text is in the author's sources; all of it is
agent-written framing. The author's own words for how the satire works (COMEDY-RUBRIC.md):
"the words are sincere, the situation cannot be, and that gap is the joke" and "the failure
case is the sincere line with nothing absurd around it, where the only thing on offer is the
position." The cards are the failure case: position, no situation.

## Game by game: spec vs. built

### The Interview (character creation)
**Spec (§2):** "Oprah interviews the player about themselves: warm, probing, faux-intimate.
Answers drive SPECIAL-style stat allocation (Fallout G.O.A.T.-exam register). Character
creation *is* a talk show segment."

**Built (scripts/minigames/interview.gd, 130 lines):** Oprah quote as the question; five
agent-written answers each carrying stat deltas; `pick()` adds deltas and advances; `finish()`
writes `stats`, `interview_answers`, `interview_done`. No camera, no audience, no host
reaction to an answer, no follow-up question, no reveal of the resulting character. The stats
are written to WorldState and nothing in the game reads them (grep `get_flag("stats"`: no
consumer). The paper doll is not on stage, so the created character is never seen.

**Gap:** the G.O.A.T. register is there in shape (question → weighted answers) but it is a form,
not a segment: nothing Oprah does depends on the answer, and the outcome has no effect
anywhere. The answers are agent prose in a self-aware register the author did not write.

### Hottest of the HOT (flagship) and the get-ready chain
**Spec (§2):** "Tyra Banks's top-model judging show where passengers are judged on appearance
with negative framing and passive-aggressive language ('who did your hair?', 'so brave to wear
that'). Makeover/hair-salon/get-ready-for-the-fashion-show chains, Day of the Tentacle-style
chained tasks across the ship." And: "The same paper-doll system powers both worlds: island
dress-up is kind; cruise makeovers are judged. The mechanical identity of the two, with
opposite emotional framing, IS the lesson." Then the Name It beat: "pick the hook hidden in
the compliment."

**Built, chain (hottest_chains.gd, 206 lines):** seven station buttons; each station lists
tasks; a task is a button that is enabled when its `needs`/`requires` are met; clicking it
consumes items, gives an item, may set a doll slot. Fourteen tasks, all on one screen; the
"ship" is a row of buttons. No walking, no rooms, no time pressure, no way to fail, no choice
that matters (every path ends in the same white dress and runway number).

**Built, show (hottest_of_the_hot.gd, 156 lines):** Chelsea's default lines; a doll with
cycle buttons per slot; a Walk button; `walk()` picks a random verdict from a two-entry list
("who did your hair?", "so brave to wear that") and shows "OK". Then Name It (`NameIt.start
("hottest_verdict")`) over the same two lines.

**Gap:** no judging happens. The verdict is random, so the outfit the player chose has no
effect; there is no panel, no other contestants, no scoring, no elimination, no round
structure, no runway. The "chain across the ship" is a menu. The lesson in §2 (same verbs as
Florida dress-up, opposite framing) cannot land because the Florida wardrobe is a real
dress-up and this is two buttons and a coin flip. The agent-written station text carries the
whole "passive-aggressive" load in prose instead of the mechanics carrying it.

### Next Top Comic
**Spec (§2):** "stand-up mini-game using the dialogue system in Monkey Island
insult-sword-fighting structure (Sarah Silverman). Just horrible unfunny setup / punchline
pairings, but of course, the women in the audience think it's hilarious."

**Spec, author's redesign (bead qqx, five verbatim notes 2026-10-24, filed as fwn and not built):**
- Pools of real setup/punchline pairs from several comedians, "all randomized. So you have to
  do setup punchline."
- Add edgy male comedians (Gottfried, Kinison, Dice Clay, Murphy) AND funny women: "if you
  choose like really funny ones and are successful, and it can be women too … they'll go, boo,
  boo, boo, joke thief."
- Audience inverted by funniness: "the only comedy that you're allowed to pick that they laugh
  at would be the matching, like, Hannah Gadsby jokes that are like not funny … they wildly
  applaud those ones. Then the ones that are mildly funny, they kind of like mid level."
- The heckle is "joke thief" (the name of the comic Rogan called out).
- The point: "we're both calling out like the IP theft aspect … and we're also making a
  satirical commentary on comedy itself, where like the people who have the worst jokes are
  rewarded, and the ones that are like most universal and funny are actually treated like
  bad." And: "This game is about like social control and social manipulation. And part of that
  is the narrative control and cultural narrative control."

**Built (next_top_comic.gd, 180 lines; dialogue/next_top_comic.dialogue):** one pool from
three sources (Schumer, Silverman, Gadsby; `verified` jokes only); the player picks a setup
from the whole pool, then a punchline from the whole pool; "the women in the audience laugh
after every exchange"; the only penalty is picking an "interjection"/"opener" (agent-chosen
Schumer lines: "My vagina itches", "I just queefed", "I'm so fat...") which gets boos and
"[judges dock you points for stealing jokes from Amy Schumer]". Points accumulate; no win, no
loss, no end state except running out of setups.

**Gap:** this is Monkey Island with the duel removed. Insult sword-fighting works because the
opponent attacks, the right riposte is specific, and you learn ripostes by losing. Here there
is no opponent line, no right answer, the audience reaction is constant (laugh), and the one
variable (boo on an "opener") is agent-chosen and reads as a bodily-function joke at
Schumer's expense: "insulting, and not funny" is the exact description. None of the author's
redesign is present: no funniness tiers, no inverted applause, no edgy-male/funny-women pool,
no "joke thief" heckle, no narrative-control reading.

### The Landing (wreck bridge)
**Spec (§2):** "Spaceteam-style coordinated-panic bridge game: absurd timed commands ('Align the
Promenade Stabilizers!'), button-pushing chaos as the ship comes down. Among Us-flavored social
layout (crew tasks around the ship) without the killing; the 'impostor' energy is social, not
violent." The flashback `_note` adds the book's opening: "a ship in fog, systems failing, the
first mate yelling for the captain."

**Built (landing.gd, 253 lines):** a ship plan with stations; a command appears with an 8 s
timer; the player clicks the station then the control; misses mark systems failed; a status
line "systems failing: …". This is the closest to its spec: there is a loop, a clock and
failure. What is missing: the *coordinated* part (Spaceteam is other people shouting your
commands; here nothing shouts), the social crew tasks (`_note` describes "look busy, take
credit, borrow authority" but no task in the data does anything), any escalation or ending
other than the timer running out, and any character on screen (Cap'n Kate, the first mate are
names in text).

## Why it happened (process)
1. The four build beads were written by an agent as "mechanics only, per docs/DESIGN.md"; the
   builders built the §2 bullet, literally, in one sitting each (all four created and closed
   2026-10-23).
2. The author's redesign of the comedy game arrived the next day as five spoken notes; it was
   filed as fwn "revisit with the author before building" and blocked behind qqx. qqx was
   never reopened; fwn is still open.
3. "Any text not in the sources is left as an empty slot for the author" was honoured for the
   quotes and broken everywhere else: the flashback cards, the chain stations, the Landing
   commands and the Interview answers are agent prose, each justified in its own `_note` as
   "written in the sources' voice".
4. Nobody played the four games end to end against the §2 paragraph before closing the beads;
   the tests check that scenes load, data is well-formed and quotes are verified, not that a
   game is a game.

## What needs the author (decisions, not work)
- D1. The agent-written framing text: remove outright, or hand the author the slots to fill?
  (Flashback cards, island end card lines 2-3, chain station text, Landing commands, Interview
  answers.) Removing leaves placeholders on screen; the games still run.
- D2. Next Top Comic: build the qqx redesign as specified (pools by funniness tier from many
  comedians, inverted applause, "joke thief" heckle)? This needs new verified quote sets for the
  added comedians (same `verified: true` discipline) and the author's call on the tiers.
- D3. Hottest of the HOT: is the show a scored round-based judging (outfit vs. a stated brief,
  Tyra's verdict depends on it, the "compliment" is generated from the actual miss, Name It
  names that hook), and is the get-ready chain played by walking the real ship (the cruise hub
  now exists: scenes/cruise/ship_section.tscn) instead of a button menu?
- D4. The Interview: should the answers be the author's, and should the result be shown (the
  doll on the couch, the stat card) and read by something (dialogue checks, deck games)?

## What can be built without the author (mechanics)
- M1. Hottest of the HOT scoring: a brief per round ("tonight: nautical"), each part tagged in
  outfits.json, the verdict chosen by the biggest miss instead of at random; Name It then has a
  true hook to name. No new prose needed beyond existing verified verdict lines.
- M2. Get-ready chain in the ship: stations become rooms on the cruise slice (Stateroom = her
  cabin, Purser's Desk = atrium, Gift Shop, Laundry, Glow Lounge = spa, Lido, Atrium Runway);
  the tasks stay as data; the player walks between them. The station *text* stays a slot.
- M3. Next Top Comic duel structure: an audience line (the "attack") before each pick, a reaction
  tiered by a per-joke `tier` field, a set length, a result. The content of the tiers is D2.
- M4. The Landing: a second voice (the first mate) issuing commands over the player's station,
  escalation (shorter timers, two commands at once), a definite end (the landing), the crew
  tasks wired to something (a task done = a system saved).
- M5. Interview result on screen: the doll and the stat card after the last answer.

Suite impact: none of M1-M5 changes a verified quote or a data contract the tests check except
outfits.json tags (test_paperdoll reads parts, not tags) and flashbacks.json card lines (if D1
removes them, test_flashbacks checks structure, not text; to be verified when done).
