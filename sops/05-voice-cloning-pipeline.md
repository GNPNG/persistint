# SOP-05: Cloned character voices for spoken lines

Status: draft
Owner: Brett Whitty
Applies to: game projects (any project with scripted spoken lines and a runtime that can play audio files)
Last reviewed: 2026-10-23
Related SOPs: SOP-04 (04-generative-render-pipeline.md: background rendering, tracking and retries); SOP-06 (06-quote-sourcing-vv.md: sources and verifies the real-person quotes that clips speak)

## 1. Purpose

Give every scripted spoken line a pre-rendered voice clip in the speaking character's voice, cloned from a short reference recording or taken from a stock synthetic voice. Use platform text-to-speech for any line that has no clip, so no line is ever silent and no line uses placeholder babble.

## 2. When to use / when not to

Use when:
- The project has a finite, exportable set of spoken lines (dialogue files, barks, data-driven text).
- Characters are real public figures or stand-ins who need a recognisable voice, or fictional characters who need a consistent voice.
- Clips can be rendered offline and shipped as static audio.

Do not use when:
- Lines are generated at runtime (LLM chat, procedurally assembled sentences). Pre-rendered clips cannot match; use runtime TTS.
- No lawful reference audio exists for a real person, or the author has not accepted the cloning model's licence.
- The line attributed to a real person is invented. Real people speak only sourced quotes (see step 2 and SOP-06).
- The target is babble-style "talking noise" (Animalese, beeps). This SOP replaces that; it does not produce it.

## 3. Inputs and prerequisites

- Line sources: dialogue files, bark tables, and any data files with spoken text, plus the cast table (`{data_dir}/cast.json`) that resolves character ids to display names.
- For real people: a sourced-quotes file per person, produced by SOP-06.
- For each cloned speaker: a public recording with at least 30 s of that person speaking alone (interview, speech, talk), its URL and a start-end span.
- A licence decision: the author accepts the cloning model's licence before any rendering, and checks its terms for commercial use (for XTTS v2, the model card at huggingface.co/coqui/XTTS-v2).
- Tools on the render machine: `yt-dlp`, `ffmpeg`, Python 3.10+, a dedicated venv (`{venv}`) holding both the TTS stack and the verifier dependencies.
- Runtime: the engine's audio player, a platform TTS API for fallback, and the engine's asset importer if it needs one for audio files.

## 4. Roles and tools

| Role | Does |
|---|---|
| Author | Chooses which characters get cloned voices, approves real-person quotes, accepts the model licence, listens to flagged clips. |
| Controller agent | Owns the pipeline: runs the exporter, maintains `voices.json`, starts renders in the background, runs verification, decides what to regenerate, commits. |
| Sub-agents | Optional: source and check quotes per person (SOP-06); find and cut reference spans. Each returns file paths and URLs, not prose. |

Tools by exact name:
- `yt-dlp`: fetch reference audio from a public video.
- `ffmpeg`: cut, downmix and resample the reference span.
- Coqui XTTS v2 via the `coqui-tts` package (`TTS.api.TTS("tts_models/multilingual/multi-dataset/xtts_v2")`): render clips.
- `faster-whisper` (model `small.en`, CPU, int8): transcribe clips for the text check.
- `resemblyzer` (`VoiceEncoder`): speaker embeddings for the voice check.
- `librosa`: load and resample audio for both checks.
- Engine-side: the project's voice autoload/service, which plays clips and falls back to platform TTS; the engine's headless asset importer.

## 5. Procedure

1. **Wire the runtime first.** Implement `speak(text, pitch, speaker)` that computes `key = md5("{speaker}|{text}")`, plays `{clip_uri}/{key}.wav` if it exists, and otherwise calls platform TTS with one stable system voice per speaker. Hook the dialogue system so every displayed line calls `speak` automatically. Note exactly which speaker string the hook passes (usually the display name the dialogue system shows, not a cast id).
   Check: with no clips present, every dialogue line is spoken by system TTS; no babble or beep code path remains.

2. **Collect real-person lines.** Source and verify quotes with SOP-06. This SOP needs only its output: one `{data_dir}/quotes/{person}.json` per real speaker. Export and render only entries whose `verified` field holds a date (SOP-06 step 9); leave every other entry out of the manifest.
   Check: every real person who speaks has a quotes file; every manifest line for a real speaker matches an entry with `text`, `source`, `url` and a `verified` date.

