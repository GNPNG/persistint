# Sources: project/audio/sfx

Where every sound in this folder comes from (release checklist LP-04, sops/09). All ten are
synthesized from scratch by `tools/gen_clone_sfx.py`: no recording of anyone and no generative
model. Each sound is built from oscillators, noise and filters in that script, and its level is
set as it is written (sops/10-audio-levels.md). Run `python3 -I tools/gen_clone_sfx.py` to write
them again (22.05 kHz, 16-bit mono).

| Sound | Built by | How |
|---|---|---|
| `boing.wav` | `boing()` | the polar bear cub's soft pounce |
| `chomp.wav` | `chomp()` | a squishy chomp and crunch |
| `splat.wav` | `splat()` | a wet splat |
| `burp.wav` | `burp()` | a cute burp |
| `snore.wav` | `snore()` | a little cub snore |
| `groan_1.wav` | `groan()` | a cartoon voice ("Uuunnngh"): a glottal pulse train with vibrato through two vowel formants, plus breath noise |
| `groan_2.wav` | `groan()` | the same, a second variant |
| `groan_3.wav` | `groan()` | the same, a third variant |
| `moan.wav` | `moan()` | the same cartoon voice, closed-mouth ("Mmmrrrh") |
| `growl.wav` | `growl()` | a small chest growl ("Grrrr"), fry and trill, soft-clipped to reach its level |

History: the script was added on 2026-10-23 (commit 26429d9). The vocalizations were added
2026-10-24 (16b73ee), and levelling 2026-10-24 (ebad484). The baked kid-voice copies under
`project/audio/voice/clones/` are made from these by `tools/bake_clone_voices.py`.
