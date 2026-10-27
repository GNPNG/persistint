# Changelog

## v0.3.2 — 2026-10-27

Safer saves:

- Your save can no longer be lost to a crash or a closed tab mid-save: the game keeps the save
  before it as a backup, and if a save can't be read it picks up from the backup and tells you.
- A small "Saved" note shows when the game saves.
- Settings has Export save and Import save, so you can keep your progress as a file and bring it
  back, in another browser too.
- If your browser isn't keeping saves (a private window, or site storage turned off), the game
  says so and suggests exporting your save.

## v0.3.1 — 2026-10-27

Playtest hotfix for v0.3.0 (the opening sting held on its last frame until a key was pressed):

- The G|P|G sting ends on its own at the end of the clip, and a click or tap skips it, so phones
  and tablets reach the main menu.
- A Credits & Licences screen on the main menu: the people and tools behind the game, and every
  third-party licence in full.
- The main menu shows the copyright and the credit to the book.

## v0.3.0 — 2026-10-27

Everything since v0.2.1:

- Animated title screen: the island and the wreck under a sky that turns from day to golden hour
  to night, surf, drifting clouds, trees and palms in the breeze, seabirds, and charms falling
  like petals; the book trailer's red O paints itself in over the title theme. The PERSISTINT
  letters jiggle on the beat, and tapping them pops hearts.
- A Settings screen: Master, Music, Voices and Effects sliders, from the main menu, Escape in
  play, or a gear you can tap. Your levels are saved.
- Sound levels fixed: the music is quieter and no longer clips, every voice clip is at one
  loudness so the zombies are heard, music starts at once instead of fading in slowly, and the
  music dips while someone speaks.
- The rest of the music: the island village, the temple, the ruins, the clone lab and the ritual
  puzzle, plus the chapter-end and Name It stingers. Every world track now exists.
- 61 more voice clips: lines the voice list named but that had no recording now speak, and 17
  clips are re-recorded.
- Site: every page shares one header and footer, the Updates page renders cleanly, the title
  theme plays far more quietly, and the sound toggle is a speaker that pulses while music plays.
- Development: large art and audio files are in Git LFS; the web-render engine is its own
  repository, `gnomatix/web-render`, included as a submodule; review scenes open with
  `?scene=<name>` and stay out of the player build; each agent workspace keeps its notes in its
  own encrypted folder.

## v0.2.1 — 2026-10-24

Playtest hotfix for v0.2.0 (performance drop, sound going wrong, background music stopping):

- No real-time audio processing: the clone children's kid voices are baked into offline copies
  of their clips and groans (`tools/bake_clone_voices.py`); the audio buses carry no effects.
- No text-to-speech anywhere: every line is a pre-rendered clip, and a line with no clip yet shows
  its bubble silently.
- The crisp pixel look is back for every sprite (nearest filtering), the player included.
- A Fullscreen button on the main menu, and F toggles it.
- Site: fewer, faster, subtler hearts; they fade out at once when you scroll back up.

## v0.2.0 — 2026-10-24

The first playtest build. Everything since v0.1.0:

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
- Web build: `index.pck` down to 66 MB (112 kbps music, WebP-lossy big textures); builds deploy to
  the Cloudflare Pages project behind persistint.dataglut.org; the game data is served in parts.
- Renderer: Google's check page is its own "blocked" outcome; batch mode submits and harvests
  Gemini chats in one reused tab; prompt files can mark author-rendered assets.
- Private development material (design doc, style bible, canon sheets, lore notebook) moved under
  the encrypted `dev/` folder.

## v0.1.0 — 2026-10-23

- Versioning starts: one version number for the whole project, shown on the main menu.

