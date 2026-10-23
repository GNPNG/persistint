# Promotion website plan (template)

Companion to SOP-09 (`../09-game-release-checklist.md`), items PW-01 to PW-14, SP-04 to SP-07 and PR-08. This file holds the design that is the same for every game. Each game keeps a short values file, `docs/PROMO_SITE_PLAN.md`, with the two sections marked "copy to the game" filled in, and nothing else.

Written 2026-10-23. Cloudflare is the worked example because it was the first host chosen; the page structure, config file and checks apply to any static host.

## 1. Per-game values (copy to the game)

Every value a game changes lives in `site/site.config.json` (section 6). The game's values file repeats them in a table so a reader does not need the repo checked out.

| Key | Meaning | Example |
|---|---|---|
| `slug` | `{game_slug}` | `mygame` |
| `title` | display name | `MY GAME` |
| `pitch` | one-line pitch (og:description) | |
| `site_host` | public hostname: subdomain, apex or separate domain | `{game_slug}.{site_domain}` or `{game_domain}` |
| `zone` | DNS zone that holds `site_host` | `{site_domain}` |
| `worker_name` | hosting project name | `{game_slug}-site` |
| `build_bucket` | object storage bucket for oversized build files, or empty | `{game_slug}-builds` |
| `oversized_files` | build files over the host's per-file limit, served from the bucket | `["index.wasm"]` |
| `repo_url` | public repository URL | |
| `itch_url` | itch.io page, or empty | |
| `contact` | public contact for press, bugs and complaints | |
| `disclosure_file` | path of the single disclosure text (LP-09) | `docs/DISCLOSURE.md` |
| `icon_master`, `hero_image` | source images for icons and share images | prompt or file paths in the game repo |
| `analytics_token` | web analytics site token, or empty | |
| `thread_support` | whether the web export uses threads (turns on COOP/COEP) | `false` |

## 2. Measurements (copy to the game)

Record before choosing a host, and again on every release (BD-06, BD-13):

| File | Raw | gzip -9 | brotli -q9 |
|---|---|---|---|
| engine (`index.wasm` for Godot) | | | |
| data pack (`index.pck`) | | | |
| loader (`index.js`) | | | |
| total compressed first load | | | |

With the export preset's thread setting, the date, the commit and the engine version.

## 3. Choosing the host

