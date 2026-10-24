# SOP-03: Style bible and self-contained generator prompts for game assets

Status: active
Owner: Brett Whitty
Applies to: game projects (any project that renders images, video or music with generative models)
Last reviewed: 2026-10-23
Related SOPs: SOP-02 (02-content-from-sources.md: names and vocabulary come from the same sources and rules); SOP-04 (04-generative-render-pipeline.md: rendering, tracking, retries, sync)

## 1. Purpose

Produce one written world-and-style bible and, from it, one prompt file per asset whose prompt text
can be pasted into a generator as is and still produce on-style, on-lore output. A mechanical checker,
run before every commit, keeps the prompts from drifting from the bible.

## 2. When to use / when not to

Use when:

- A project needs more than a handful of generated assets (key art, UI screens, loading vignettes,
  icons, cinematics, music loops, stingers) that must look and sound like one game.
- Assets will be rendered by a person in a web UI, by a script through an API, or both.
- More than one agent or model will write or revise prompts.

Do not use when:

- You need one throwaway image. Write the prompt by hand.
- The art is hand-drawn or commissioned; write an art brief instead (the bible sections in step 2
  still help).
- The project has no source of truth yet (no design doc, no shipped art, no lore). Write the design
  first; a bible built on nothing invents content.

## 3. Inputs and prerequisites

- Design document (binding plan), story or lore documents, game data files (cast list, areas,
  dialogue), and any shipped or canon art.
- A list of every asset the game needs: id, type (image, video, music, stinger), target path in the
  game project, aspect ratio or length.
- A list of real people, brands or trademarks that appear in game text (these never go into
  image/video prompts by name).
- The project's banned vocabulary (author's word rules) and lore corrections.
- Python 3 for the checker; ffmpeg if video must be transcoded for the engine.
- Generator access: web UI and/or API key for the image, video and music models.

## 4. Roles and tools

| Role | Does |
|---|---|
| Author (project owner) | Owns the sources, the vocabulary rules and lore; approves the bible; renders in the web UI or runs the render script; makes the final call on any contradiction. |
| Controller agent | Writes the bible from the sources, compiles the leaf prompt files, writes and runs the checker, integrates review output, commits only on a clean checker run. |
| Reviewer model (a second, different model) | Audits every leaf prompt against the bible and rewrites leaf files where it finds drift, missing must-appear items or contradictions. |
| Sub-agents (optional) | Draft bible sections or groups of prompt files in parallel; the controller merges and runs the checker. |

Tools (placeholders by role; suggested default paths in brackets; section 9 gives the persistint
bindings):

- `{bible}`: the world-and-style bible, one Markdown file usable with no other context
  [`dev/STYLE.md`].
- `{checker}`: a script that runs a mechanical pre-flight check of every leaf prompt file and exits
  non-zero on any failure [`tools/check_prompts.py`].
- `{sync}`: a script that copies rendered drops into the game project, transcodes video for the
  engine and lists prompts with nothing rendered [`tools/sync_rendered_assets.py`].
- `{render}` (optional): a script that reports render status, exports a copy-paste queue and renders
  through the generator APIs [`tools/render_all_assets.py`]; see SOP-04.
- Image, video and music generators (web UI or API).

## 5. Procedure

1. **Collect the sources.** List every file the bible may draw on: design doc, story docs, game
   data, dialogue, canon art, art-generator scripts.
   Check: each source has a path; nothing in the plan rests on memory or a chat message.

2. **Write the bible.** One Markdown file, usable with no other context. Sections, in order:
   1. Absolute rules: vocabulary table (never write / write instead), content rules (what may
      never be depicted, where exceptions live), real-person rule, no-text rule, no-invention rule.
   2. What the game is (premise, framings, structure of play).
   3. The world in brief (facts every asset rests on).
   4. Visual system: medium and the shipped look; resolution and grid; outline and shading rules
      (including per-world outline variants); master palette; motifs; animation feel; VFX; UI and
      typography; camera and framing; title and chapter cards; do/don't table; the negative prompt.
   5. One section per area or world: layout, look, light, mood, must-appear list, must-never list,
      audio identity.
   6. Characters: general rules, factions or groups as drawn in canon art, named cast (only names from
      the cast data), player character, how to depict real people.
   7. World-at-a-glance table.
   8. Audio system: music specs (length, loop, loudness, format), per-area identity, leitmotif,
      stingers, sound effects, voices.
   9. Asset pipeline (folders, drop and game paths, sync, checker).
   10. Preambles: one per asset type, their variants, and one world line per world (image/video
       line and music line).
   11. Template for a new prompt file, with a pre-save checklist.
   12. Sources table: fact area to source file.
   Check: every fact in the bible traces to a row in the sources table; anything designed but not
   built is marked "planned".

