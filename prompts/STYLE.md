# PERSISTINT — world and style bible (visual + audio)

This file is the single reference for generating PERSISTINT assets: music (Gemini Lyria), images
(Gemini image) and video (Gemini Veo). It is written to be used with no other context. Every
prompt in `prompts/` follows it. Every leaf prompt file is **pre-compiled** from this bible: its
`## Prompt` section already contains the asset-type preamble, the world line, the asset's own
subject and the negative prompt or loop spec (section 11), so it is pasted into the generator as is.
`python3 tools/check_prompts.py` checks the files mechanically.

Everything here comes from the author's sources: `docs/DESIGN.md` (the plan, binding), the novel's
Story Structure, the canon art in `art/canon/`, the game data in `project/data/`, the dialogue in
`project/dialogue/`, and the art generators in `tools/`. Section 13 lists where each fact comes from.

---

## 1. Absolute rules

### 1.1 Vocabulary

| Never write | Write instead |
|---|---|
| the stacking word ("l-a-y-e-r") for a game space | **area** or **world** |
| any pastoral-paradise word for Florida | Florida is **tropical** |
| references to other authors' dystopian regimes or their costumes | the ship is a **feminist-themed celebrity cruise**; the island is the **Covenant** on **Little St. Piere Island** |
| the roadside-safety-rail metaphor for rules or limits | say **rule** or **limit** |
| invented fantasy names | names from `project/data/cast.json` only (ordinary real-world names) |

The paper doll is built from **parts** (body, hair, dress, accessory).

### 1.2 Content

- **No combat, no violence.** Nothing in the game fights. Influence, not violence: the player
  models behaviour and conformity spreads; nobody commands anyone.
- **Gore exists in one place only:** the bunker clone hall, where polar bear cubs eat failed clone
  children. It is kawaii gore: pastel pink splats, hearts, sparkles, a cartoon bone, a worried
  little chunk with a sweat drop. Nothing realistic, no screams.
- **Blood as a motif** is limited to the Calendar of Blood as a ritual calendar: little red
  droplets on calendar squares, red/pink calendar wheels, a pale red stripe painted on old pipes.
  "Blood-art" is an activity NPCs mention; it is never depicted. No bodily or anatomical imagery.
- **Real people appear under their real names** in game text, exactly as in the source (Chelsea
  Clinton, Tyra Banks, Sarah Silverman, Oprah Winfrey, Cap'n Kate, Hillary Clinton, Margaret
  Atwood, Ellen, Gloria Steinem; the clone originals Jeffrey Epstein, Bill Clinton, Hillary
  Clinton, Bill Gates). Never rename them or swap them for archetypes in game text. **In prompts
  for image and video generators**, which may refuse named people, describe the role and the look
  instead (section 7.4).
- **Celebrity lines are only their own sourced words** (`project/data/quotes/*.json`). No invented
  quotes.
- **Generated images carry no text** unless the prompt asks for the logo. Type is set in-engine.
- **No content beyond the sources.** Do not invent lore, characters, places or mechanics. Where
  this bible says "planned" the thing is in DESIGN.md but not yet built.

---

## 2. What the game is

PERSISTINT (Per-sist-INT, "INT like INTJ") is a promotional, not-for-profit sandbox RPG for the
novel **Persistint**. Its mission: help girls and women recognize, name, and feel comfortable
criticizing social-control behaviour, at school, at work or online. The novel depicts a
dehumanizing dystopia with **no violence**; the game's cuteness is the weapon.

**Design thesis — the cuteness is the weapon.** Every grotesque social mechanic is presented in
the cutest possible wrapper (Stardew Valley / Animal Crossing / Toca Boca presentation). The
player's discomfort is the curriculum; the absurdity gives permission to criticize.

**Tone.** From the Story Structure: the work "never editorializes. It shows; the reader concludes."
"Make them love it, then make them realize what they were loving." The surface reads like a cozy
life-sim and a YA dystopia; underneath, the hierarchy is enforced by the community itself, through
"quiet consensus, ritual stigma, and social exclusion" — and it is dressed in ceremony. "The
same feminist language from the cruise chapters has calcified into liturgy... The language was
always the cult. It just didn't have candles yet." "The behaviour on the cruise is exactly the
behaviour in the cult, just with better lighting and an open bar."

Every asset should be **cute first**, and on a second look **something is slightly wrong**: too
uniform, too polite, too eager, too sincere about something absurd.

### 2.1 The three framings (the whole curriculum)

The player does the same verbs — dress up, garden, perform, be judged — in three worlds. Only the
social framing changes.

| World | Framing | The paper doll there | Feel | Visual temperature | Audio temperature |
|---|---|---|---|---|---|
| Tropical Florida Keys | **innocent play** | dress-up for fun; every outfit gets a delighted reaction | pure joy, nothing wrong anywhere | warm, saturated, sunny | bright, acoustic, carefree |
| The Cruise (flashback) | **judged performance** | the makeover is judged ("control dressed as care") | glamour with a critic's eye | glossy, spotlit, sunset gold, night-deck neon | showbiz: lounge, runway house, talk show, comedy club, panic |
| Little St. Piere Island (present) | **ritualized control** | dress-up is kind (play, identity), but everything around it is ritual | cute, polite, too uniform | pastel, soft, slightly less saturated than Florida | lullaby sweetness with a drone under it |
| Ruins of Utopia / bunker (part of the island) | discovery, decay, horror-comedy | — | lost glamour, retro sci-fi, spooky-cute | blue-green gloom with pink/mint accents | warped lounge, analog synth, theremin |

### 2.2 Name It (the pedagogy loop)

After each judged or manipulative beat (a Hottest of the HOT verdict, a temple social manoeuvre),
a short beat asks the player to **pick the hook hidden in the compliment** and **name the tactic**
(negging, concern-trolling, in-group gatekeeping…). Named tactics collect in a journal, the
player's own growing Forbidden Knowledge. Example beat (Priestess Betty): "See how easy? / The
Covenant loves an easy girl. / ...That was a compliment, dear." Visual identity of Name It: a
bright, clear "revelation" moment — celesta/glockenspiel sting rising to a clear major chord,
sparkle shimmer. It is the one place the game's music is allowed to sound fully, honestly happy.

### 2.3 Structure of play

- **Island present (sandbox):** overhead 2D, small connected map areas (Animal Crossing scale),
  Stardew *aesthetic only* — not a farm sim (the Drones garden; the player does not).
  Click-to-walk-and-interact. NPC barks react to world state and the calendar. Fallout-style
  branching dialogue everywhere. Paper-doll dress-up. Ritual puzzle mini-games. Ruins of Utopia
  dungeon crawl (recovering Forbidden Knowledge).
- **Cruise flashbacks (mini-game arcade):** the Landing (bridge panic), celebrity-hosted
  WarioWare-style mini-games, the makeover chains and Hottest of the HOT, Next Top Comic, The
  Interview (character creation).
- **Tropical Florida Keys (innocent sandbox):** gardening, crafting, critters, mermaids, ponies.
- **Chapters:** the game is told in chapters, each with its own player character and cast. The
  island chapter ends at the village's west dock; a time-jump card ("Before the Wreck") takes the
  player *back* to the Cruise with a fresh character.

---

## 3. The world in brief

The story backstory behind the worlds (how the ship came to the island, what the Covenant built from what it found) is kept in `dev/STYLE-world-backstory.md` (encrypted, author only). Everything an asset needs visually is in the sections below.

## 4. Visual system

### 4.1 Medium and the shipped look

The author's prompts call the style **"kawaii pixel art"**; keep that term in prompts, and define
it as the shipped look, which is:

- **Clean-line kawaii sticker illustration, read at low resolution.** The canon sheets
  (`art/canon/`) are soft cartoon drawings with a **warm brown outline** of even weight, flat
  pastel fills, one soft shade per shape, round pink cheek blush, dot eyes, tiny curved smiles.
  In the game they are downscaled (supersampled and LANCZOS-resized), so edges are soft and
  antialiased — **not** hard 1-px stair-stepped pixels, no dithering, no scanlines (unless a
  prompt asks, e.g. the VHS chapter transition).
- **Everything has a face.** Buildings, signs, trees, calendars, rulers, telescopes, the ship, the
  bunker: two dot eyes, pink blush ovals, a small smile. The face is the house style and the joke.
- **Overhead three-quarter view** (top-down with a slight front tilt), Animal Crossing scale for
  maps; straight-on or three-quarter for key art.
- **Silhouettes are big and round:** bubbly tree canopies of three or four overlapping circles,
  rounded rectangles for buildings, chunky outlines readable at 640×360.
- Bunting, ribbons, bows, vines and little flowers decorate everything the Covenant has touched
  (fences, signs, the wreck, the bunker).

### 4.2 Resolution and grid

