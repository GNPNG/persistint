# PERSISTINT — master style guide (visual + audio)

Every prompt in `prompts/` follows this. Paste the **style preamble** for the asset type into
Gemini first, then the asset's own prompt.

## The idea the style serves

Kawaii on the surface, something wrong underneath. The same verbs (dress up, garden, perform,
be judged) appear in three worlds with three framings (DESIGN.md):

| World | Framing | Feel | Visual temperature | Audio temperature |
|---|---|---|---|---|
| Florida Keys | innocent play | pure joy, nothing wrong | warm, saturated, sunny | bright, acoustic, carefree |
| The Cruise (flashback) | judged performance | glamour with a critic's eye | glossy, spotlit, sunset gold | showbiz: lounge, runway, talk show |
| Little St. Piere Island | ritualized control | cute, polite, too uniform | pastel, soft, slightly desaturated | lullaby sweetness with a drone under it |
| Ruins of Utopia / bunker | discovery, decay, horror-comedy | lost glamour, retro sci-fi, spooky-cute | blue-green gloom with neon accents | warped lounge, analog synth, theremin |

No combat anywhere. Gore exists only as kawaii splatter (pastel pink, hearts, sparkles).

## Visual

**Medium:** 2D pixel art, top-down/three-quarter view, Animal Crossing scale, Stardew aesthetic,
Toca Boca paper-doll characters. Clean outlines, soft shading, no photorealism, no 3D render look.

**Resolution:** game view 640×360 (scaled ×2 to 1280×720). Map cells 32 px. Characters 48 px tall
(paper-doll source art 91×96, drawn at half scale). Illustrations/key art 1920×1080, read at 640×360,
so keep shapes big and silhouettes clear.

**Palette** (sampled from the shipped art in `project/assets/`):

- Island ground and paths: `#c0e0a0` grass, `#f0e0b0` sand path, `#f0e0e0` blush stone,
  `#a0d0f0` water, `#f0b0c0` pink accents, `#f0f0f0` white temple stone
- Characters: skin `#f0c0b0` / `#e0b080` / `#906050` / `#705040`, hair browns `#806050` `#704030`,
  gold `#f0e0a0`
- Deco: lavender `#c0b0f0`, pink `#f0c0d0` `#f0c0e0`, leaf green `#a0e0a0`, wood `#c09060`
- Florida: sea blue `#80b0d0`, turquoise `#70d0c0`, lilac `#b090e0`, coral `#f08060`, foam `#e0f0f0`
- Props/ruins metal: steel blue `#b0d0e0`, sandstone `#d0c0a0`, moss `#c0c080`, ash `#b0a090`
- Clone lab: tank green `#c0f0c0` `#b0d0b0`, kawaii-gore pink `#e05070`, lab white `#f0f0f0`

Rules: pastel first; saturated colour only for accents (hearts, gore pink, Florida coral). The
island is slightly *less* saturated than Florida. The ruins drop to blue-green and add one neon accent.

**Motifs:** hearts, sparkles, flowers, the Seal of the O (approval mark), Queen Mother portrait
icons, the 28-day Calendar of Blood wheel, deck chairs facing a sunset, cruise life rings.

**Characters:** big heads, dot eyes, small smiles; on the island every NPC wears the *same* smile.
Castes read at a glance: Priestesses/Mothers in white and gold, Initiates in white robes,
Drones in identical work clothes, Barren in plain grey-brown. Real celebrities appear under their
real names in game text; image generators may refuse named people, so prompts describe roles instead.

**Typography (in-engine):** one rounded, bubbly pixel font for titles; a small clean pixel font for
UI and dialogue (8–10 px at 640×360). Light text gets a white outline; dark text sits on pastel
panels with rounded corners. Generated images carry no text unless the prompt asks for the logo.

**UI:** rounded pastel panels (`#f0e0e0` fill, `#906050` border), soft drop shadow, heart/sparkle
icons, buttons that squash on press.

**Style preamble for image/video prompts:**

> Kawaii pixel-art game art, top-down three-quarter view, clean outlines, soft shading, pastel
> palette (mint grass, blush stone, sky-blue water, pink and lavender accents), big readable shapes
> for a 640×360 game, cute characters with big heads and dot eyes, hearts and sparkles as motifs.
> Cute on the surface with something faintly wrong underneath. No photorealism, no 3D, no text.

## Audio

**Music:** instrumental only, no vocals, seamless loops of 2:00–3:00 (stingers 3–30 s, not looped).
Mix to sit under dialogue: target about −16 LUFS integrated for music, −14 for stingers; no hard
transients in the first or last 50 ms so loops join cleanly.

| World | Tempo | Instruments | Harmony |
|---|---|---|---|
| Island | 60–112 BPM | music box, celesta, marimba, ukulele, toy organ, wordless choir | major keys and dorian; a quiet drone or a phrase that always resolves the same polite way |
| Florida | 76–108 BPM | steel drum, ukulele, acoustic guitar, flute, harp, banjo/fiddle (stable) | bright major, nothing unresolved |
| Cruise | 98–160 BPM | bossa guitar, vibraphone, horn section, four-on-the-floor house, comedy-club jazz, panic synths | showbiz major/minor by venue |
| Ruins / bunker | 72–100 BPM | warped lounge piano, analog synth, theremin, music box, bubbling-tank foley | minor keys, tape warble, unresolved endings |

**Sound effects:** short, soft-attack, cartoon (boing, squish, chime). Kawaii gore uses wet splats
and a cute burp, never realistic screams. Effects are generated procedurally in `tools/` or rendered
to the same character; nothing sampled from other games.

**Voices:** spoken lines use cloned voices of the real people (XTTS, `voices.json`), and celebrity
lines come only from their sourced quotes in `project/data/quotes/`. Non-celebrity characters use
their assigned clone voice or the platform's text-to-speech. Never Animalese or beeps.

**Style preamble for Lyria prompts:**

> Instrumental video-game music for a kawaii pixel-art game, no vocals, seamless loop, soft attack,
> mixed quietly to sit under dialogue. Cute and melodic on the surface with a subtle sense that
> something is slightly wrong.
