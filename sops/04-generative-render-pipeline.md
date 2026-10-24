# SOP-04: Rendering assets through generator web apps and APIs, with tracking, retries and quota throttling

Status: draft
Owner: Brett Whitty
Applies to: any project that renders images, video or music from a set of prompt files
Last reviewed: 2026-10-24
Related SOPs: SOP-03 (03-asset-style-bible-and-prompts.md: its compiled leaf prompts and pre-flight checker feed this one); SOP-05 (05-voice-cloning-pipeline.md: voice clips use the same background rendering, tracking and retry approach); SOP-08 (08-session-hygiene-tracking.md: generation-gap tickets and their report at each standup); SOP-12 (12-team-roles-and-dispatch.md: who sends prompts in which browser, who harvests, the wait between them)

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
- A vetting command `{vet_cmd}` that puts a question to the generator's own model (or its documentation) before a prompt is queued, and again when a render falls short of its prompt.
- For the batch path: a record file `{runs_dir}/batch.json` mapping each asset to the chat it was sent in, and a wait `{harvest_wait}` (about ten minutes) between sending and harvesting.

## 4. Roles and tools

- Author: writes and approves prompts; signs the automation profile into the generator once; answers `--assist` prompts (captchas, consent screens, ambiguous UI states); edits prompts flagged as refused; decides daily caps; hears the open generation gaps at each standup.
- Controller agent: builds and maintains the renderer, verifies model ids against official docs before each build, sets up the tracker tabs, harvests finished chats headlessly, reads the attempt log, files generation-gap tickets, and reports status. Does not edit prompt content to get past a refusal without the author; does no interactive browser work on the author's laptop (SOP-12).
- Browser lead (optional, a session on the machine with the author's browser): vets prompts with `{vet_cmd}`, sends the batch from the author's signed-in browser, reports chat ids and outcomes to the controller. Never touches the repository.
- Sub-agents: optional, for parallel work that does not touch the same generator account (for example writing the sync step or the tracker script while the controller drives renders). Never two agents driving the same account at once.
- Tools:
  - Renderer CLI with `--status`, `--export-queue`, `--type {image|video|music|all}`, `--only {ids}`, `--force`, `--sync`; batch mode `--submit` (send every missing prompt into its own chat from one tab, record the chat ids) and `--harvest` (reopen each recorded chat, download what finished), `--browser-url` to attach to a running browser, `--dry-run` and `--limit N` honoured in every mode.
  - `{vet_cmd}`: a command-line client for the generator's model, used in the author's voice to check a prompt or ask about a gap.
  - Vendor SDK (API path).
  - Puppeteer driving a dedicated Chrome profile (browser path), with selectors kept in `selectors.json`, not in code.
  - Google Sheets as tracker; a Google Apps Script web app bound to the sheet as the write path (no cloud project or service account needed); the Google Sheets connector for the agent to create and inspect tabs.
  - Sync script (drops to project tree, transcoding).

## 5. Procedure

1. Verify generator surfaces. Open the vendor's official model or product docs and record today's model ids, call shape and output format for each kind. Check: ids and the verification date are written into the renderer's defaults and its header comment.
2. Run the prompt pre-flight checker. Check: exit status 0.
2a. Vet each new or changed prompt with the generator's model before it is queued: `{vet_cmd} "Will this prompt render as intended on {surface}? {prompt text}"`; ask about text in the image, real-person names, length limits and anything the surface is known to refuse. Fix the prompt file, re-run the checker. Check: the vetting answer is noted on the asset's issue or in the run log, and the checker still exits 0.
3. Run `--status`. Check: the count of assets matches the number of leaf prompt files (excluding the style bible and README); every row shows DONE or MISSING; files the parser skipped are listed on stderr and are either fixed or deliberately excluded.
4. Export the copy-paste queue with `--export-queue`. Check: the queue file lists exactly the MISSING assets, each with its drop path. This file is the fallback when every automated path is blocked.
5. Set up the tracker (once per project). Create the Assets, Attempts and Quotas tabs with the headers in section 8; load one Assets row per leaf prompt file. Fill Quotas per kind (`daily_cap`, `min_gap_s`, `cooldown_s`) from the plan's published limits, or conservative values if none are published, and record the source and date of each value in a note on the Quotas tab. Implement the operations in section 8 (`state`, `claim`, `attempt`, `quota`, `reset_stale`) in the bound script, wrapping every write in `LockService` so concurrent requests do not interleave. Deploy it as a web app with "Execute as: me" and "Who has access: Anyone"; the shared secret is the access control. Redeploy a new version after every script edit (the `/exec` URL serves the last deployed version, not the saved code). Store the `/exec` URL and the secret in an env file read by the renderer, and add that file to `.gitignore`. The client must follow redirects: `/exec` answers a POST with a 302 to `script.googleusercontent.com`, which returns the response. Check: `git check-ignore {env_file}` prints the path; a test `claim` sets the Assets row to `rendering`; a test `attempt` appends one row to Attempts and increments the Assets row's `attempts`; a `state` call returns the Quotas rows and today's counts.
6. Prepare the browser path (if used). Add the profile directory and the debug-dump directory to `.gitignore` (dumps hold page HTML and screenshots of a signed-in session). Launch the automation profile, have the author sign in by hand, close it. Check: `git check-ignore {render_tool}/profile {render_tool}/debug` prints both paths; a headed launch of the profile lands on the generator signed in, with no prompt to log in.
7. Render one asset per kind with `--only {id}`. Check: the file exists at its drop path, is non-empty and opens; one Attempts row with outcome `done`; Assets row `status=done`, `file` set.
8. Run the batch per kind with `--type {kind}`. On start the renderer calls `reset_stale`. Before each attempt it: calls `state` to read Quotas and today's Attempts count for that kind; skips the kind if the cap is reached or the kind is in cooldown; waits at least the minimum gap since the last attempt of that kind; calls `claim` for the asset. After the attempt it calls `attempt`, and on a quota signal also `quota`. Check: no two attempts of one kind are closer than the min gap in the log; attempts per kind per day never exceed the cap.
8a. Where the generator's web app queues long renders (video, music), split sending from collecting. Send: `{render_cli} --submit --kind {kind} --gap {sec}` from one reused tab (the sender is the browser lead in the author's browser, or the controller attached to the automation profile with `--browser-url`); each asset gets its own chat and the chat id goes into `{runs_dir}/batch.json`. No new tab or page reload per asset: fresh loads trip the generator's traffic check. Check: one chat id per asset sent; no `blocked` outcome.
8b. Wait `{harvest_wait}` without polling; record the wait as a tracker item or a scheduled check and do other work. Then harvest: `{render_cli} --harvest --kind {kind}` reopens each recorded chat and downloads what has finished; chats still generating are left for the next pass. Check: each harvested asset exists at its drop path and opens; the record marks it harvested; chats with no media after two passes go to step 8c.
8c. **Close the generation gap.** When a render differs from what its prompt asked (missing element, wrong style, text where none was asked, a stalled chat, a refusal, a format the surface cannot produce), open a ticket for the gap: type bug, labels `gen-gap` and one of `needs-improvement` or `needs-review`, naming the generator, the surface, the date, and the alternatives (another surface, another generator, a different prompt shape, post-processing). Mark it as possibly transient: a generator update may remove it. Then put the gap to the generator's model in the author's voice through `{vet_cmd}` ("I'm {author}. I tried {what}, on {surface}, and got {result}. Is this a real limitation, and what else can I try?"), and paste the answer into the ticket. Check: `bd list --label gen-gap` shows the ticket with the tool, date, alternatives and the model's answer.
9. Handle each failure by its class (section 7 table). Check: every non-`done` Attempts row has an outcome from the fixed list and, for browser runs, a debug dump directory.
10. Run the sync step (`--sync` or the sync script). Check: every DONE asset exists at its target path in the project tree, in the target format.
11. Re-run `--status` and refresh the queue. Check: MISSING count equals the Assets rows not in `done`.
12. **Report the open gaps.** At each standup with the author, list the open `gen-gap` tickets: what was asked, what the generator did, the model's answer, the alternative proposed, and whether a retry is due. Check: every open `gen-gap` ticket has been named to the author since it was opened.
13. **Retry after generator updates.** When the generator announces a model or surface change, or a month has passed, re-run each open `gen-gap` asset once (`--only {id} --force`); close the ticket with the new result, or append the date of the failed retry. Check: no `gen-gap` ticket is older than `{retry_interval}` without a retry note.

