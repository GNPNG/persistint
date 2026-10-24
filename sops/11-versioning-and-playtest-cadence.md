# SOP-11: Versioning and playtest cadence

Status: active
Owner: Brett Whitty
Applies to: any project that ships builds to a product owner who plays them and reports back
Last reviewed: 2026-10-24
Related SOPs: SOP-07 (07-playtest-bug-triage.md: each playtest report becomes a reproduced, tested fix); SOP-08 (08-session-hygiene-tracking.md: issues, labels, commits and the pushed close of every sprint session); SOP-09 (09-game-release-checklist.md: the public-release items that a version milestone must meet); SOP-12 (12-team-roles-and-dispatch.md: who stands the build up, who plays it, how notes come back)

## 1. Purpose

Run the work as sprints keyed to playtest builds. Every build the product owner plays is a minor version; every fix shipped while they are still playing it is a patch. One version file is the single source of truth, one tool stamps it everywhere, the changelog and the public updates page are regenerated from the same text, and every build carries an id that identifies its commit on screen.

## 2. When to use / when not to

Use when:
- A product owner plays each build and brings back bugs and requests between builds.
- Builds go live to a public URL as soon as they are stable, so players and the owner must be able to say which build they are on.
- More than one agent session contributes to a build, so "what is in this version" must come from the repository, not from memory.

Do not use when:
- The project has a single contributor and no one plays builds between commits; plain tags are enough.
- A build is a private experiment that will not be played; do not bump the version for it, deploy it under its build id only (section 8.4).

## 3. Inputs and prerequisites

- `{version_file}`: one file at the repository root holding `X.Y.Z` and nothing else.
- `{version_tool}` with `show`, `bump major|minor|patch`, `set X.Y.Z`, `stamp` and `check`: `bump` and `set` rewrite `{version_file}`, stamp every place the version appears (engine project file, README, site pages), and add a `## vX.Y.Z — {date}` heading to `{changelog}`; `check` exits non-zero when any stamped place disagrees with `{version_file}`.
- `{changelog}`: Markdown, one `## vX.Y.Z — {date}` section per version, newest first, bullets in plain words for players.
- `{roadmap}`: public Markdown, one `## vX.Y.0 — target {date}` section for the next version and a `## Later` section; unshipped features that would spoil a surprise carry a code name, and the key from code name to feature lives in a private file `{roadmap_key}`.
- `{updates_page_tool}`: renders the public updates page from `{changelog}` and `{roadmap}`; re-run after every bump or roadmap edit.
- `{deploy_cmd}`: refuses a dirty tree unless told otherwise, names the build after the short commit hash, writes that id into the build so the main menu or about screen shows `vX.Y.Z · {build_id}`, and keeps older builds reachable under their own ids.
- An issue tracker with labels `sprint-X.Y.0` (work planned for the next minor) and `playtest-X.Y.0` (reports from playing that minor).
- The target device the owner plays on, available for a check before any tag.
- The gate commands `{gate_commands}` (test suite, prompt and content checkers, link check, media-level check).

## 4. Roles and tools

| Role | Does | Does not |
|---|---|---|
| Author (product owner) | Plays each minor on the target device; sends bugs and requests as notes while the team works; decides what goes in the next sprint and when a milestone is reached. | Bump versions, write changelog entries, run gates. |
| Controller agent | Opens and closes sprints, labels issues, merges, runs gates, bumps, writes the changelog from the merged commits, regenerates the updates page, tags, deploys, tells the owner the build is up, files every report verbatim. | Tag a build that has not passed every gate; deploy from an uncommitted tree; invent changelog entries that are not in the merged commits. |
| Sub-agents | Fix one issue each in their own worktree (SOP-01); report in five lines. | Bump versions, tag, deploy. |

Tools, by exact name:
- `{version_tool} show|bump|set|stamp|check`
- `git tag -a vX.Y.Z -m "vX.Y.Z"`, `git describe --tags`, `git log --oneline vA.B.C..HEAD`
- `{updates_page_tool}`, `{deploy_cmd} [--site-only] [--dry-run] [--allow-dirty]`
- `bd create ... --labels sprint-X.Y.0`, `bd label add {id} playtest-X.Y.0`, `bd list --label {label}`, `bd comment {id} "{verbatim note}"`
- `{gate_commands}`

## 5. Procedure

