# PERSISTINT — Game Design Document

Promotional/fundraising sandbox game for the novel **Persistint** (Per-sist-INT, "INT like INTJ").
Not-for-profit mission: help girls and women recognize, name, and feel comfortable criticizing
social-control behavior — at school, work, or online. The novel depicts a horrific dehumanizing
dystopia **with no violence**; the game's cuteness is the weapon: kawaii Stardew/Animal Crossing
presentation makes the absurdity of social control safe to laugh at and reject.

## Design thesis

**The cuteness is the weapon.** Every grotesque social mechanic is presented in the cutest
possible wrapper. The player's discomfort is the curriculum; the absurdity gives permission
to criticize.

**Influence, not violence.** No combat anywhere. The stretch "god-game" mechanic
(Populous/Powermonger register) is *social influence*: you model behavior, conformity
propagates. You never command anyone.

## World (from the novel / canon poster)

- **Little St. Piere Island** — the island world ("Isle of Galgrla" in-faith), built on the
  Ruins of "Utopia": a luxury cruise ship wreck + repurposed sci-fi colony infrastructure,
  treated as sacred architecture by a civilization that has repurposed but not understood it.
- **The Temple** — Queen Mother icons (celebrity portraits as sacred icons), the Seal of the O
  (approval mark), high temple walls.
- **The Covenant Hierarchy** — Mothers & Priestesses (ruling class; power via rare live birth),
  Devout Initiates (young women in "training"), Drones (men kept in compounds as reproductive
  commodities; they garden — **not** the women), Barren (women who fail to conceive; stigmatized,
  manual labor).
- **Calendar of Blood** — 28-day cycle; time measured in cycles; the "spiritual" signals of the
  Priestess cohorts; Festival of the Fourteenth. The Great Biological Misreading: society
  ritualized menstruation as the signal of peak fertility — reproductive rites at the wrong
  cycle phase (the tragic scientific irony underneath everything).
- **Forbidden Knowledge** — "masculine science" is banned; discovery/collection drives the
  main story.
- **The Cruise (flashback era)** — the ship before the wreck: the Crew, and the Celebrities
  whose pop-culture personas later become the foundations of the new religion.

## Game structure

Two interleaved layers:

### 1. Island present (the sandbox)
- Overhead 2D, small connected map areas (Animal Crossing scale), Stardew *aesthetic only* —
  this is NOT a farm sim (drones garden; the player does not).
- Click-to-walk-and-interact.
- NPCs with state-reactive contextual barks (Animal Crossing) keyed on world flags.
- Fallout-style branching dialogue trees for the main story arc.
- Paper-doll dress-up (Toca Boca register) — kind framing: expression, play, identity.
- Ritual puzzle mini-games; **Ruins of Utopia dungeon crawl** (exploring the wreck/colony
  infrastructure, recovering Forbidden Knowledge).
- Calendar of Blood drives festivals, NPC schedules, bark variation.

### 2. Cruise flashbacks (the mini-game arcade)
Discovered Forbidden Knowledge unlocks flashback chapters aboard the pre-wreck cruise:

- **The Landing/Wreck (prologue-capable):** Spaceteam-style coordinated-panic bridge game —
  absurd timed commands ("Align the Promenade Stabilizers!"), button-pushing chaos as the
  ship comes down. Among Us-flavored social layout (crew tasks around the ship) without the
  killing — the "impostor" energy is social, not violent.
