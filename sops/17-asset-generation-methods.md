# SOP-17: Asset generation methods: verify before batches, approve iteratively, automate

Status: draft
Owner: Brett Whitty
Applies to: any project that ships generated assets (images, sprites, backdrops, UI art, video, music, sound, voice)
Last reviewed: 2026-11-04
Related SOPs: SOP-03 (03-asset-style-bible-and-prompts.md: the style bible and prompt files a method's skill is built from); SOP-04 (04-generative-render-pipeline.md: one way to run an approved method at scale); SOP-05 (05-voice-cloning-pipeline.md: voice methods, which also need the author's approved source plan per voice); SOP-13 (13-evaluating-external-tools-and-methods.md: how a new tool or service enters as a candidate method)

## 1. Purpose

One procedure for every way of producing an asset, so that no batch is generated with a method nobody has shown to be sound. A batch from an unverified method wastes money and time, and what it produces can publicly embarrass the project and the people and agents who made it. The author's direction: assets are generated to the project's own specification, by methods that are evaluated and approved step by step, and those methods move toward scripted, reliable, automated generation.

## 2. When to use / when not to

Use when:
- choosing or changing how any kind of asset is produced (a new generator, model, skill, prompt form, post-processing step or landing tool);
- before generating more than one asset with a method;
- when a method's results drift (a model update, a quota change, a new failure pattern).

Do not use when:
- rendering one asset with a method that is already approved for its asset type; run the approved script (section 5, step 8) instead;
- evaluating whether to adopt an outside tool at all; that is SOP-13, which hands its verdict to step 1 here.

## 3. Inputs and prerequisites

- `{spec}`: the project's visual and audio specification for the asset type (style bible, palette, format, size, frame layout), from SOP-03.
- `{author_notes}`: the author's notes on the subject (characters, places, lore) and any notes he has been asked to add. A method is never given a generic description in their place.
- `{skill}`: the generator skill for this asset type (a style skill or prompt template the generator loads), versioned with the project.
- `{gate}`: the automated checks an asset must pass (asset conformance, import, size, the in-game check, the test suite).
- `{renderers}`: the generators available, with their terms read per SOP-13.
- `{feedback_cli}`: a command-line route to the generator's own critique of a result (for example the generator's CLI agent).
- For voices: the author's approved source plan per voice (SOP-05).

## 4. Roles and tools

| Role | Does | Does not |
|---|---|---|
| Author | Sets the spec and notes; approves each method for each asset type; reviews subject descriptions and voice sources before generation; judges usability | Run batches |
| Method owner (an agent) | Writes and refines the skill, runs trials, collects evidence, writes the script | Start a batch before approval; cut, redraw or patch outputs by hand to make them pass |
| Generator | Renders from the skill and prompt; critiques a result on request through `{feedback_cli}` | Decide what ships |
| Pipeline script | Renders, lands, gates and records each asset in place | Change the spec or the skill |

## 5. Procedure

1. **Name the method.** Asset type, renderer, skill, prompt form, post-processing and landing tool, each with its version. A method is one combination; changing any part makes a new method.
2. **Write the skill for the asset type.** Elaborate and specific: the full `{spec}` and the subject from `{author_notes}`, in the project's own terms. Generic defaults are a defect. Ask the author for notes wherever the subject is thin.
3. **Author review of the subject.** The author reads the subject descriptions (and, for voices, the source plan) before anything is generated.
4. **Trial.** Render a small, representative set (at least one of each variant the type has) by script.
5. **Test the result.** Run `{gate}` and the in-game check. Ask the generator for its critique through `{feedback_cli}`. Record what passed, what failed and why.
6. **Refine and repeat.** Change the skill or prompt form, not the output. Repeat steps 4 to 6 until the trial passes without hand edits.
7. **Approval.** Present the trial evidence to the author (renders, gate results, failure counts, cost, time). The method is approved for that asset type only when he says so. Record the approval with its date.
8. **Script it.** The approved method becomes one scripted command per asset family that renders, lands, gates and records every asset of that type in place, and re-running it improves them in place.
9. **Batch.** Only now run the batch, through the script. Any unscripted model step (an agent choosing, editing or cutting by hand) is an exception: keep it to a minimum and record it beside the asset.
10. **Watch for drift.** A rising failure rate, a model change or an author complaint sends the method back to step 4.

## 6. Acceptance checks

- Every batch traces to an approved method with a recorded approval date.
- No shipped asset is code-drawn as a long-term stand-in, and none is cut and pasted from a render made to a different specification.
- Every asset of the type passes `{gate}` and looks right in the game; the author accepts the trial.
- The script reproduces an asset from its prompt file and notes with no hand steps.
- Each subject description is specific to the project's world and traceable to `{author_notes}`.

## 7. Failure modes and recovery

| Symptom | Cause | Recovery |
|---|---|---|
| A batch comes back unusable | No verified trial before the batch | Stop; discard or quarantine the batch; go back to step 4 |
| Outputs are in the wrong style (for example pixel art where the spec says paper doll) | The skill or prompt doesn't carry the spec | Refine the skill (step 6); do not cut or repaint outputs to fit |
| Descriptions read as generic | `{author_notes}` not used, or too thin | Use the notes; ask the author for more; re-review (step 3) |
| Agents patch outputs by hand | The method doesn't produce usable results | Treat it as a failed trial; refine the method |
| Results drift after a model update | Renderer changed | Re-run the trial (step 10) before any further batch |

## 8. Artifacts and templates

Method record (one per asset type and method):

```
method: {asset_type} / {renderer} / {skill}@{version} / {post} / {landing_tool}
trial: {date} {n} assets, {pass}/{n} passed {gate}; generator critique: {summary}
refinements: {what changed in the skill, per round}
approval: {author} {date} (or: not approved, {reason})
script: {command}
exceptions: {unscripted steps, per asset, with reason}
```

## 9. Reference implementation in persistint

- Author's rules, 2026-11-04: bd memories asset-generation-to-spec and voice-models-user-directed.
- Backlog of assets still code-drawn or cut from off-spec canon renders: persistint-game-vvg (336 files on 2026-11-04).
- Skills per asset type, refined with Gemini's feedback through agy: persistint-game-tth2. Scripted pipeline: persistint-game-fw3e. Character notes page (author notes and subject review): persistint-game-wmzc. Voice source plans: persistint-game-mt29. This SOP: persistint-game-5uhv.
- Renderers: Gemini (Antigravity, the web app through tools/web_render, the API) and Codex image_gen through the agent channel.

## 10. Lessons learned

- 2026-10-23 to 2026-11-04: many sprites were drawn by code as stand-ins and never replaced (ponies, Florida props, ruins rooms, UI), and several were cut from canon renders made to a different specification. The result looked unfinished in front of the author. This SOP exists so that does not happen again.
- 2026-11-02: a heuristic cutter scaled a hair layer over the whole doll on the live build (persistint-game-1rjz). Hand-made fixes to outputs hide method failures; fix the method.