1. **Open the sprint.** From the owner's notes on the last playtest, create one issue per bug and per request, label each `sprint-X.(Y+1).0`, group related ones under an epic. Put the owner's words in a comment on the issue, verbatim, before paraphrasing anything. Check: `bd list --label sprint-X.(Y+1).0` shows every item the owner raised, and each has a verbatim comment.
2. **Build on branches.** Each item is fixed or built on its own branch in its own worktree (SOP-01); the controller merges one at a time and runs the full suite after each merge. Check: `{main}` is green after every merge.
3. **Confirm on the target device.** Before any tag, play the current `{main}` build on the device the owner uses, or have the browser lead do it (SOP-12), through the whole slice that changed. A headless suite does not see frame drops, audio stutter or a crash on a single-threaded web build. Check: the device run is recorded on the sprint epic (device, build id, result).
4. **Run the gates.** `{gate_commands}`. Check: every gate exits 0, or each failure has its own issue and the owner has agreed to ship around it.
5. **Bump.** `{version_tool} bump minor` for a playtest build, `bump patch` for a hotfix. Check: `{version_tool} check` exits 0 and `git diff --stat` shows `{version_file}`, the stamped places and `{changelog}`.
6. **Write the changelog.** Under the new heading, list what changed since the previous tag in the players' words: `git log --oneline v{prev}..HEAD` is the source; one bullet per thing a player would notice. No internal metrics, no file sizes, no issue ids. Check: every bullet traces to a merged commit, and nothing in the merged commits that a player would notice is missing.
7. **Update the roadmap.** Move shipped items out of `{roadmap}`; keep the next target date; give any surprise feature a code name and record the key in `{roadmap_key}`. Check: no bullet under `## Later` or the next version names a feature the owner wants kept quiet.
8. **Regenerate the updates page.** `{updates_page_tool}`. Check: the page shows the new version at the top and the roadmap below; the link checker passes.
9. **Commit and tag.** One commit `vX.Y.Z: {one line on what the build is}` holding the bump, the changelog, the roadmap and the page; then `git tag -a vX.Y.Z -m "vX.Y.Z"`. Check: `git describe --tags` prints `vX.Y.Z`; `git status` is clean.
10. **Deploy.** `{deploy_cmd}`. The tree must be clean so the build id is the tagged commit. Check: the live main menu shows `vX.Y.Z · {build_id}` with `{build_id}` equal to `git rev-parse --short vX.Y.Z`.
11. **Push.** Code, tags (`git push --tags`) and the tracker (SOP-08 step 18 and 19). Check: `git status` is up to date and the tag is on the remote (`git ls-remote --tags {remote} vX.Y.Z`).
12. **Tell the owner the build is up.** One message: the version, the build id, the URL, what to look at first, and the status line "no blocker on your side" when that is true. Never a sentence that could be read as asking them to stop sending notes. Check: the message names the version and the build id.
13. **Receive the playtest.** Each report the owner sends, in any channel, becomes an issue labelled `playtest-X.Y.0` with the report verbatim in a comment (SOP-07 for the fix). Check: `bd list --label playtest-X.Y.0` matches the reports received.
14. **Hotfix while they play.** A report that stops play (crash, performance collapse, sound or control failure) is fixed on `{main}` at once, then steps 3 to 12 run again with `bump patch`. Check: the patch is live and announced the same day; the owner has the new build id.
15. **Close the sprint.** When the owner has played the minor and the next sprint's issues are filed, close the sprint epic with a reason naming the version and the build id. Check: no `sprint-X.Y.0` issue is open without a note saying where it moved.

## 6. Acceptance checks

The version is out when all of these hold:

```bash
{version_tool} check                       # exit 0: every stamped place agrees
git describe --tags --exact-match          # vX.Y.Z on HEAD (or on the tagged commit)
git ls-remote --tags {remote} vX.Y.Z       # the tag is on the remote
head -3 {changelog}                        # ## vX.Y.Z — {date} on top
{updates_page_tool} && git status --short  # empty: the committed page is current
bd list --label playtest-X.Y.0             # one issue per report received so far
```

- The live build's main menu shows `vX.Y.Z · {build_id}`, and `{build_id}` is the short hash of the tagged commit.
- The device check in step 3 is recorded on the sprint epic for this build id.
- The owner has received the "build is up" message with the version and build id.

## 7. Failure modes and recovery

| Failure | How it shows | Recovery |
|---|---|---|
| Stamped places disagree | `{version_tool} check` exits 1; the menu shows an old version | `{version_tool} stamp`, commit, redeploy. Prevention: step 5 always runs `check`. |
| Deploy from a dirty tree | Build id ends in `-dirty`; the live build does not match any commit | Commit (or discard), deploy again. Prevention: `{deploy_cmd}` refuses a dirty tree; `--allow-dirty` is for private experiments only. |
| Tag on the wrong commit | `git describe` names a commit that lacks the changelog or the bump | `git tag -d vX.Y.Z`, tag the right commit; if pushed, tell the owner before moving a public tag. Prevention: step 9 tags right after the version commit. |
| A failure the suite cannot see | The owner reports stutter, queued sound, a stopped music track, a crash; every test passed | Treat as a stop-play report (step 14); add the device check (step 3) to the gates for the class of change that caused it. |
| Changelog written from memory | A bullet describes something not merged, or a merged change is missing | Rewrite from `git log v{prev}..HEAD`; amend before push, new patch entry after. Prevention: step 6 uses the log as its only source. |
| Roadmap names a surprise | A public bullet spells out a feature the owner wanted kept quiet | Replace with a code name, record the key in `{roadmap_key}`, regenerate the page, redeploy the site (`--site-only`). Prevention: step 7 check. |
| Hotfix skipped the gates | A patch fixes one report and breaks another | Revert or fix forward on `{main}`, re-run every gate, `bump patch` again. Prevention: step 14 runs the whole of steps 3 to 12. |
| Reports left in chat | A bug the owner described twice has no issue | File it now with the verbatim text and the label. Prevention: step 13 at every message. |

