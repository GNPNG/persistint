# PERSISTINT promo site values

Persistint's values and measurements for the generic site plan in [`sops/templates/promo-site-plan.md`](../sops/templates/promo-site-plan.md) (pages, config schema, worker, headers, deploy steps). Checklist: [`docs/RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md), items PW-01 to PW-14, SP-04 to SP-07 and PR-08. Written 2026-10-23 against commit 93870ee.

**Domain:** **persistint.gnpng.org** (confirmed by the author 2026-10-23; "persitint" was a typo). It does not resolve yet. `dig +short NS gnpng.org` returned `dom.ns.cloudflare.com` and `gwen.ns.cloudflare.com` on 2026-10-23, so the zone is on Cloudflare.

## 1. Per-game values

These become `site/site.config.json` (schema in the template, section 6).

| Key | persistint value | Source |
|---|---|---|
| `slug` | `persistint` | |
| `title` | `PERSISTINT` | `project/project.godot` `config/name` |
| `pitch` | not written | author (decision 9 in the checklist) |
| `site_host` | `persistint.gnpng.org` | decision 1 (confirmed 2026-10-23) |
| `zone` | `gnpng.org` | dig, 2026-10-23 |
| `worker_name` | `persistint-site` | |
| `build_bucket` | `persistint-builds` | |
| `oversized_files` | `["index.wasm"]` | section 2 |
| `repo_url` | Gitea repository (public URL to be set when the repo goes public) | decision 6 |
| `itch_url` | none yet | decision 7 |
| `contact` | not chosen | decision 12 |
| `disclosure_file` | `docs/DISCLOSURE.md` (planned) | LP-09 |
| `icon_master` | `prompts/image/ui/icon/app_icon.md` (prompt; not rendered) | SOP-03 |
| `hero_image` | `prompts/image/ui/title/title_screen_plain.md` (prompt; not rendered) | SOP-03 |
| `analytics_token` | none | decision 10 |
| `thread_support` | `false` | `project/export_presets.cfg` `variant/thread_support=false` |

## 2. Measurements

A Godot 4.6.3 web export of this project (preset "Web" in `project/export_presets.cfg`: `variant/thread_support=false`, `progressive_web_app/enabled=false`), made 2026-10-23 at 93870ee outside the repo:

| File | Raw | gzip -9 | brotli -q9 |
|---|---|---|---|
| `index.wasm` | 37,700,666 B (35.95 MiB) | 9.40 MB | 7.45 MB |
| `index.pck` | 2,345,160 B (2.24 MiB) | 1.60 MB | 1.56 MB |
| `index.js` | 315,759 B | | |
| total compressed first load (wasm + pck, brotli) | about 9.0 MB | | |

Other files: `index.html`, `index.audio.worklet.js`, `index.audio.position.worklet.js`, `index.png`, `index.icon.png`, `index.apple-touch-icon.png`.

- `index.wasm` is over Cloudflare's 25 MiB (26,214,400 B) per-file cap (https://developers.cloudflare.com/workers/platform/limits/), so it goes through R2 and the worker (template section 6). Everything else is a static asset.
- The `.pck` will grow. `project/audio/voice/` holds 28 WAV clips, 5,842,086 B on disk; every `.import` file there has `compress/mode=2`, which is Quite OK Audio, Godot's default lossy WAV compression (https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_audio_samples.html), so the pck carries them compressed. Music, stingers and video are still to come (`tools/render_all_assets.py --status`: 0/45 rendered). Re-measure on each build (BD-13).
- No download budget is set yet (BD-13).

## 3. Persistint choices against the template

