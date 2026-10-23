# web_render: render the asset prompts through the Gemini web app

AI Ultra's image, video and music generation is only available in Google's web apps, not through
the REST API. This tool drives those web apps with Puppeteer. It opens a real Chrome on a
dedicated profile, puts each prompt from `prompts/` into the right generator, waits for the
result and saves the file at the prompt's `drop:` path. `tools/sync_rendered_assets.py` then
copies the files into the game.

It reads the prompts the same way as `tools/render_all_assets.py`, which uses the API. A unit
test compares the two parsers on every file under `prompts/`.

| Kind | Default surface | File |
|---|---|---|
| image (16) | Gemini app: the prompt is sent as "Create an image: ..." (the + menu's image item is picked when it exists). The aspect ratio is stated in the prompt (the app has no ratio control). | `.png` via "Download full size" (download button only) |
| video (9) | Gemini app, Tools > Create video. Each clip gets a new chat. | `.mp4` via Share > Download video, else the `<video>` src |
| music (20) | Gemini app, Tools > Create music | `.mp3` via Download > Audio only (download button only) |

Prompts are pasted as they are in `prompts/`, except that image prompts get the prefix
"Create an image:" (Gemini's image tool triggers on prompts that start with create, generate or
draw). Only the ratio is appended when a prompt does not state one. A downloaded image is checked
before it is saved: real PNG/JPEG/WebP bytes, at least 512 px on its short side and within 12% of
the asset's ratio (`verify` in a surface overrides `minBytes` / `minSide` / `tolerance`). A
JPEG or WebP download is re-encoded to PNG in the browser. Images and music are taken only from the page's download button:
the on-page `<img>` is a downscaled preview, and a track can be shown as a `<video>` with cover
art, so neither is ever saved as the final file. If the download button breaks, fix its selector
or use `--assist`.

## Setup

```bash
cd tools/web_render
npm install                     # puppeteer-core 24.43.1 (works on the installed Node 22.6)
node render.mjs --status        # works before npm install too
```

`puppeteer-core` 25.x needs Node 22.12 or later. Node 22.16 is already installed under mise
(`mise use node@22.16.0`) if you want to upgrade. 24.43.1 is enough for this tool.

### Which Chrome

By default the script looks for a Chrome in this order:

1. `--chrome PATH`, `WEB_RENDER_CHROME`, or `"chrome"` in `config.local.json`.
2. `google-chrome-stable` (Google's .deb). This is the most likely to be accepted by Google sign-in.
3. The cached Chrome for Testing (`~/.cache/puppeteer/chrome/linux-*/chrome-linux64/chrome`).
   This is what is found on this machine now. **Whether Google lets you sign in from Chrome for
   Testing has not been tested.**
4. `/usr/bin/chromium` or `/snap/bin/chromium`. Snap confinement can get in the way.

The script starts Chrome itself, with `--user-data-dir=<profile> --remote-debugging-port=0`,
and connects with `puppeteer.connect`. It does not use `puppeteer.launch` automation flags or
any stealth plugin. The profile defaults to
`~/.local/share/persistint-web-render/chrome-profile`. It is never your normal browser profile:
the script refuses the standard Chrome, Chromium, Chrome for Testing, Edge, Brave, Vivaldi and
Opera profile folders (Linux, snap, flatpak, Windows `User Data`, macOS), also when reached
through a symlink. It also refuses a `profileDir` or `downloadDir` inside the repository, where
cookies or downloads could be committed.

**Alternative: Windows Chrome.** WSL interop is turned off in `/etc/wsl.conf`, so the script
cannot start `chrome.exe`. Start it yourself in PowerShell, on its own profile folder, in two
steps (`--login --browser-url ...` prints the same):

1. Sign in **without** a debugging port, because Google may refuse sign-in while one is open.
   Sign in to the AI Ultra account, open Gemini once, then close the window:

   ```powershell
   & "C:\Program Files\Google\Chrome\Application\chrome.exe" --user-data-dir="C:\Users\<you>\persistint-chrome-profile" --no-first-run https://accounts.google.com/ https://gemini.google.com/app
   ```

2. Start it again on the same profile with the debugging port, and leave it running while you
   render:

   ```powershell
   & "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9222 --user-data-dir="C:\Users\<you>\persistint-chrome-profile" --no-first-run
   ```

Then add `--browser-url http://127.0.0.1:9222` to every command (mirrored networking makes
Windows' localhost reachable from WSL). Downloads must go to a folder both sides can see: set
`"downloadDir": "/mnt/c/Users/<you>/persistint-downloads"` in `config.local.json`. The Windows
form (`C:\...`) is worked out automatically. The script refuses to render in this mode while
`downloadDir` is not under `/mnt/` (and `downloadDirBrowser` is not set).

The dedicated-profile check cannot see which profile an attached Chrome uses, so in this mode
keeping it off your normal profile is up to the command above. Chrome 136 and later refuse
remote debugging on the default profile, so step 2 fails if `--user-data-dir` is left out. This
mode is untested.

## First run: sign in once

```bash
node tools/web_render/render.mjs --login
```

This opens Chrome on the automation profile with **no** debugging port (Google may refuse
sign-in when one is open), with a tab for Google sign-in (`loginUrl`) and one for each surface
URL in `selectors.json` (gemini.google.com and Flow). Then:

1. Sign in with the AI Ultra account.
2. Open Gemini and accept any first-run prompts. Check that Tools lists Create images, Create
   video and Create music.
3. Close the window.

The sign-in stays in the profile. If Google says "This browser or app may not be secure",
install Google Chrome (`google-chrome-stable`) and run `--login` again, or use the Windows Chrome
mode.

## Usage

```bash
node tools/web_render/render.mjs --status                         # rendered vs missing
node tools/web_render/render.mjs --render --dry-run --kind image  # what would run, final prompt text
node tools/web_render/render.mjs --render --only app_icon         # one asset, watch it work
node tools/web_render/render.mjs --render --kind image --limit 5  # five images, 90 s apart
node tools/web_render/render.mjs --render --kind music --pause-on-error
node tools/web_render/render.mjs --assist --kind video            # you click, it saves
node tools/web_render/render.mjs --render --kind all --sync       # then copy into project/
node tools/web_render/render.mjs --convert                        # ffmpeg-convert CONVERT assets
```

- Assets whose drop file already exists are skipped, so an interrupted run can be restarted.
  Use `--force` to render them again.
- `--delay SEC` sets the pause between generations (default 90). `maxPerRun` (default 10) caps
  every run, and `--limit N` can lower it further. Both protect your quota. Raise `maxPerRun` in
  `config.local.json` when you trust the run.
- Ctrl-C once stops after the current asset. Press it twice to quit at once.
- Each run writes `tools/web_render/runs/<time>.json` with status, route, bytes, seconds and the
  failing step for every asset.
- `--delay` must be a number >= 0 and `--limit` a whole number >= 1. Anything else (also a bad
  `delaySec` or `maxPerRun` in `config.local.json`) stops the script with exit code 2, so a typo
  cannot switch off the pacing.
- If the file comes back in a different format (for example JPEG for a `.png` drop), it is
  converted with ffmpeg if ffmpeg is installed. Otherwise it is saved next to the drop with its
  real extension (`theme.mp4` beside `theme.mp3`). `--status` then shows the asset as
  `CONVERT`, and `--render` does not generate it again (that would spend quota twice). Install
  ffmpeg (`sudo apt install ffmpeg`) and run `node tools/web_render/render.mjs --convert`.
  ffmpeg is not installed on this machine yet. `sync_rendered_assets.py` needs it for `.mp4` to
  `.ogv` as well.
- If the captured bytes are not a media file at all (for example a sign-in or error page in
  HTML), nothing is written at the drop. The bytes are kept as `<drop>.unknown` for a look, the
  asset fails and stays `MISSING`. Such a file can hold account data like the debug folders;
  `*.unknown` (and the ffmpeg temp `*.src.*`) under `prompts/` are gitignored. Delete it once
  you have looked.
- A reply that finishes without media (a refusal, "I can't generate that", a signed-out page)
  fails after `timeouts.textOnlyMs` (90 s for images, 2 min for music, 5 min for video) with the
  reply text in the error, instead of waiting out the whole `generateMs`. A usage-limit notice
  (`steps.limitNotice`) fails the asset and stops the run.

`config.local.json` (gitignored) can override any of `chrome`, `profileDir`, `browserURL`,
`downloadDir`, `downloadDirBrowser`, `delaySec`, `maxPerRun` and `launchTimeoutSec`. For example:

```json
{ "delaySec": 120, "maxPerRun": 20, "chrome": "/usr/bin/google-chrome-stable" }
```

## When something breaks

All URLs, selectors and click orders are in **`selectors.json`**, one entry ("surface") per
generator. `kinds` chooses the surface used for each asset kind. The code never needs to change
when Google moves a button.

When a step fails, the script writes `tools/web_render/debug/<id>-<time>/` with
`screenshot.png`, `page.html`, `console.log` and `error.txt`. `error.txt` names the step, for
example `[mode[1] pick Create images]`. Then it moves on to the next asset.

**Debug folders hold account data. Do not share them or attach them to issues.** The screenshot
shows the signed-in Gemini page (account name, avatar, chat history), and the console log can
carry account details. `page.html` has every `<script>` body, known token fields and email
addresses removed before it is written, but it can still contain your name and chat titles.
`debug/` is gitignored. Delete the folders when you are done with them.

Gemini first serves a static shell (a plain "Ask Gemini" box with a + and a mic, no other
controls) and replaces it with the real app a few seconds later. Every render waits until
`steps.input` is visible (up to `timeouts.readyMs`, default 60 s) before acting. If Google shows
its "unusual traffic" reCAPTCHA page instead (`steps.blocked`), the run stops: solve it by hand
with `node inspect.mjs --keep 300` and try again later. Launching Chrome many times in a few
minutes can trigger that page.

**`inspect.mjs`** looks at a live surface without generating anything. It opens the surface on
the dedicated profile, waits for the app to load, and writes the accessibility tree, every
button / input / menu item (aria-label, text, data-test-id, icon), a redacted HTML copy and a
screenshot to `debug/inspect-<time>/`. Actions run in order and each one writes a new snapshot:

```bash
node tools/web_render/inspect.mjs                                     # gemini_image surface
node tools/web_render/inspect.mjs --click "::-p-aria(Upload & tools)" # what is in the + menu
node tools/web_render/inspect.mjs --do "type:a red apple" --keep 30   # send button appears; nothing is sent
```

`--do` takes `click:SELECTOR`, `hover:SELECTOR`, `press:KEY` and `type:TEXT`. Nothing is sent
unless you add `--do press:Enter`, which spends a generation.

To fix a selector:

1. Run the asset with `--render --only <id> --pause-on-error`. The window stays open at the
   failure.
2. In that window open DevTools (F12) > Elements > Accessibility pane, and find the control's
   accessible name.
3. Add a candidate to that step's list in `selectors.json`. Candidates are tried in order, so
   put the new one first. Forms you can use:
   - `::-p-aria(Send message)`: the accessible name. This is the most stable form.
   - `::-p-text(Create images)`: visible text. It also matches longer text containing it.
   - plain CSS such as `button[data-test-id='toolbox-trigger']`.
   - CSS plus text, such as `.cdk-overlay-container ::-p-text(Create music)`.

   `steps.result` must be plain CSS (it locates the new `<img>`, `<video>` or `<audio>`).
   `{aspect}` in a selector or `promptSuffix` becomes the asset's ratio.
4. `node tools/web_render/render.mjs --check-selectors` checks the file.

The step fields are `open`, `mode`, `options` (step lists), `input` (selector list), `submit`
(steps), `busy` (selectors visible while generating), `result` (CSS), `response` (CSS for a
model reply, used to notice a reply without media), `limitNotice` (selectors for a usage-limit
notice), and `download` (steps). Download controls are scoped under `model-response` or the
menu overlay (`.cdk-overlay-container`) so they cannot hit the conversation's own Share or
Download buttons.
A step is `{ "action": "click" | "hover" | "waitFor" | "press" | "sleep" | "goto", "selectors":
[...], "optional": true, "timeoutMs": 3000, "afterMs": 500, "orPress": "Escape", "note": "..." }`.
`orPress` presses that key instead when no selector matches (Enter to send, Escape to close a
menu without the wanted item) and carries on. `blocked` lists selectors for a Google check page.
`"target": "result"` acts on the newest result instead of a selector. `capture` sets the order
in which the routes are tried. `download` clicks the page's download control and collects the
file through Chrome's download events. `src` fetches the result element's `src` inside the page
(blob:, data: or cookie-protected https).

## Assist mode (works even when selectors are broken)

`--assist` opens the right surface for each missing asset. It runs the `open`, `mode` and
`options` steps and puts the prompt in the box. **You** then check the settings, click send and
wait. When the result appears, press Enter, and the newest image, video or audio on the page is
saved to the drop. Or click the page's own download button: the download is caught and moved to
the drop. For images and music, click the download button: pressing Enter saves what the
page shows, which for an image is the downscaled preview (the script warns when it does that). Type `s` and Enter to skip an asset. If the mode or input steps fail, fix them by hand
in the window and use `--pause-on-error` instead. Its capture works the same way.

## Video on Flow instead

Flow can render Veo 3.1 Lite at "Lower Priority" for 0 credits on Ultra, with real 16:9 and
length controls. `selectors.json` has a `flow_video` surface with the documented click order.
Its selectors are guesses: none are documented publicly, Flow needs reCAPTCHA in a headed real
Chrome, and its URL is moving to flow.google.com. To try it, set `"kinds": { "video":
"flow_video" }`, then run `--render --only <one video id> --pause-on-error` and fix the
selectors from the debug output.

## Tests

```bash
cd tools/web_render
npm test             # no browser: parser parity with render_all_assets.py on all 45 prompts,
                     # selectors.json validation, drop extensions, format sniffing, unknown-format
                     # refusal, CONVERT status, option validation, profile checks, HTML redaction
DISPLAY=:0 npm run smoke   # headful Chrome against tests/fixtures/fake_gemini.html
```

The smoke test runs the real drivers against a local fake page. The page has a Tools menu, a
Quill-like editor, a send button, a busy indicator, and a result with hover, download and share
menus. The test checks that an image (download button), a video (Share > Download) and a track
(in-page fetch of a `blob:` src) are saved with the right format, that a broken selector
leaves a debug folder with redacted HTML, that a text-only reply fails fast at `wait`, and that a
usage-limit notice stops the run.

## Known limits

- **No Google selector has been tested against the live pages.** They come from Google's help
  pages and community scripts. Expect to fix some of them on the first run, using
  `--pause-on-error` and the debug folder, or to use `--assist`.
- The Gemini app has no aspect-ratio control for images. Every image and video prompt in
  `prompts/` already states its ratio, and `promptSuffix` adds it if a prompt does not.
- Where the Gemini app's video aspect and length controls are is not documented. The `options`
  step tries an "Aspect ratio" control and skips it if there is none. 16:9 is the app's default.
- Music length is "short" (about 1 min) or "full" in the app. The stingers ask for 4 to 30 s in
  the prompt. Expect to trim them.
- Usage limits are compute-based and not published. Keep `--limit` low until you know how much
  a run costs. The `limitNotice` phrases are guesses; if a real notice is not caught, the reply
  still fails after `textOnlyMs`. Add the notice's wording to `limitNotice`.
- Google's Terms forbid bypassing its protective measures, so this tool has no stealth or
  fingerprint patches. If Google blocks sign-in or generation in the automated browser, use
  `--assist`.