## 6. Acceptance checks

- The renderer's status reports all N assets rendered.
- `{prompt_checker}` exits 0 on the final prompt set.
- Tracker: no Assets row in `rendering` (a stuck row means a crashed run); every `failed` row has an `error`; for every kind with Assets rows in `quota`, `Quotas.resume_at` is set and in the future, or those rows have been retried.
- Each target file exists and opens in the consuming application (game engine import, media player).
- The queue file is empty or lists only assets the author has chosen to render by hand.
- Every asset whose render fell short of its prompt has a `gen-gap` ticket with the model's answer, and the author has heard the open ones.

## 7. Failure modes and recovery

| Outcome | Typical signal | Action | Auto-retry |
|---|---|---|---|
| `quota` | Usage-limit or "try again later" message in the UI; HTTP 429 or quota error from the API | Mark the asset `quota`; call the `quota` operation to set `Quotas.resume_at` for the kind (the resume time if shown, else now + `cooldown_s`); move on to other kinds | Yes, after reset or cooldown |
| `timeout` | No result within the per-kind time limit | Save debug dump, back off | Yes, exponential backoff, up to `{max_retries}` |
| `selector` | An expected element from `selectors.json` not found | Save debug dump (screenshot + DOM), back off; if it repeats across assets the UI changed: stop the kind and update `selectors.json` | Yes, up to `{max_retries}`, then stop |
| `refused` | Content-policy refusal or a blocked-output message | Mark `failed`, flag the prompt for the author to edit | No |
| `failed` | Any other exception | Record error text, keep going with the next asset | Suggested default: yes, up to `{max_retries}` (not part of the retry policy set by the author; confirm per project) |
| `blocked` | The generator's traffic check or captcha page instead of the app | Stop the whole run at once (no cooldown, no quota mark); solve the check by hand once in the automation profile; re-run from one reused tab | No; a run that opens tabs or reloads per asset will hit it again |
| gap (not an outcome) | A `done` render that does not match its prompt; a chat with no media after two harvest passes; a prompt echoed back as text | Step 8c: `gen-gap` ticket, question to the model in the author's voice, alternatives, report at standup, retry after updates | Step 13 |

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