| Item | Spec |
|---|---|
| Game view | 640×360, stretched ×2 to 1280×720 (`canvas_items`, aspect kept) |
| Map cells | 32×32 px |
| Characters in the world | 48 px tall (NPC sprites cut from the canon caste sheet: front, side, back) |
| Paper-doll source art | 91×96 per part, drawn at half scale in the world |
| Clone children | 20×30 px; polar bear cubs 24×22 px |
| Props | ship 150 px tall, bunker 120, Queen Mother icon 72, pillar-orb 64, sign 48, skull altar 48, calendar 40, Seal of the O 36, fence 34 |
| Key art / illustrations | 1920×1080 (16:9), read at 640×360: keep shapes big, silhouettes clear, detail sparse |
| App icon | 1:1, 1024×1024, must read at 64×64 |

### 4.3 Outline and shading rules

- Outline colour: warm brown **`#8a5a5a`** on island art (tiles, trees, faces); the clone lab uses
  a cooler plum **`#5a4a5e`**. Outline weight is even and soft; never black.
- Shading: flat fill + one lighter highlight shape (a white oval on hair, water, hearts) and at
  most one darker fold. No gradients on characters; soft gradients allowed in skies and key-art
  backgrounds.
- Blush: pink ovals `#ff9fb8` / `#ffb3c8` under the eyes of every face.
- Eyes: dark dot eyes (outline colour), often with one white catch-light on cute animals.
- Sparkles: four-point stars in white or pale yellow `#fff3a8` with a gold edge `#e0b24a`.
- Backgrounds of canon sheets are warm cream **`#fdf6e3`**.

### 4.4 Master palette

Sampled from the shipped art in `project/assets/` (unchanged from the first version of this guide):

- Island ground and paths: `#c0e0a0` grass, `#f0e0b0` sand path, `#f0e0e0` blush stone,
  `#a0d0f0` water, `#f0b0c0` pink accents, `#f0f0f0` white temple stone
- Characters: skin `#f0c0b0` / `#e0b080` / `#906050` / `#705040`, hair browns `#806050` `#704030`,
  gold `#f0e0a0`
- Deco: lavender `#c0b0f0`, pink `#f0c0d0` `#f0c0e0`, leaf green `#a0e0a0`, wood `#c09060`
- Florida: sea blue `#80b0d0`, turquoise `#70d0c0`, lilac `#b090e0`, coral `#f08060`, foam `#e0f0f0`
- Props/ruins metal: steel blue `#b0d0e0`, sandstone `#d0c0a0`, moss `#c0c080`, ash `#b0a090`
- Clone lab: tank green `#c0f0c0` `#b0d0b0`, kawaii-gore pink `#e05070`, lab white `#f0f0f0`

Exact colours used by the generators and the game code:

| Use | Hex |
|---|---|
| Grass / clover / grass highlight | `#c5ecaa` / `#a6dc8a` / `#d6f5bf` |
| Path / path pebbles | `#fff0cf` / `#ffe2b0` |
| Sand / sand pebbles | `#ffe9b8` / `#ffd3c2` |
| Soil rows / sprouts | `#e0b48f` `#c99468` / `#9be07c` `#b4ee95` |
| Plaza (paving) | `#f6e9f2`, slabs `#fbf2f8`, edge `#e1c6d8`, hearts `#ffd0e0` `#d9e9ff` |
| Floor / alt floor (temple checkerboard) | `#fff6e2` / `#ffe6ee` |
| Rug runner | `#ffb3c8` with `#ffe3a8` borders and pale hearts |
| Water / foam | `#a9ddf2` / `#c6eefb`, white wave arcs |
| Wall / wall cap | `#f1e2cd` brick with `#d9c3a5` mortar / `#f8efe0` |
| Hedge | `#95d37c` |
| Temple stripes | white `#ffffff` and sky blue `#a8d4f5` |
| Temple gold dome | `#ffe59a`, highlight `#fff4c4`, rib `#efc86a`, edge `#e0b24a` |
| Rock | lavender-grey `#e1dcef` |
| Tree canopies | mint `#a8e6a0`, pink `#ffc9de`, lavender `#c9b8f2`; trunk `#c8956d` |
| Flowers | pink `#ff9fc0`, white, yellow `#ffd36e`, centres `#ffe27a` |
| Heart | `#ff8fb1` with white highlight |
| Ritual-puzzle icon colours | rose `#f7a8c4`, sky `#a8d8f0`, gold `#f9e4a8` |
| Clone children skin / goo | `#c9ecc4` / `#8fe07a` |
| Clone gowns | pink `#ffb3c8`, sky `#a8d8f0`, lilac `#c9b3f0`, butter `#ffe08a` |
| Polar bear cub fur / muzzle / inner ear | `#fbfbff` / `#f0eef6` / `#ffc4d4` |
| Kawaii gore | splat ramp `#ff9ebf` → `#e64061`, puddle `#e8547a` with a `#ffd0dc` heart outline, chunk `#ff8fa8`, sweat drop `#9fd8ff`, bone `#fff8ec` |
| Ruins room slabs | pink `#ed9ebd`, cream `#e6d9b3`, sky `#8cbde6`, violet `#9e8cd1`, rust `#9e665c`, mint `#8cd1b3`, machine grey `#4d5466`, cub-basket pink `#f2bfd1` |
| Florida plants | hibiscus `#ff9ad0`, sea grape `#b89ae0`, key lime `#d8f07a`, bougainvillea `#e0408a`, plumeria `#fff1b8`, guava `#f4a6a0`, mango `#ffb347`, coconut `#b08a5a` |
| HUD text / outline | plum `#593859` / white |
| Ruins captions / outline | `#f2e6f2` / `#331f40` |
| Chapter-end card ground | near-black `#05080f` |
| Landing fog overlay | `#ebedf2` at 55% |

**Saturation rule:** pastel first; saturated colour only for accents (hearts, gore pink, Florida
coral and bougainvillea). Florida is the most saturated world. The island is slightly *less*
saturated than Florida. The cruise is glossy: white, gold and spotlight, with sunset orange and
night-deck navy. The ruins drop to blue-green and machine grey with pink/mint accents.

### 4.5 Motifs and iconography

| Motif | Where | Look |
|---|---|---|
| **Seal of the O** | temple dais, temple gate, ruins core (pink stencil), approved texts | a red round stamp with a big "O" in the centre (canon infographic: "Seal of the O / Book Club" ring lettering); in generated art draw it as a red ring with a bold O, no legible words |
| **Queen Mother icon** | temple high wall, temple gate | a smiling woman with a short blonde bob and pearls, gold crown above, lavender jacket and pale-blue sash, framed in a white columned shrine; painted "from memory": eyes slightly too large and too kind |
| **Atwood's skull** (skull altar) | temple ritual table | a cute white cartoon skull on a round pedestal, crowned with pink flowers and a red bow, sparkles |
| **Pillar-orb** | temple colonnade | a white column topped with a pale orb that has a smiling face |
| **Calendar of Blood** | temple wall, festival | a desk calendar with a face, red binding rings, pink and red squares, little red droplets, stars and crescent moons |
| **Forbidden tag** | sealed doors, Barren yard | a red luggage tag with a red X in a circle |
| **Forbidden instruments** | Forbidden Knowledge pickups, ruins | kawaii telescope (lavender and brass), ruler (honey), calculator (pink and lilac), tide/moon scroll (moon phases over waves and shells), thermometer, wall calendar |
| **Hearts and sparkles** | dwellings, main house, temple, wreck, gore bursts | pink hearts with a white highlight; four-point sparkles |
| **Bunting and ribbons** | fences, signs, the wreck, the bunker | pastel triangle flags (mint, pink, lavender, butter), ribbon streamers, little bells |
| **Deck chair facing a sunset** | wreck, Ruins | a striped deck chair arranged toward a horizon "that stopped being scheduled" |
| **Life rings / LIFEBOAT 7** | wreck, loading screens | cruise life ring, a lifeboat stencilled LIFEBOAT 7 |
| **Rubber duck** | clone hall tank 3 | a yellow duck afloat in pink fluid; "the Covenant has a rite for it" |
| **Cat-in-a-lab-coat sticker** | every bunker machine | small kawaii cat sticker; "the stickers outlasted the funding" |
| **Pastel hazard stripes** | bunker lift shaft | pink, mint, pink, mint |

### 4.6 Animation feel

- Bouncy, squash-and-stretch, short. Spawns pop in with an overshoot (scale 0.2 → 1 with a back
  ease, 0.5 s). Buttons squash on press.
- Critters react with **jump**, **spin**, **wiggle** or **hop**.
- Clone children **shamble**: arms straight out, tiny steps, a little sway, a groan bubble.
- Polar bear cubs: pounce (boing), chomp, splat, burp, then a 6-second nap with a tiny snore.
- Island NPCs move calmly and identically; Covenant women stand very straight, hands folded.
- Ambient captions in the ruins cycle every 7 s. The island clock runs 90 s per day phase.

### 4.7 VFX

- **Sparkles**: drifting four-point stars over the temple, the Seal gate and the wreck.
- **Hearts**: float over homes and the main house; burst out of gore splats.
- **Kawaii gore** (clone hall only): a 24-particle splat in the pink ramp, six hearts and six
  sparkles bursting, a cartoon bone and a worried pink chunk (dot eyes, frown, blue sweat drop)
  bouncing twice and spinning, a pastel puddle with a heart outline that fades after 8 s.
