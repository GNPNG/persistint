# Changelog

All notable changes, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/). `tools/version.py bump` turns the Unreleased section
into the new version's heading; the Updates page on the site shows the released versions.

## Unreleased

### Added

- Map: the map sticker or M opens a little overhead map of the area you are in, with a heart for
  every way out and its name; tap a heart to walk there.
- Zoom: two paper-cutout figures beside the magnifier show the zoom, the big one for the normal
  view and the small one for one level out; tap one to go to it.

### Fixed

- Text in the world (door names, speech bubbles, the little words that float up in Florida) is
  drawn at the screen's full resolution, and in the ruins above the gloom, so light letters no
  longer come out grey. The floating words stay solid until they fade at the end, and a speech
  bubble always shows its last line.

## v0.3.8 — 2026-10-27

The paper look, and Florida:

### Added

- Paper look: the people, the player, the trees, flowers and props on the island, and the props in
  Florida and the ruins now have a cut-paper border and a soft shadow.
- Florida garden: on your first visit the Father explains the garden and the craft bench.
- Florida beach: two vacationing clinical psychologists lounge under the beach umbrella, with an
  optional chat.
- Citations: Benenson (2013) and Stockley & Campbell (2013).

### Changed

- Development: the voice review scene is a character picker; Node versions of the asset tools.

## v0.3.7 — 2026-10-27

Sound on the web title, and the clone hall:

### Added

- On the web, the game opens on a "tap to start" card, so the studio sting and the title theme play
  with their sound (on an iPad the title music never started before).
- Citations: Disneynature's Monkey Kingdom (2015), a main source; the book trailer opens with it.

### Changed

- The red brush-stroke O on the title screen is a large, faint background layer.
- Development: a review scene for the island conquest (not in the player build).

### Fixed

- In the clone hall every clone and cub speaks from its own place, so their noises overlap instead
  of cutting each other off.

## v0.3.6 — 2026-10-27

Zoom and help:

### Added

- Zoom: - (or the mouse wheel, a pinch, a pad shoulder or the magnifier sticker) zooms out one
  level to see what is around, + zooms back in.
- Help: the ? sticker or F1 shows how to play with keys, touch and a pad, with your own keys.

### Changed

- The settings gear and the stickers are drawn as art from a generator, like the rest of the game.

## v0.3.5 — 2026-10-27

Gamepad play:

### Added

- Gamepad play: the left stick or d-pad walks, A talks and uses, Y opens the wardrobe, X the
  journal, B gets off the pony, Start pauses, and every menu works with the d-pad and A.

## v0.3.4 — 2026-10-27

Keyboard-only and touch play, text size and key remapping:

### Added

- E talks to whoever is next to you (or uses the mirror, a door or a pickup), so the game plays
  from the keyboard alone.
- A clothes-hanger sticker and a book sticker under the settings gear open the wardrobe and the
  journal with a tap or a click.
- Text size in Settings: Normal, Large or Larger, for every menu, bubble and label.
- Controls in Settings: give any action a different key (Reset puts them back), and a Fullscreen
  toggle.

## v0.3.3 — 2026-10-27

A pause menu, and fixes:

### Added

- A pause menu: Escape or the gear pauses the game, with Resume and Quit to Menu next to the
  volume sliders.
- Quit on the main menu of desktop builds.

### Fixed

- The Fullscreen button is back on the main menu.
- Lines a character speaks inside a conversation follow the Voices slider.
- The keys can no longer stop moving the player after a conversation is cut short.

### Changed

- Every control is a named input action, ready for remapping and gamepads.

## v0.3.2 — 2026-10-27

Safer saves:

### Added

- A small "Saved" note shows when the game saves.
- Settings has Export save and Import save, so you can keep your progress as a file and bring it
  back, in another browser too.
- If your browser isn't keeping saves (a private window, or site storage turned off), the game
  says so and suggests exporting your save.

### Fixed

- Your save can no longer be lost to a crash or a closed tab mid-save: the game keeps the save
  before it as a backup, and if a save can't be read it picks up from the backup and tells you.

## v0.3.1 — 2026-10-27

Playtest hotfix for v0.3.0 (the opening sting held on its last frame until a key was pressed):

