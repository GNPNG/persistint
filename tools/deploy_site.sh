#!/usr/bin/env bash
# Deploy the PERSISTINT promo site (site/) to Cloudflare Workers static assets, with the
# oversized Godot engine file(s) served from R2 through site/src/worker.js on the same origin.
# Spec: sops/templates/promo-site-plan.md sections 6 and 7; values: site/site.config.json;
# usage notes: docs/PROMO_SITE_PLAN.md ("Deploying").
#
# Usage: tools/deploy_site.sh [--dry-run] [--site-only] [--allow-dirty] [--check-external]
#   --dry-run         do everything except the R2 upload and the deploy; runs
#                     `wrangler deploy --dry-run --outdir <tmp>` instead. No credentials needed.
#   --site-only       skip the Godot export and R2; deploy the landing page and keep the play
#                     build already in site/public/play/ (found through site/public/_redirects).
#                     With no local build, /play/ becomes a "not available yet" page.
#   --allow-dirty     deploy from a tree with uncommitted changes (build id gets "-dirty").
#   --check-external  also fetch external links in the link check.
#   --channel=NAME    review channel: deploy to the separate Cloudflare Pages project
#                     <worker_name>-NAME (served at https://<worker_name>-NAME.pages.dev/, no custom
#                     domain, R2 untouched), so a test build never replaces the player-facing site.
#                     Its play build is /play/<build-id>/ with /play/current/ pointing at it; the
#                     landing pages are deployed alongside unchanged. NAME: [a-z0-9-]{1,24}.
#                     Pages only (host_type pages). A test scene opens with ?scene=<name> (DevScene).
#
# Steps: read site/site.config.json -> refuse a dirty tree -> export the "Web" preset
# (project/export_presets.cfg) to a temp dir -> print every file's size, fail on any file over
# 25 MiB that is not in oversized_files -> copy the rest to site/public/play/<build-id>/ (older
# local build folders are pruned; their R2 objects stay) -> write site/public/play/index.html
# and site/public/_redirects (/play/current/* alias) -> generate site/wrangler.toml and
# site/src/worker.js -> make the social-card URLs in site/public/index.html absolute -> link
# check (tools/check_site_links.py) -> ensure the R2 bucket, upload oversized files to
# {build_bucket}/<build-id>/ -> `npx -y wrangler@4 deploy` from site/.
# build-id = short commit hash.
#
# Credentials: CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID from the environment or from
# ~/.config/persistint/cloudflare.env, or the file named by PERSISTINT_CF_ENV (sourced if present; outside the repo; never printed).
#
# Generated files: site/wrangler.toml, site/src/worker.js and the absolute URLs in
# site/public/index.html depend only on site.config.json, so they are committed; a run that
# changes them leaves the tree dirty as a sign to commit. site/public/play/index.html,
# site/public/play/<build-id>/, site/public/_redirects and site/.wrangler/ name a build and
# are gitignored.
set -euo pipefail
# Never enable xtrace here: it would print the credentials.
set +x

usage() { sed -n '2,/^set -euo/{/^#/s/^# \{0,1\}//p}' "$0"; }
die() { printf 'deploy_site: %s\n' "$*" >&2; exit 1; }
log() { printf '\n== %s\n' "$*"; }

DRY_RUN=0 SITE_ONLY=0 ALLOW_DIRTY=0 CHECK_EXTERNAL=0 CHANNEL=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --site-only) SITE_ONLY=1 ;;
    --allow-dirty) ALLOW_DIRTY=1 ;;
    --check-external) CHECK_EXTERNAL=1 ;;
    --channel=*) CHANNEL="${arg#--channel=}" ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $arg (see --help)" ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SITE="$ROOT/site"
PUBLIC="$SITE/public"
CONFIG="$SITE/site.config.json"
MAX_ASSET_BYTES=26214400          # Cloudflare Workers static assets: 25 MiB per file
MAX_R2_PUT_BYTES=314572800        # wrangler r2 object put: 300 MiB per object
PART_BYTES=$((24 * 1024 * 1024))  # oversized_mode gzip: part size for a file whose gzip is still over 25 MiB
COMPAT_DATE="2026-10-01"          # pinned so wrangler.toml stays deterministic
WRANGLER=(npx -y wrangler@4)
export WRANGLER_SEND_METRICS=false

for cmd in jq git python3 npx; do
  command -v "$cmd" >/dev/null || die "missing required command: $cmd"
done
[[ -f "$CONFIG" ]] || die "missing $CONFIG"

