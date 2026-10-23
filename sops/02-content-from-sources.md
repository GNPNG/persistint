# SOP-02: Writing game content from the author's source material

Status: draft
Owner: Brett Whitty
Applies to: game projects adapted from an author's own writing (novel, essays, notes); any project where content must stay in an author's voice
Last reviewed: 2026-10-23
Related SOPs: SOP-03 (03-asset-style-bible-and-prompts.md: vocabulary rules and asset prompts); SOP-06 (06-quote-sourcing-vv.md: adding and verifying a real person's quote, used in step 6)

## 1. Purpose

Fill a game's content slots (dialogue, barks, quiz questions, item text, ambient text, records) by adapting the author's own source material. Keep the author's plan, names, voice and vocabulary intact. Ship filled slots, not empty ones, and report back only the gaps the sources cannot cover.

## 2. When to use / when not to

Use when:
- A system or mini-game is built and its data file has empty or placeholder content.
- The design document specifies content (a scene, a show, a set of lines) and the author has written source material it should come from.
- Real people appear in the game and speak.

Do not use when:
- The task is changing the design itself. The design document is the author's; only the author changes it.
- The content is art or audio prompts (use SOP-03; this SOP still governs names and vocabulary those prompts use).
- The author has supplied finished content to paste in verbatim. Paste it; do not adapt it.

## 3. Inputs and prerequisites

- `{design_doc}`: the author's plan. Read in full before writing anything.
- `{source_index}`: a list of every source document the author has provided, with path, one-line scope, and a flag for sections marked "not for game content".
- The source documents themselves (story structure, manuscript, research papers, notes).
- `{cast_file}`: the single file holding every character name. Names are chosen by the author.
- `{quotes_dir}`: one sourced quote file per real person who speaks.
- `{style_rules}`: the project's vocabulary and content rules (words never used and their replacements).
- `{issue_tracker}`: the project's issue tracker, used to file gaps and follow-ups and to record persistent rules.
- The data file schema for each slot being filled (read the loader code and any `_note` in the data file).
- A headless test runner for the project.

If `{source_index}` does not exist, build it first (step 1). If `{cast_file}` lacks a name you need, stop and ask the author for it.

## 4. Roles and tools

- **Author:** owns `{design_doc}`, the sources, every character name, and every ruling on content. Answers the gap list. The only person who can approve changing a test that asserts content is empty.
- **Controller agent:** builds `{source_index}`, assigns slots to sub-agents, owns `{cast_file}` edits (sub-agents do not edit it), reviews every content commit against the acceptance checks, sends the gap list to the author.
- **Sub-agents:** fill one content slot each (one data file or one dialogue file), from the sources named in their brief. They report which source passage each piece adapts and which pieces were written in the sources' voice because the sources were silent.
- **Tools:** `Read` (sources, design, schemas), `Grep` / `grep` (vocabulary checks, name checks), `Write` / `Edit` (data files), `WebFetch` (only to verify a real person's quote against its cited page), `Bash` (test runner, checker scripts), `{issue_tracker}` (issues for gaps and follow-ups, persistent rules).

## 5. Procedure

1. **Index the sources.** List every source document in `{source_index}`: path, scope, and which sections the author flagged as not for game content.
   Check: every document the author named appears; flagged sections are marked.
2. **Read the design for the slot.** Read the `{design_doc}` passage that specifies the slot. Copy its exact wording into the sub-agent brief.
   Check: the brief quotes the design text; it adds no goals, win conditions, scores or endings the design does not state.
3. **Map the slot to sources.** For each slot, list the source passages that cover it. Mark what the design specifies that no source covers. If any slot is marked "sources silent", read `{style_rules}`: if they forbid content beyond the sources, get the author's ruling on writing in the sources' voice and record that ruling in `{style_rules}` before step 7.
   Check: every slot has either source passages or an explicit "sources silent" mark; `{style_rules}` and the author's ruling on writing in voice agree.
4. **Collect names.** List every character the slot needs. Take each name from `{cast_file}`. For a missing name, ask the author; do not invent one, and do not use a placeholder name in shipped data.
   Check: every name in the slot resolves to a key in `{cast_file}`.
5. **Write the sub-agent brief and assign the slot.** The controller writes one brief per slot: the quoted design text (step 2), the source passages and the flagged sections to avoid (steps 1 and 3), the names from `{cast_file}` (step 4), the quote files for any real person who speaks, the data file schema, and the acceptance checks in section 6. Assign the slot to one sub-agent.
   Check: the brief contains each of these items; each slot has exactly one assigned sub-agent.
6. **Collect real people's lines.** For each real person who speaks, take their spoken lines only from `{quotes_dir}/{person}.json`. If the file lacks a usable line, add and verify one under SOP-06 before using it.
   Check: every line spoken by a real person is a member of that person's quote file, character for character, and that entry has a `verified` date (SOP-06 step 9).
7. **Write the content.** Adapt the source passages into the slot's schema. Where the sources are silent on something the design specifies, and the author's ruling recorded in step 3 allows it, write it in the sources' voice (their register, their vocabulary, their humour) and record it as "written in voice" in the commit message or `_note`.
   Check: no slot ships empty; each piece traces to a source passage or is recorded as written in voice; nothing comes from a flagged section.
8. **Build what the author asks.** If the author has asked for specific content, build it as asked. Do not hold content back, soften it, or swap it for something milder on your own judgement. If you believe a request conflicts with a stated project rule, quote the rule to the author and ask; build the answer.
   Check: every item in the author's request is present in the data.
9. **Apply the vocabulary rules.** Run the vocabulary check over the changed files.
   Check: the check prints nothing.
10. **Run the tests.** Run the headless test suite, including any test that checks names and sourced quotes.
    Check: all pass. If a test asserts that a slot ships empty, do not delete the assertion; take it to the author with the filled content (step 13).
11. **Commit one slot per commit.** Message names the slot, what was filled, the sources used, and anything written in voice. The sub-agent reports the same source and "written in voice" lists to the controller.
    Check: `git show --stat` touches only that slot's files (plus `{cast_file}` if the controller added an author-supplied name).
12. **Review before merge.** The controller reviews the commit against section 6, runs the acceptance checks itself, and checks the sources and "written in voice" items the sub-agent reported against the source passages and the brief.
    Check: all section 6 checks pass when the controller runs them; every reported source passage exists and says what the content adapts; nothing written in voice lacks a "sources silent" mark from step 3. Only then merge.
13. **Send the gap list to the author.** List what the sources cannot fill: missing documents, specified content with no source and no clear voice to write in, names needed, and tests that assert emptiness.
    Check: each gap is filed in `{issue_tracker}` and the list is sent to the author.

## 6. Acceptance checks

Run from the repo root. Each must pass before the slot is done.

```bash
# 1. No empty content slots in the changed data files.
#    Walks nested values; skips keys starting with "_". Every empty list or
#    dict at any depth is reported. If the schema has a container that is
#    meant to be empty, confirm it with the author and note it in "_note".
python3 - {changed_data_files} <<'EOF'
import json, sys
def empties(v, path):
    if isinstance(v, dict):
        if not v: yield path
        for k, x in v.items():
            if not str(k).startswith("_"): yield from empties(x, f"{path}.{k}")
    elif isinstance(v, list):
        if not v: yield path
        for i, x in enumerate(v): yield from empties(x, f"{path}[{i}]")
for f in sys.argv[1:]:
    found = list(empties(json.load(open(f)), "$"))
    print(f, "EMPTY:" if found else "ok", *found)
EOF

# 2. Every real person's spoken line is a verified entry in their quote file.
#    lines_by_speaker() is written per project: it reads the slot's data files
#    and returns {person: [line text, ...]} using your slot schema.
python3 - {changed_data_files} <<'EOF'
import json, sys
def lines_by_speaker(files):
    raise NotImplementedError("write an extractor for your slot schema")
for person, lines in lines_by_speaker(sys.argv[1:]).items():
    quotes = {q["text"] for q in json.load(open(f"{quotes_dir}/{person}.json"))["quotes"] if q.get("verified")}
    missing = [l for l in lines if l not in quotes]
    print(person, "missing:", missing)   # must be [] for every speaker
EOF

# 3. Vocabulary check (patterns from {style_rules}); prints nothing when clean
grep -n -i -E '{banned_regex}' {changed_files}

# 4. Headless test suite
{test_command}
```

Also check by reading:
- Every speaker name resolves through `{cast_file}`; no name is spelled anywhere else.
- No goal, score, win or end condition appears that `{design_doc}` does not state.
- The commit message lists sources used and anything written in voice.

## 7. Failure modes and recovery

| Failure | How it shows | Recovery |
|---|---|---|
| Slot shipped empty "for the author to fill" | Data file has `[]`; `_note` says content is the author's | Fill it from sources (steps 3-7). Content the author has written is in the sources; adapting it is the job. |
| Invented win condition or goal | Content adds scoring, winners or a pass mark the design does not state | Remove it. Quote the design text; build only that. |
| Invented character names | Fantasy or placeholder names in data, dialogue or comments | Replace with role ids resolved through `{cast_file}`; ask the author for missing names; scrub old names from comments too. |
| Real person given made-up lines | A celebrity says something not in their quote file | Replace with a sourced line from `{quotes_dir}`; add a test that checks membership. |
| Requested content withheld on the agent's judgement | Author asked for X; data has a milder X or none | Build X as asked in the next commit. Record the rule "build what the author asks" as a persistent rule in `{issue_tracker}`. |
| Design reinterpreted | Design doc edited, or content follows a "better" reading of it | Revert design doc edits. Follow the text as written; ask the author where it is unclear. |
| Banned vocabulary in content | Vocabulary check prints matches | Replace with the listed alternative; rerun. |
| Content drawn from a flagged source section | A piece traces to a "not for game content" section | Remove it; refill from an unflagged passage or write in voice. |
| Test asserts the slot is empty | Filling the slot fails a test | Keep the test until the author agrees; then change the assertion to check the content (non-empty, sourced, names resolve). |

## 8. Artifacts and templates

**Source index** (`{source_index}`, kept outside the repo if the sources are private):

```markdown
# Sources for {project}

| Doc | Path | Scope | Not for game content |
|---|---|---|---|
| {Source doc} | {path} | {scope} | {flagged sections or "none"} |
| {Source doc} | {path} | {scope} | {flagged sections or "none"} |

## Slot map
| Slot (data file) | Design passage | Source passages | Written in voice |
|---|---|---|---|
| {data/slot.json} | {design_doc}:{line} | {doc §} | {what, or "none"} |
```

**Cast file** (`{cast_file}`), the only place names are spelled:

```json
{
  "_note": "Names chosen by the author ({date}). The game reads names only from here.",
  "{role_id}": { "name": "{Full Name}", "short": "{Short}" }
}
```

**Quote file** (`{quotes_dir}/{person}.json`; full schema in SOP-06 section 8; fields this SOP reads):

```json
{
  "_note": "{Person}'s own words only. See _verification for what was checked.",
  "quotes": [
    { "text": "{exact words}", "source": "{event or publication, date}", "url": "{page}", "aggregator": false, "verified": "{YYYY-MM-DD}" }
  ]
}
```

**Content data file** header:

```json
{
  "_note": "{Design passage, quoted}. Adapted from {sources}. Written in voice: {list or none}.",
  "{slot_key}": [ ... ]
}
```

**Gap list to the author**:

```markdown
## Content gaps: {slot or milestone}
- Missing source: {document the design names but the author has not provided}
- Sources silent, no clear voice: {design item} ({design_doc}:{line})
- Names needed: {role} for {slot}
- Tests asserting empty content: {test file}:{line}
```

## 9. Reference implementation in persistint

Repo: `{repo_root}` (state at `93870ee`). Godot project under `project/`.

- **Design doc:** `dev/DESIGN.md`. Names the source "Story Structure" for the celebrity cast (`dev/DESIGN.md:62`, `:126-127`). "Next Top Comic" (`dev/DESIGN.md:69-71`) states no win condition; the author's ruling is that it has none.
- **Sources:** source index: a scratchpad `sources.md` kept outside the repo (private sources); only Story Structure is cited in the repo (`dev/DESIGN.md:62`, `:127`).
- **Cast file:** `project/data/cast.json` (`_note`: names chosen by the author 2026-10-23, real-world names). Read only through `project/scripts/autoload/cast.gd`. Commits: `e3618b2` (Priestess Betty, Susan, Bruce), `6e66424` (Gloria), `b568de7` (role ids replace earlier invented names everywhere), `d05be5f` (old names dropped from comments), `36c969b` (critter names moved into cast.json). Test: `project/tests/verify_slice.gd:80-92` checks speaker names resolve from cast.json.
- **Quote files:** `project/data/quotes/` (atwood, chelsea, ellen, hillary, kate, oprah, silverman, steinem, tyra), file keys `_note`, `quotes`, `_verification` (e.g. `project/data/quotes/oprah.json`); per-quote `verified` dates are not there yet (planned under SOP-06), so the step 6 and acceptance check 2 `verified` test cannot pass on these files today. Commits: `0fe03b6`, `7b6f1ad`, `f8036a1`, `6538b1b` (verification method and status recorded). Test: `project/tests/verify_slice.gd:167-174` checks every Chelsea Clinton emcee line is in `quotes/chelsea.json`. `project/scripts/ruins/zombie_child.gd` also draws a real person's lines only from `data/quotes/<file>.json`.
- **Vocabulary rules:** `dev/STYLE.md` section 1.1 (area or world for game spaces; Florida is tropical; no references to other authors' dystopian regimes; rule or limit, not the safety-rail metaphor; names only from cast.json). Mechanical check: `BANNED` in `tools/check_prompts.py` (covers `prompts/` only). A content-file vocabulary check over `project/data/` and `project/dialogue/` is planned. The no-Animalese rule is `dev/STYLE.md:871` ("Never Animalese, babble or beeps."); replacing Animalese with impersonated narration is tracked in bd issue `persistint-game-zkk`. Leftover: a stale comment at `project/scripts/minigames/next_top_comic.gd:59` still says "her Animalese voice".
- **Writing in voice conflicts with the style rules:** `dev/STYLE.md` section 1.2 says "No content beyond the sources. Do not invent lore, characters, places or mechanics." The author's ruling (section 10) is to write in the sources' voice where the sources are silent. Section 1.2 needs updating with the author to record that ruling (step 3).
- **Issue tracker:** `bd` (beads); gaps filed with `bd create`, persistent rules recorded with `bd remember`.
- **Slots filled from sources:** The Interview, shipped empty in `d0e76e0`, filled in `b261d40` (seven stats, twelve questions built on Oprah quotes). Also `cef1341` (Landing), `dda4588` (Hottest of the HOT), `843f6f6` (Ruins of Utopia), `adddaf2` (Calendar of Blood, festival barks), `73c0517` (Florida Keys).
- **Repo disagrees with the brief:** Next Top Comic still ships empty. `project/data/next_top_comic.json` has `"setups": []` and its `_note` says the content is the author's and ships empty; `project/tests/verify_slice.gd:192` asserts it is empty. Filling it from sources, and changing that assertion with the author's agreement, is planned.
- **Author's request built as asked:** clone children in the bunker, `afe1771` (branch `sys-zombies`, merged `381f2c9`); data in `project/data/ruins.json` (`clone_children`).
- **Gaps listed to the author (per the brief):** the world-docs named in `dev/DESIGN.md` (Buildings of Little St. Piere Island, Plants on the Island, Inside the Temple, Crew of the Ship, Celebrities of The Cruise) are not in the repo; festival content beyond the barks and schedules in `project/data/calendar.json` and `project/data/barks.json` has no data file.
- **Tests:** `godot --headless --path project -s tests/verify_slice.gd`; per-system tests in `project/tests/test_*.gd`, same invocation.

## 10. Lessons learned

- The author's plan is not the agent's to reinterpret. Next Top Comic has no win (author's ruling); no win conditions, goals or scores beyond what the design states.
- Shipping empty content slots is wrong. The author's content is in the sources; adapt it, and where the sources are silent on something the design specifies, write it in the sources' voice.
- Names come from the author. Invented names had to be replaced across data, scripts and comments (`b568de7`, `d05be5f`). Ask for names; do not make them up.
- Real people say only what they have said. Every celebrity line comes from a sourced quote file.
- Build what the author asks. The agent withheld the requested clone children in the bunker on its own judgement; the author pointed out it is standard horror-game fare. The rule is now: build what the author asks.
- Report the gaps the sources cannot fill (missing world-docs, festival content) back to the author instead of filling them with guesses or leaving them silently empty.