### Added

- A Credits & Licences screen on the main menu: the people and tools behind the game, and every
  third-party licence in full.
- The main menu shows the copyright and the credit to the book.

### Fixed

- The G|P|G sting ends on its own at the end of the clip, and a click or tap skips it, so phones
  and tablets reach the main menu.

## v0.3.0 — 2026-10-27

Everything since v0.2.1:

### Added

- Animated title screen: the island and the wreck under a sky that turns from day to golden hour
  to night, surf, drifting clouds, trees and palms in the breeze, seabirds, and charms falling
  like petals; the book trailer's red O paints itself in over the title theme. The PERSISTINT
  letters jiggle on the beat, and tapping them pops hearts.
- A Settings screen: Master, Music, Voices and Effects sliders, from the main menu, Escape in
  play, or a gear you can tap. Your levels are saved.
- The rest of the music: the island village, the temple, the ruins, the clone lab and the ritual
  puzzle, plus the chapter-end and Name It stingers. Every world track now exists.
- 61 more voice clips: lines the voice list named but that had no recording now speak, and 17
  clips are re-recorded.

### Changed

- Site: every page shares one header and footer, the Updates page renders cleanly, the title
  theme plays far more quietly, and the sound toggle is a speaker that pulses while music plays.
- Development: large art and audio files are in Git LFS; the web-render engine is its own
  repository, `gnomatix/web-render`, included as a submodule; review scenes open with
  `?scene=<name>` and stay out of the player build; each agent workspace keeps its notes in its
  own encrypted folder.

### Fixed

- Sound levels fixed: the music is quieter and no longer clips, every voice clip is at one
  loudness so the zombies are heard, music starts at once instead of fading in slowly, and the
  music dips while someone speaks.

## v0.2.1 — 2026-10-24

Playtest hotfix for v0.2.0 (performance drop, sound going wrong, background music stopping):

### Added

- A Fullscreen button on the main menu, and F toggles it.

### Changed

- No text-to-speech anywhere: every line is a pre-rendered clip, and a line with no clip yet shows
  its bubble silently.
- Site: fewer, faster, subtler hearts; they fade out at once when you scroll back up.

### Fixed

- No real-time audio processing: the clone children's kid voices are baked into offline copies
  of their clips and groans (`tools/bake_clone_voices.py`); the audio buses carry no effects.
- The crisp pixel look is back for every sprite (nearest filtering), the player included.

## v0.2.0 — 2026-10-24

The first playtest build. Everything since v0.1.0:

### Added

- Every scene looks finished: character rigs with directional walk cycles for the player and the
  NPCs, canon props cut at sheet resolution, the Florida surf and aquarium, ruins wall signs and
  plaques, the cruise stage hosts and backdrops, a generated PERSISTINT wordmark, boot splash and
  app icon, smooth texture filtering.
- The game opens on the G|P|G studio sting, then the main menu, which shows the version and build id.
- Speech: Margaret Atwood and the clone originals (Epstein, Bill and Hillary Clinton, Bill Gates)
  speak their own verified lines in cloned voices; villager barks are spoken.
- Zombie clone children: groans in square brackets play as generated vocalizations instead of
  being read aloud; the clones speak through a kid-pitched bus; the Hillary clone has her "basket
  of deplorables" line for the other clones; clones floss and dab now and then, and a dancing
  clone gets pounced by the nearest cub.
- Music: twelve world tracks rendered (title theme, island, Florida, cruise) with crossfades.
- The promo site plays the title theme quietly on a toggle and rains hearts on clicks and scrolls.

### Changed

- Web build: `index.pck` down to 66 MB (112 kbps music, WebP-lossy big textures); builds deploy to
  the Cloudflare Pages project behind persistint.dataglut.org; the game data is served in parts.
- Renderer: Google's check page is its own "blocked" outcome; batch mode submits and harvests
  Gemini chats in one reused tab; prompt files can mark author-rendered assets.
- Private development material (design doc, style bible, canon sheets, lore notebook) moved under
  the encrypted `dev/` folder.

## v0.1.0 — 2026-10-23

### Added

- Versioning starts: one version number for the whole project, shown on the main menu.