- **Host:** Cloudflare Workers static assets plus one R2 bucket for `index.wasm`, same origin. Fallback: itch.io.
- **Origins and saves:** the `/play/` page loads the build in a same-origin iframe, so saves persist under the normal browser rules. An itch.io embed is a cross-origin iframe and needs third-party cookies for saves (GC-13). The existing self-hosted host (`tools/deploy_web.sh`, `infra/nginx-persistint-tls.conf`), persistint.gnpng.org and itch.io would each keep separate saves; link players to one play URL.
- **Worker requests:** every request for `/play/*/index.wasm` that reaches Cloudflare invokes the worker, cached or not; 100,000 a day on the free plan is therefore an upper bound on uncached engine loads a day, not on visitors (template section 6, "Worker requests and cost").
- **Precompressed wasm** (`index.wasm.gz`, 9.4 MB, returned with `content-encoding: gzip` and `encodeBody: "manual"`: https://developers.cloudflare.com/workers/runtime-apis/response/) would fit under 25 MiB as a static asset. Unverified whether the edge passes it through cleanly; test before relying on it.
- **Size-optimised engine build** (template section 3): unmeasured for this project; do not count on it to get under 25 MiB.
- **Deploy:** `tools/deploy_site.sh` (planned) beside `tools/deploy_web.sh`, which stays for the self-hosted host. Gitea Actions availability on the project's Gitea instance is unverified (server reports 1.24.5). A GitHub mirror plus Workers Builds is possible only if decision 6 picks a mirror.

## 4. Persistint asset sources

Prompt paths are under `prompts/` (SOP-03); none is rendered yet. "New" means no prompt or file exists.

| Asset | Source | Status |
|---|---|---|
| Icon master and every derived icon; game icon in `project.godot` (also fixes GC-10) | `prompts/image/ui/icon/app_icon.md` | prompt exists |
| `icon.svg` | trace or redraw the icon | new |
| Hero | `prompts/image/ui/title/title_screen.md` (with title text) or `title_screen_plain.md` (no text, logo overlaid) | prompt exists |
| Logo | none; `title_screen_plain.md` says "type is added in-engine" | new prompt or hand-made |
| `og.jpg`, `twitter.jpg`, repo social preview | crop of `title_screen_plain` plus logo | new composite |
| Key art | `prompts/image/levels/cruise/key_art_cruise.md`, `key_art_landing.md`; `florida/key_art_florida.md`; `island/key_art_festival.md`, `key_art_island_present.md`; `ruins/key_art_bunker.md`, `key_art_ruins.md`; `temple/key_art_temple.md` | prompts exist |
| Key art 4K (optional) | none at 3840x2160 | upscale or new |
| Play poster | `title_screen_plain` | derive |
| Screenshots | `project/tools/screenshot_scenes.gd` (18 scenes, needs a display); 1920x1080 is 3x the 640x360 viewport | capture at 1920x1080 window |
| Loops | gameplay capture | new |
| Trailer | gameplay capture plus `prompts/video/ui/intro_cinematic.md` (8 s, 1280x720, silent) plus `prompts/audio/music/ui/title_theme.md` | new edit |
| Level clips (optional) | `prompts/video/levels/*/` (7 prompts) | prompts exist |

## 5. About page content (persistint)

The disclosure text (LP-09, author's text) covers: satire using real public figures under their real names (`docs/DESIGN.md`, "Legal/brand rules"); voices for real people cloned with Coqui XTTS v2 from public recordings, and voices for fictional characters from XTTS v2's built-in studio voices (`project/data/voices.json`); real-person lines taken from sourced quotes (`project/data/quotes/*.json`, with a Sources list); generated art, music and video and the tools actually used; the not-for-profit purpose stated in `README.md`. Then the content advisory (LP-10); credits including the Dialogue Manager addon (`project/addons/dialogue_manager/LICENSE`, MIT), Godot, the OpenStreetMap ODbL attribution and derived-database notice for `project/data/island_layout.json` (`art/reference/little_st_james/SOURCES.md`); the XTTS v2 licence notice for every voice clip (CPML: https://huggingface.co/coqui/XTTS-v2/raw/main/LICENSE.txt); and the complaints contact and takedown route (LA-06). Counsel review is checklist item LP-08.

## 6. Open items

- Blocked on author decisions in `docs/RELEASE_CHECKLIST.md`: domain spelling (1), real-person review (5), mirror (6), disclosure text (9), data collection (10), contact and takedown route (12).
- Unverified: Gitea Actions on the project's Gitea instance; edge behaviour for precompressed wasm; the content type Workers infers for `.pck` (the `_headers` rule sets it anyway).