Browser run flags: `--assist` (headed; pause for the author on login, captcha or unknown state), pacing from the Quotas tab; batch: `--submit`, `--harvest`, `--gap {sec}`, `--wait`, `--browser-url http://127.0.0.1:{port}`.

Batch record:

```text
{runs_dir}/batch.json
{ "{asset_id}": { "chat": "{chat url}", "sent": "{iso time}", "harvested": true|false }, ... }
```

Generation-gap ticket:

```text
bd create "gen-gap: {asset or capability}: {what was asked} -> {what the generator did}" -t bug -p 2 \
  --labels gen-gap,needs-review --actor {actor}
bd comment {id} "Generator {name}, surface {surface}, {date}. Possibly transient: retry after the next generator update. Alternatives: {other surface / other generator / prompt change / post-processing}." --actor {actor}
bd comment {id} "{vet_cmd} answer ({date}): {the model's reply, verbatim}" --actor {actor}
# at each standup: bd list --label gen-gap --status open
# after a retry: bd comment {id} "Retry {date}: {result}" --actor {actor}   or   bd close {id} --reason "Renders since {date}: {what changed}" --actor {actor}
```

Labels: `gen-gap` on every such ticket; `needs-improvement` when a workaround exists and the result is usable but short of the prompt; `needs-review` when the author has to decide (accept, change the prompt, change the generator).

## 9. Reference implementation in persistint

