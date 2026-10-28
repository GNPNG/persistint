---
id: studio_intro
tool: Gemini Veo
rendered: author
drop: prompts/video/ui/assets/studio_intro.mp4
game: project/assets/video/studio_intro.ogv
audio: keep
---

# studio_intro

G|P|G studio sting, played when the game starts, before the main menu (6.7 s, 1280×720, 24 fps,
with its own sound). Two smiling ping-pong paddles, pink and mint, volley a smiling ball over a
sky-blue net on a cream background with sparkles; the letters pop together into the G|P|G
wordmark. Any click or key skips it.

## Prompt

Rendered by the author in Gemini (Veo) on 2026-10-24 and supplied as the finished file
(gemini_generated_video_c95987de.mp4); the prompt text was not recorded.

## Notes

`audio: keep`: tools/sync_rendered_assets.py keeps the sound (Vorbis) when it converts this .mp4
to .ogv (Theora), unlike the other videos, whose music comes from the audio prompts.

The render's glitch, cut out on 2026-10-28 (bd r1hp): the render plays the ball's flight off the
mint paddle twice, a second ball 8 frames behind the first, so frames 67-69 (0-based; 2.792-2.917 s)
show two balls and at frame 70 the ball jumps back. tools/splice_studio_intro.sh drops frames 62-69
(2.583-2.917 s; frame 61 cuts to frame 70, where the ball is one step on) and takes the same 0.333 s
out of the sound between the two hits without tripping the music's beat: one 0.5 s repeat of the
chord stabs (3.200-3.700 s, phase-matched, 20 ms crossfade) out, 0.167 s of silence into the rest
before the downbeat (at 3.978 s). 160 frames, 6.67 s; from the downbeat on, picture and sound are
the render's, 8 frames earlier. The author's render as supplied is kept unchanged as
assets/studio_intro.veo-original.mp4; assets/studio_intro.mp4 (the drop) is the cut at 1280×720,
assets/studio_intro.2x.mp4 the same cut at 2560×1440 (lanczos), the master for any later upscale.
The game's .ogv stays 1280×720 (Theora decodes in software, and the web build in wasm).
