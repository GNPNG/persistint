# Asset prompts

One file per asset: front matter gives the id, the generator and the path the result goes to in the game.

- `audio/music/<level>/` — looping area music (Gemini Lyria, MP3)
- `audio/stingers/` — short non-looping cues
- `image/ui/<element>/` — title screens, chapter cards, loading screens, icon (Gemini image, PNG)
- `image/levels/<level>/` — key art per level
- `video/ui/`, `video/levels/<level>/` — cinematics and transitions (Gemini Veo)

Levels: island, temple, ruins, florida, cruise. Style for everything: kawaii pixel art over something unsettling;
Florida is innocent play, the cruise is judged performance, the island is ritualized control.

## Rendering workflow

Render each prompt in the Gemini web UI and save the result into the `assets/` folder next to the
prompt, named as its `drop:` line says (e.g. `audio/music/island/assets/island_village.mp3`;
video as `.mp4`). Then run `python3 tools/sync_rendered_assets.py` — it copies every rendered file
to its `game:` path inside `project/` (converting `.mp4` to Godot's `.ogv` with ffmpeg) and lists
which prompts still have nothing rendered.