cfg() { jq -er "$1" "$CONFIG" 2>/dev/null || die "site.config.json: missing or empty $1"; }
SITE_HOST="$(cfg '.site_host | select(. != "")')"
WORKER_NAME="$(cfg '.worker_name | select(. != "")')"
TITLE="$(cfg '.title | select(. != "")')"
BUILD_BUCKET="$(jq -r '.build_bucket // ""' "$CONFIG")"
THREAD_SUPPORT="$(jq -r '.thread_support // false' "$CONFIG")"
mapfile -t OVERSIZED < <(jq -r '.oversized_files // [] | .[]' "$CONFIG")
# oversized_mode: "r2" uploads oversized files to R2 (build_bucket); "gzip" ships each as a
# static <file>.gz (which must fit the 25 MiB limit) and the worker serves it with
# Content-Encoding: gzip, so no R2 is needed. custom_domain false: no route; the worker is
# served on the account's workers.dev subdomain.
OVERSIZED_MODE="$(jq -r '.oversized_mode // "r2"' "$CONFIG")"
# review_channels: names of review channels (deploy_site.sh --channel <name>) that the player-facing
# worker proxies at https://<site_host>/play/<name>/... (to <worker_name>-<name>.pages.dev).
mapfile -t REVIEW_CHANNELS < <(jq -r '.review_channels // [] | .[]' "$CONFIG")
for c in "${REVIEW_CHANNELS[@]}"; do
  [[ "$c" =~ ^[a-z0-9-]{1,24}$ ]] || die "review_channels entry must match [a-z0-9-]{1,24}: $c"
done
CUSTOM_DOMAIN="$(jq -r 'if has("custom_domain") then .custom_domain else true end' "$CONFIG")"
# host_type: "workers" (wrangler deploy; custom domain needs the zone on Cloudflare) or "pages"
# (Cloudflare Pages project named worker_name, the worker shipped as _worker.js; site_host is
# attached as a Pages custom domain, which works for a zone whose DNS is elsewhere: point a
# CNAME for site_host at <worker_name>.pages.dev).
HOST_TYPE="$(jq -r '.host_type // "workers"' "$CONFIG")"
[[ "$HOST_TYPE" == workers || "$HOST_TYPE" == pages ]] || die "host_type must be workers or pages"
[[ "$OVERSIZED_MODE" == r2 || "$OVERSIZED_MODE" == gzip ]] || die "oversized_mode must be r2 or gzip"
if [[ -n "$CHANNEL" ]]; then
  [[ "$CHANNEL" =~ ^[a-z0-9-]{1,24}$ ]] || die "--channel must match [a-z0-9-]{1,24}"
  [[ "$HOST_TYPE" == pages ]] || die "--channel needs host_type pages"
  WORKER_NAME="$WORKER_NAME-$CHANNEL"
  CUSTOM_DOMAIN=false
  echo "review channel $CHANNEL: Pages project $WORKER_NAME (https://$WORKER_NAME.pages.dev/), player-facing site untouched"
