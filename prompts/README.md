# Asset prompts

Start with `STYLE.md` (the master world and style bible: visual and audio style, preambles, world lines).

One file per asset: front matter gives the id, the generator and the path the result goes to in the game.
Every `## Prompt` is pre-compiled from `STYLE.md` (type preamble, world line, the asset's subject with its
world's must-appear items, then the negative prompt or the music loop and loudness spec), so it is pasted
into the generator as is. Run `python3 tools/check_prompts.py` after editing any prompt.

- `audio/music/<level>/` — looping area music (Gemini Lyria, MP3)
- `audio/stingers/` — short non-looping cues
- `image/ui/<element>/` — title screens, chapter cards, loading screens (one file per vignette), icon (1:1) (Gemini image, PNG)
- `image/levels/<level>/` — key art per level
- `video/ui/`, `video/levels/<level>/` — cinematics and transitions (Gemini Veo)

To render through the Gemini API instead of the web UI: `python3 tools/render_all_assets.py --status | --export-queue | --type image|video|music|all [--sync]` (needs GEMINI_API_KEY and `pip install google-genai`). `--export-queue` writes `prompts/QUEUE.md`, every missing prompt in one copy-paste file.

Levels: island, temple, ruins, florida, cruise. Style for everything: kawaii pixel art over something unsettling;
Florida is innocent play, the cruise is judged performance, the island is ritualized control.

## Rendering workflow

Render each prompt in the Gemini web UI and save the result into the `assets/` folder next to the
prompt, named as its `drop:` line says (e.g. `audio/music/island/assets/island_village.mp3`;
video as `.mp4`). Then run `python3 tools/sync_rendered_assets.py` — it copies every rendered file
to its `game:` path inside `project/` (converting `.mp4` to Godot's `.ogv` with ffmpeg) and lists
which prompts still have nothing rendered.
