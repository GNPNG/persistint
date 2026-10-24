---
id: name_it_sting
tool: Gemini Lyria
drop: prompts/audio/stingers/assets/name_it_sting.mp3
game: project/audio/stingers/name_it_sting.mp3
---

# name_it_sting

"Name It" moment stinger (3–5 s).

## Prompt

Instrumental video-game music for a kawaii game: one short, bright revelation phrase, a soft-attack acoustic celesta and glockenspiel duet, pure, innocent, heartwarming major-key joy. Two tender celesta notes open a quick rising celesta-and-glockenspiel arpeggio with delicate high overtones that resolves on a single clear, warm major chord and rings out naturally. Sparse and gentle, no drums, no bass, no pad, no vocals. Instrumental only.

Spec: instrumental only; a short non-looping cue of 4 seconds with a clean ending, soft attack in the first 50 ms; about -14 LUFS integrated; MP3 320 kbps.

## Notes

Instrumental only, 4 s, not looped, about −14 LUFS integrated. Export MP3 320 kbps. Paste only the first paragraph of ## Prompt into Gemini (prefixed with @persistint-asset-prompts); the Spec paragraph is for post-processing (tools/sync_rendered_assets.py).

Prompt v3 (2026-10-24). v1 and v2 carried a timestamped plan ending in "[00:04 - 00:30] Silence"; both renders stalled Gemini's Music tool (the chat never appeared in the sidebar, two credits spent, gen-gap persistint-game-al7). v3 drops the timestamps and the silence block and asks only for the phrase. The render will be a 30 s file, probably repeating or embellishing the phrase: in post keep the first statement (about 4 s, cut at the ring-out, 0.5 s fade if the tail is cut) and pad with silence to the cue length the game expects.