## 8. Artifacts and templates

### 8.1 Changelog section

```markdown
## vX.Y.Z — {YYYY-MM-DD}

{One line on what this build is, for example "Playtest hotfix for vX.Y.0 (what the owner saw)".}

- {What a player notices, in plain words.}
- {Another.}
```

### 8.2 Roadmap

```markdown
# Roadmap

{How versions work, two lines.} Some items carry a code name until they ship.

## vX.(Y+1).0 — target {YYYY-MM-DD} (minor)

- {Feature in the players' words.}
- {Code name}.

## Later (dates to follow)

- {Feature or code name.}
```

`{roadmap_key}` (private): one line per code name, `{Code name}: {the feature, and why it is kept quiet}`.

### 8.3 Labels

```
sprint-X.Y.0      work planned for minor X.Y.0
playtest-X.Y.0    reports from the owner playing X.Y.0 (fixed in X.Y.1, X.Y.2, ... or carried to the next sprint)
```

### 8.4 Build id

`{build_id}` = `git rev-parse --short HEAD` at deploy time; `-dirty` appended when `--allow-dirty` was used. Written into the build at export (for example a small JSON file read at start-up), shown beside the version on the main menu, and used as the directory name the build is served from, so `/play/{build_id}/` keeps every build reachable and `/play/current/` points at the newest.

### 8.5 "Build is up" message

```
vX.Y.Z is up: {url} (build {build_id}).
Look at: {one to three things that changed}.
No blocker on your side.
```

### 8.6 Version commit subject

```
vX.Y.Z: {what the build is, one line}
```

## 9. Reference implementation in persistint

- `VERSION` at the repo root; `tools/version.py` (`show`, `bump`, `set`, `stamp`, `check`) stamps `project/project.godot` (`application/config/version`), the `**Status: vX.Y.Z` line in `README.md` and every `data-version` element under `site/public/*.html`, and adds the `CHANGELOG.md` heading. `tools/deploy_site.sh` calls `check`.
- `CHANGELOG.md`: `v0.2.0 — 2026-10-24` (the first playtest build) and `v0.2.1 — 2026-10-24` (its hotfix), both written in the players' words.
- Tags on `main`: `v0.1.0`, `v0.2.0` = `4bbc63d`, `v0.2.1` = `6f93ec8`; all three are on the Gitea remote and on the GitHub mirror.
- `docs/ROADMAP.md` (public): `v0.3.0 — target 2026-10-26`, then `Later` with the code names Butterscotch, Pedestal, Open Mic and Stable Voices; the key is `dev/ROADMAP-KEY.md` (git-crypt). The size line was removed in `4074ad2`.
- `tools/gen_updates_page.py` renders `site/public/updates.html` from `CHANGELOG.md` and `docs/ROADMAP.md` (`5df08ea`); every page footer links to it.
- Build id: `tools/deploy_site.sh` writes `project/build.json` (`{"build": "{short hash}"}`, gitignored) before the Godot export; the main menu shows `vX.Y.Z · {build id}` (`0838cca`, `3f72be4`). Builds are served from `site/public/play/<build-id>/` with `/play/current/*` redirected to the newest in `site/public/_redirects`.
- Labels in beads: `sprint-0.3.0` is in use (`persistint-game-3m3`, `040`, `du9` at the time of writing). `playtest-0.2.0` has no issues: the v0.2.0 reports were fixed straight into `v0.2.1` without the label. Step 13 was not applied to that playtest.
- Gates at `6f93ec8`: 22 Godot test files (`project/tests/verify_slice.gd` plus 21 `test_*.gd`, each run with `godot --headless --path project -s tests/{file}.gd`), `tools/check_prompts.py`, `tools/verify_quotes.py`, `tools/check_site_links.py` (run by `deploy_site.sh`). The audio-level gate (`tools/audio_report.py --check`, run from `deploy_site.sh`) exists on branch `sys-audio` and is not on `main` yet.
- Device check (step 3): not a gate yet. v0.2.0 was tagged and deployed on the suite alone; the owner found the audio and performance failures on the iPad.
- Planned: `playtest-X.Y.0` labelling at intake; the device check recorded on the sprint epic; a one-command sprint close.

## 10. Lessons learned

- v0.2.0 (`4bbc63d`, 15:03) needed v0.2.1 (`6f93ec8`, 15:36) the same afternoon. Both causes were invisible to the headless suite: real-time audio effects on the single-threaded web build, and a texture import mode set by a tool (`5fdd57d`) without checking the engine's documented modes (fixed in `765e579`). A device check before the tag (step 3) is the missing gate.
- Writing the changelog from the merged commits, in the players' words, took minutes once `tools/version.py bump` had made the heading; the page followed from one command. The cadence is cheap when the tools exist.
- The owner's notes arrived while the team worked, by design (SOP-12). A status line that could be read as "stop sending notes" was rejected by the owner; the agreed wording is "no blocker on your side".
- The public roadmap was about to spoil a surprise feature by naming it; code names with a private key solved it without hiding the roadmap.
