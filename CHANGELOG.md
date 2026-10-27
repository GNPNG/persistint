# Changelog

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