- `tools/render_all_assets.py` (added in commit 5c80263): `--status` (ends with `Progress: {done}/{total} assets rendered.`; skips `STYLE.md` and `README.md`, so it counts 45 assets from the 47 Markdown files under `prompts/`), `--export-queue` (default `prompts/QUEUE.md`), `--type image|video|music|all`, `--only`, `--force`, `--sync`, plus `--prompts-dir` and per-kind `--image-model`, `--video-model`, `--music-model`. Default models, recorded in the file header as checked against ai.google.dev on 2026-10-23: images `gemini-nano-banana-2.1` (Imagen 4 shut down), video `gemini-omni-1.1-flash` (Veo 3.1 Preview ids shut down 2026-10-22), music `lyria-3.5` (MP3). All three are called through `client.interactions.create` and return base64 inline data. Needs `GEMINI_API_KEY` and `google-genai`. Not yet run: `google-genai` is not installed in this environment (import fails), so no asset has been rendered through it.
- The repo's front-matter key for the copy target is `game:` (the generic `target:` in section 8). The prompt `tool:` values are `Gemini image`, `Gemini Veo` and `Gemini Lyria`; the renderer maps `Gemini Veo` and `Gemini Omni` both to the video kind.
- `tools/check_prompts.py` (commit f1345e9): pre-flight checker for the 47 prompt Markdown files under `prompts/` (count includes `STYLE.md` and `README.md`).
- `tools/sync_rendered_assets.py`: copies each `drop:` to its `game:` path under `project/`, converting `.mp4` to `.ogv` (Theora) with ffmpeg.
- Browser path (built since the 2026-10-23 review): `tools/web_render/render.mjs` with `drivers/`, `lib/`, `selectors.json`, `inspect.mjs`, `tests/` and `README.md`; modes `--status`, `--check-selectors`, `--login`, `--render`, `--tracker`, `--queue`, `--reset`, `--assist`, `--convert`; batch `--submit`, `--harvest`, `--gap` (default 20 s), `--wait`; `--browser-url` attaches to a Chrome started with a remote debugging port; the default profile is `~/.local/share/persistint-web-render/chrome-profile`. Google's "unusual traffic" page is the outcome `blocked` and stops the run (`39f801b`); batch `--dry-run` and `--limit` are honoured since `07e4595`. Every Gemini prompt carries `@persistint-asset-prompts` (the author's Gemini skill) through `promptPrefix` in `selectors.json`. On 2026-10-24 the coordinator rendered thirteen music tracks in batch mode from one reused tab against the automation profile (`c877667` and later commits; `--browser-url http://127.0.0.1:9333`); seven more were handed to the Windows-side session for dispatch and were waiting for the author's go at the time of writing.
- Vetting: the `agy` CLI (antigravity-cli, installed through mise) on the author's AI Ultra plan; the author's rule is to check every prompt with it before queuing (tracker memories `agy-gemini-cli`, `gemini-queue-and-check`).
- Tracker: `tools/render_tracker/` (`tracker_webapp.gs`, `appsscript.json`, `deploy.mjs`, `DEPLOY.md`); the renderer reads `trackerUrl` and `trackerSecret` from `tools/web_render/config.local.json` (gitignored) or environment variables. Redeployed with `node tools/render_tracker/deploy.mjs` on 2026-10-24.
- Generation-gap loop (step 8c, 12, 13): stated by the author on 2026-10-24 to the Windows-side session, which ran it the same evening: five `gen-gap` tickets in beads (`persistint-game-1sv` short durations, `864` loudness and bitrate specs ignored, `90v` skill prefix may not reach the music model verbatim, `c0q` no seamless loops, `h8i` choir pads trigger vocals), each with the model's answer in the author's voice, labelled `needs-improvement` or `needs-review`; two more findings from the same pass were filed as tooling issues. The first version of `1sv` claimed a hard 30 s limit; the coordinator's comment on it lists the thirteen tracks rendered that day (149 to 182 s each) and the title was narrowed to the short cues: a model's answer about its own limits is a claim until a render confirms it. Earlier gaps, filed as ordinary issues: a stalled chat with no media and a prompt echoed back as Markdown (re-sent), chat deletion failing with no Delete item (`persistint-game-i03`).
- Extraction into its own repository (`gnomatix/web-render`, issue `persistint-game-07y`): in progress on 2026-10-24 by a background agent; the tracker's Apps Script goes with it unless the author decides otherwise.

## 10. Lessons learned

- Generator model ids go stale within days: Veo 3.1 Preview ids were shut down on 2026-10-22, one day before the renderer was written, and Imagen 4 was already shut down. Verify against official docs before each build and write the check date into the code.
- A paid consumer plan (Google AI Ultra) is not usable through the REST API. That one fact forced a second render path through the web UI; find it out before writing the API path.
- Keep a no-automation fallback. The copy-paste queue (`--export-queue`) lets rendering proceed by hand when both the API and the browser path are blocked.
- An API renderer that has never run is unverified. `tools/render_all_assets.py` was committed without a single live call because the SDK was not installed; treat its call shapes as untested until step 7 passes.
- Never drive the author's everyday browser profile. A separate automation profile, signed in once, keeps the author's cookies and sessions out of the pipeline. The author's own browser is driven only by the session on the author's machine, by the author's choice (SOP-12).
- Long renders are sent and collected in two passes. Sitting on a chat for ten minutes per asset cost a whole session's attention; `--submit` then `--harvest` after a recorded wait did not.
- A `--dry-run` that sent three real prompts (fixed in `07e4595`) is why every mode of the renderer is tested for the flag now.
- Gaps between prompt and render were handled ad hoc for a day (re-send, try another surface, mention it in chat). The author asked for them to be tickets with the model's own answer attached and a standing retry, so the knowledge survives the session and a generator update can close them. The first pass produced five tickets in one evening; one of them stated a limit that the day's own renders contradicted. Check the model's answer against the rendered files before it changes a prompt or a spec.