- **Fog** (Landing): pale grey-white veil over everything.
- **Tank bubbles**: a few bubbles in pink fluid "that rise as if on cue".
- **Film grain / VHS lines**: only for the time jump back to the Cruise.

### 4.8 UI and typography

- Panels: rounded pastel rectangles (`#f0e0e0` fill, `#906050` border), soft drop shadow,
  heart/sparkle icons.
- HUD text: plum `#593859` with a white outline.
- Fonts (in-engine; the game currently uses Godot's default): one rounded, bubbly face for
  titles, a small clean face for UI and dialogue (8–10 px at 640×360). Light text gets a white
  outline; dark text sits on pastel panels.
- Logo: **PERSISTINT** in rounded, bubbly pastel letters with a white outline (the canon
  infographic's title lettering: pink, sky blue and mint letterforms with a brown outline).
- Dialogue: speaker name, then line; choices are Fallout-style lists.

### 4.9 Camera and framing for key art

- **Island:** high three-quarter view or straight overhead at golden hour; the whole kidney-shaped
  island small in the frame, reef and turquoise water around it.
- **Interiors (temple, bunker, salon):** straight-on, symmetrical, centred on the focal object (the
  dais, the tanks, the runway). Symmetry reads as ritual.
- **Cruise:** low angle, looking slightly up at the ship or the stage; spotlights and glow.
- **Florida:** eye-level along the shoreline; open sky, lots of horizon.
- Leave clear space at the top for a logo (title art) or at the bottom for a tip line (loading
  screens). Everything must survive downscaling to 640×360.

### 4.10 Title screen and chapter cards

- **Title screen:** the tiny tropical island from above at golden hour, pastel pink and
  turquoise, the blue-and-white striped temple with its gold dome, bunker-shaped pastel homes with
  smiling faces, bubbly mint, pink and lavender trees with faces, the pastel blue-and-pink
  cruise-ship wreck on the south beach (vines, bunting, a smiling bow face), sparkles and little
  hearts in the air, soft clouds, gentle glow. Cute but faintly eerie. One version with the logo at
  the top, one plain.
- **Chapter-end card ("Before the Wreck"):** full-screen time-jump card. In-engine it is a
  near-black ground (`#05080f`) with the heading (30 px) and three lines at 85% white and the
  prompt "Board" at 50%. **No year count.** The heading and lines, verbatim:
  - Before the Wreck
  - "The ship on the rocks was a cruise once. Lit up, playing music, going somewhere."
  - "A feminist-themed celebrity cruise. The manifest that became a pantheon."
  - "Nobody on board knows how it ends. Different passengers. A different you."
  The card art and transition show the ship *before*: glamorous, white, lit up at sunset,
  streamers and balloons, nostalgic film grain and faint VHS lines; the transition video rewinds
  the wreck (rust peels away, lights flicker on, the ship rights itself and sails off).
- **Loading screens:** one centred vignette on a pastel gradient, lots of empty space at the bottom,
  one prompt file each: `loading_seashell` (a seashell on sand), `loading_basket` (an offering
  basket on a temple step), `loading_lifering` (a cruise life ring), `loading_cub` (a polar bear
  cub napping on a lab bench).

### 4.11 Do / don't

| Do | Don't |
|---|---|
| warm brown outlines, flat pastel fills, blush, dot eyes, faces on objects | black outlines, hard pixel stair-steps, dithering, photorealism, 3D render look |
| big round silhouettes readable at 640×360 | fine detail, thin lines, busy textures |
| identical calm smiles on Covenant women | horror faces, menace, sneers on island characters |
| kawaii gore (pastel splat, hearts, sparkles, cartoon bone) in the clone hall only | realistic blood, wounds, weapons, fighting, screams |
| Calendar droplets as a calendar motif | any bodily or anatomical imagery |
| roles and looks for real people in generator prompts | photo likeness of real people |
| tropical, sunny Florida with nothing wrong | anything ominous in Florida |
| text only when the prompt asks for the logo | captions, signage text, watermarks, UI mock-ups |

### 4.12 Negative prompt (append to image and video prompts)

> no text, no letters, no watermark, no logo (unless requested), no photorealism, no 3D render, no
> black outlines, no harsh pixel stair-stepping, no dithering, no grime, no realistic blood, no
> wounds, no weapons, no fighting, no scary faces, no nudity, no anatomy, no real-person likeness,
> no dark horror lighting (except the bunker's soft gloom), no muddy colours.

---

## 5. Little St. Piere Island — the village (island present)

**In-story:** the island the cruise wrecked on, decades later: a compound run by the Covenant of
Mothers. Its name is a pun on Little St. James; the map is
**traced from OpenStreetMap data for the real Little Saint James** (coastline, path network,
positions of the temple, helipad, pier, pools, tennis court, ruins and buildings; 24 m per cell,
north up; reference photos show a green, hilly island with a beach on the south shore), then
redrawn kawaii.

**Who lives here:** Mothers and Priestesses, Initiates, Drones, Barren (section 7). In the
vertical slice: Gloria (Initiate), Bruce (Drone), Susan (Barren); Priestess Betty is in the temple.

**Layout and landmarks** (as built in `tools/build_island_maps.gd`, 40×38 cells):

| Place | Real feature it sits on | What is there |
|---|---|---|
| Main house (north tip) | the main residence and its pool | quarter of the Mothers and Priestesses: pink paving, a pink rug runner, a small pool, a bunker-shaped house with a face, a heart floating over it |
| Initiates' quarter | the guest villas | two smaller bunker-shaped dwellings on pink checker floor, hearts over them; the paper-doll mirror stands nearby |
| Helipad | the helipad | paved pad with two tiny huts, a walkway down to the beach |
| Drones' compound | west pool house and pool | pool house, pool, and the Drones' fenced garden: soil rows, sprouts, a path, a sign at the gate |
| Tennis court | the disused tennis court | fenced pink paving, empty |
| Barren yard | maintenance sheds | bare path ground, a rock pile, a sign, the red forbidden tag |
| **Temple** | the real island's temple building (south-west hill) | terrace of pink paving, a **blue-and-white striped pavilion with a gold dome**, two Queen Mother icons flanking the door, the Seal of the O over the gate, sparkles |
| **The wreck** | the ruins on the south beach | the cruise ship aground: pastel blue hull, pink upper deck, white superstructure, porthole rows, a pink funnel, vines climbing it, bunting strung from mast to flagpoles, a smiling face on the bow, sitting on sand and moss; entrance to the Ruins of Utopia |
| West dock | the real pier | a dock and a boat house; **exit to the Cruise** (chapter end) |
| East jetty | (the map's own) | a short jetty; exit to tropical Florida |

**Architecture:** buildings are the canon **bunker** shape — a squat stone-grey concrete block with
a rounded doorway, a face, bunting and ribbon bows, moss and bushes at the base, a pink flower
growing on the roof. The ship and the bunker are "treated as sacred architectural wonders".
Fences are weathered wooden rails, some broken, wrapped in flowering vines, with bows and bunting.
Signs are wooden boards on posts with ivy, ribbon streamers, little bells and a painted face.

**Flora:** bubbly round trees (mint, pink and lavender canopies, each with a face and sparkles),
flower clumps (pink, white, yellow), clover grass, hedges. The Drones' garden: tomatoes and
seedlings; the greenhouse ("glass houses... everyone can see in, nobody looks").

**Fauna:** none on the island maps. The polar bear exists only as the bunker's cub batch.

**Time of day:** four phases — morning, midday, evening, night (90 s each). Morning: Initiates
memorize texts, Drones water seedlings, Barren haul water. Midday: blood-art practice (never
shown), doctrinal rounds, weeding, manual labour. Evening: gossip by the well, cohort chant, nets
mended on the shore. Night: Initiates sleep "beneath the icons", Priestesses keep vigil, Drones
are returned to the compound, a Barren woman stands by the tide line.

**Lighting and colour temperature:** soft daylight, pastel, slightly desaturated compared with
Florida. Golden hour for key art. Night is a calm deep blue with warm windows, "calm on the
surface, watchful underneath".

**Mood words:** cozy, polite, pastel, orderly, uniform, sincere, watched, too-perfect.

**Must appear (in island key art):** the striped temple with its gold dome; a Queen Mother icon;
bunker-shaped homes with faces; bunting; the wreck on the south beach; men in identical work
clothes tending the garden; Covenant women all wearing the same small smile.

**Must never appear:** violence; weapons; women gardening (the Drones garden, not the women);
measuring instruments in use (they are forbidden); the adult polar bear; Chelsea Clinton.

**Audio identity:** see 9.2 — village (96 BPM, G major, ukulele, marimba, pizzicato, the melody
always resolving to the same polite phrase), night (70 BPM, A minor), ritual puzzle (90 BPM,
E minor), festival (112 BPM, F major).

---

## 6. The other areas and worlds

### 6.1 The Temple of the Queen Mothers

**In-story:** the high-holy temple, built on the island's real temple building. It holds the Queen
Mother icons, the Seal of the O and Atwood's skull. Priestess Betty receives offerings here.
"The Queen Mothers see all who wish to be seen. And all who don't, of course."

**Interior (30×20 cells):** high cream brick walls with a pale cap; a cream and blush-pink
**checkerboard floor**; a **pink rug runner** from the door up to a pink **dais**; **six Queen
Mother icons** in a row along the high north wall (three each side of the dais); the **Seal of the
O** over the dais; the **Calendar of Blood** on the wall; a **colonnade** of pillar-orbs (four each
side); the **ritual table** with the **skull altar** (Atwood's skull, flower crown, red bow) on the
east side, where the ritual puzzle is played (arranging the icons); a **sealed alcove door** on the
west wall leading down to the Ruins, with the red forbidden tag beside it.

**Who:** Priestess Betty (lavender robe, braids, circlet) stands before the dais. Initiates come at
morning to memorize texts and in the sacred weeks for "visions and weeping".

**Lighting:** bright, even, white-pink, like sunlight through gauze; candles at night vigil. Warm
pastel; the gold of the dome and crowns is the warmest note.

**Mood words:** reverent, pastel, ceremonial, hushed, symmetrical, faintly oppressive.

**Must appear:** the six icons, the Seal of the O, symmetry, the rug runner, the skull altar.
**Never:** a portrait of Chelsea; legible scripture; anything frightening; blood other than the
calendar's droplets.

**Audio:** 60 BPM, D dorian, harp and glass harmonica, slow pipe-organ chords softened like a toy
organ, a small bell on every downbeat, wordless choir pads.

### 6.2 The Calendar of Blood and the Festival of the Fourteenth

**In-story:** time is counted in 28-day cycles keyed to the Priestess cohorts, regardless of the
seasons. The count drifts every cycle ("the festival was in the cool season last cycle; now it's
hot"); nobody corrects it because noticing would require measuring. The **Festival of the
Fourteenth** falls on cycle day 14.

**The cycle as the game runs it** (cohort signals, `calendar.json`):

| Days | Signal | What NPCs do |
|---|---|---|
| 1–3 | "The Gate has opened" — a new cycle begins | cohort announces the new cycle |
| 4–6 | "The womb calls" — the rites are held | Priestesses prepare the birth chambers; Drones are brought in at evening |
| 7–11 | training days | texts, blood-art, memorization; second cohort chants |
| 13 | festival eve | the cohorts fast and sing |
| **14** | **Festival of the Fourteenth** | "The cohorts rise as one. Offerings are made and the Mothers are praised." Initiates make offerings in the great hall ("I wore my good sash!"); the Priestess leads; Barren carry baskets for the Mothers ("same as every cycle, but with ribbons"); Drones are given "the tonic" and brought in at evening |
| 15–20 | quiet days | nobody discusses what the rites did or did not accomplish |
| 21–27 | the sacred weeks | "Visions, weeping and fury are holy. Do not interrupt a vision." |
| 28 | the Gate nearly shut | waiting; "the count will drift again" |

**Festival look:** a parade through the village to the great hall: everyone in their good clothes,
sashes and ribbons, flower garlands, offering baskets, bunting on every fence, the Mothers carried
or walked at the front and praised, Initiates in a perfectly even line, Drones and Barren carrying
things at the back. Bright pastel daylight, petals, sparkles. Joyful parade energy with a
mechanical, too-perfect uniformity: everyone claps on the same beat.

**Calendar motif:** the canon calendar prop — a smiling desk calendar with spiral rings, a grid of
pink and red squares, small red droplets, stars and crescent moons. A 28-day wheel works the same
way. This is the only place red "blood" droplets appear.

**Must never appear:** the rites themselves; anything bodily; the birth chambers' interior beyond
"immaculate and dusty".

**Audio:** festival march 112 BPM, F major, hand drums, tambourine, steel drum, kazoo-like reed
lead, clapping on 2 and 4, a repeating call-and-response hook.

### 6.3 The Ruins of Utopia

**In-story:** the cruise wreck fused with Epstein's bunker infrastructure, entered from the wreck
on the south beach (or the temple's sealed door). The Covenant treats everything as sacred and
understands none of it. This is the dungeon crawl: the player recovers **Forbidden Knowledge**.

General look: lost glamour plus retro sci-fi. Tilted cruise decks, brass and carpet, pipes and
server racks, all candle-lit and ribboned by shrine-keepers. Blue-green gloom (steel blue,
sandstone, moss, ash, machine grey) with pink and mint accents. Captions are soft lilac-white on a
dark plum outline.

| Room | Title in game | What is there | Ambient tone (from the game) |
|---|---|---|---|
| Wreck | **The Promenade Deck (Sideways)** | sacked gift shop (pink), deck chairs, a melted ice swan, tilted slot machines, a lifeboat stencilled LIFEBOAT 7, a buffet laid out "reverently" | "The deck tilts a few degrees... The shrine-keepers have decided that is the direction of prayer." A deck chair still faces a sunset. The gift-shop awning says SOUVENIRS, which the Covenant calls scripture and cannot read. |
| Corridor | **The Service Spine** | ceiling pipes painted with a pale red stripe ("someone believed it was meant to be blood"), portraits painted from memory, a towel trolley that has waited for decades, a vending machine used for offerings, CREW ONLY scratched out | a powerless sign: ALIGN THE PROMENADE STABILIZERS. Every portrait's eyes are "slightly too large and slightly too kind". |
| Core | **The Reliquary Core** | humming server racks, an altar built on a control desk, a candle forest with wax run into the vents, a pink Seal of the O stencil, a hatch stencilled DOWN | the cooling fan's hum is "the Voice of the Gate". Cables braided with sacred ribbons. A big pink O with an arrow pointing down that keeps coming back. |

**Forbidden Knowledge pickups** (draw as cute glowing collectibles): a gift-shop paperback (only
the back-cover reviews were ever read), a gift-shop receipt inside a book of soup-for-the-soul
platitudes, a laminated tide table with a little moon, a glass thermometer, a plain wall calendar
(squares all the same size, none red), a cycle chart with one highlighted bar, a tank label, the
procedure on the wall, the conception ledger, the bunker's mission statement, a head-count sheet,
the batch board, the reproduction proposal, the polar bear appendix (a thin file with a heart on
the tab).

**Mood words:** decayed glamour, discovery, hush, dripping, candle-lit, melancholy, absurd.
**Must appear:** at least one cruise relic (deck chair, life ring, slot machine, gift-shop awning)
beside at least one machine (pipes, racks, screens), with ribbons and candles on both.
**Never:** danger, traps, monsters (the only creatures are the bunker's clones and cubs).

**Audio:** wreck — 72 BPM, B minor, lounge piano playing a half-remembered cruise melody through
tape warble, rusty creaks, ocean swell, distant foghorn. Bunker machinery (the Service Spine and the
Reliquary Core; file `ruins_colony`) — 80 BPM, F# minor, analog synth arpeggio slowly filtering,
sub pulse, data blips, airy choir.

### 6.4 The secret bunker (Epstein's clone lab)

**In-story:** below the Reliquary Core: the doomsday bunker and clone lab, "built to make more
people, in comfort, for the future". A bound proposal planned to reproduce four prominent people
of the old world from cells: **Jeffrey Epstein, Bill Clinton, Hillary Clinton, Bill Gates.** Every
batch "walks, groans and will not grow up". Nobody discontinued anything; the incubators kept them
warm out of habit. A **polar bear batch**, grown as a control, came out fine — and "the control
group is eating the experimental group". Horror-game fare (Splatterhouse register), entirely
kawaii. Nobody fights: the player only watches.

**Rooms:**

| Room | Title | What is there |
|---|---|---|
| Lift | **The Descent Hatch** | a lift cage propped open by a mop bucket; pastel hazard stripes climbing the shaft (pink, mint, pink, mint); an intercom that only clicks, politely; coat hooks hung with "cloaks of the dead"; AUTHORISED STAFF ONLY with a smaller PLEASE KNOCK beneath; little footprints in pink fluid leading to the tanks and back; smell of cold metal and very old strawberry cleaning fluid |
| Clone hall | **The Hall of Tanks** | four tall glass tanks of pink fluid (a rubber duck in tank 3), warm incubators, a sequencer with the cat-in-a-lab-coat sticker, a centrifuge "mid-spin forever", sterile dusty prep benches, a humming freezer, a fluffy cub basket |
| Records | **The Quiet Archive** | shelves of binders with tiny-print spines (by year, cross-referenced), a desk lamp that has been on for decades, filing cabinets, labelled stationery, cream untouched carpet, a drawer labelled FAILED BATCHES too full to close, a drawer labelled BEARS with a heart drawn on it, a drawer labelled MISC |

**The clone children** (draw them small, pale-green, shambling, kawaii):

- Body: pale mint skin `#c9ecc4`, a big round head, a hospital gown with a stitched seam, little
  legs, both arms stretched straight forward in the classic shamble.
- Face (every clone): one sleepy dot eye and **one X eye**, pink blush, a tiny round groaning
  mouth, **forehead stitches**, a **green goo drip** off the chin.
- Every batch of one original **shares the same little face**; the originals are told apart by
  hair and gown colour:

| Original (game text) | Look for generators | Gown |
|---|---|---|
| Jeffrey Epstein | grey hair swept back | pink `#ffb3c8` |
| Bill Clinton | white puffy hair, a round red nose | sky `#a8d8f0` |
| Hillary Clinton | blonde bob | lilac `#c9b3f0` |
| Bill Gates | brown side-parted hair, big round glasses | butter `#ffe08a` |

- Designation in game: "<name> clone, batch <n>" (batches: Epstein 1–9, Bill Clinton 1–4, Hillary
  Clinton 1–4, Bill Gates 1–6; every one "did not take"). Restocked clones climb out of the tanks.
- They groan politely and ask for snacks and braids ("Braaaains? No. Braaaids."); they are never
  scary and never attack.

**The polar bear cubs** ("Polar bear clone", "Cub"; designation "Polar bear clone, batch <n>";
polar bear batch 1: "took. Very well."): round white fluffy body, stubby feet, small round ears
with pink insides, a pale muzzle, a dark button nose, shiny dot eyes with a white catch-light,
pink blush. After a meal the muzzle is smeared pink; napping cubs have closed curved eyes. They
"Mrrf!", snuffle and do a happy wiggle.

**The pounce (the bunker's set piece):** every 14–32 s a cub pounces on a nearby clone: **boing →
chomp → splat → burp**, then the kawaii-gore burst (4.7), then a 6-second nap ("zzz", tiny snore).
The pastel puddle fades after 8 s; 25 s later a fresh clone of that batch climbs out of a tank.

**Lighting:** dim blue-green lab gloom, the tanks glowing soft pink and the incubators warm;
mint and pink hazard stripes; the archive lit by one warm desk lamp.

**Mood words:** spooky-cute, Halloween cartoon, splatter comedy, sterile, patient, absurd.
**Must appear (bunker key art):** rows of glowing tanks, small pale-green shambling clone children
with X eyes and stitches, fluffy white cubs, pink cartoon splatter with hearts and sparkles.
**Never:** realistic gore; fear or pain on any face; a named person's likeness; the adult bear.

**Audio:** 100 BPM, C minor, bubbling theremin lead, squelchy synth bass, music-box
counter-melody, bubbling-tank foley rhythm, playful toy percussion, sudden cute stabs. Clone voice
pitch ×1.5, cubs ×1.9.

### 6.5 Tropical Florida Keys

**In-story:** the pre-dystopia normal world, the novel's "control group": the real world that kept
going. A tropical Toca World / Animal Crossing setting in the Florida Keys. **Innocent play:** pure
sandbox, nothing can be done wrong, no scoring, zero judgment. This world gets the gardening and
crafting (gardening is only gendered on the island; in Florida it is just fun). Mermaids are
"real" — aquarium-show mermaids, friendly, never explained.

**Who lives here:**

- **Father** — a fisherman, "or something close to it. The boat does the real work." Teaches
  stone-skipping ("Low and sideways, from the wrist"). Key lime lemonade up at the house.
- **Daughter** — collects stones (two hundred in a bucket, allowed to keep fifty; grey ones with a
  white stripe are lucky); grabs her hat and her brush to show you the horses out back.
- **Hannah** — the Daughter's friend from down the road, at the stable "basically every day",
  brushing a pony's mane ("Little strokes, like you're brushing a cloud").
- **Dolphins** Sunny and Pearl; **crabs** Sidestep, Clementine and Pebble; **gulls** Biscuit, Mabel
  and Pickle; **mermaids** Marina and Lagoon. A pelican "who thinks he owns the dock" is mentioned.
- Every critter reacts with delight to whatever the player wears ("A flower crown! You look like a
  wave in bloom!", "Sunshine! Sandwiches! Friends! Today has everything!").

**Areas:**

| Area | What is there |
|---|---|
| **Beach** | turquoise shallows, white foam, sand with shells to collect, the Father and Daughter, leaping dolphins, crabs walking sideways, gulls hopping, mangroves at the edge ("out past the mangroves"), the dock; doors to the garden and the aquarium |
| **Garden** | six garden plots (empty, growing, ready), a seed bag, a craft bench, a crab and a gull visiting |
| **Aquarium** | an aquarium show pool where two mermaids swim and do bubble tricks; fish that "wave back" |
| **Pony stable** (planned) | behind the house: ponies to groom (the paper-doll makeover on a pony), ride (faster click-to-move) and breed (coat and mane traits mix, played straight and joyful); two girls brushing a horse's mane |

**Plants (grow over days; watering speeds them up):** hibiscus, sea grape, key lime,
bougainvillea, plumeria, guava, mango, coconut (colours in 4.4).
**Crafts:** flower crown (hibiscus), shell garland, plumeria lei, bougainvillea wreath (all
wearable), key lime pie, sea grape jelly, guava pastry, mango smoothie, shell wind chime.

**Lighting:** full tropical sun, high saturated colour, clear sky, sparkling water; warm golden
afternoons. **Colour temperature:** the warmest, most saturated world in the game: turquoise,
coral, hibiscus pink, mango, key-lime green.

**Mood words:** tropical, sunny, carefree, generous, unhurried ("Nobody's in a hurry"), kind.

**Must appear:** turquoise water, sunshine, critters delighted, flowers, the father-and-daughter
warmth. **Never:** anything ominous, uniform, judged or ritual; any Covenant symbol; any "wrong"
undertone. Florida is the one world where nothing is wrong.

**Audio:** beach 104 BPM D major (steel drum, ukulele, bongos, breezy flute, wave wash); garden
88 BPM G major (fingerpicked acoustic guitar, marimba, brushed snare, flute trills); aquarium
76 BPM E major (harp glissandi, bubbly plucks, whale-song pad, vibraphone); pony stable 108 BPM
A major (banjo, fiddle, clip-clop woodblock, harmonica, glockenspiel). Critter voice pitches:
dolphin ×1.3, crab ×1.1, gull ×1.4, mermaid ×1.2.

### 6.6 The Cruise (flashback era)

**In-story:** the ship before the wreck, at peak confidence: a feminist-themed celebrity cruise,
champagne, triumph, speeches, panels on motherhood. Every scene is empowering on its surface; the
dialogue is lifted almost verbatim from mass-media empowerment culture (TED talks, Lean In,
Women's March signs: "The Future is Feminist.", "Let's take up more space."). The celebrities'
pop-culture personas later become the island's religion: "The manifest that became a pantheon."
**Judged performance:** the same paper doll as the island, but the makeover is judged.

**The ship:** a glamorous white mega cruise ship, gold trim, deck lights, streamers and balloons;
by day a sunny Lido deck, by night a glowing deck connecting stages. Stations: Bridge, Promenade,
Atrium (grand staircase, chandelier, champagne fountain), Lido Deck (wave pool, poolside bar,
towels, sunscreen), Spa (hot stones, eucalyptus, mud wraps, a gong), Gift Shop (snow globes,
souvenir mugs, bestseller rack, postcards), Galley (soufflés, brunch buffet, oat milk), Engine
Room; plus Staterooms, the Purser's Desk, the Laundry, the **Glow Lounge** salon, and the
**Atrium Runway**.

**Hosts** (real names in game text; roles in generator prompts):

| Host | Role | Generator description |
|---|---|---|
| Chelsea Clinton | introduces every celebrity mini-game, explaining how empowering and fun it will be ("They persisted and so should you.") | a poised emcee with cue cards, warm smile, stage light |
| Tyra Banks | hosts **Hottest of the HOT**, the top-model judging show | a glamorous runway-show host in a sleek gown, judging-panel desk |
| Sarah Silverman | hosts **Next Top Comic** | a stand-up comic at a mic stand in a small club |
| Oprah Winfrey | hosts **The Interview** (character creation) | a warm talk-show host on a studio couch |
| Cap'n Kate (based on Kate McCue) | the captain; "I am the CEO of the ship." | a telegenic cruise captain in a white dress uniform with gold epaulettes |

Ellen and Margaret Atwood are on board (no game role yet); Gloria Steinem's line "The truth will
set you free, but first it will piss you off!" is the novel's title page.

**The Landing (bridge panic):** Spaceteam-style coordinated panic as the dead ship comes down,
Among Us-flavoured crew tasks without any killing (the impostor energy is social: look busy, take
credit, borrow authority). Fog over everything; systems failing; the First Mate yelling for the
captain. Absurd commands at every station: "Align the Promenade Stabilizers!", "Reassure the EMP
Recovery Hamster!", "Strike the Gong of Calm. No, not like that. Like that!", "Turn the Backup Warp
Knob to eleven (it only goes to ten)!" Crew tasks: "Wave at the fog so it knows we are friendly",
"Moderate an impromptu panel on the crisis, topic: your feelings". Look: pale grey fog, dimmed
glamour, flashing panels, tilting deck chairs, comedy chaos. 160 BPM, D minor panic loop.

**Makeover chains → Hottest of the HOT:** Day of the Tentacle-style chained tasks across the ship.
The passenger gets a call sheet under the door ("We only want you to feel your best (we
noticed)"), the one-size complimentary robe, a mirror hung a little too low, a Glow Lounge
appointment ("a cancellation, you're so lucky, honestly, you looked like you needed it"), a
"Very Brave" red ribbon from the "Be a Bigger Yourself" display, a trim "to make it more
manageable", a braid ("A braid hides so much. It's a compliment, hold still."), a white dress
pinned "size not final", a Lido warm-up where everyone is rooting for you, and a runway number
pinned with a bow "so nobody looks at anything else". Then Tyra's verdicts: "who did your hair?",
"so brave to wear that". Look: salon mirrors with bulb lights, spotlit runway, judging desk,
camera flashes, glossy white and gold with hot pink. 124 BPM, F minor runway house.

**Next Top Comic:** stand-up in Monkey Island insult-sword-fighting structure: horrible unfunny
setup/punchline pairs, and the women in the audience think it's hilarious. Look: brick wall,
spotlight circle, mic stand, little round tables. 128 BPM, C major comedy-club jazz.

**The Interview:** character creation as a daytime talk-show segment; Oprah's lines are her own
quotes ("You are your possibilities.", "Turn your wounds into wisdom."), the player's answers set
seven stats (Strength, Perception, Endurance, Charisma, Intelligence, Agility, Luck). Look: warm
studio couch, audience in soft focus, big friendly lights; inviting, confessional, a little too
eager. 116 BPM, E major talk-show theme.

**Lighting and colour temperature:** sunset gold and champagne by day; spotlights, deck lights and
night navy by night; gloss everywhere. The Landing alone is grey with fog.

**Mood words:** glamorous, glossy, eager, celebratory, judging, entitled, confident.
**Must appear:** gloss, gold, spotlights, champagne, sunset, streamers. **Never:** the wreck (the
cruise is *before*); the island's Covenant symbols (they do not exist yet); real-person likeness.

**Audio:** lounge 98 BPM Bb major (bossa guitar, upright bass, brushes, vibraphone, light strings).

### 6.7 The time jump: "Before the Wreck"

The island chapter ends at the west dock. A full-screen card (4.10) jumps **back** to the cruise;
the next chapter has a different player character and cast. Art: the ship at sunset, lit up,
streamers and balloons, seen slightly from below, film grain and faint VHS lines; video rewinds the
wreck into the living ship. Audio: 70 BPM, Ab major, a rewinding-tape effect into a warm lounge
chord, the music box restating the title melody, ending on an unresolved suspended chord.

---

## 7. Characters

### 7.1 General character rules

- Chibi proportions: a big round head (about half the height), short body, stubby limbs, dot eyes,
  pink blush ovals, a small curved smile; warm brown outline.
- Three views per NPC (front, side, back), 48 px tall in game.
- **Covenant women** (Mothers, Priestesses, Initiates) all wear **the same small calm smile**,
  stand very straight, hands folded or holding something devotional. The sameness is the point.
- **Drones** look plain and mild: neutral or slightly tired faces, mouths small and flat or a weak
  smile, standing loosely.
- **Barren** women look capable and a little weary: a small smile, a work tool in hand.

### 7.2 The castes (as drawn on the canon caste sheet)

| Caste | In-story | Costume and colour | Silhouette and posture | Expression |
|---|---|---|---|---|
| **Mothers** (Covenant of Mothers) | governing body; women who have given birth — rare, therefore powerful | long wavy golden-blonde hair, small gold crown (sometimes), drop earrings, white gown with a pale-blue wrap, holding a sleeping swaddled baby | soft, wide, gown to the floor, cradling arms | eyes closed in serene bliss, gentle smile |
| **Priestesses** | ritual leaders; enforce doctrine, train Initiates | light-brown hair in braids (front plaits or one long back braid) with a silver/lavender circlet and jewel; long lavender-to-purple robe with wide sleeves and trim | tall, straight, hands folded at the waist | the same small calm smile |
| **Devout Initiates** | young women in training; study sacred texts, prepare for the rites; "believing their society is the peak of human evolution" | brown pigtails with pink ties; sailor school uniform: white blouse, navy sailor collar, red neckerchief, black pleated skirt, white socks, black shoes; carrying a book of sacred texts | small, neat, book held to the chest | bright eager smile |
| **Drones** | men kept in compounds; they garden (the women do not); brought in for the rites, returned after | messy brown hair; ragged grey-green tee; patched brown trousers; boots | plain, slightly slumped, hands at sides; often a trowel or watering can | neutral, mild, a little sad |
| **Barren** | women who did not conceive; stigmatized, assigned to labour | brown hair under a tan headscarf; orange shirt; denim overalls; a broom | sturdy, feet planted, tool in hand | small tired smile |

The infographic also shows Mothers/Priestesses in white with a pink sash and in pale blue and
lavender, and Initiates in sailor uniform reading together; Drones are drawn behind wooden fences
with blank signs; the Barren hold brooms beside a red X.

### 7.3 Named cast (from `cast.json` — use only these names)

| Id | Name | Who |
|---|---|---|
| initiate | **Gloria** | the Initiate who asks you to carry the offering ("Everyone contributes. Everyone.") |
| priestess | **Priestess Betty** (Betty) | the temple's Priestess ("Stand straighter, dear. The icons are watching.") |
| drone | **Bruce** | the Drone in the garden ("The tomatoes listen better than anyone on this island.") |
| barren | **Susan** | the Barren woman at the yard and the tide line ("Water doesn't care what the Calendar says.") |
| chelsea, tyra, kate, silverman, oprah | Chelsea Clinton, Tyra Banks, Cap'n Kate, Sarah Silverman, Oprah Winfrey | cruise hosts and captain |
| dolphin_sunny, dolphin_pearl | Sunny, Pearl | Florida dolphins |
| crab_sidestep, crab_clementine, crab_pebble | Sidestep, Clementine, Pebble | Florida crabs |
| gull_biscuit, gull_mabel, gull_pickle | Biscuit, Mabel, Pickle | Florida gulls |
| mermaid_marina, mermaid_lagoon | Marina, Lagoon | aquarium mermaids |
| stable_friend | Hannah | the Daughter's friend from down the road, brushing a pony's mane at the stable |
| epstein, bill_clinton, hillary_clinton, bill_gates | Jeffrey Epstein, Bill Clinton, Hillary Clinton, Bill Gates | clone originals (bunker) |
| polar_bear_clone | Polar bear clone (Cub) | the cub batch |

Also speaking: **Father** and **Daughter** (Florida), the **First Mate** (Landing).

### 7.4 The paper-doll player

- Toca Boca paper doll: a bald chibi base body (big round head, dot eyes, blush, small smile,
  cream vest and shorts) with swappable parts that sit exactly on the body.
- **Hair:** pigtails (brown, pink ties), crown (long wavy blonde with a little gold crown), braids
  (light brown, two plaits, circlet with a jewel), short (brown wavy bob).
- **Dress:** uniform (sailor), robe (cream with a gold sash and wide sleeves — also the cruise's
  one-size complimentary robe), white (the Hottest of the HOT dress).
- **Accessory:** pink bow; Florida crafts (flower crown, shell garland, plumeria lei, bougainvillea
  wreath). Placeholder dresses also exist in rose, teal and cream; hair in cocoa, ink and rose.
- The player is drawn at NPC height (48 px) in the world.
- Framing by world: Florida — every outfit delights someone; island — kind, expressive play (the
  village mirror); Cruise — the same parts applied *to* you by stylists and judged.

### 7.5 Depicting real people

- **Game text:** real names, exactly as in the source.
- **Image/video prompts:** describe the role, the costume and the setting, never the name or a
  likeness (see the host table in 6.6). The Queen Mother icon is "a smiling woman with a short
  blonde bob, pearls and a gold crown, in a white shrine frame". Clone originals are described by
  hair cues only (6.4).
- About real people, use what the sources state (no invented content).

---

## 8. World-at-a-glance table

| Area | Light | Temperature | Dominant colours | Accent | Mood words |
|---|---|---|---|---|---|
| Village | soft day, golden hour | mild pastel | mint, blush, cream, sky | pink hearts, gold | cozy, polite, uniform |
| Temple | gauzy white-pink | warm pastel | cream, blush, lavender | gold, Seal red | reverent, symmetrical |
| Festival | bright day | warm pastel | ribbons in all pastels | flower pink | joyful, too-perfect |
| Island night | deep calm blue | cool | navy, lavender | warm windows | watchful |
| Ruins | dim, candle-lit | cool | steel blue, sandstone, moss, ash | pink, mint ribbons | decayed glamour |
| Bunker | blue-green gloom, glowing tanks | cool with pink glow | machine grey, tank green | gore pink, hazard mint | spooky-cute |
| Florida | full sun | hot, saturated | turquoise, sand, leaf green | coral, hibiscus, mango | tropical, carefree |
| Cruise day | sunset gold | warm, glossy | white, gold, champagne | hot pink | glamorous, eager |
| Cruise night / shows | spotlights | warm on cool | navy, white | gold, neon pink | judging, showbiz |
| Landing | fog | cold grey | grey-white | flashing panel lights | panic, comedy |

---

## 9. Audio system

### 9.1 Music specs

- Instrumental only, no vocals, no lyrics (wordless choir pads allowed where listed).
- Area music: seamless loops of 2:00–3:00. Stingers: 3–30 s, not looped.
- Loudness: about −16 LUFS integrated for music, −14 for stingers; mixed to sit under dialogue.
- No hard transients in the first or last 50 ms, so loops join cleanly.
- Export MP3 320 kbps.

### 9.2 Per-area identity (the shipped prompts are the reference)

| Area | Tempo | Key / mode | Instruments | Character |
|---|---|---|---|---|
| Title | 84 | C major | music box and celesta lead, felt piano, warm pad, faint detuned toy-organ drone | the lullaby; the drone slowly makes the sweetness feel wrong |
| Island village | 96 | G major | ukulele, marimba, shaker, pizzicato strings, glockenspiel answers | life-sim town; the melody always resolves to the same polite phrase |
| Island night | 70 | A minor | nylon guitar, vibraphone, cricket shakers, distant wordless choir hum | calm surface, watchful underneath |
| Ritual puzzle | 90 | E minor | kalimba ostinato, woodblock clock ticks, bowed glass, end-of-phrase chime | focused, ceremonial edge |
| Festival of the Fourteenth | 112 | F major | hand drums, tambourine, steel drum, kazoo-like reed, claps on 2 and 4, call-and-response hook | parade joy, mechanical uniformity |
| Temple | 60 | D dorian | harp, glass harmonica, toy-soft pipe organ, bells on downbeats, wordless choir | reverent, faintly oppressive |
| Ruins wreck | 72 | B minor | tape-warbled lounge piano, metal creaks, ocean swell, distant foghorn | lonely decayed glamour |
| Ruins bunker machinery (`ruins_colony`) | 80 | F# minor | filtering analog arpeggio, sub pulse, data blips, airy choir | discovery with dread, 1990s adventure game |
| Bunker clone lab | 100 | C minor | theremin, squelchy bass, music box, bubbling-tank foley, toy percussion, cute stabs | Halloween cartoon, splatter comedy |
| Florida beach | 104 | D major | steel drum, ukulele, bongos, flute, wave wash | pure carefree summer |
| Florida garden | 88 | G major | fingerpicked guitar, marimba, brushed snare, flute trills | warm slow afternoon |
| Florida aquarium | 76 | E major | harp glissandi, bubbly plucks, whale-song pad, vibraphone | magical wonder |
| Pony stable | 108 | A major | banjo, fiddle, clip-clop woodblock, harmonica, glockenspiel | bouncy and bright |
| Cruise lounge | 98 | Bb major | bossa guitar, upright bass, brushes, vibraphone, light strings | luxury, champagne |
| The Landing | 160 | D minor | galloping synth bass, alarm-like square lead, snare rolls, brass stabs, rising every 8 bars | chaotic, funny panic |
| Hottest of the HOT | 124 | F minor | four-on-the-floor, glossy synth chords, camera-shutter percussion, filtered bass | glamorous and judging |
| Next Top Comic | 128 | C major | walking bass, ride cymbal, muted trumpet, honky-tonk piano, rimshots | smoky, sardonic |
| The Interview | 116 | E major | piano, horn section, funky bass, audience handclaps, swelling strings | inviting, a little too eager |

**Harmony rules by world:** Florida — bright major, nothing unresolved. Island — major and dorian,
sweet, with a quiet drone or a phrase that always resolves the same polite way. Cruise — showbiz
major/minor by venue. Ruins/bunker — minor, tape warble, unresolved endings.

### 9.3 Leitmotif

The **title melody** (C major music-box lullaby) is the game's theme. Restate it in stingers and
transitions: the chapter-end stinger restates it on music box over a warm lounge chord (Ab major)
and stops on an unresolved suspended chord. When writing a new stinger or ritual cue, quote a
fragment of the title melody on music box or celesta.

### 9.4 Stingers

| Stinger | Spec |
|---|---|
| Name It | bright revelation: celesta and glockenspiel rising arpeggio, sparkle shimmer, a clear major chord |
| Before the Wreck | 20–30 s, 70 BPM, Ab major, rewinding tape into a lounge chord, music box restates the title melody, unresolved suspended ending |

### 9.5 Sound effects

- Short, soft-attack, cartoon: boing, squish, chime, pop, sparkle.
- The clone hall set (synthesized in `tools/gen_clone_sfx.py`, 22.05 kHz 16-bit mono):
  **boing** (the cub's soft pounce), **chomp** (squishy crunch), **splat** (wet), **burp** (cute),
  **snore** (tiny cub snore).
- Kawaii gore uses wet splats and a cute burp, never realistic screams.
- Everything is original (generated in `tools/` or rendered in the same character); nothing
  sampled from other games.

### 9.6 Voices

- Spoken lines are **speech** with impersonated voices: cloned voices of the real people (XTTS,
  `project/data/voices.json`, reference recordings in `art/voice_refs/`) for Chelsea, Tyra, Oprah,
  Sarah Silverman and Cap'n Kate.
- Non-celebrity characters use built-in studio voices: Initiate "Daisy Studious", Priestess "Ana
  Florence", Barren "Gracie Wise", Drone "Andrew Chipper", First Mate "Damien Black"; anyone else
  uses system text-to-speech. Playback pitch: Initiate ×1.25, Priestess ×0.85, Barren ×0.9,
  Drone ×0.7.
- Celebrity lines come only from their sourced quotes in `project/data/quotes/`.
- **Never Animalese, babble or beeps.**

---

## 10. Asset pipeline

- One prompt file per asset in `prompts/<type>/<group>/<id>.md`.
- Render in the Gemini web UI; save the result in the `assets/` folder beside the prompt, named
  as its `drop:` line says (video as `.mp4`).
- `python3 tools/sync_rendered_assets.py` copies each rendered file to its `game:` path inside
  `project/` (converting `.mp4` to Godot's `.ogv`) and lists prompts with nothing rendered.
- Groups: `audio/music/<area>/` (Lyria, MP3), `audio/stingers/`, `image/ui/<element>/` (title,
  chapter_cards, loading, icon), `image/levels/<area>/`, `video/ui/`, `video/levels/<area>/` (Veo).
  Areas: island, temple, ruins, florida, cruise (plus ui). Key art is
  `project/assets/key_art/<area>/<id>.png`; video is `project/assets/video/<id>.ogv`.
- Before committing, run `python3 tools/check_prompts.py` (front matter, `assets/` folders,
  preamble and negative markers, no hex, no banned words, no real names in image/video prompts).

---

## 11. Preambles (compiled into every prompt)

Each leaf prompt's `## Prompt` is compiled in this order: the **asset-type preamble**, then the
**world line**, then the asset's own subject, framing, light and mood (with every must-appear item
of its world), then for images and video the **negative prompt** from 4.12 (with "(unless
requested)" resolved: "no logo" everywhere except `title_screen`), and for music the **loop and
loudness spec**. The result is pasted into the generator as is; nothing else is added at render
time. Blockquote markers below are not part of the text.

### 11.1 Image (Gemini image)

> Kawaii pixel-art game art in a clean sticker-illustration style: even warm-brown outlines (never
> black), flat pastel fills with one soft highlight, round pink cheek blush, dot eyes and small
> smiles, cute faces (two dot eyes, pink blush, a small smile) on buildings, trees, props, the
> ship and the bunker, big round readable shapes for a 640×360 game, overhead three-quarter view
> for places, hearts and four-point sparkles as motifs, soft antialiased edges with no harsh pixel
> stair-steps. Cute on the surface with something faintly wrong underneath. 16:9. No
> photorealism, no 3D, no text.

### 11.2 Video (Gemini Veo)

> Kawaii pixel-art style animation in a clean sticker-illustration look: even warm-brown outlines
> (never black), flat pastel fills with one soft highlight, round pink cheek blush, dot eyes and
> small smiles, cute faces (two dot eyes, pink blush, a small smile) on buildings, trees, props,
> the ship and the bunker, soft antialiased edges with no harsh pixel stair-steps, bouncy
> squash-and-stretch motion, slow smooth camera, sparkles drifting, big readable shapes for a
> 640×360 game. Cute with something faintly wrong underneath. 16:9, 5–8 seconds, no dialogue, no
> text.

Image and video variants: for **Florida**, replace "Cute on the surface with something faintly
wrong underneath." (or "Cute with something faintly wrong underneath.") with "Pure carefree joy,
nothing wrong anywhere." For video, replace "5–8 seconds" with the asset's length. For the **app
icon**, drop the overhead-view clause and replace "16:9" with "1:1 square, 1024×1024, must read at
64×64". For the **title screen with logo**, replace "no text" with "no text other than the
requested logo".

### 11.3 Music (Gemini Lyria)

> Instrumental video-game music for a kawaii game, no vocals, seamless loop of 2 to 3 minutes,
> soft attack and no hard transient at the loop point, mixed quietly to sit under dialogue. Cute
> and melodic on the surface with a subtle sense that something is slightly wrong.

For **stingers**, replace the loop clause with: "a short non-looping cue of N seconds with a clean
ending". For **Florida** and the **Name It** sting (the one honestly happy cue), drop the last
sentence and use: "Pure carefree joy, nothing wrong anywhere."

Music spec line (appended last, from 9.1): "Spec: instrumental only, no vocals or lyrics; seamless
loop of 2:00 to 3:00 with no hard transient in the first or last 50 ms; about -16 LUFS integrated;
MP3 320 kbps." For stingers: "Spec: instrumental only, no vocals or lyrics; N seconds, not looped,
clean ending, no hard transient in the first 50 ms; about -14 LUFS integrated; MP3 320 kbps."

### 11.4 World lines (add after the type preamble)

| World | Image / video line | Music line |
|---|---|---|
| Island village | Little tropical island village traced from a real island's shape: bunker-shaped pastel homes with smiling faces, bubbly mint, pink and lavender trees, bunting on vine-wrapped fences, a blue-and-white striped temple with a gold dome, a pastel cruise-ship wreck with vines on the south beach; mint grass, blush paving, sky-blue water; slightly soft, slightly desaturated pastels; every woman wears the same calm small smile; men in plain work clothes tend the gardens. | Cozy life-sim island music, ukulele, marimba, glockenspiel, music box, toy organ; sweet major or dorian melodies that always resolve the same polite way, with a quiet drone underneath. |
| Temple | Symmetrical pastel temple interior: cream and blush checkerboard floor, pink runner to a dais, a row of identical portrait icons of a smiling blonde woman with a crown on the high wall, a red round seal with a bold O above the dais, white columns topped with smiling orbs, a cute flower-crowned skull on a pedestal; gauzy white-pink light. | Slow sacred kawaii ambience, harp, glass harmonica, toy-soft organ, small bells, wordless choir, dorian, reverent and faintly oppressive. |
| Festival | A pastel parade on a sunny island: identical smiling young women in sailor uniforms in perfect lines, women in lavender robes leading, ribbons, garlands, offering baskets, bunting everywhere, petals and sparkles; joyful but eerily uniform. | Bright ritual parade march, hand drums, tambourine, steel drum, reedy kazoo lead, claps on 2 and 4, call-and-response hook, joyful but mechanically uniform. |
| Ruins | Ruins of a luxury cruise ship fused with retro sci-fi bunker machinery: tilted decks, a deck chair facing a lost sunset, slot machines, pipes and humming server racks, candles and ribbons placed by worshippers who don't understand any of it; soft blue-green gloom with pink and mint accents. | Melancholy exploration ambience, tape-warbled lounge piano or filtering analog synth, ocean swell, distant foghorn, minor key, unresolved. |
| Bunker | Secret underground clone lab, spooky-cute: rows of glowing pink-fluid glass tanks, mint and pink hazard stripes, small pale-green shambling clone children with one X eye, stitches and goo drips, fluffy round white polar bear cubs, cartoon pink splatter with hearts and sparkles; Halloween-cartoon energy, nothing scary. | Kawaii horror lab music, bubbling theremin, squelchy synth bass, music box, bubbling-tank foley, toy percussion, cute stabs, minor key, splatter-comedy energy. |
| Florida | Sunny tropical Florida Keys: turquoise shallows, white foam, sand and shells, hibiscus, bougainvillea, key lime and mango trees, leaping dolphins, sideways crabs, hopping gulls, friendly mermaids; warm saturated colours, pure joy. | Bright tropical acoustic music, steel drum, ukulele, acoustic guitar, flute, harp or banjo and fiddle, bright major, nothing unresolved. |
| Cruise | Glamorous white cruise ship at sunset or under spotlights: gold trim, champagne, streamers and balloons, runway, talk-show couch, comedy-club mic, salon mirrors with bulb lights; glossy, celebratory and quietly judging. | Showbiz music for a celebrity cruise: bossa lounge, runway house, talk-show horns, comedy-club jazz; glossy and confident. |
| Landing | The same cruise ship dead in thick pale fog, deck lights failing, crew rushing between absurd control panels, deck chairs sliding, comedic chaos, no one hurt. | Frantic comedic panic loop, galloping synth bass, alarm-like lead, snare rolls, brass stabs, rising tension, funny not scary. |
| Title (UI) | as Island village (the title art is the island from above) | The game's theme: a gentle C-major music-box and celesta lullaby over felt piano and a warm pad, with a faint detuned toy-organ drone underneath. |
| Name It (UI) | — | A bright, clear revelation: celesta and glockenspiel, sparkle shimmer, a clear major chord; the one cue in the game that is fully, honestly happy. |
| Before the Wreck | The cruise ship before the wreck at sunset, lit up and glamorous, streamers and balloons, seen slightly from below, nostalgic film grain and faint VHS lines. | Rewinding-tape transition into a warm lounge chord, music box restating the gentle C-major title lullaby, ending unresolved. |

---

## 12. Template for a new prompt file

Match the existing files exactly: front matter, a heading, one line of purpose, `## Prompt`,
`## Notes`, and an `assets/` folder (with `.gitkeep`) beside the file. The prompt body is
**pre-compiled and self-contained** (section 11): one paragraph made of four parts in order —
(1) the asset-type preamble with its variants applied, (2) the world line, (3) the asset's
subject, framing, light and mood including every must-appear item of its world, described in
natural-language colours (no hex codes) and by role, hair and costume (no real names), (4) the
negative prompt (image/video) or the spec line (music).

```markdown
---
id: <asset_id>
tool: Gemini Lyria | Gemini image | Gemini Veo
drop: prompts/<type>/<group>/assets/<asset_id>.<mp3|png|mp4>
game: project/<audio|assets>/<...>/<asset_id>.<mp3|png|ogv>
---

# <asset_id>

<one line: what screen or area this is for>

## Prompt

<preamble> <world line> <asset: subject, framing, palette in words, light, mood, must-appear
items> <negative prompt (image/video) or spec line (music)>, all in one paragraph

## Notes

<format: image 16:9 1920×1080 shown at 640×360, no text unless the logo is asked for;
music instrumental, seamless loop 2:00–3:00, MP3 320 kbps; stinger N s, not looped;
video 16:9, converted to .ogv by tools/sync_rendered_assets.py>
```

Checklist before saving a prompt: the prompt is self-contained (all four parts); the look is
defined (warm-brown outlines never black, flat pastel fills, soft antialiased edges, no pixel
stair-steps); faces are on everything; the world's must-appear items are present; none of its
must-never items are; no real person is named in an image/video prompt; no text in visual assets
except the title logo; no hex codes in visual prompts; vocabulary rules (1.1) hold; tempo and key
fit the table in 9.2. Then run `python3 tools/check_prompts.py`.

---

## 13. Sources

| Fact area | Source |
|---|---|
| Mission, thesis, worlds, framings, Name It, mini-games, hosts | `docs/DESIGN.md` |
| Cruise, Landing, island origin, Covenant, icons, Seal of the O, calendar, Florida father and daughter, Kate McCue | the novel's Story Structure (sections 3, 6, 7, 8) |
| Castes and props as drawn | `dev/art/PERSISTINT_Novel_World-Building_Overview.png`, `art/canon/gemini/*.jpg` |
| Island map | `art/reference/little_st_james/SOURCES.md`, `project/data/island_layout.json`, `tools/build_island_maps.gd` |
| Tiles, deco, clone and gore art, palette hexes | `tools/gen_island_tiles.py`, `tools/gen_island_deco.py`, `tools/gen_clone_children.py`, `project/scripts/ruins/clone_lab.gd` |
| Names | `project/data/cast.json` |
| Ruins rooms, Forbidden Knowledge, clones, cubs | `project/data/ruins.json` |
| Florida | `project/data/florida.json`, `project/dialogue/florida_beach.dialogue` |
| Landing, makeover chains, shows, interview, emcee | `project/data/landing.json`, `hottest_chains.json`, `hottest_of_the_hot.json`, `next_top_comic.json`, `interview.json`, `emcee.json`, `empowerment_lines.json` |
| Calendar, schedules, barks | `project/data/calendar.json`, `barks.json`, `project/scripts/autoload/game_clock.gd` |
| Chapters and end card | `project/data/chapters.json`, `project/scripts/chapters/chapter_end.gd` |
| Voices and quotes | `project/data/voices.json`, `project/data/quotes/*.json` |
| Music specs | `prompts/audio/**` |
| Author rules | `bd memories` (design vocabulary, real names, no invented content, voices are speech) |