3. **Ground the palette and costumes in real files.** Sample palette hex values from shipped art
   and from the code that generates art; take costumes and props from the canon sheets.
   Check: every hex in the bible appears in a shipped asset or a generator script.

4. **Write the preambles and world lines.** One preamble per asset type (image, video, music) that
   defines the look in words the model understands (outline colour and weight, "never black",
   fills, shading, faces, edge quality, aspect, "no text"). One world line per world for
   image/video and one for music. Define each variant explicitly (aspect change for the icon,
   mood change for a world whose tone differs from the default, logo exception for the title screen, stinger instead
   of loop, per-world outline colour).
   Check: each variant names the exact sentence it replaces and the replacement, and each
   per-world variant has a marker phrase (e.g. its outline colour words) that the checker can test
   for in that world's leaves (step 7).

5. **Lay out the prompt tree.** One file per asset at `prompts/{audio|image|video}/{group}/{id}.md`,
   with an `assets/` folder holding `.gitkeep` beside each group of prompts.
   Check: file name equals the asset id; ids are unique across the tree.

6. **Compile every leaf prompt.** The `## Prompt` section is one paragraph in this order:
   (1) type preamble with its variants applied, (2) world line, (3) the asset's subject, framing,
   light and mood, including every must-appear item of its world, (4) the negative prompt
   (image/video) or the loop and loudness spec line (music). Colours in natural language, never
   hex. Real people by role, hair and costume, never by name. For a single-subject asset (a loading
   vignette) mark the world line as colour and style only, so the model does not paint the whole
   scene. Put the aspect ratio or length in `## Notes`.
   Check: nothing is added at render time; a person can paste the paragraph as is.

7. **Write the checker.** It reads every leaf file and fails on any rule a script can see
   (section 6 lists them), including, for each world with a preamble variant, the variant's marker
   phrase in every leaf of that world. Give it a `--root` (or `--prompts`) argument so it can run on
   a copy of the tree. Validate it with planted violations:
   1. Work on a scratch branch or worktree, or copy the whole prompt tree to a temp directory and
      point the checker at it with `--root`. Do not add copies of leaf files beside the originals:
      a renamed copy fails "id != file name" and an unrenamed one fails "duplicate id/drop/game",
      which adds failure lines that have nothing to do with the planted violation.
   2. Edit a few leaf files in place, one violation each (hex code, real name, banned term, missing
      negative prompt, missing world variant marker, CRLF, ALL-CAPS word).
   3. Run the checker; then discard the edits (`git checkout -- {prompt dir}` or delete the temp
      copy).
   Check: the checker exits 0 on the clean tree, and on the planted tree exits non-zero with
   exactly one failure line per planted violation.

8. **Cross-model review.** Give a second model the bible and the full prompt tree; ask it to audit
   every leaf against the bible (must-appear items, must-never items, lore, vocabulary, variants)
   and to rewrite the leaf files it finds wrong. Take its files as the base, then the controller
   fixes what remains (contradictions between files, missing assets), and runs the checker.
   Check: checker passes; every contradiction found is fixed in the bible or the leaf, not both
   ways.

9. **Commit on a clean check only.** Run `{checker}` by hand before every commit that touches
   `prompts/`; nothing runs it for you unless you wire it in. Where possible, add it to a pre-commit
   hook or CI job so a failing run blocks the commit.
   Check: the last checker run before the commit printed 0 failures; the commit message states what
   was compiled, fixed or added.

10. **Render.** In the web UI: paste `## Prompt`, set the aspect from `## Notes`, save the output
    to the file's `drop:` path. Or run `{render}` for the missing assets. SOP-04 covers rendering,
    tracking, retries and quota throttling in detail.
    Check: every rendered file sits at its `drop:` path with the right extension.

11. **Sync into the game.** Run `{sync}`; it copies each drop to its `game:` path, transcodes video
    for the engine, and lists prompts with nothing rendered (see also SOP-04).
    Check: the "not rendered yet" list matches what you expect; the engine imports the files.