3. **Export the line manifest.** Run the exporter over dialogue, barks, data files and quotes files. The exporter usually runs in a different language from the runtime, so it cannot call the runtime's functions; it must apply the same resolution rules as the runtime, reading the same cast table. Before computing the key:
   - Resolve every template interpolation (`{template_syntax}`, for example a cast-name lookup) from the cast table.
   - Normalise markup exactly as the dialogue system does before it hands text to `speak`: strip inline tags (BBCode, wait/pause tags, trailing tags), and either expand random alternatives into one line per variant or skip lines that contain them; drop condition prefixes.
   - Drop any line that still contains unresolved template or markup syntax.
   - De-duplicate by key.
   Check: `grep -c '{{' {manifest}` (or the project's template opener) returns 0; for one plain line and one line that had an interpolation or markup, the manifest key equals the key the runtime computes for that line (log `line_key(speaker, text)` at runtime and compare).

4. **Choose a voice per speaker.** The key uses the exact speaker string the runtime passes (step 1), normally the display name. `voices.json` may be keyed by cast id only if the generator maps display name to cast id through the cast table; speakers that are not in the cast table (literal labels such as a role title) are keyed as is. Give each speaker either `ref` (path to a reference wav) plus `source`, `span` and `from`, or `builtin` (a stock XTTS studio voice name) for fictional characters. Leave a speaker out to keep it on system TTS.
   Check: every speaker that should be voiced appears in `voices.json` under the key the generator will look up; the generator's "no voice yet (skipped)" line lists only speakers meant to stay on TTS.

5. **Cut reference recordings.** For each `ref` speaker, download audio with `yt-dlp`, cut the 30 s span where the person speaks alone (no music, no second voice, no applause) with `ffmpeg`, downmix to mono, resample to 22050 Hz. Store under a gitignored refs directory. Never commit the recordings. Because refs are not in git, every new render machine starts without them: regenerate each missing ref from its `source` and `span` in `voices.json`.
   Check: each ref is mono, 22050 Hz, about 30.0 s; `git check-ignore -v {refs_dir}/{speaker}.wav` names the ignore rule; every `ref` path in `voices.json` exists on disk (a generator that skips missing refs silently leaves that speaker on TTS).

6. **Set up the render environment.** Create a dedicated venv. Pin `torch`, `coqui-tts` and `transformers` together as a known-good triple (`{torch_ver}`, `{coqui_tts_ver}`, `{transformers_ver}`); the latest `coqui-tts` may need a newer `transformers` than your `torch` supports (see section 7). Install the verifier dependencies in the same venv. Test the GPU with a one-line render; if it fails, force CPU with `CUDA_VISIBLE_DEVICES=""`.
   Check: a single test clip renders and plays.

7. **Render clips.** Run the generator, per speaker or for all, in the background (CPU renders are slow). It skips clips that already exist unless forced.
   Check: one `.wav` per manifest line whose speaker has a voice; the generator log names each clip written.

8. **Import clips into the engine.** If the engine only loads imported assets (Godot needs a `.import` sidecar per `.wav` for `ResourceLoader.exists` and for export builds), run its headless import after rendering, e.g. `godot --headless --import --path {project}`.
   Check: every new `.wav` has its import sidecar; at runtime a new clip plays instead of TTS.

9. **Verify every clip.** Transcribe each clip with faster-whisper and compare normalised words to the intended text (difflib ratio); flag below 0.8. For `ref` speakers, compute cosine similarity of the clip's and the reference's speaker embeddings; flag below 0.75. Write results to JSON.
   Check: the verifier prints a per-speaker table and a total flagged count.

10. **Regenerate flagged clips.** Re-render each flagged key with `--key {key} --force` and re-verify. Recommended (not yet recorded practice): after two failed retries, edit the text only if it is not a sourced quote (e.g. spell out numbers), otherwise drop the clip and let the line fall back to TTS. Listen to anything still borderline.
    Check: flagged count is 0, or every remaining flag is recorded with a reason.

11. **Clean up and commit.** Delete clips (and their import sidecars) whose keys are no longer in the manifest (they came from stale text or unresolved templates). Commit the manifest, `voices.json`, quotes files, clips and their import sidecars. Do not commit reference recordings.
    Check: set of clip keys on disk equals set of manifest keys for voiced speakers; every committed `.wav` has a committed sidecar; `git status` shows no `{refs_dir}/*.wav`.

## 6. Acceptance checks

```bash
# Manifest has no unresolved templates
grep -c '{{' {clip_dir}/manifest.json            # expect 0

# Every voiced manifest line has a clip, every clip has an import sidecar, and no orphan clips exist
{venv}/bin/python -I - <<'EOF'
import json, pathlib
d = pathlib.Path("{clip_dir}")
cast = json.load(open("{data_dir}/cast.json"))
voices = json.load(open("{data_dir}/voices.json"))
name_to_id = {v["name"]: cid for cid, v in cast.items() if isinstance(v, dict) and "name" in v}
def voiced(speaker):
    return (voices.get(name_to_id.get(speaker, speaker)) or voices.get(speaker)) is not None
manifest = json.load(open(d / "manifest.json"))
keys = {l["key"] for l in manifest if voiced(l["speaker"])}
wavs = {p.stem for p in d.glob("*.wav")}
print("orphans:", sorted(wavs - {l["key"] for l in manifest}))   # expect []
print("missing:", len(keys - wavs))                               # expect 0
print("no sidecar:", sorted(w for w in wavs if not (d / f"{w}.wav.import").exists()))  # expect [] (engines that import)
EOF

# Every ref in voices.json exists on this machine
{venv}/bin/python -I -c 'import json,os; v=json.load(open("{data_dir}/voices.json")); print([x["ref"] for x in v.values() if isinstance(x,dict) and "ref" in x and not os.path.exists(x["ref"])])'   # expect []

# Text and voice verification
{venv}/bin/python -I tools/verify_voice_clips.py --json {scratch}/verify.json   # expect "0 flagged"

# Reference recordings not tracked
git ls-files '{refs_dir}/*.wav'                              # expect empty
```

Runtime check: play a scene containing a templated line, a line with markup and a voiced line; the clip plays (not TTS) for each manifest line, and an unvoiced speaker is heard through system TTS.

## 7. Failure modes and recovery

| Symptom | Cause | Recovery |
|---|---|---|
| Clip reads the literal template markup aloud and is never played at runtime | Exporter keyed lines before resolving dialogue interpolations, so text and key differ from what the runtime speaks | Resolve all interpolations from the cast table before keying; drop lines still containing template syntax; delete the orphan clip; re-export and re-render |
| `coqui-tts` import errors on a newer release | Latest `coqui-tts` requires a newer `transformers` than the installed `torch` supports | Pin `torch`, `coqui-tts` and `transformers` together as a known-good triple in a dedicated venv (persistint's triple is in section 10) |
| CUDA error "no kernel image is available for execution on the device" | The installed torch build has no kernels for an older GPU | Run on CPU: `CUDA_VISIBLE_DEVICES="" {venv}/bin/python -I tools/generate_voice_clips.py ...`; run in the background |
| Renders take a long time and block the session | CPU inference | Run in background, render per speaker, verify finished speakers while others render |
| A speaker listed in `voices.json` is still heard through TTS | Its `ref` wav is missing on this machine (refs are gitignored) and the generator skipped it, or `voices.json` is keyed differently from the speaker string in the manifest | Regenerate the ref from `source`/`span`; fix the key or the name-to-id mapping; re-render that speaker |
| Freshly rendered clips fall back to TTS at runtime | Engine has not imported them (no import sidecar) | Run the engine's headless import; commit the sidecars with the clips |
| Clip transcription drifts from the text (dropped or repeated words) | Model hallucination on long or unusual sentences | Regenerate the key with `--force`; if it repeats, split or simplify non-quote text |
| Clip sounds like the wrong person | Reference has music, applause or another voice | Re-cut a cleaner solo span; regenerate all clips for that speaker |
| Real person says something they never said | Line written in-house and assigned to a real speaker | Real people speak only entries from their sourced-quotes file (SOP-06) |

## 8. Artifacts and templates

Layout:

```
{project}/
  {clip_dir}/
    manifest.json            # generated by exporter
    {md5}.wav                # one per voiced line
    {md5}.wav.import         # engine import sidecar, where the engine needs one
  {data_dir}/
    cast.json                # id -> {name, short}
    voices.json              # speaker (display name, cast id, or literal label) -> voice
    quotes/{person}.json     # sourced quotes for real people (SOP-06)
{refs_dir}/                  # gitignored: *.wav
  README.md
  {speaker}.wav              # 30 s, mono, 22050 Hz
tools/
  export_voice_lines.py
  generate_voice_clips.py
  verify_voice_clips.py
```

`manifest.json`:

```json
[
  {"speaker": "{exact speaker string the runtime passes}", "text": "{resolved, normalised line}", "key": "{md5(speaker|text)}", "clip": "{clip_uri}/{key}.wav"}
]
```

`voices.json`:

```json
{
  "_note": "{what ref and builtin mean; keyed by cast id, mapped from display name through cast.json}",
  "{cast_id}": { "ref": "{refs_dir}/{cast_id}.wav", "source": "https://www.youtube.com/watch?v={id}", "span": "{mm:ss}-{mm:ss}", "from": "{event, year, outlet}" },
  "{fictional_id}": { "builtin": "{XTTS studio voice name}" },
  "{literal speaker label}": { "builtin": "{XTTS studio voice name}" }
}
```

`quotes/{person}.json` (schema owned by SOP-06; fields this SOP reads):

```json
{
  "_note": "{person}'s own words only. See _verification for what was checked.",
  "quotes": [
    {"text": "{exact words}", "source": "{outlet, date}", "url": "{url}", "aggregator": false, "verified": "{YYYY-MM-DD}"}
  ]
}
```

Reference cut:

```bash
yt-dlp -x --audio-format wav -o "{scratch}/{speaker}.%(ext)s" "https://www.youtube.com/watch?v={id}"
ffmpeg -ss {start} -to {end} -i "{scratch}/{speaker}.wav" -ac 1 -ar 22050 "{refs_dir}/{speaker}.wav"
```

`.gitignore`:

```
{refs_dir}/*.wav
```

Render environment:

```bash
python3 -m venv {venv}
{venv}/bin/pip install torch=={torch_ver} --index-url {torch_index_url}
{venv}/bin/pip install coqui-tts=={coqui_tts_ver} transformers=={transformers_ver}
{venv}/bin/pip install faster-whisper resemblyzer librosa
CUDA_VISIBLE_DEVICES="" {venv}/bin/python -I tools/generate_voice_clips.py --speaker "{speaker}"
{engine_import_cmd}          # e.g. godot --headless --import --path {project}
```

Runtime key (any engine; must match the exporter byte for byte):

```
key = md5_hex(speaker + "|" + text)
```

## 9. Reference implementation in persistint

Example stack: Godot 4 + Dialogue Manager. In persistint `{clip_dir}` = `project/audio/voice`, `{clip_uri}` = `res://audio/voice`, `{data_dir}` = `project/data`, `{refs_dir}` = `art/voice_refs`, `{template_syntax}` = `{{Cast.short("id")}}` / `{{Cast.full("id")}}`.

Main checkout (`main`, 93870ee):
- `project/scripts/autoload/voice.gd`: `Voice.speak(text, pitch, speaker)`, `line_key()` = `md5("speaker|text")`, plays `res://audio/voice/<key>.wav` if `ResourceLoader.exists` finds it, else `DisplayServer.tts_speak` with one OS voice per speaker; connects to `DialogueManager.got_dialogue` and passes `line.character` (the display name) as speaker. `audio/general/text_to_speech=true` in `project/project.godot`. Babble removed in 1416347; speech and exporter added in 44065ff.
- `tools/export_voice_lines.py`: builds `project/audio/voice/manifest.json` from `data/emcee.json`, `data/hottest_of_the_hot.json`, `data/landing.json` and `dialogue/*.dialogue`. It re-implements cast-name resolution in Python (its own regex and `name`/`short` lambdas over `cast.json`); it does not call the GDScript code.
- `tools/generate_voice_clips.py`: XTTS v2 renderer (d2a7bea), reads `project/data/voices.json` (85d0f3b), keyed by cast id. It maps display names to cast ids through `cast.json` names, and also accepts literal keys not in the cast table (e.g. `First Mate`). `voice_for` returns no voice when a `ref` file does not exist, so a missing ref silently leaves that speaker on TTS. It picks CUDA whenever torch reports it available, so CPU must be forced with `CUDA_VISIBLE_DEVICES=""`.
- `project/data/voices.json`: `ref` for chelsea, tyra, oprah, silverman, kate; `builtin` XTTS voices for initiate (Daisy Studious), priestess (Ana Florence), barren (Gracie Wise), drone (Andrew Chipper), First Mate (Damien Black). `art/voice_refs/kate.wav` does not exist in the main checkout or the voices worktree, so Kate is currently left on TTS.
- First pass, 57ef5b2: 28 clips, manifest of 28 lines (Gloria 13, Priestess Betty 10, Chelsea Clinton 2, Tyra Banks 2, First Mate 1). One of them, `00e2cd72...wav`, is the template bug: its text is `Ah. {{Cast.short("initiate")}}'s little offering. ...`.
- `art/voice_refs/`: `README.md` tracked, `*.wav` ignored by `.gitignore` line 14. Local refs are mono, 22050 Hz, 30.0 s.

Branch `sys-clone-voices` (worktree `../persistint-game-wt-voices`, f84a22a, not yet merged to `main`):
- Exporter resolves `Cast.full` and `Cast.short`, drops lines still containing `{{`, adds quote lines from `project/data/quotes/{epstein,bill_clinton,hillary,bill_gates}.json` under cast ids; deletes the stale `00e2cd72...` clip.
- `voices.json` adds epstein, bill_clinton, hillary_clinton, bill_gates with `ref`, YouTube `source`, `span` and `from`.
- Generator gains repeatable `--speaker` and `--key`.
- `tools/verify_voice_clips.py`: faster-whisper `small.en` on CPU, word-level difflib ratio, flag below 0.8; Resemblyzer cosine vs reference, flag below 0.75; per-speaker table; `--json OUT`.
- Manifest: 170 lines; 27 clips committed, each with its `.wav.import`. At the time of writing the worktree held 50 `.wav` files but only 27 `.import` sidecars: the newly rendered clips had not been imported by Godot.
- Planned: no tool runs the Godot headless import after rendering; the exporter does not strip Dialogue Manager markup beyond cast interpolations.

Where the brief and repo differ (the repo wins):
- The brief describes `voices.json` as speaker to reference wav plus YouTube id and time span. In the repo only the four branch entries carry `source`/`span`; the main-branch refs have none, and island characters use `builtin` studio voices, not cloned references.
- The brief lists Gloria, Priestess Betty and First Mate as first-pass voices. They were voiced with built-in XTTS studio voices, not clones.
- The venv pins and CPU workaround are not recorded in any repo file; the generator docstring still says `pip install coqui-tts (uses CUDA when available)`. Planned: record the pins and the `CUDA_VISIBLE_DEVICES=""` note in the generator docstring or a requirements file.
- The voice-similarity check is not optional in the repo: the verifier always runs it for `ref` speakers.
- Step 2's `verified` gate is not enforced: no quote file has per-quote `verified` fields yet (planned under SOP-06), and the exporter adds quote lines without checking verification.

## 10. Lessons learned

- Key clips on the exact text the runtime speaks. An unresolved `{{Cast.short("initiate")}}` produced a clip that read the template aloud and could never match at runtime.
- The latest `coqui-tts` (0.28) needed a newer `transformers` than `torch 2.4.1` allowed; `coqui-tts 0.24.3` with `transformers 4.46.3` on `torch 2.4.1` in a venv worked. This is the known-good triple for `{torch_ver}`, `{coqui_tts_ver}`, `{transformers_ver}`.
- The GTX 1650 Ti failed with "no kernel image"; CPU with `CUDA_VISIBLE_DEVICES=""` works but is slow, so render in the background.
- 30 s mono 22050 Hz solo-speech cuts from public interviews and speeches were enough references; keep them gitignored so no ripped audio is committed.
- Transcribe every clip and compare it to the intended text; regenerate anything below 0.8. Speaker-embedding similarity against the reference catches wrong-sounding clones.
- Real people speak only sourced quotes.
- First pass: 28 lines voiced (Chelsea, Tyra, Gloria, Priestess Betty, First Mate).