- **WarioWare celebrity mini-games:** each hosted by one of the real celebrities on the cruise
  (Story Structure: Sarah Silverman, Tyra Banks, Ellen, Chelsea Clinton, Margaret Atwood, Oprah;
  Cap'n Kate captains). Flagship: **"Hottest of the HOT"** — Tyra Banks's top-model judging show where passengers
  are judged on appearance with negative framing and passive-aggressive language ("who did
  your hair?", "so brave to wear that"). Makeover/hair-salon/get-ready-for-the-fashion-show
  chains, Day of the Tentacle-style chained tasks across the ship.
- **The Empowerment Emcee:** every celebrity mini-game is introduced by Chelsea Clinton, who explains how *empowering and fun* this is going
  to be. Empowerment-washing as a running gag — the frame that blesses the judging.
- **"Next Top Comic":** stand-up mini-game using the dialogue system in Monkey Island
  insult-sword-fighting structure — except every punchline choice is bad, weird, and
  nonsensically inappropriate (Sarah Silverman). The crowd rewards cruelty-shaped
  noise; the player feels the wrongness of every "correct" answer.
- **The Interview (character creation):** Oprah interviews the
  player about themselves — warm, probing, faux-intimate. Answers drive SPECIAL-style stat
  allocation (Fallout G.O.A.T.-exam register). Character creation *is* a talk show segment.
- **The same paper-doll system powers both layers**: island dress-up is kind (play, identity);
  cruise makeovers are judged (control dressed as care). The mechanical identity of the two,
  with opposite emotional framing, IS the lesson.

### 3. Florida Keys idyll (the innocent sandbox)
The pre-dystopia normal world: an idyllic Toca World / Animal Crossing setting in the
Florida Keys. THIS layer gets the gardening and crafting — pure sandbox play, paper-doll
surprise interactions, zero judgment (gardening is only gendered on the island; in Florida
it's just fun). Pet dolphins, friendly crabs and seagulls. Mermaids are "real" —
aquarium-show mermaids, friendly Sofia-the-First register, never explained.
There's a stable with ponies: groomable (reuses the paper-doll/makeover tech on a pony),
rideable (mounted click-to-move, faster), and they can have babies (simple breeding:
coat/mane traits mix — genetics played straight and joyful here, in pointed contrast to
the island's Covenant obsession with controlled reproduction).

**Three framings of the same mechanics = the whole curriculum:**
Florida (innocent play) → Cruise (judged performance) → Island (ritualized control).
The player does the same verbs in all three; only the social framing changes. That
contrast is what the game teaches.

### The pedagogy loop ("Name It")
After each judged/manipulative beat (a Hottest-of-the-HOT verdict, a temple social maneuver),
a short beat where the player identifies what actually happened: pick the hook hidden in the
compliment, name the tactic (negging, concern-trolling, in-group gatekeeping…). Naming the
behavior is the novel's mission; the game makes it a verb. Vocabulary accumulates in a
journal — the player's own growing Forbidden Knowledge.

## Systems architecture (Godot 4)

- `WorldState` autoload — flags/vars, JSON save; single source of truth.
- `GameClock` autoload — day phases, Calendar of Blood, festivals.
- `Voice` autoload — procedural Animalese gibberish per character (pitch per caste/host).
- `SceneRouter` autoload — map transitions with named spawns.
- Dialogue Manager addon — `.dialogue` files with conditions/mutations on WorldState.
- NPC scene — bark table (data/barks.json) + dialogue tree entry.
- Mini-game contract — self-contained scenes: enter with context, write results to WorldState.
- Paper-doll — layered sprites, outfit JSON, reused by wardrobe (kind) and makeover (judged).

## Content pipeline (Track B)

- World-docs ("The Buildings of Little St. Piere Island", "Plants on the Island", "Inside the
  Temple", "The Crew of the Ship", "The Celebrities of The Cruise") → NotebookLM infographic
  sheets = style-locked canon art.
- Extraction/normalization → sprites, portraits, paper-doll layers.
- Local SD (ComfyUI headless on production server): IP-Adapter style-ref from sheets, later a
  style LoRA; Gemma-generated prompt manifests; batch generation with tiling validation and
  human-in-the-loop style scoring.
- Audio: Animalese synth is the default voice; local TTS (Piper/XTTS) cute-voice experiments
  for short barks evaluated against it.

## Legal/brand guardrails

- Celebrities appear under their real names, exactly as in the source material (Story
  Structure); never renamed or swapped for archetypes.
- All assets original or generated; no ripped game assets.

## Vertical slice scope (current milestone)

Village + Temple maps, 4 caste NPCs with reactive barks, one branching quest ("The Offering"),
paper-doll wardrobe, one ritual puzzle, Animalese voices, HTML5 export. Cruise layer and
dungeon crawl are stubbed doors with barks.