12. **Change control.** To change style or lore, edit the bible first, then recompile every
    affected leaf, then run the checker.
    Check: no leaf contradicts the bible; `grep` for the old wording returns nothing.

## 6. Acceptance checks

- `python3 {checker}` prints `{N} prompt files checked, 0 failures` and exits 0. It verifies, per
  leaf file:
  - front matter has `id` (equals file name), `tool` (matches the type folder), `drop`
    (`<prompt dir>/assets/<id>.<ext>`), `game` (under the game project, matching extension);
    `id`, `drop` and `game` are unique;
  - `assets/.gitkeep` exists beside the file; `# <id>` heading, `## Prompt` and `## Notes` exist;
  - image/video: preamble marker phrases, the "never black" outline rule, the anti-stair-step
    clause, any project-specific style-clause markers from the preamble (e.g. a clause that
    puts faces on objects) and the negative prompt are present; "no text" is present (or, for the
    logo asset, the logo word and a phrase that excludes all other text, such as "no other text");
    no other ALL-CAPS lettering; no hex colour codes; no real-person name tokens (read from the cast
    data plus an extra list);
  - per-world variants: for each world with a preamble variant, the variant's marker phrase (e.g.
    its outline colour words) is present in every leaf of that world;
  - music: preamble marker, loop clause or stinger clause, loudness spec and spec line are present;
  - banned vocabulary and known lore errors are absent from every leaf;
  - no CRLF line endings.
- Planted-violation test (step 7): on a scratch branch, worktree or temp copy of the whole tree
  (`python3 {checker} --root {temp copy}`), edit a few leaf files in place with one violation each,
  run the checker, confirm exactly one failure line per violation, then discard the edits.
- `python3 {sync}` runs without error and the "not rendered yet" list is correct.
- Spot check: paste three prompts (one per type) into the generator; output matches the bible's
  do/don't table.

## 7. Failure modes and recovery

| Failure | Symptom | Recovery |
|---|---|---|
| Prompts depend on context the generator never sees ("use the house style") | Off-style output; different renderers get different looks | Pre-compile: every leaf carries preamble, world line, subject and negatives in full (step 6). |
| Hex codes in visual prompts | Models ignore or misread them, or draw them as text | Keep hex in the bible for code and humans; prompts use natural-language colours; checker fails on any hex in an image/video file. |
| Real names in image/video prompts | Generator refuses the request | Describe role, hair, costume and setting; checker fails on name tokens read from the cast data. |
| Hard pixel stair-steps, black outlines | Output does not match shipped, downscaled art | State the outline colour and "never black" in the preamble; add an anti-stair-step clause to both preamble and negative prompt; checker requires both. |
| Unwanted text or lettering in images | Captions, signs, fake logos | "no text" in the preamble and negatives; only the logo asset may request a word; checker flags ALL-CAPS words. |
| A world-specific variant not applied | One asset uses the default outline colour where its world has its own | Recompile that leaf with the variant; add the variant to the bible's preamble variants list so the next compile includes it. |
| Lore contradictions between bible and leaves (wrong costume, wrong colour of a key prop) | Reviewer or author finds a leaf that disagrees with canon | Fix the leaf to match the bible; add the wrong term to the checker's lore-ban list so it cannot return. |
| Single-subject asset renders a whole scene | Loading vignette filled with the world's full set | Mark the world line as colour and style only (example wording: "for colour and style only; the image shows just the single subject"). |
| Wrong aspect ratio | Icon rendered 16:9 | Variant in the preamble (1:1, size, minimum read size) and aspect in `## Notes` (if your render script reads `## Notes`, it picks the aspect up from there). |
| Checker passes broken files | False confidence | Validate the checker with planted violations whenever a rule is added. |
| Planted copies beside the originals | Extra "id != file name" or "duplicate id" failures swamp the planted ones | Plant in place on a scratch branch or worktree, or on a temp copy of the whole tree via `--root` (step 7). |
| Checker skipped before a commit | Broken leaf lands on the main branch | Run the checker by hand before each commit; better, call it from a pre-commit hook or CI. |
| Video format the engine cannot load | Import error | Save the generator's MP4 at the drop path; the sync tool transcodes to the engine's format. |

## 8. Artifacts and templates

Directory layout:

```
prompts/
  STYLE.md                    # the bible
  README.md                   # how to render and sync
  audio/music/{area}/{id}.md
  audio/music/{area}/assets/.gitkeep
  audio/stingers/{id}.md
  audio/stingers/assets/.gitkeep
  image/ui/{element}/{id}.md  # title, chapter_cards, loading, icon
  image/levels/{area}/{id}.md
  video/ui/{id}.md
  video/levels/{area}/{id}.md
  (an assets/ folder with .gitkeep beside every group)
tools/
  check_prompts.py
  sync_rendered_assets.py
  render_all_assets.py        # optional
```

Leaf prompt file:

```markdown
---
id: {asset_id}
tool: {Image model name | Video model name | Music model name}
drop: prompts/{type}/{group}/assets/{asset_id}.{png|mp4|mp3}
game: {game_project}/{...}/{asset_id}.{png|ogv|mp3}
---

# {asset_id}

{one line: what screen or area this asset is for}

## Prompt

{type preamble with variants applied} {world line} {subject, framing, palette in words, light,
mood, every must-appear item} {negative prompt (image/video) or spec line (music)}

## Notes

{aspect e.g. 16:9 1920x1080 or 1:1 1024x1024; or music length, loop, loudness, format}
```

Image preamble skeleton:

```
{style name} game art in a {look} style: even {outline colour} outlines (never black), flat
{fill style} fills with one soft highlight, {face rule}, {shape rule} for a {game resolution} game,
{view} for places, {motifs} as motifs, soft antialiased edges with no harsh pixel stair-steps.
{mood sentence}. {aspect}. No photorealism, no 3D, no text.
```

Music preamble and spec skeleton:

```
Instrumental video-game music for a {genre} game, no vocals, seamless loop of {min} to {max}
minutes, soft attack and no hard transient at the loop point, mixed quietly to sit under dialogue.
{mood sentence}.
...
Spec: instrumental only, no vocals or lyrics; seamless loop of {m:ss} to {m:ss} with no hard
transient in the first or last 50 ms; about {-16} LUFS integrated; {format}.
```

Stinger variant: replace the loop clause with "a short non-looping cue of {N} seconds with a clean
ending" and the spec line with "{N} seconds, not looped, clean ending, no hard transient in the first
50 ms; about {-14} LUFS integrated".

Negative prompt skeleton:

```
no text, no letters, no watermark, no logo, no photorealism, no 3D render, no black outlines,
no harsh pixel stair-stepping, no dithering, {project content bans}, no real-person likeness,
{lighting bans}, no muddy colours.
```

Checker rule table (adapt per project):

```python
TOOLS = {"audio": ("{music model}", "mp3"), "image": ("{image model}", "png"), "video": ("{video model}", "mp4")}
GAME_EXT = {"mp3": "mp3", "png": "png", "mp4": "{engine video ext}"}
VISUAL_MARKERS = {"preamble": "{unique preamble phrase}", "outline rule": "never black",
                  "anti-stair-step": "no harsh pixel stair-steps", "negative prompt": "{unique negative phrase}",
                  # plus any project-specific style clauses from the preamble
                  }
WORLD_VARIANTS = {"{world_group}": "{variant marker, e.g. outline colour words}"}  # per-world preamble variants
MUSIC_MARKERS = {"music preamble": "{unique music preamble phrase}", "loudness": "LUFS", "spec line": "Spec: instrumental only"}
BANNED = [(r"\b{banned_term}\b", "{what to write instead}"), ...]   # vocabulary and lore bans
HEX = re.compile(r"#[0-9a-fA-F]{3,8}\b")                              # image/video files only
REAL_IDS = [...]                                                      # cast ids whose names stay out of visual prompts
```

## 9. Reference implementation in persistint

- Bible: `dev/STYLE.md` (11,842 words by `wc -w` on 2026-10-23).
  Written in commit `47acfe7`, after an earlier style guide `998da48`; sources listed in its
  section 13 (`dev/DESIGN.md`, the novel's Story Structure, `art/canon/`, `project/data/`,
  `project/dialogue/`, art generators in `tools/`). Palette hexes sampled from `project/assets/`
  and the generator scripts (section 4.4); castes from the canon caste sheet (section 7.2).
  Preambles and world lines: section 11; template and checklist: section 12.
