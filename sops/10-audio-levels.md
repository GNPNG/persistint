# SOP 10: audio levels

Sound must be professional (author, 2026-10-24): music under the voices, every voice line at one
level, nothing clipping, no lag. Levels are fixed in the samples and with plain bus volumes;
nothing is processed in real time in the game (no bus effects). The player sets Master, Music,
Voices and Effects on the settings screen.

## Targets (tools/audio_levels.py)

| What | Where | Target |
|---|---|---|
| Music game copies | project/audio/music | -18 LUFS integrated, true peak -1.5 dBTP |
| Voice clips | project/audio/voice | -16 LUFS integrated, true peak -1 dBTP |
| Vocalizations (groans, moan, growl, snore) | project/audio/sfx | -16 LUFS, -1.5 dBTP |
| Short effects (boing, burp, chomp, splat) | project/audio/sfx | mean level -14 dB, -1.5 dBTP |
| Buses | project/default_bus_layout.tres | all at 0 dB; Music, Voice, Clones (to Voice), SFX |

While a line plays, Music lowers the loop by voice_duck_db (data/music.json, -6 dB) with a volume
move, and brings it back after. A track starting from silence fades in over 0.3 s; a change of
track crossfades over crossfade_seconds.

## How levels get there

- Music: `tools/sync_rendered_assets.py` re-encodes each drop to its game copy at the target
  (`--force mp3` redoes them all). The drops under prompts/ keep the render's own level.
- Voice: `tools/generate_voice_clips.py` sets the level as it writes a clip;
  `tools/normalize_voice_clips.py` brings older clips (and baked copies under voice/) to it.
- Effects: `tools/gen_clone_sfx.py` sets each sound's level as it writes it.

## The gate

`python3 tools/audio_report.py --check` measures every file against its target and checks the
buses; readings are cached in docs/AUDIO_LEVELS.json by file hash, so a run after a small change
is quick. `tools/deploy_site.sh` runs it before every export and refuses to deploy on a failure;
`tests/test_audio_levels.gd` runs it in the suite.

**On each minor release** (x.y.0): run `python3 tools/audio_report.py --check --all` so every file
is measured fresh, read the table, and listen to one scene of each world in the web build with
voices over music before tagging.
