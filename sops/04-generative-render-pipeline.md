# SOP-04: Rendering assets through generator web apps and APIs, with tracking, retries and quota throttling

Status: draft
Owner: Brett Whitty
Applies to: any project that renders images, video or music from a set of prompt files
Last reviewed: 2026-10-23
Related SOPs: SOP-03 (03-asset-style-bible-and-prompts.md: its compiled leaf prompts and pre-flight checker feed this one); SOP-05 (05-voice-cloning-pipeline.md: voice clips use the same background rendering, tracking and retry approach)

## 1. Purpose

Turn a directory of finished prompt files into rendered asset files, through a generator's API or, where the paid plan only works in the browser, by driving the generator's web app. Every attempt is tracked, failures are retried by error class, and daily quotas are respected without manual bookkeeping.

Runs are unattended by design: after the one-time sign-in of the automation profile, the pipeline renders, retries, throttles and records results with no repeated manual clicking. `--assist` exists only to recover from a state automation cannot clear (expired sign-in, captcha), never as the normal way to render.

## 2. When to use / when not to

Use when:
- There are more than a handful of assets to render and you need to know at any time what is done, missing, failed or waiting on quota.
- The generator has daily or per-minute limits, or a plan that is only usable through its web UI.
- Renders will span several sessions or days.

Do not use when:
- Prompts are not final. Run the prompt pre-flight checker first; rendering unchecked prompts burns quota.
- Only one or two assets are needed. Paste them by hand.
- The generator's terms forbid automated use of the web UI. Use the API path or the copy-paste queue only.

## 3. Inputs and prerequisites