- **Every file under the host's per-file limit:** a plain static upload (Cloudflare Workers static assets or Pages, 25 MiB per file: https://developers.cloudflare.com/workers/platform/limits/).
- **One or more files over the limit:** keep the site static and serve only those files from object storage through a small worker on the same origin (section 7), use a size-optimised engine build (https://docs.godotengine.org/en/stable/engine_details/development/compiling/optimizing_for_size.html; measure, do not assume), or host the build on itch.io (200 MB per file, 1,000 files, 500 MB total extracted: https://itch.io/docs/creators/html5) and link to it.
- **Embedding a build hosted elsewhere:** an itch.io embed is a cross-origin iframe. Godot's web page says `user://` inside an iframe persists only when third-party cookies are allowed (https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html), and saves are tied to an origin, so the same game on the site, on a self-hosted or staging host and on itch.io keeps three separate saves. Prefer a same-origin `/play/` page and treat any embed as a fallback (GC-13).

Godot web requirements (same page): a single-threaded export needs no COOP/COEP headers; serve `.wasm` as `application/wasm`; WebGL 2 only; Safari has WebGL 2 issues; single-threaded builds use sample playback, so audio effects such as reverb do not work; browsers may block audio until the player clicks; gamepads are not detected until a button is pressed.

## 4. Pages

```
site/
  site.config.json        every per-game value (section 6)
  wrangler.toml           generated from site.config.json by the deploy script
  src/worker.js
  public/
    index.html            landing
    play/index.html       click-to-play poster, same-origin iframe to the current build
    play/<build-id>/      engine export (oversized files go to the bucket)
    press/index.html      press kit
    press/<slug>-press.zip
    about/index.html      disclosure, advisory, credits, contact, complaints route
    privacy/index.html
    404.html
    _headers  _redirects
    favicon.ico  icon.svg  apple-touch-icon.png  icon-192.png  icon-512.png  icon-mask.png
    manifest.webmanifest  og.jpg  twitter.jpg
```

- **Landing (`/`).** Hero key art, pitch, trailer, Play button, desktop downloads once they exist, repo link, signup if chosen. Footer on every page: About, Press, Privacy, repo.
- **Play (`/play/`).** A poster and a "Click to play" button; only on click does it load `<iframe src="/play/<build-id>/" allow="autoplay; fullscreen; gamepad">`. Visitors do not download the build just by opening the page, and the click is the one browsers need before audio. Show the download size, the browser recommendation and the disclosure line. Before loading, test for WebGL 2 and a supported device; if either fails, show the "your browser can't run this" message with download links instead (PW-14). If the game reports that saves will not persist, it shows its own warning (GC-13).
- **Press (`/press/`).** presskit() fields (https://dopresskit.com/; template fields at https://github.com/ramiismail/dopresskit/blob/master/archive/_template/_data.xml): title, developer, release date, platforms, website, price, description, history, features, trailer, images, logo and icon, awards, quotes, links, credits, contact.
- **About (`/about/`).** The single disclosure text (LP-09), the content advisory (LP-10), credits and licence notices (LP-03), and the contact and takedown route (LA-06).
- **Privacy (`/privacy/`).** What crash capture, analytics and signup collect, or "nothing" (LP-11).
- **404 (`/404.html`).** Served for unknown paths; links back to the landing and play pages.

## 5. Assets

| Asset | Size / format | Derived from |
|---|---|---|
| Icon master | 1024x1024 PNG, reads at 64x64 | `icon_master` |
| `favicon.ico` | 32x32 | icon master |
| `icon.svg` | square vector | traced or redrawn icon |
| `apple-touch-icon.png` | 180x180 | icon master |
| `icon-192.png`, `icon-512.png` | 192x192, 512x512 | icon master |
| `icon-mask.png` | 512x512, safe zone 409x409 circle | icon master, padded |
| Favicon set reference | | https://evilmartians.com/chronicles/how-to-favicon-in-2021-six-files-that-fit-most-needs |
| Hero | 1920x1080 | `hero_image` |
| Logo | transparent PNG and SVG | hand-made or generated |
| `og.jpg` | 1200x630, under 8 MB (https://developers.facebook.com/documentation/sharing/webmasters/images) | hero crop plus logo |
| `twitter.jpg` | 2:1, e.g. 1200x600, under 5 MB, no SVG (https://web.archive.org/web/20231217021401/https://developer.twitter.com/en/docs/twitter-for-websites/cards/overview/summary-card-with-large-image; archived, since X's current docs at docs.x.com no longer have this page) | same composite |
| Repo social preview | 1280x640, under 1 MB (https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview) | same composite |
| Play poster | 1280x720 or 1920x1080 | hero without text |
| Screenshots | 1920x1080 | gameplay capture |
| Loops | 3 to 5 short MP4/WebM | gameplay capture |
| Trailer | up to 1920x1080, H.264/AAC MP4 (https://partner.steamgames.com/doc/store/trailer) | gameplay-first edit |

Head meta for each page, filled from `site.config.json`:

```html
<link rel="canonical" href="https://{site_host}/">
<meta property="og:title" content="{title}">
<meta property="og:type" content="website">
<meta property="og:url" content="https://{site_host}/">
<meta property="og:image" content="https://{site_host}/og.jpg">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="{alt text}">
<meta property="og:description" content="{pitch}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:image" content="https://{site_host}/twitter.jpg">
<link rel="icon" href="/favicon.ico" sizes="32x32">
<link rel="icon" href="/icon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="manifest" href="/manifest.webmanifest">
```

Open Graph properties: https://ogp.me/.

## 6. Site starter and `site.config.json`

The starter is a `site/` folder with no game data in it: pages that read their text from `site.config.json` at build time, the worker, `_headers`, `404.html` and `tools/deploy_site.sh`. A new game copies the folder and edits only `site.config.json`.

```json
{
  "slug": "{game_slug}",
  "title": "{title}",
  "pitch": "{one-line pitch}",
  "site_host": "{site_host}",
  "zone": "{zone}",
  "worker_name": "{game_slug}-site",
  "build_bucket": "{game_slug}-builds",
  "oversized_files": ["index.wasm"],
  "repo_url": "https://{forge_host}/{org}/{repo}",
  "itch_url": "",
  "contact": "{contact}",
  "disclosure_file": "docs/DISCLOSURE.md",
  "icon_master": "{path}",
  "hero_image": "{path}",
  "analytics_token": "",
  "thread_support": false
}
```

The deploy script generates `wrangler.toml` from it (Cloudflare example):

```toml
name = "{worker_name}"
main = "src/worker.js"
compatibility_date = "{date}"

[assets]
directory = "./public"
binding = "ASSETS"
not_found_handling = "404-page"
run_worker_first = ["/play/*/index.wasm"]   # one entry per oversized file

[[r2_buckets]]
binding = "GAME"
bucket_name = "{build_bucket}"

[[routes]]
pattern = "{site_host}"
custom_domain = true
```

`src/worker.js` (serves only the oversized files; everything else is static):

```js
export default {
  async fetch(req, env) {
    const p = new URL(req.url).pathname;
    const m = p.match(/^\/play\/([\w.-]+)\/(index\.wasm)$/);
    if (m) {
      const obj = await env.GAME.get(`${m[1]}/${m[2]}`);
      if (!obj) return new Response("Not found", { status: 404 });
      const h = new Headers();
      obj.writeHttpMetadata(h);
      h.set("etag", obj.httpEtag);
      h.set("content-type", "application/wasm");
      h.set("cache-control", "public, max-age=31536000, immutable");
      return new Response(obj.body, { headers: h });
    }
    return env.ASSETS.fetch(req);
  }
};
```

`_headers` rules do not apply to responses the worker builds, so the worker sets its own headers (https://developers.cloudflare.com/workers/static-assets/headers/).

`site/public/_headers`:

```
/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Strict-Transport-Security: max-age=31536000
/play/*/index.pck
  Content-Type: application/octet-stream
  Cache-Control: public, max-age=31536000, immutable
/play/*/index.js
  Cache-Control: public, max-age=31536000, immutable
/play/*/*.worklet.js
  Cache-Control: public, max-age=31536000, immutable
# Only if thread_support is true. Scope to /play/* only:
# require-corp on the other pages would block video embeds and third-party scripts.
#/play/*
#  Cross-Origin-Opener-Policy: same-origin
#  Cross-Origin-Embedder-Policy: require-corp
```

Static assets default to `public, max-age=0, must-revalidate` with an ETag, so HTML revalidates. Because Godot reuses the `index.*` names, each build goes in its own folder `/play/<build-id>/` (short commit hash or version tag) and files inside are immutable. The deploy script writes the current build id into `play/index.html`. `_redirects` adds a convenience alias:

```
/play/current/*  /play/<build-id>/:splat  302
```

### Worker requests and cost

On the Workers free plan (100,000 requests a day: https://developers.cloudflare.com/workers/platform/limits/), every request that matches a `run_worker_first` pattern invokes the worker, even when Cloudflare could have served it from cache; over the limit those requests get a 429 rather than falling back to static assets (https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/). So the limit counts every request for an oversized file that reaches Cloudflare: first loads, and repeat loads whose browser cache has expired or been cleared. Repeat loads served from the browser's own cache (the response is `immutable`) make no request. To keep the count down:
- Keep `run_worker_first` to the oversized files only. Negative patterns (`!/...`) send matching paths to static assets without invoking the worker, which helps when a broad pattern is needed elsewhere; they cannot remove the oversized files themselves, which only the worker can serve.
- Use the Cache API in the worker (https://developers.cloudflare.com/workers/runtime-apis/cache/) to cut object-storage reads; this saves reads, not worker invocations.
- If daily loads approach the limit, move to a paid plan or serve the build from itch.io.

## 7. Deploy

1. **Local script first: `tools/deploy_site.sh`**, reading `site/site.config.json`:
   1. Export the web preset into a temp folder.
   2. Fail if any file not listed in `oversized_files` is over the host's per-file limit (`stat -c %s`), and print every file's size (LA-09 keeps the history).
   3. Upload each oversized file to `{build_bucket}/<build-id>/` with its content type (`wrangler r2 object put`; up to 315 MB per object: https://developers.cloudflare.com/r2/objects/upload-objects/).
   4. Copy the other export files into `site/public/play/<build-id>/`.
   5. Write `<build-id>` into `site/public/play/index.html` and the `_redirects` alias; generate `wrangler.toml`.
   6. Run the link check (PW-13): `lychee --no-progress site/public README.md docs/`; stop on failure.
   7. `cd site && {host_cli} deploy`.
   Needs `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` in the environment, never in the repo (https://developers.cloudflare.com/workers/ci-cd/external-cicd/github-actions/).
2. **Forge CI, later.** Gitea Actions is mostly compatible with GitHub Actions and needs a separate runner (https://docs.gitea.com/usage/actions/overview/); a bare `uses:` resolves to github.com unless `DEFAULT_ACTIONS_URL` is changed (https://docs.gitea.com/usage/actions/faq/). The runner image needs the engine and its web export templates.
3. **Host-side Git integration.** Cloudflare Workers Builds connects to GitHub and GitLab, not self-hosted forges (https://developers.cloudflare.com/workers/ci-cd/builds/git-integration/); it needs a mirror there and covers site files only, since its image has no game engine.

## 8. Analytics and signup (optional)

- **Cloudflare Web Analytics:** free; Cloudflare says it "does not collect or use your visitors' personal data" (https://developers.cloudflare.com/web-analytics/about/). Add the beacon by hand; automatic setup injects it on every subdomain in the zone unless limited by rules. Soft limit of 10 sites per account, which matters once several games have sites.
- **Signup:** a hosted newsletter (for example Buttondown: https://buttondown.com/pricing), or a worker endpoint protected by Turnstile (https://developers.cloudflare.com/turnstile/plans/). Link the privacy page from the form.

## 9. After deploy

- Uptime check on `https://{site_host}/` and `/play/` (LA-09).
- Link check before every deploy (PW-13).
- Compare the deploy script's file sizes with the previous build; a jump is a regression to explain (BD-13).