- Prompt tree: 45 leaf files under `prompts/audio/`, `prompts/image/`, `prompts/video/`, each with
  front matter `id`, `tool`, `drop`, `game` and sections `## Prompt`, `## Notes`. `prompts/README.md`
  describes rendering and sync. First version: commit `27945b0`.
- Pre-compilation, lore fixes, split loading screens (four files), 1:1 app icon
  (`prompts/image/ui/icon/app_icon.md`), temple, festival and Landing key art with matching video,
  and `tools/check_prompts.py`: commit `f1345e9`, merged in `93870ee`.
- Follow-up fix `6133116`: `prompts/image/ui/loading/loading_cub.md` changed from the default
  warm-brown outline to the clone-lab plum-brown outline per STYLE 4.3. The checker did not flag
  this (it checks "never black", not the per-world outline colour).
- Single-subject marker "World for colour and style only" is used in the four loading vignettes
  under `prompts/image/ui/loading/`.
- Checker: `tools/check_prompts.py`. It hard-codes `PROMPTS = ROOT / "prompts"` and takes no
  path argument, so it can only check the live tree. Visual markers include the faces-on-objects
  clause ("on buildings, trees, props, the ship and the bunker"); the logo rule accepts "no other
  text" or "other than". Run on 2026-10-23: `45 prompt files checked, 0 failures`. Real-name
  tokens come from `project/data/cast.json` (ids in `REAL_IDS`) plus `REAL_EXTRA`. Banned list
  covers the vocabulary rules from STYLE 1.1 and lore corrections (e.g. clone tank colour, Initiate
  costume, home shape).
- Sync: `tools/sync_rendered_assets.py` copies each `drop:` to its `game:` path; `.mp4` to `.ogv`
  via ffmpeg (`libtheora`, no audio); prints the "not rendered yet" list.
- Render script: `tools/render_all_assets.py` (`--status`, `--export-queue` writing
  `prompts/QUEUE.md`, `--type image|video|music|all`, `--only`, `--force`, `--sync`), commit
  `5c80263`. It reads the aspect ratio from `## Notes` (default 16:9). Needs `GEMINI_API_KEY` and
  `google-genai`.
- Generators: the `tool:` field carries the labels `Gemini image`, `Gemini Veo` and `Gemini Lyria`.
  The render script maps labels to kinds (its `KIND` map also accepts `Gemini Omni` for video) and
  renders with the default models `gemini-nano-banana-2.1` (image), `gemini-omni-1.1-flash` (video;
  its docstring says the Veo 3.1 Preview ids were shut down) and `lyria-3.5` (music), commit
  `5c80263`. "Veo" is the label, not the model used.
- Commit gate: nothing enforces it. No git hook (including `.beads/hooks`, the configured
  `core.hooksPath`) or CI job calls `tools/check_prompts.py`; only `prompts/README.md` and
  `dev/STYLE.md` tell you to run it. It is a manual step.
- Known doc error: the internal cross-reference in STYLE 1.2 points to "section 7.4" for depicting
  real people; the rule is in section 7.5.
- Not recorded in the repo: the planted-violation run (7 violations, all reported) and the Gemini
  review pass.
- Not built (planned): a `--root`/`--prompts` argument for the checker; a checker rule for per-world
  outline variants; a test file for the planted-violation check (it was a manual run on
  2026-10-23); a pre-commit hook or CI job that runs the checker.

## 10. Lessons learned

- Pre-compiled, self-contained prompts are what make web-UI rendering and API rendering give the
  same result; nothing is added at render time.
- Hex codes belong in the bible, not in visual prompts; the checker enforces it.
- Image and video generators refuse named likenesses of real people; name them in game text, but
  describe role and look in visual prompts.
- A checker is only trusted after it catches planted violations (7 planted, all reported; this
  run is not recorded in the repo, see section 9).
- A second model auditing the prompts against the bible found drift and contradictions; using its
  rewritten files as the base, then fixing the remaining contradictions and adding missing assets,
  with a clean checker run before the commit, closed the loop (the Gemini review pass is not
  recorded in the repo, see section 9).
- Per-world variants (the clone-lab outline colour) slip through when the checker tests only the
  shared rule; the loading_cub fix landed after the merge. Hence the per-world variant check in
  steps 4 and 7 and section 6.
- The app icon needs its own aspect variant (1:1) in both the prompt and `## Notes`; the default
  16:9 is wrong for it.