fi
use_r2() { [[ "$OVERSIZED_MODE" == r2 ]] && ((${#OVERSIZED[@]})); }
[[ "$SITE_HOST" =~ ^[a-z0-9.-]+$ ]] || die "site_host is not a hostname: $SITE_HOST"
for f in "${OVERSIZED[@]}"; do
  [[ "$f" =~ ^[A-Za-z0-9._-]+$ ]] || die "oversized_files entry is not a plain file name: $f"
done
if use_r2 && [[ -z "$BUILD_BUCKET" ]]; then
  die "oversized_files is set but build_bucket is empty"
fi
if [[ "$THREAD_SUPPORT" == "true" ]] && ! grep -q '^ *Cross-Origin-Embedder-Policy' "$PUBLIC/_headers"; then
  die "thread_support is true: add the /play/* COOP/COEP rule to site/public/_headers (template section 6) and the same headers in the worker"
fi

is_oversized() { local x; for x in "${OVERSIZED[@]}"; do [[ "$x" == "$1" ]] && return 0; done; return 1; }
human() { awk -v b="$1" 'BEGIN { printf "%.2f MiB", b / 1048576 }'; }

# ---------------------------------------------------------------- tree state and build id
log "Tree state"
DIRTY="$(git status --porcelain --untracked-files=no; git status --porcelain -- project site | grep '^??' || true)"
BUILD_ID="$(git rev-parse --short HEAD)"
if [[ -n "$DIRTY" ]]; then
  if ((ALLOW_DIRTY)); then
    echo "warning: uncommitted changes (--allow-dirty):"; printf '%s\n' "$DIRTY" | sed 's/^/  /'
    BUILD_ID="$BUILD_ID-dirty"
  else
    printf '%s\n' "$DIRTY" | sed 's/^/  /' >&2
    die "uncommitted changes; commit them or pass --allow-dirty"
  fi
fi
echo "commit $(git rev-parse --short HEAD), build id $BUILD_ID"

# ---------------------------------------------------------------- credentials
CRED_FILE="${PERSISTINT_CF_ENV:-$HOME/.config/persistint/cloudflare.env}"
if [[ -f "$CRED_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  . "$CRED_FILE"
  set +a
  echo "credentials: loaded $CRED_FILE"
fi
if ((DRY_RUN)); then
  echo "credentials: not needed for --dry-run"
else
  missing=()
  [[ -n "${CLOUDFLARE_API_TOKEN:-}" ]] || missing+=(CLOUDFLARE_API_TOKEN)
  [[ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]] || missing+=(CLOUDFLARE_ACCOUNT_ID)
  if ((${#missing[@]})); then
    die "missing ${missing[*]}: export them or put them in $CRED_FILE (chmod 600), e.g.
  CLOUDFLARE_API_TOKEN=...   # token with Workers Scripts edit, Workers R2 Storage edit,
                             # and Workers Routes + DNS edit on the zone $(jq -r .zone "$CONFIG")
  CLOUDFLARE_ACCOUNT_ID=...
(see docs/PROMO_SITE_PLAN.md, \"Deploying\")"
  fi
  export CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/deploy_site.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
if [[ -n "$CHANNEL" ]]; then
  # A review channel works on its own copy of site/public: the build copy, play/index.html and
  # _redirects written below land there, so the checkout (and the next player-facing deploy, which
  # with --site-only reuses whatever build the checkout holds) keeps the released build.
  cp -a "$PUBLIC" "$TMP/public"
  rm -rf "$TMP/public/play" "$TMP/public/_redirects"
  PUBLIC="$TMP/public"
fi

# ---------------------------------------------------------------- export and size check
PLAY="$PUBLIC/play"
mkdir -p "$PLAY"
if ((SITE_ONLY)); then
  log "Play build (--site-only: keeping the existing local build)"
  BUILD_ID=""
  if [[ -f "$PUBLIC/_redirects" ]]; then
    BUILD_ID="$(sed -n 's#^/play/current/\*[[:space:]]\{1,\}/play/\([^/]*\)/:splat.*#\1#p' "$PUBLIC/_redirects" | head -n1)"
  fi
  if [[ -n "$BUILD_ID" && -f "$PLAY/$BUILD_ID/index.html" ]]; then
    echo "keeping play build $BUILD_ID (assumes an earlier full deploy uploaded its oversized files to R2)"
  else
    BUILD_ID=""
    echo "WARNING: no local play build in site/public/play/; /play/ will say the game is not available."
    echo "WARNING: deploying replaces every static asset, so a play build deployed from elsewhere goes away."
  fi
else
  command -v godot >/dev/null || die "missing godot (Godot 4.6.3 with web export templates)"
  log "Godot export (preset \"Web\")"
  EXPORT="$TMP/export"
  mkdir -p "$EXPORT"
  # Opening the project re-serialises project/project.godot (editor plugins, section order);
  # put the committed file back afterwards so a deploy does not dirty the tree.
  cp project/project.godot "$TMP/project.godot.orig"
  cp project/export_presets.cfg "$TMP/export_presets.cfg.orig"
  trap 'cp "$TMP/project.godot.orig" "$ROOT/project/project.godot"; cp "$TMP/export_presets.cfg.orig" "$ROOT/project/export_presets.cfg"; rm -rf "$TMP"' EXIT
  if [[ -n "$CHANNEL" ]]; then
    # Review scenes (scenes/test, scripts/test, assets/test) are excluded from the player build by
    # the preset's exclude_filter; a review channel carries them, so clear the filter for this export.
    sed -i 's#^exclude_filter=.*#exclude_filter=""#' project/export_presets.cfg
    echo "review channel: test scenes and their assets included in this export"
  fi
  untracked_before="$(git status --porcelain -- project | grep '^??' || true)"
  if [[ ! -d project/.godot ]]; then
    echo "project/.godot missing: importing first"
    godot --headless --path project --import >"$TMP/import.log" 2>&1 || { tail -n 40 "$TMP/import.log"; die "godot --import failed"; }
  fi
  # The main menu shows this build id next to the version (res://build.json, gitignored; the Web
  # preset's include_filter "*.json" packs it).
  printf '{"build": "%s"}\n' "$BUILD_ID" > project/build.json
  godot --headless --path project --export-release Web "$EXPORT/index.html" >"$TMP/export.log" 2>&1 \
    || { tail -n 40 "$TMP/export.log"; die "godot export failed"; }
  cp "$TMP/project.godot.orig" project/project.godot
  cp "$TMP/export_presets.cfg.orig" project/export_presets.cfg
  grep -E '^(ERROR|SCRIPT ERROR)' "$TMP/export.log" | head -n 20 || true
  untracked_after="$(git status --porcelain -- project | grep '^??' || true)"
  if [[ "$untracked_after" != "$untracked_before" ]]; then
    echo "note: the import created untracked files under project/ (commit them, e.g. *.import):"
    comm -13 <(printf '%s\n' "$untracked_before") <(printf '%s\n' "$untracked_after") | head -n 10 | sed 's/^/  /'
  fi
  for f in index.html index.js index.pck index.wasm; do
    [[ -s "$EXPORT/$f" ]] || { tail -n 40 "$TMP/export.log"; die "export is missing $f"; }
  done
  for f in "${OVERSIZED[@]}"; do
    [[ -f "$EXPORT/$f" ]] || die "oversized_files lists $f but the export has no such file"
  done

  log "File sizes (limit $MAX_ASSET_BYTES B = 25 MiB per static file)"
  over=0
  while IFS= read -r -d '' p; do
    f="${p#"$EXPORT"/}"
    bytes="$(stat -c %s "$p")"
    if is_oversized "$f" && [[ "$OVERSIZED_MODE" == gzip ]]; then
      gz="$(gzip -9 -n -c "$p" | wc -c)"
      if ((gz <= MAX_ASSET_BYTES)); then
        where="static $f.gz ($(human "$gz") gzip)"
      else
        # Already-compressed content (the .pck with its MP3s) doesn't shrink: ship it in parts the
        # worker joins back into one response.
        where="static parts $f.partNN ($(( (bytes + PART_BYTES - 1) / PART_BYTES )) x <= $(human "$PART_BYTES"); gzip would be $(human "$gz"))"
      fi
    elif is_oversized "$f"; then
      where="R2 $BUILD_BUCKET/$BUILD_ID/$f"
      ((bytes <= MAX_R2_PUT_BYTES)) || { where="TOO BIG FOR r2 object put"; over=1; }
    elif ((bytes > MAX_ASSET_BYTES)); then
      where="OVER LIMIT (add to oversized_files?)"; over=1
    else
      where="static"
    fi
    printf '  %-36s %12s B  %11s  %s\n' "$f" "$bytes" "$(human "$bytes")" "$where"
  done < <(find "$EXPORT" -type f -print0 | sort -z)
  ((over == 0)) || die "file size check failed"

  log "Copying the build to site/public/play/$BUILD_ID/"
  for d in "$PLAY"/*/; do
    [[ -d "$d" ]] || continue
    old="$(basename "$d")"
    [[ "$old" == "$BUILD_ID" ]] && continue
    [[ "$old" =~ ^[0-9a-f]{4,40}(-dirty)?$ ]] || continue
    echo "pruning old local build $old"
    rm -rf "${PLAY:?}/$old"
  done
  rm -rf "${PLAY:?}/$BUILD_ID"
  mkdir -p "$PLAY/$BUILD_ID"
  while IFS= read -r -d '' p; do
    f="${p#"$EXPORT"/}"
    if is_oversized "$f"; then
      if [[ "$OVERSIZED_MODE" == gzip ]]; then
        gzip -9 -n -c "$p" >"$PLAY/$BUILD_ID/$f.gz"
        if (($(stat -c %s "$PLAY/$BUILD_ID/$f.gz") > MAX_ASSET_BYTES)); then
          rm -f "$PLAY/$BUILD_ID/$f.gz"
          split -b "$PART_BYTES" -d -a 2 "$p" "$PLAY/$BUILD_ID/$f.part"
          python3 -I - "$PLAY/$BUILD_ID" "$f" "$(stat -c %s "$p")" <<'PY2'
import json, os, sys
d, name, size = sys.argv[1], sys.argv[2], int(sys.argv[3])
parts = sorted(x for x in os.listdir(d) if x.startswith(name + ".part") and x[len(name) + 5:].isdigit())
assert sum(os.path.getsize(os.path.join(d, x)) for x in parts) == size, "parts do not add up"
with open(os.path.join(d, name + ".parts.json"), "w") as fh:
    json.dump({"size": size, "parts": parts}, fh)
PY2
        fi
      fi
      continue
    fi
    mkdir -p "$PLAY/$BUILD_ID/$(dirname "$f")"
    cp "$p" "$PLAY/$BUILD_ID/$f"
  done < <(find "$EXPORT" -type f -print0)
fi

# ---------------------------------------------------------------- play page and _redirects
log "Writing site/public/play/index.html and site/public/_redirects"
if [[ -n "$BUILD_ID" ]]; then
  GAME_URL="/play/$BUILD_ID/index.html"
  STAGE='    <div class="stage" id="stage">
      <button class="stage-start" id="start" type="button" aria-describedby="stage-note">
        <img src="/img/banner-adventure-in-paradise-1600.png" width="1600" height="791" alt="">
        <span class="btn btn-play btn-big"><svg aria-hidden="true" viewBox="0 0 24 24" width="22" height="22"><path d="M7 4.5v15l12-7.5z" fill="currentColor"/></svg> Start the game</span>
      </button>
    </div>
    <p class="fineprint" id="stage-note">Loads about 10 MB. Click inside the game once to turn on sound.
      <a href="'"$GAME_URL"'">Open the game in its own window</a> &middot;
      <button class="linkish" id="fullscreen" type="button">Full screen</button></p>'
  SCRIPT='<script>
(function () {
  var stage = document.getElementById("stage");
  var frame = null;
  function start() {
    frame = document.createElement("iframe");
    frame.src = "'"$GAME_URL"'";
    frame.title = "'"$TITLE"' (game)";
    frame.allow = "autoplay; fullscreen; gamepad";
    frame.allowFullscreen = true;
    stage.replaceChildren(frame);
    frame.focus();
  }
  document.getElementById("start").addEventListener("click", start);
  document.getElementById("fullscreen").addEventListener("click", function () {
    if (!frame) start();
    var el = frame || stage;
    (el.requestFullscreen || el.webkitRequestFullscreen || function () {}).call(el);
  });
})();
</script>'
  printf '/play/current/*  /play/%s/:splat  302\n' "$BUILD_ID" >"$PUBLIC/_redirects"
else
  STAGE='    <div class="stage stage-empty"><p>The browser build is not available yet. Check back soon.</p></div>'
  SCRIPT=''
  rm -f "$PUBLIC/_redirects"
fi
cat >"$PLAY/index.html" <<EOF
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Play $TITLE</title>
<meta name="description" content="Play $TITLE, a free companion game, in your browser.">
<meta name="theme-color" content="#fdf6e3">
<meta name="color-scheme" content="light">
<link rel="canonical" href="https://$SITE_HOST/play/">
<link rel="icon" href="/favicon.ico" sizes="32x32">
<link rel="icon" href="/icon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="preload" href="/fonts/fredoka.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="/css/site.css">
<style>
  .play-page { padding: clamp(28px, 5vw, 56px) 0; }
  .play-page h1 { font-size: clamp(1.8rem, 1.3rem + 2vw, 2.6rem); text-align: center; }
  .back { display: inline-block; margin-bottom: 14px; font: 500 1rem/1 var(--display); color: var(--plum); }
  .stage { position: relative; aspect-ratio: 16 / 9; width: 100%; background: var(--plum-deep);
    border-radius: var(--radius); box-shadow: var(--shadow); overflow: hidden; }
  .stage iframe { position: absolute; inset: 0; width: 100%; height: 100%; border: 0; display: block; }
  .stage-start { all: unset; position: absolute; inset: 0; cursor: pointer; display: grid; place-items: center; }
  .stage-start img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; opacity: .75; }
  .stage-start .btn { position: relative; }
  .stage-start:focus-visible .btn { outline: 3px solid var(--white); outline-offset: 4px; }
  .stage-empty { display: grid; place-items: center; color: var(--cream); text-align: center; padding: 24px; }
  .stage:fullscreen { border-radius: 0; }
  .linkish { all: unset; cursor: pointer; text-decoration: underline; color: var(--pink-ink); }
  .linkish:focus-visible { outline: 2px solid var(--plum); }
  .play-page .fineprint { text-align: center; }
</style>
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header class="topbar">
  <a class="brand" href="/" aria-label="$TITLE home">
    <img src="/icon.svg" alt="" width="28" height="28">
    <span>$TITLE</span>
  </a>
</header>
<main id="main" class="play-page">
  <div class="wrap">
    <a class="back" href="/">&larr; Back to the $TITLE site</a>
    <h1>Play $TITLE</h1>
$STAGE
  </div>
</main>
$SCRIPT
</body>
</html>
EOF
echo "play page -> ${BUILD_ID:-not available}"

# ---------------------------------------------------------------- wrangler.toml and worker.js
log "Generating site/wrangler.toml and site/src/worker.js"
{
  echo "# Generated by tools/deploy_site.sh from site/site.config.json. Do not edit by hand."
  echo "name = \"$WORKER_NAME\""
  echo 'main = "src/worker.js"'
  echo "compatibility_date = \"$COMPAT_DATE\""
  [[ "$CUSTOM_DOMAIN" == true ]] || echo 'workers_dev = true'
  echo
  echo '[assets]'
  echo 'directory = "./public"'
  echo 'binding = "ASSETS"'
  echo 'not_found_handling = "404-page"'
  if ((${#OVERSIZED[@]})); then
    printf 'run_worker_first = ['
    sep=""
    for f in "${OVERSIZED[@]}"; do printf '%s"/play/*/%s"' "$sep" "$f"; sep=", "; done
    echo ']'
    if use_r2; then
      echo
      echo '[[r2_buckets]]'
      echo 'binding = "GAME"'
      echo "bucket_name = \"$BUILD_BUCKET\""
    fi
  fi
  echo
  if [[ "$CUSTOM_DOMAIN" == true ]]; then
    echo '[[routes]]'
    echo "pattern = \"$SITE_HOST\""
    echo 'custom_domain = true'
  fi
} >"$SITE/wrangler.toml"

mkdir -p "$SITE/src"
NAMES_RE=""
for f in "${OVERSIZED[@]}"; do NAMES_RE+="${NAMES_RE:+|}${f//./\\.}"; done
# Review channels on the trusted host: the player-facing worker proxies /play/<channel>/... to the
# channel's own Pages project and rewrites its redirects under the prefix, so a test build never
# replaces the player-facing files and never asks a browser to trust a fresh pages.dev host (Chrome
# Safe Browsing interstitials on new hosts). A channel's own worker serves its files directly.
emit_review_consts() {
  [[ -z "$CHANNEL" && ${#REVIEW_CHANNELS[@]} -gt 0 ]] || return 0
  echo "const REVIEW_CHANNELS = $(printf '%s\n' "${REVIEW_CHANNELS[@]}" | jq -Rc . | jq -sc .);"
  echo "const REVIEW_PROJECT = \"$WORKER_NAME\";"
  echo
}
emit_review_proxy() {
  [[ -z "$CHANNEL" && ${#REVIEW_CHANNELS[@]} -gt 0 ]] || return 0
  cat <<'EOF'
    // Review channels (deploy_site.sh --channel <name>, site.config.json review_channels): proxied
    // from /play/<channel>/... to <project>-<channel>.pages.dev/play/..., redirects rewritten.
    const rc = new URL(req.url).pathname.match(/^\/play\/([a-z0-9-]{1,24})\/(.*)$/);
    if (rc && (env.REVIEW_CHANNELS ? env.REVIEW_CHANNELS.split(",") : REVIEW_CHANNELS).includes(rc[1])) {
      if (req.method !== "GET" && req.method !== "HEAD") {
        return new Response("Method not allowed", { status: 405, headers: { allow: "GET, HEAD" } });
      }
      const u0 = new URL(req.url);
      const target = new URL("https://" + REVIEW_PROJECT + "-" + rc[1] + ".pages.dev/play/" + rc[2] + u0.search);
      const fh = new Headers({ accept: req.headers.get("accept") || "*/*" });
      const range = req.headers.get("range");
      if (range) fh.set("range", range);
      const r = await fetch(new Request(target, { method: req.method, headers: fh, redirect: "manual" }));
      const h = new Headers(r.headers);
      const loc = h.get("location");
      if (loc && loc.startsWith("/play/")) h.set("location", "/play/" + rc[1] + loc.slice("/play".length));
      h.set("x-review-channel", rc[1]);
      return new Response(r.body, { status: r.status, headers: h });
    }
EOF
}
{
  echo '// Generated by tools/deploy_site.sh from site/site.config.json. Do not edit by hand.'
  echo '// Serves the build files too big for static assets (oversized_files) from R2; every'
  echo '// other request goes to the static assets in ./public. _headers does not apply to'
  echo '// responses built here, so the headers are set below.'
  if [[ -n "$NAMES_RE" && "$OVERSIZED_MODE" == gzip ]]; then
    cat <<EOF
const TYPES = { wasm: "application/wasm", pck: "application/octet-stream", js: "text/javascript" };
const OVERSIZED = /^\/play\/([\w.-]+)\/($NAMES_RE)\$/;

// oversized_mode "gzip": a file ships either as static <name>.gz, served with
// Content-Encoding: gzip (encodeBody "manual" passes the bytes through, the browser inflates
// it), or, when even its gzip is over the 25 MiB static-file limit (the .pck: its MP3s don't
// compress), as static parts <name>.part00, .part01, ... listed in <name>.parts.json
// ({"size": bytes, "parts": [names]}), streamed back to back as one response of that length.
// Pages answers a missing file with the HTML landing page, so each lookup checks the type.
const isHtml = (r) => (r.headers.get("content-type") || "").includes("text/html");

function baseHeaders(name) {
  const h = new Headers();
  h.set("content-type", TYPES[name.split(".").pop()] || "application/octet-stream");
  h.set("cache-control", "public, max-age=31536000, immutable");
  h.set("x-content-type-options", "nosniff");
  h.set("strict-transport-security", "max-age=31536000");
  return h;
}

EOF
    emit_review_consts
    cat <<EOF
export default {
  async fetch(req, env, ctx) {
EOF
    emit_review_proxy
    cat <<EOF
    const url = new URL(req.url);
    const m = url.pathname.match(OVERSIZED);
    if (m) {
      if (req.method !== "GET" && req.method !== "HEAD") {
        return new Response("Method not allowed", { status: 405, headers: { allow: "GET, HEAD" } });
      }
      const asset = (suffix) => env.ASSETS.fetch(new Request(new URL(url.pathname + suffix, url)));
      const man = await asset(".parts.json");
      let info = null;
      if (man.ok && !isHtml(man)) {
        try { info = await man.json(); } catch { info = null; }
      }
      if (info && Number.isSafeInteger(info.size) && Array.isArray(info.parts) && info.parts.length) {
        const h = baseHeaders(m[2]);
        h.set("content-length", String(info.size));
        if (req.method === "HEAD") return new Response(null, { headers: h });
        const { readable, writable } = new FixedLengthStream(info.size);
        const dir = url.pathname.slice(0, url.pathname.lastIndexOf("/") + 1);
        ctx.waitUntil((async () => {
          try {
            for (const part of info.parts) {
              const r = await env.ASSETS.fetch(new Request(new URL(dir + part, url)));
              if (!r.ok || isHtml(r)) throw new Error("missing part " + part);
              await r.body.pipeTo(writable, { preventClose: true });
            }
            await writable.close();
          } catch (e) {
            await writable.abort(e);
          }
        })());
        return new Response(readable, { headers: h });
      }
      const gz = await asset(".gz");
      if (!gz.ok || isHtml(gz)) return new Response("Not found", { status: 404 });
      const h = baseHeaders(m[2]);
      h.set("content-encoding", "gzip");
      const etag = gz.headers.get("etag");
      if (etag) h.set("etag", etag);
      return new Response(req.method === "HEAD" ? null : gz.body, { headers: h, encodeBody: "manual" });
    }
    return env.ASSETS.fetch(req);
  }
};
EOF
  elif [[ -n "$NAMES_RE" ]]; then
    cat <<EOF
const TYPES = { wasm: "application/wasm", pck: "application/octet-stream", js: "text/javascript" };
const OVERSIZED = /^\/play\/([\w.-]+)\/($NAMES_RE)\$/;

EOF
    emit_review_consts
    cat <<EOF
export default {
  async fetch(req, env) {
EOF
    emit_review_proxy
    cat <<EOF
    const m = new URL(req.url).pathname.match(OVERSIZED);
    if (m) {
      if (req.method !== "GET" && req.method !== "HEAD") {
        return new Response("Method not allowed", { status: 405, headers: { allow: "GET, HEAD" } });
      }
      const obj = await env.GAME.get(\`\${m[1]}/\${m[2]}\`);
      if (!obj) return new Response("Not found", { status: 404 });
      const h = new Headers();
      obj.writeHttpMetadata(h);
      h.set("etag", obj.httpEtag);
      h.set("content-type", TYPES[m[2].split(".").pop()] || "application/octet-stream");
      h.set("cache-control", "public, max-age=31536000, immutable");
      h.set("x-content-type-options", "nosniff");
      h.set("strict-transport-security", "max-age=31536000");
      return new Response(req.method === "HEAD" ? null : obj.body, { headers: h });
    }
    return env.ASSETS.fetch(req);
  }
};
EOF
  else
    emit_review_consts
    cat <<'EOF'
export default {
  async fetch(req, env) {
EOF
    emit_review_proxy
    cat <<'EOF'
    return env.ASSETS.fetch(req);
  }
};
EOF
  fi
} >"$SITE/src/worker.js"
if [[ "$OVERSIZED_MODE" == gzip ]]; then
  echo "worker routes: ${OVERSIZED[*]:-(none)} -> static .gz, or static parts when the gzip is over 25 MiB"
else
  echo "worker routes: ${OVERSIZED[*]:-(none)} -> R2 ${BUILD_BUCKET:-(none)}"
fi

# ---------------------------------------------------------------- absolute social-card URLs
log "Making social-card URLs in site/public/index.html absolute (https://$SITE_HOST)"
python3 -I - "$PUBLIC/index.html" "$SITE_HOST" <<'PY'
import re, sys
path, host = sys.argv[1], sys.argv[2]
base = f"https://{host}"
with open(path, encoding="utf-8") as f:
    src = f.read()
s = src
# The comment above the social tags explains where the absolute URLs come from.
note = ("<!-- Social-card URLs (og:image, twitter:image, og:url, canonical) are absolute and are\n"
        "     rewritten from ../site.config.json (site_host) by tools/deploy_site.sh on every deploy;\n"
        "     edit the host there, not here. -->\n")
s = re.sub(r"<!-- (?:Host-relative URLs on purpose|Social-card URLs).*?-->\n", lambda m: note, s, count=1, flags=re.S)
if note not in s:
    s = s.replace('<meta property="og:title"', note + '<meta property="og:title"', 1)
for prop, attr in (("og:image", "property"), ("twitter:image", "name")):
    s, n = re.subn(rf'(<meta {attr}="{prop}" content=")(?:https?://[^/"]+)?(/[^"]*")',
                   lambda m: m.group(1) + base + m.group(2), s)
    if n != 1:
        sys.exit(f"index.html: expected one {prop} tag, found {n}")
og_url = f'<meta property="og:url" content="{base}/">'
if re.search(r'<meta property="og:url"', s):
    s = re.sub(r'<meta property="og:url" content="[^"]*">', og_url, s)
else:
    s = s.replace('<meta property="og:site_name"', og_url + '\n<meta property="og:site_name"', 1)
canon = f'<link rel="canonical" href="{base}/">'
if re.search(r'<link rel="canonical"', s):
    s = re.sub(r'<link rel="canonical" href="[^"]*">', canon, s)
else:
    s = s.replace('<link rel="icon"', canon + '\n<link rel="icon"', 1)
for needle in (og_url, canon):
    if needle not in s:
        sys.exit(f"index.html: could not place {needle}")
if s != src:
    with open(path, "w", encoding="utf-8") as f:
        f.write(s)
    print("index.html updated (commit it)")
else:
    print("index.html already up to date")
PY

# ---------------------------------------------------------------- link check
log "Version"
python3 -I tools/version.py check || die "version not stamped; nothing was uploaded or deployed"

log "Link check (PW-13)"
allow=()
for f in "${OVERSIZED[@]}"; do allow+=(--allow "/play/*/$f"); done
ext=()
((CHECK_EXTERNAL)) && ext=(--check-external)
python3 -I tools/check_site_links.py "$PUBLIC" --host "$SITE_HOST" "${allow[@]}" "${ext[@]}" \
  || die "link check failed; nothing was uploaded or deployed"

# ---------------------------------------------------------------- R2 and deploy
cd "$SITE"
if ((DRY_RUN)); then
  log "Dry run: skipping R2 upload; wrangler deploy --dry-run"
  if ((!SITE_ONLY)) && use_r2; then
    for f in "${OVERSIZED[@]}"; do echo "would upload $f -> r2://$BUILD_BUCKET/$BUILD_ID/$f"; done
  fi
  "${WRANGLER[@]}" deploy --dry-run --outdir "$TMP/wrangler-dist"
  log "Dry run OK (build ${BUILD_ID:-none}, https://$SITE_HOST/)"
  exit 0
fi

if ((!SITE_ONLY)) && use_r2; then
  log "R2: bucket $BUILD_BUCKET"
  if "${WRANGLER[@]}" r2 bucket info "$BUILD_BUCKET" >/dev/null 2>&1; then
    echo "bucket exists"
  else
    "${WRANGLER[@]}" r2 bucket create "$BUILD_BUCKET"
  fi
  for f in "${OVERSIZED[@]}"; do
    case "$f" in
      *.wasm) ct=application/wasm ;;
      *.js) ct=text/javascript ;;
      *) ct=application/octet-stream ;;
    esac
    echo "uploading $f -> $BUILD_BUCKET/$BUILD_ID/$f ($ct)"
    "${WRANGLER[@]}" r2 object put "$BUILD_BUCKET/$BUILD_ID/$f" --remote --force \
      --file "$TMP/export/$f" --content-type "$ct" \
      --cache-control "public, max-age=31536000, immutable"
  done
fi

if [[ "$HOST_TYPE" == pages ]]; then
  log "Cloudflare Pages: project $WORKER_NAME"
  STAGE="$TMP/pages"
  rm -rf "$STAGE"
  cp -a "$PUBLIC" "$STAGE"
  cp "$SITE/src/worker.js" "$STAGE/_worker.js"
  if ! "${WRANGLER[@]}" pages project list 2>/dev/null | grep -q "│ $WORKER_NAME "; then
    # --force: create the project on classic Pages (what the live project is). Without it, current
    # wrangler delegates new projects to the Workers API, which this account's token refuses.
    "${WRANGLER[@]}" pages project create "$WORKER_NAME" --production-branch main --force
  fi
  "${WRANGLER[@]}" pages deploy "$STAGE" --project-name "$WORKER_NAME" --branch main \
    --commit-hash "$(git -C "$ROOT" rev-parse HEAD)" --commit-message "build $BUILD_ID" --commit-dirty=true
  if [[ "$CUSTOM_DOMAIN" == true ]]; then
    log "Pages custom domain $SITE_HOST"
    python3 -I - "$WORKER_NAME" "$SITE_HOST" <<'PY'
import json, os, sys, urllib.error, urllib.request
project, host = sys.argv[1], sys.argv[2]
acct, tok = os.environ["CLOUDFLARE_ACCOUNT_ID"], os.environ["CLOUDFLARE_API_TOKEN"]
base = f"https://api.cloudflare.com/client/v4/accounts/{acct}/pages/projects/{project}/domains"
def call(url, data=None):
    req = urllib.request.Request(url, data=json.dumps(data).encode() if data else None,
                                 method="POST" if data else "GET",
                                 headers={"Authorization": f"Bearer {tok}", "Content-Type": "application/json"})
    try:
        return json.load(urllib.request.urlopen(req, timeout=60))
    except urllib.error.HTTPError as e:
        return json.load(e)
have = {d["name"]: d for d in call(base).get("result") or []}
d = have.get(host) or call(base, {"name": host}).get("result")
if not d:
    sys.exit(f"could not add custom domain {host}")
print(f"{host}: status {d.get('status')}; DNS: CNAME {host} -> {project}.pages.dev")
PY
  fi
  if [[ -n "$CHANNEL" ]]; then
    # The generated wrangler.toml named the channel project; put the committed one back so the
    # tree does not carry the channel's name into the next player-facing deploy.
    git -C "$ROOT" checkout -q -- site/wrangler.toml 2>/dev/null || true
    log "Deployed build ${BUILD_ID:-none} to review channel $CHANNEL: https://$WORKER_NAME.pages.dev/play/current/ (the player-facing site is untouched)"
  else
  log "Deployed build ${BUILD_ID:-none} to https://$WORKER_NAME.pages.dev/ and https://$SITE_HOST/ (play: /play/)"
  fi
  exit 0
fi

log "wrangler deploy"
"${WRANGLER[@]}" deploy
log "Deployed build ${BUILD_ID:-none} to https://$SITE_HOST/ (play: https://$SITE_HOST/play/)"