- One prompt file per asset, each with front matter naming at least `id`, `tool` (generator), `drop` (where the rendered file is saved) and, if the asset is copied elsewhere afterwards, `target` (SOP-03's template names this field `game`); and a self-contained `## Prompt` section.
- A passing run of the prompt pre-flight checker.
- For the API path: an API key in the environment (`{API_KEY_ENV}`), the vendor SDK installed, and model ids verified against the vendor's official model docs on the day of the build (staleness rule: model and surface names go stale within weeks; never take them from memory or from an older script).
- For the browser path: a dedicated automation browser profile, signed in once by the author by hand. Never the author's everyday profile or its cookies.
- For tracking: a tracker spreadsheet with the three tabs in section 8, and a write endpoint (spreadsheet-bound script web app) implementing the operations in section 8.
- A sync step that copies drops into the project tree and converts formats where needed.

## 4. Roles and tools

- Author: writes and approves prompts; signs the automation profile into the generator once; answers `--assist` prompts (captchas, consent screens, ambiguous UI states); edits prompts flagged as refused; decides daily caps.
- Controller agent: builds and maintains the renderer, verifies model ids against official docs before each build, sets up the tracker tabs, runs the renderer, reads the attempt log, and reports status. Does not edit prompt content to get past a refusal without the author.
- Sub-agents: optional, for parallel work that does not touch the same generator account (for example writing the sync step or the tracker script while the controller drives renders). Never two agents driving the same account at once.
- Tools:
  - Renderer CLI with `--status`, `--export-queue`, `--type {image|video|music|all}`, `--only {ids}`, `--force`, `--sync`.
  - Vendor SDK (API path).
  - Puppeteer driving a dedicated Chrome profile (browser path), with selectors kept in `selectors.json`, not in code.
  - Google Sheets as tracker; a Google Apps Script web app bound to the sheet as the write path (no cloud project or service account needed); the Google Sheets connector for the agent to create and inspect tabs.
  - Sync script (drops to project tree, transcoding).

## 5. Procedure

1. Verify generator surfaces. Open the vendor's official model or product docs and record today's model ids, call shape and output format for each kind. Check: ids and the verification date are written into the renderer's defaults and its header comment.
2. Run the prompt pre-flight checker. Check: exit status 0.
3. Run `--status`. Check: the count of assets matches the number of leaf prompt files (excluding the style bible and README); every row shows DONE or MISSING; files the parser skipped are listed on stderr and are either fixed or deliberately excluded.
4. Export the copy-paste queue with `--export-queue`. Check: the queue file lists exactly the MISSING assets, each with its drop path. This file is the fallback when every automated path is blocked.
5. Set up the tracker (once per project). Create the Assets, Attempts and Quotas tabs with the headers in section 8; load one Assets row per leaf prompt file. Fill Quotas per kind (`daily_cap`, `min_gap_s`, `cooldown_s`) from the plan's published limits, or conservative values if none are published, and record the source and date of each value in a note on the Quotas tab. Implement the operations in section 8 (`state`, `claim`, `attempt`, `quota`, `reset_stale`) in the bound script, wrapping every write in `LockService` so concurrent requests do not interleave. Deploy it as a web app with "Execute as: me" and "Who has access: Anyone"; the shared secret is the access control. Redeploy a new version after every script edit (the `/exec` URL serves the last deployed version, not the saved code). Store the `/exec` URL and the secret in an env file read by the renderer, and add that file to `.gitignore`. The client must follow redirects: `/exec` answers a POST with a 302 to `script.googleusercontent.com`, which returns the response. Check: `git check-ignore {env_file}` prints the path; a test `claim` sets the Assets row to `rendering`; a test `attempt` appends one row to Attempts and increments the Assets row's `attempts`; a `state` call returns the Quotas rows and today's counts.
6. Prepare the browser path (if used). Add the profile directory and the debug-dump directory to `.gitignore` (dumps hold page HTML and screenshots of a signed-in session). Launch the automation profile, have the author sign in by hand, close it. Check: `git check-ignore {render_tool}/profile {render_tool}/debug` prints both paths; a headed launch of the profile lands on the generator signed in, with no prompt to log in.
7. Render one asset per kind with `--only {id}`. Check: the file exists at its drop path, is non-empty and opens; one Attempts row with outcome `done`; Assets row `status=done`, `file` set.
8. Run the batch per kind with `--type {kind}`. On start the renderer calls `reset_stale`. Before each attempt it: calls `state` to read Quotas and today's Attempts count for that kind; skips the kind if the cap is reached or the kind is in cooldown; waits at least the minimum gap since the last attempt of that kind; calls `claim` for the asset. After the attempt it calls `attempt`, and on a quota signal also `quota`. Check: no two attempts of one kind are closer than the min gap in the log; attempts per kind per day never exceed the cap.
9. Handle each failure by its class (section 7 table). Check: every non-`done` Attempts row has an outcome from the fixed list and, for browser runs, a debug dump directory.
10. Run the sync step (`--sync` or the sync script). Check: every DONE asset exists at its target path in the project tree, in the target format.
11. Re-run `--status` and refresh the queue. Check: MISSING count equals the Assets rows not in `done`.

## 6. Acceptance checks

- The renderer's status reports all N assets rendered.
- `{prompt_checker}` exits 0 on the final prompt set.
- Tracker: no Assets row in `rendering` (a stuck row means a crashed run); every `failed` row has an `error`; for every kind with Assets rows in `quota`, `Quotas.resume_at` is set and in the future, or those rows have been retried.
- Each target file exists and opens in the consuming application (game engine import, media player).
- The queue file is empty or lists only assets the author has chosen to render by hand.

## 7. Failure modes and recovery

| Outcome | Typical signal | Action | Auto-retry |
|---|---|---|---|
| `quota` | Usage-limit or "try again later" message in the UI; HTTP 429 or quota error from the API | Mark the asset `quota`; call the `quota` operation to set `Quotas.resume_at` for the kind (the resume time if shown, else now + `cooldown_s`); move on to other kinds | Yes, after reset or cooldown |
| `timeout` | No result within the per-kind time limit | Save debug dump, back off | Yes, exponential backoff, up to `{max_retries}` |
| `selector` | An expected element from `selectors.json` not found | Save debug dump (screenshot + DOM), back off; if it repeats across assets the UI changed: stop the kind and update `selectors.json` | Yes, up to `{max_retries}`, then stop |
| `refused` | Content-policy refusal or a blocked-output message | Mark `failed`, flag the prompt for the author to edit | No |
| `failed` | Any other exception | Record error text, keep going with the next asset | Suggested default: yes, up to `{max_retries}` (not part of the retry policy set by the author; confirm per project) |

Further failure modes:
- Model or product retired between sessions. Generator ids are shut down with little notice. Recovery: re-run step 1 before every build or batch; never trust ids carried over from earlier work.
- Paid plan not available through the API. A consumer subscription may cover the web app but not the REST API. Recovery: use the browser path for that plan, or the API with a separate key and billing; decide which before building.
- SDK not installed or key not set. The renderer must exit early with a clear message rather than fail per asset. Recovery: install the SDK, set the key, re-run.
- Session expired in the automation profile. Recovery: run in `--assist` mode; the author signs in again in the headed window; the run resumes.
- Crash mid-run leaves rows in `rendering`. Recovery: on start, call `reset_stale`, which resets any `rendering` row whose `last_tried` is older than the per-kind time limit to `todo` and logs it as `timeout`.
- Duplicate work from two runners. Recovery: one runner per generator account; the renderer takes the row with `claim` (sets `rendering` and `last_tried`) before starting, and `claim` refuses a row already in `rendering`.

## 8. Artifacts and templates

Prompt file front matter:

```text
---
id: {id}
tool: {generator name}
drop: {drop_path}
target: {project_dir}/{path}/{id}.{target_ext}
---

# {id}

{one-line description}

## Prompt

{self-contained prompt as compiled by the prompt-authoring SOP (SOP-03)}

## Notes

{aspect ratio, length, anything the renderer reads}
```

`{drop_path}` is any path the sync step can find; one folder per asset kind (for example `{prompts_dir}/{kind}/.../{id}.{ext}`) is a suggestion, not a requirement.

Tracker tabs (header rows):

```text
Assets:   id | kind | prompt | drop | status | attempts | last_tried | file | error
          status in {todo, rendering, done, failed, quota}
Attempts: id | attempt | started | ended | outcome | error | debug_dir
          outcome in {done, failed, quota, refused, timeout, selector}; one row per attempt
Quotas:   kind | daily_cap | min_gap_s | cooldown_s | resume_at
```

Throttle rule (pseudocode):

```text
today = count(Attempts where kind(id) == K and date(started) == today)
if today >= Quotas[K].daily_cap: skip K
if now < Quotas[K].resume_at:    skip K
wait until last_started(K) + Quotas[K].min_gap_s
```

Write path (Apps Script bound to the sheet, deployed as web app; every request carries the secret; every write runs inside `LockService.getScriptLock()`):

```text
POST {webapp_url}            # client follows the 302 to script.googleusercontent.com
{ "secret": "{shared_secret}", "op": "{op}", ... }

op "state"        {}
  -> { "quotas": [ {kind, daily_cap, min_gap_s, cooldown_s, resume_at} ],
       "today":  { "{kind}": { "attempts": n, "last_started": "..." } } }
op "claim"        { "id": "..." }
  -> sets Assets.status = rendering, last_tried = now; refuses if already rendering
op "attempt"      { "row": { "id": "...", "attempt": 1, "started": "...", "ended": "...",
                             "outcome": "done|failed|quota|refused|timeout|selector",
                             "error": "...", "debug_dir": "...", "file": "..." } }
  -> appends to Attempts, updates the matching Assets row (status, attempts, last_tried, file, error)
op "quota"        { "kind": "...", "resume_at": "..." }
  -> sets Quotas.resume_at for the kind
op "reset_stale"  { "older_than_s": {per_kind_time_limit} }
  -> Assets rows in rendering with last_tried older than the limit -> todo,
     one Attempts row with outcome timeout each; returns the ids reset
```

Git-ignore entries (verify with `git check-ignore`):

```text
{env_file}                   # web-app URL and shared secret
{render_tool}/profile/
{render_tool}/debug/
```

Browser path layout:

```text
{render_tool}/
  selectors.json          # per generator: prompt box, submit, result, download, usage-limit text
  profile/                # dedicated automation Chrome profile (git-ignored)
  debug/{date}/{id}-{n}/  # screenshot.png, page.html, console.log on any non-done outcome
```

Browser run flags: `--assist` (headed; pause for the author on login, captcha or unknown state), pacing from the Quotas tab.

## 9. Reference implementation in persistint

- `tools/render_all_assets.py` (added in commit 5c80263): `--status` (ends with `Progress: {done}/{total} assets rendered.`; skips `STYLE.md` and `README.md`, so it counts 45 assets from the 47 Markdown files under `prompts/`), `--export-queue` (default `prompts/QUEUE.md`), `--type image|video|music|all`, `--only`, `--force`, `--sync`, plus `--prompts-dir` and per-kind `--image-model`, `--video-model`, `--music-model`. Default models, recorded in the file header as checked against ai.google.dev on 2026-10-23: images `gemini-nano-banana-2.1` (Imagen 4 shut down), video `gemini-omni-1.1-flash` (Veo 3.1 Preview ids shut down 2026-10-22), music `lyria-3.5` (MP3). All three are called through `client.interactions.create` and return base64 inline data. Needs `GEMINI_API_KEY` and `google-genai`. Not yet run: `google-genai` is not installed in this environment (import fails), so no asset has been rendered through it.
- The repo's front-matter key for the copy target is `game:` (the generic `target:` in section 8). The prompt `tool:` values are `Gemini image`, `Gemini Veo` and `Gemini Lyria`; the renderer maps `Gemini Veo` and `Gemini Omni` both to the video kind.
- `tools/check_prompts.py` (commit f1345e9): pre-flight checker for the 47 prompt Markdown files under `prompts/` (count includes `STYLE.md` and `README.md`).
- `tools/sync_rendered_assets.py`: copies each `drop:` to its `game:` path under `project/`, converting `.mp4` to `.ogv` (Theora) with ffmpeg.
- Browser path (planned, in progress): Puppeteer pipeline on branch `sys-web-render`, worktree `../persistint-game-wt-webrender`. At the time of review the branch has no commits beyond main (93870ee); dedicated automation profile, `selectors.json`, debug dumps, `--assist` and pacing are design, not code.
- Google Sheet tracker with Assets, Attempts and Quotas tabs, Apps Script write path, throttle and per-class retry policy: planned (author, 2026-10-23). Tabs to be created by the controller agent through the Google Sheets connector.
- Extraction of the browser render pipeline into a standalone Gitea repository for reuse in other projects: planned (author's choice). Whether the tracker's Apps Script goes into that repository is not decided.

## 10. Lessons learned

- Generator model ids go stale within days: Veo 3.1 Preview ids were shut down on 2026-10-22, one day before the renderer was written, and Imagen 4 was already shut down. Verify against official docs before each build and write the check date into the code.
- A paid consumer plan (Google AI Ultra) is not usable through the REST API. That one fact forced a second render path through the web UI; find it out before writing the API path.
- Keep a no-automation fallback. The copy-paste queue (`--export-queue`) lets rendering proceed by hand when both the API and the browser path are blocked.
- An API renderer that has never run is unverified. `tools/render_all_assets.py` was committed without a single live call because the SDK was not installed; treat its call shapes as untested until step 7 passes.
- Never drive the author's everyday browser profile. A separate automation profile, signed in once, keeps the author's cookies and sessions out of the pipeline.
