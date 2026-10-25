# SOP-09: Release checklist for a public game

Status: draft
Owner: Brett Whitty
Applies to: game projects (any engine; Godot specifics are marked as such)
Last reviewed: 2026-10-24
Related SOPs: SOP-11 (11-versioning-and-playtest-cadence.md: the version, tag and build id that a release candidate carries); SOP-03 (03-asset-style-bible-and-prompts.md: prompts for key art, icon, title and trailer footage); SOP-04 (04-generative-render-pipeline.md: renders those prompts); SOP-05 (05-voice-cloning-pipeline.md: voice reference provenance and model licence); SOP-06 (06-quote-sourcing-vv.md: real-person quote evidence); SOP-07 (07-playtest-bug-triage.md: playtest pass before release); SOP-08 (08-session-hygiene-tracking.md: issues, commits and push for every checklist session). Companion template: `templates/promo-site-plan.md` (the promotion website). A new game's repository gets these files as described in section 8.3.

Legal items in this SOP are neutral summaries with sources. They are not legal advice. Items marked "author decides" are decisions for the author, ideally with counsel.

## 1. Purpose

Take a playable game to a public release: a finished front end, tested builds per platform, licence and provenance records, a public repository, a promotion website, store pages and a press kit. The checklist in section 5 is the same for every game; each game keeps its own status file (section 8) that points at evidence in its repository.

## 2. When to use / when not to

Use when:
- A game is moving from internal builds to anything public: an open repository, a web build on a public URL, an itch.io or Steam page.
- A new game starts and needs a release plan from day one (follow section 8.3, mark everything "missing").
- Before every public version bump, to re-check items that can regress (build sizes, disclosures, credits, links).

Do not use when:
- The build is a private playtest for named testers; use SOP-07 and skip the public items.
- The work is a jam entry with its own rules; follow the jam's rules and use only phases 1, 3 and 4.

## 3. Inputs and prerequisites

- `{game_slug}`: short lowercase id, used for worker, bucket and repo names.
- `{site_host}`: the public hostname of the promotion website. A subdomain of a shared domain (`{game_slug}.{site_domain}`), the apex of the game's own domain (`{game_domain}`), or any other name the author picks. Every check below uses `{site_host}`, never a hard-coded parent domain.
- `{project}`: path to the engine project (for Godot, the folder holding `project.godot`).
- `{design_doc}`: the design document that holds milestone scope.
- `{test_cmd}`: one command that runs every automated test and exits non-zero on any failure.
- `{instance_file}`: the per-game status file, usually `docs/RELEASE_CHECKLIST.md`, made from the skeleton in section 8.
- `{site_plan}`: the per-game values file for the website, usually `docs/PROMO_SITE_PLAN.md`, made from `templates/promo-site-plan.md`.
- `{forge_host}`: the forge that holds the repository; `{tracker}`: the issue tracker command (SOP-08); `{host_cli}`: the hosting provider's command-line tool.
- DNS access for the zone that holds `{site_host}`; a hosting account (the site plan names one).
- Author decisions recorded before phase 4 starts: code licence, asset licence, store list, whether the game earns or raises money.
- For games with real people, cloned voices or generated assets: the provenance records SOP-05 and SOP-06 produce.

## 4. Roles and tools

| Role | Does | Does not |
|---|---|---|
| Author (human) | Decides licences, stores, prices, domain, legal posture, release date; approves disclosure text; reviews every real-person line; owns accounts (DNS, hosting, stores, forge, signing certificates). | Write status files or run audits. |
| Controller agent | Audits the repo against the checklist, keeps `{instance_file}` current, builds menus, scripts, configs and docs, runs builds and size checks, files one issue per open item (SOP-08). | Choose a licence, accept a model or store licence, publish disclosure text, or make anything public without the author's go-ahead. |
| Sub-agents | Scoped research (one store's current requirements, one law's current status) returning URLs; repo audits returning paths. | Edit the status file directly; the controller merges findings. |

Tools, by exact name where the tool is fixed:
- Engine export: `godot --headless --path {project} --export-release "{preset}" {out}` (Godot 4).
- Size check: `stat -c %s {file}`.
- DNS: `dig +short NS {zone}` for the zone that holds `{site_host}`.
- Hosting CLI: `{host_cli}` (for Cloudflare, `wrangler`).
- itch.io: `butler push {dir} {user}/{game_slug}:{channel} --userversion {version}`.
- Link check: `lychee` (https://lychee.cli.rs/) or `linkinator` (https://github.com/JustinBeckwith/linkinator).
- Tracker: `{tracker}` (SOP-08).

## 5. Procedure

Each step is one phase. Work the phases in order where an item depends on an earlier one; otherwise run them in parallel. Each item has a stable ID; the instance file uses the same IDs. "Done when" is the acceptance criterion for that item.

1. **Audit and open the instance file.** Copy the skeleton from section 8 to `{instance_file}`. For every ID below, record status (done / partial / missing / n/a), evidence (repo path or command output), owner (author / agent) and notes. List author decisions at the top. File one tracker issue per missing or partial item.
   Check: every ID in this section appears exactly once in `{instance_file}`: `grep -oE '^\| [A-Z]{2}-[0-9]{2}' {instance_file} | sort | uniq -d` prints nothing.

2. **Phase 1: Game complete (GC).**
   - [ ] GC-01 Milestone scopes written. Done when `{design_doc}` names the scope of vertical slice, content complete and release candidate.
   - [ ] GC-02 Main menu complete. Done when it offers New Game, Continue (only with a save), Options, Credits and, on desktop builds, Quit.
   - [ ] GC-03 Pause menu. Done when play can be paused at any time, with Resume, Options and Quit to Menu.
   - [ ] GC-04 Options menu. Done when it holds per-bus volume, text size, subtitle toggle, fullscreen toggle (desktop) and input remapping, and the choices persist across restarts.
   - [ ] GC-05 Audio buses. Done when a bus layout exists with at least Master, Music, SFX and Voice, and every audio player node is on the right bus.
   - [ ] GC-06 Input actions. Done when every control is a named input action in project settings and no script tests raw key codes.
   - [ ] GC-07 Save system. Done when saves carry a schema version; writes are atomic (write a temp file, then rename over the save) and a backup of the previous save is kept before each overwrite; a corrupt, truncated or old save is detected, reported to the player and recovered from the backup rather than silently replaced by a new game; and the player can tell when the game saved.
   - [ ] GC-08 Credits and licences screen. Done when the game shows people credits, tool credits and every third-party licence text, including the engine's, and every notice a model licence requires for its output (all output of that model, not only some of it). Godot: `Engine.get_license_text()`, `get_license_info()`, `get_copyright_info()` (https://docs.godotengine.org/en/stable/about/complying_with_licenses.html).
   - [ ] GC-09 In-game disclosure. Done when any required notice (satire, real people, generated media, cloned voices) shows in the game itself before or at first play, not only in documentation. Guidance on EU AI Act Art. 50 at https://artificialintelligenceact.eu/transparency-rules-article-50/ (a secondary source) says notices only in terms, docs or buried menus are insufficient; the rule itself is Regulation (EU) 2024/1689 Art. 50 (https://eur-lex.europa.eu/eli/reg/2024/1689/oj).
   - [ ] GC-10 Application metadata. Done when name, version, description, icon and boot splash are set in the project, so exports do not ship engine defaults.
   - [ ] GC-11 Placeholders gone. Done when every placeholder asset is replaced or listed in the instance file as intentionally kept.
   - [ ] GC-12 Web audio start. Done when the web build waits for a click, tap or key before any audio, because browsers may block autoplay (https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).
   - [ ] GC-13 Web save persistence. Web builds only. Done when save persistence has been tested in each target browser (normal window, private window, and inside every iframe the game is embedded in); the game shows a warning when `OS.is_userfs_persistent()` is false (Godot; it can give false positives, https://docs.godotengine.org/en/stable/classes/class_os.html); and the player can export the save to a file and import it again. Why: the Godot web page says `user://` persists only when the browser allows IndexedDB, not in private windows, and inside an iframe only when third-party cookies are allowed (https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html). Saves are tied to the page's origin, so each host that serves the build (the site, a self-hosted or staging host, itch.io) keeps a separate save.
   - [ ] GC-14 End of content. Done when the last playable point of the release shows a clear "end of content" or "demo ends here" message, with what comes next (wishlist, site, signup), so a vertical-slice release does not just stop.
   Check: open the exported game and walk the menu tree; every GC item marked done has a repo path as evidence.

3. **Phase 2: Quality and accessibility (QA).**
   - [ ] QA-01 One test command. Done when `{test_cmd}` runs every test and exits non-zero on any failure.
   - [ ] QA-02 CI. Done when tests run on every push to the main branch and a failure is visible on the forge.
   - [ ] QA-03 Clean test output. Done when tests finish with no leak, orphan or error lines.
   - [ ] QA-04 Tests isolated from player data. Done when tests use a temporary save path and never read or write the real save.
   - [ ] QA-05 Subtitles. Done when every spoken line (recorded clip or text-to-speech) is also shown as text, and the shown text matches what is spoken. Check every direct call to the voice or speech API, not only the dialogue system.
   - [ ] QA-06 Readable text. Done when default text is readable at the target resolution and text size is adjustable (Game Accessibility Guidelines, basic tier: https://gameaccessibilityguidelines.com/).
   - [ ] QA-07 Input coverage. Done when the game is playable keyboard-only and mouse-only (touch-only too if mobile web is a target).
   - [ ] QA-08 Accessibility list. Done when the instance file lists which Steam accessibility features the game supports, using Valve's categories even if not on Steam (https://partner.steamgames.com/doc/accessibility_features).
   - [ ] QA-09 Screen reader evaluated. Done when the author has decided whether to enable engine screen-reader support (Godot 4.5+ AccessKit, experimental: https://godotengine.org/releases/4.5/) and recorded the result.
   - [ ] QA-10 Localisation ready. Done when UI and dialogue strings go through translation keys, a fallback locale is set, the template (POT) covers every dialogue file and a pseudolocalisation run shows no hard-coded strings (https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html).
   - [ ] QA-11 Performance measured. Done when load time and frame rate are recorded on the minimum target machine and in Chromium, Firefox and Safari for web builds (Safari has WebGL 2 issues per the Godot web export page).
   - [ ] QA-12 Release playtest. Done when a full playthrough by someone other than the developer has been triaged with SOP-07 and no blocker issues remain open.
   - [ ] QA-13 Gamepad. Done when every input action has a joypad binding, every menu can be reached and used by focus navigation with a pad alone, and the web build has been tried with a pad in each target browser. On the web a gamepad is not detected until one of its buttons is pressed, its mapping can differ by browser, OS and pad, and many browser features need a secure (https) context (https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html; https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html).
   - [ ] QA-14 Steam Deck. Only if Steam is chosen. Done when the build meets Valve's Deck compatibility criteria (input, display, seamlessness, system support) and has been submitted for review (https://partner.steamgames.com/doc/steamhardware/compat).
   - [ ] QA-15 Crash and error capture. Done when the author has decided how crashes and script errors are captured (none, a local log file the player can attach to a report, or a reporting service), the decision is reflected in LP-11, and the feedback route (LA-04) says what to attach.
   - [ ] QA-16 First ten minutes. Done when, on every target browser and OS, a fresh start is played for ten minutes and none of these occur: black or blank screen, no audio after the first click, input that stops responding, or a save lost on reload. Any one of them blocks release. Repeat on every release candidate.
   - [ ] QA-17 Speech fallback. Only if the game falls back to system text-to-speech. Done when the fallback has been heard in each target browser and OS (browser speech voices and support vary), and a line with no voice available still shows as text (QA-05).
   Check: `{test_cmd}; echo $?` prints 0; the instance file has a QA-08 list, a QA-11 table and a QA-16 result per target.

4. **Phase 3: Builds and distribution (BD).**
   - [ ] BD-01 Export presets. Done when there is one preset per target platform in the project.
   - [ ] BD-02 Export templates. Done when the build machine (and CI image) has templates for every preset at the exact engine version.
   - [ ] BD-03 Version number. Done when the project's version field holds a SemVer string (https://semver.org/) and the game shows it (menu or credits).
   - [ ] BD-04 Changelog. Done when `CHANGELOG.md` follows Keep a Changelog: newest first, dated, Added/Changed/Deprecated/Removed/Fixed/Security (https://keepachangelog.com/en/1.1.0/).
   - [ ] BD-05 Tags and releases. Done when each release is a `v{version}` tag with a forge Release carrying the builds and the changelog excerpt.
   - [ ] BD-06 Size limits. Done when a script compares every web build file against each chosen host's limits and fails the build if one is over. Cloudflare Workers static assets: 25 MiB per file, 20,000 files per version on the free plan (https://developers.cloudflare.com/workers/platform/limits/). itch.io HTML5: 200 MB per file, 1,000 files, 500 MB total once extracted (https://itch.io/docs/creators/html5).
   - [ ] BD-07 Web serving. Done when the host serves `.wasm` as `application/wasm`, compresses `.wasm` and `.pck`, uses https only (including any URL a deploy script prints or reads from its environment), and sends COOP/COEP headers if (and only if) the build uses threads (https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).
   - [ ] BD-08 Windows signing. Done when the build is signed, or the author has decided to ship unsigned and the download page says so. If signing, do not embed the PCK (https://docs.godotengine.org/en/4.4/tutorials/export/exporting_for_windows.html).
   - [ ] BD-09 macOS notarization. Done when the build is notarized and stapled, or the author has dropped macOS or accepted that Gatekeeper will block it (https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html).
   - [ ] BD-10 One build command. Done when one script exports every preset into a versioned output folder.
   - [ ] BD-11 itch.io upload. Done when builds go up with `butler push` to platform-named channels with `--userversion` (https://itch.io/docs/butler/pushing).
   - [ ] BD-12 Steam Direct. Only if Steam is chosen. Done when the fee is paid, the 30-day wait and the 2-week Coming Soon period are scheduled and the build passed review (https://partner.steamgames.com/steamdirect).
   - [ ] BD-13 Download budget. Web builds only. Done when the instance file records a target for total compressed download and first-load time, the measured numbers meet it, the loading screen shows progress, and audio import settings have been checked (compressed formats such as Ogg Vorbis or QOA rather than uncompressed PCM where quality allows: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_audio_samples.html).
   - [ ] BD-14 Export contents reviewed. Done when the list of files the export filters include has been read and every shipped data file is meant to be public (internal notes, tool flags and work-in-progress data either removed from the export or accepted by the author).
   Check: for each web file, `[ $(stat -c %s {file}) -le {host_file_limit} ]`; `git tag -l 'v*'` lists the release.

5. **Phase 4: Legal and provenance (LP).**
   - [ ] LP-01 Code licence. Done when `LICENSE` at the repo root states the code licence (author decides).
   - [ ] LP-02 Asset licence. Done when a separate file (`ASSETS_LICENSE` or `NOTICE`) states the licence for art, audio, video and text, which may differ from the code licence (author decides).
   - [ ] LP-03 Third-party notices. Done when a `THIRD_PARTY.md` (or credits data) lists the engine, every addon, font, library, dataset and model with its licence, and the same list ships in the game (GC-08). Fonts: list each shipped font file; if none is shipped, record that the engine's default font is used and is covered by the engine's licence text. Datasets: say whether a shipped file is a database derived from the dataset, since some data licences (for example ODbL, https://opendatacommons.org/licenses/odbl/1-0/) set share-alike terms for derived databases as well as attribution.
   - [ ] LP-04 Generated asset provenance. Done when every shipped generated asset can be traced to tool, model, date and prompt file, in a sources file next to the assets.
   - [ ] LP-05 Voice reference provenance. Done when each cloned voice has its source URL, time span and capture date recorded (SOP-05 steps 4 and 5) and every referenced recording exists on the render machine.
   - [ ] LP-06 Model and tool licences. Done when the licence of every generation model whose output ships is recorded, its notice obligations are met for every output of that model (including stock or built-in voices, not only cloned ones), and its commercial-use terms are checked against how the game earns or raises money (author decides). Watch for non-commercial model licences whose terms reach the output.
   - [ ] LP-07 Generator terms. Done when the terms and use policies of each image, music and video service used are recorded with the date read (e.g. https://ai.google.dev/gemini-api/terms and https://policies.google.com/terms/generative-ai/use-policy).
   - [ ] LP-08 Real-person content. Only if real people appear. Done when the instance file lists every real person depicted, named, quoted, voiced or referred to (in data, dialogue, art, level design and file names), not only those quoted or voiced; every line attributed to a real person is a sourced quote (SOP-06); the parody framing is explicit; and the author has reviewed, with counsel for the countries where the game is offered, each of these as a separate question:
     - Parody and emotional distress: Hustler v. Falwell (1988) bars recovery for intentional infliction of emotional distress by public figures over parody that cannot reasonably be read as stating actual facts, absent a false statement of fact made with actual malice (https://www.law.cornell.edu/supremecourt/text/485/46). It does not settle defamation or publicity claims.
     - Defamation and false light: a statement that can reasonably be read as implying a false fact about a real person is a separate consideration, and it is raised when real living people are placed beside a notorious figure or crime. Public officials and figures must show actual malice (New York Times v. Sullivan, https://www.law.cornell.edu/supremecourt/text/376/254); there is no separate blanket protection for "opinion", and the question is whether the statement implies a provably false fact (Milkovich v. Lorain Journal, https://www.law.cornell.edu/supremecourt/text/497/1).
     - Publicity and likeness: Hart v. Electronic Arts, 717 F.3d 141 (3d Cir. 2013) (https://law.justia.com/cases/federal/appellate-courts/ca3/11-3750/11-3750-2013-05-21.html).
     - Voice: Midler v. Ford (https://law.justia.com/cases/federal/appellate-courts/F2/849/460/37485/); state laws such as Tennessee's ELVIS Act add simulated voice to publicity rights with a First Amendment exemption for satire and parody (https://www.manatt.com/insights/newsletters/client-alert/tennessees-elvis-act-expands-publicity-rights-for).
   - [ ] LP-09 AI disclosure text. Done when one disclosure text names the tools actually used for shipped content and is used in the game (GC-09), on the site, in the README and on each store form. Steam asks about AI in its Content Survey (https://partner.steamgames.com/doc/gettingstarted/contentsurvey). itch.io's disclosure (post of 2024-11-20) is mandatory for asset creators and encouraged, not required, for games (https://itch.io/t/4309690/generative-ai-disclosure-tagging).
   - [ ] LP-10 Content advisory and ratings. Done when a self-declared content advisory (language, crude humour, real-person satire, other themes) is written, and a rating is obtained wherever a chosen store requires one. IARC works only through participating storefronts; Steam and itch.io are not on the list (https://www.globalratings.com/storefronts/).
   - [ ] LP-11 Privacy policy. Done when the site and game either collect nothing (stated) or a policy names what is collected, why, by which processor and for how long, including crash reports (QA-15), analytics (PW-11) and signup (PW-12) (https://developers.cloudflare.com/web-analytics/ for one analytics example).
   - [ ] LP-12 Human authorship record. Done when the human contribution to generated assets (prompt files, selection, edits, composition) is traceable in the repo. The US Copyright Office's 2025 report says copyright protects human-determined expression, which may limit what an asset licence can grant for generated material (https://copyright.gov/newsnet/2025/1060.html).
   Check: `test -f LICENSE && test -f THIRD_PARTY.md`; every shipped asset folder has a sources file or is covered by one; the LP-08 list matches a search of the game's data for each listed name.

6. **Phase 5: Public repo (PR).**
   - [ ] PR-01 README. Done when it has a one-line pitch, a screenshot or GIF, the play link, build and test commands, the licence summary, the content advisory and the AI disclosure.
   - [ ] PR-02 CONTRIBUTING.md. Done when it says whether outside contributions are accepted and how.
   - [ ] PR-03 CODE_OF_CONDUCT.md. Done when a code of conduct with a contact is present (Contributor Covenant 3.0 is one option: https://ethicalsource.dev/blog/contributor-covenant-3/).
   - [ ] PR-04 SECURITY.md. Done when it gives a private reporting route (https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file).
   - [ ] PR-05 Issue and PR templates. Done when templates live in `.github/`, which both Gitea and GitHub read (https://docs.gitea.com/usage/issues-prs/issue-pull-request-templates/).
   - [ ] PR-06 Internal files reviewed. Done when every tracked dot-directory and log has been reviewed and either removed from the public tree or kept on purpose (author decides), and no internal host, address or absolute home path remains in tracked files.
   - [ ] PR-07 Secrets scan. Done when the full history has been scanned for keys and tokens and none are found (or they are rotated).
   - [ ] PR-08 Repo metadata. Done when description, topics, website link and a 1280x640 social preview image are set (https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview).
   - [ ] PR-09 Mirror. Done when the author has decided on a mirror and, if yes, a push mirror is configured and verified.
   Check: `git ls-files | grep -E '^\.[a-z]+/'` lists only directories the author kept on purpose; `ls CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md .github/ISSUE_TEMPLATE` succeeds.

7. **Phase 6: Promo website (PW).**
   - [ ] PW-01 Domain. Done when the hostname spelling is confirmed by the author and its DNS zone is on the hosting provider: `dig +short NS {zone}`.
   - [ ] PW-02 Site source. Done when the site lives in the repo (`site/`) with its hosting config, and every per-game value sits in one config file (`site/site.config.json`, schema in `templates/promo-site-plan.md`).
   - [ ] PW-03 Landing page. Done when it shows key art, pitch, trailer, Play button and download links.
   - [ ] PW-04 Play page. Done when the web build loads behind a click-to-play poster, in a per-build folder, with a browser note and a download-size warning.
   - [ ] PW-05 Press page. Done when the presskit() fields are filled (https://dopresskit.com/) and a press zip is downloadable.
   - [ ] PW-06 About page. Done when the disclosure text (LP-09), content advisory (LP-10), credits (LP-03) and a contact address are on it.
   - [ ] PW-07 Privacy page. Done when it matches LP-11 and is linked from every page footer and any form.
   - [ ] PW-08 Icons and share images. Done when favicon set, web manifest, Open Graph image (1200x630) and X/Twitter card image (2:1) exist and validate (https://ogp.me/).
   - [ ] PW-09 Headers and caching. Done when HSTS and nosniff are sent, build folders are cached immutable and HTML revalidates.
   - [ ] PW-10 Deploy. Done when one script or CI job deploys the site, with API tokens in secrets, never in the repo.
   - [ ] PW-11 Analytics (optional). Done when the author has chosen none or a cookieless option and LP-11 reflects it.
   - [ ] PW-12 Signup (optional). Done when the author has chosen none, a hosted list or a self-hosted form, and LP-11 reflects it.
   - [ ] PW-13 Link check. Done when a link checker (`lychee` or `linkinator`) runs over the site, README, press kit and store copy before every deploy, and the deploy fails on a broken link or on a redirect to a moved page.
   - [ ] PW-14 Error and fallback pages. Done when the site has a 404 page, and the play page shows a "your browser can't run this" message (with download links) when WebGL 2 is missing or the visitor is on a mobile device the build does not support.
   Check: `curl -sI https://{site_host}/` returns 200 with `strict-transport-security`; `curl -s -o /dev/null -w '%{http_code}' https://{site_host}/no-such-page` prints 404; every page passes an Open Graph debugger.

8. **Phase 7: Store pages and press (SP).**
   - [ ] SP-01 itch.io page. Done when the page has the HTML5 build (or downloads), screenshots, content notes and, if the author chooses, the AI disclosure (encouraged for games, LP-09).
   - [ ] SP-02 Steam assets. Only if Steam is chosen. Done when every capsule and library image is uploaded at Valve's sizes (https://partner.steamgames.com/doc/store/assets).
   - [ ] SP-03 Steam Content Survey. Only if Steam is chosen. Done when the survey, including the AI section, is submitted (https://partner.steamgames.com/doc/gettingstarted/contentsurvey).
   - [ ] SP-04 Trailer. Done when a gameplay-first trailer that reads without sound exists at up to 1920x1080, H.264/AAC (https://partner.steamgames.com/doc/store/trailer).
   - [ ] SP-05 Screenshots and loops. Done when 5 to 10 screenshots at 1920x1080 and 3 to 5 short loops exist.
   - [ ] SP-06 Logo and key art. Done when the logo exists as transparent PNG and SVG, and key art exists at every size a chosen store or the site needs.
   - [ ] SP-07 Press kit. Done when a factsheet, description, features, media zip, credits and contact are published (PW-05).
   - [ ] SP-08 Store copy. Done when short and long descriptions, feature bullets, content warnings, AI disclosure and the accessibility list (QA-08) are written once and reused on every store.
   Check: each store page's public URL is recorded in the instance file.

9. **Phase 8: Launch and after (LA).**
   - [ ] LA-01 Release date. Done when the date is set after checking store wait times and events, and the trailer (SP-04) and the real-person review (LA-08) are done before any announcement. Valve lists current and coming Steam Next Fest editions and other events on its Upcoming Events page (https://partner.steamgames.com/doc/marketing/upcoming_events).
   - [ ] LA-02 Announcement channel. Done when a devlog or blog exists and the first post is drafted.
   - [ ] LA-03 Community space. Done when the author has chosen a community space (or none) and it carries the code of conduct.
   - [ ] LA-04 Feedback intake. Done when the game, site and stores link to one place to report bugs, and it says what to attach (QA-15).
   - [ ] LA-05 Patch process. Done when a hotfix path exists: branch, version bump, changelog entry, rebuild, re-deploy, re-push to stores.
   - [ ] LA-06 Complaints and takedown. Done when a contact for rights or content complaints is published on the site and in the repo; a copyright notice route exists (for US hosting, a DMCA designated agent is one option: https://www.copyright.gov/dmca-directory/); and the author has a written plan for handling a complaint, including how to remove one person's content quickly. Where per-person content sits in data files, that plan is a data change plus rebuild and redeploy, and the plan names the files.
   - [ ] LA-07 Retrospective. Done when lessons from this release are added to section 10 of this SOP and to the instance file.
   - [ ] LA-08 Real-person line review. Only if real people appear. Done when the author has read every line, image and situation involving each person listed in LP-08 in the release candidate and signed off in the instance file. Blocks LA-01.
   - [ ] LA-09 Monitoring. Done when an uptime check runs against `https://{site_host}/` and the play page, and each deploy records the size of every web build file, so a broken deploy or a size jump is seen without a visitor reporting it.
   - [ ] LA-10 Account recovery. Done when the owner, a second recovery route and two-factor authentication are recorded (in a private place, not the repo) for every account the release depends on: domain registrar and DNS, hosting, stores, forge and mirror, analytics and signup.
   Check: the instance file shows no "missing" or "partial" item without an issue id or an author decision.

### 5.x Prospective hazard analysis for release stages (added 2026-10-25)

A public release, a publication to the public mirror (SOP-14) and the voice pipeline (SOP-05, SOP-06) are held to the prospective standard: before the stage opens, the governing SOP's section 7 table lists the anticipated contamination events with their control point, signal, limit, corrective action and record, and the release instance file links to it. A stage whose table is empty or only contains "learned" rows is not open. The author's words for the standard: "in a CAP/CLIA / FDA-regulated world, you need to anticipate ALL OF THAT." The project profile (docs/PROJECT-PROFILE.md) names which stages are held to it.

## 6. Acceptance checks

The release is ready when all of these hold:

```bash
test -f LICENSE && test -f THIRD_PARTY.md && test -f CHANGELOG.md     # exit 0
grep -q 'config/version=' {project}/project.godot                      # Godot: exit 0
git tag -l "v{version}"                                                # prints the tag
for f in {web_out}/*; do [ $(stat -c %s "$f") -le 26214400 ] || echo "OVER: $f"; done   # prints nothing (25 MiB host)
{test_cmd}; echo $?                                                    # 0
grep -cE '\| (missing|partial) ' {instance_file}                       # 0, or each remaining row names an issue or decision
grep -rn 'http[:]//' --include='*.md' --include='*.html' --include='*.toml' \
  --include='*.sh' --include='*.gd' --include='*.py' --include='*.cfg' .   # prints nothing (https only)
lychee --no-progress site/public README.md docs/                       # exit 0 (or linkinator); PW-13
```

- Every item in the instance file has evidence a reader can open (a path, a URL or command output).
- The disclosure text is identical in game, site, README and stores.
- Author word rules, if the project has them, are checked on whole words, for example `grep -rniwE 'l[a]yer|i[d]yll|g[u]ardrail'` (equivalently `\bl[a]yer\b`; the bracket keeps the check from matching its own text). A plain substring search also matches words such as "player".

## 7. Failure modes and recovery

| Failure | How it shows | Recovery |
|---|---|---|
| Web engine file over the host's per-file limit | Deploy rejects the file, or the play page 404s on `.wasm` | Serve that one file from object storage through the host's worker, use a size-optimised engine build, or host the build on itch.io and embed it. Add the BD-06 size check to the build so it fails early. |
| Exports ship engine default icon and splash | Browser tab and launcher show the engine logo | Set icon, splash and version (GC-10) before the first public build. |
| Disclosure only in docs | Notice is in README or terms, not in the game | Add an in-game screen at first play (GC-09); re-check against current guidance. |
| Disclosures disagree | README names one tool, store form another | Keep one disclosure text in the repo and paste it everywhere (LP-09). Audit tools actually used from the render logs. |
| Model licence forbids the planned use | Licence says non-commercial; game sells or fundraises | Author decides: keep that release free and separate from fundraising, or replace the model and re-render before release. |
| Missing provenance for a reference recording | Config points at a file with no source URL or span; file missing on a new machine | Record source, span and date per SOP-05; regenerate the recording from them. |
| Internal logs or hosts become public | Tracker logs, agent logs, internal addresses or home paths visible on the public forge | Decide per file (PR-06); remove from tracking and, if needed, rewrite history before the repo goes public. |
| Tests touch the player's save | A crashed test leaves the real save changed | Point tests at a temporary save path (QA-04). |
| Save emptied by a crash | Game starts fresh after a crash or tab close; the save file is empty or cut short | Atomic write and backup (GC-07); on load, fall back to the backup and tell the player. |
| Web save missing | Progress gone in a private window, inside an embed, or on another host | GC-13 warning and save export; link players to one canonical play URL. |
| Broken or moved links | Site or README links 404 or redirect to a moved page | PW-13 before every deploy. |
| Domain typo | DNS for the intended name is empty; links break | Confirm spelling with the author before PW-01; register both names only if the author wants a redirect. |

## 8. Artifacts and templates

### 8.1 Layout

```
LICENSE                     code licence (LP-01)
ASSETS_LICENSE              asset licence (LP-02)
THIRD_PARTY.md              engine, addons, models, fonts, datasets with licences (LP-03)
CHANGELOG.md                Keep a Changelog (BD-04)
CONTRIBUTING.md  CODE_OF_CONDUCT.md  SECURITY.md
.github/ISSUE_TEMPLATE/     bug.yml, config.yml
.github/PULL_REQUEST_TEMPLATE.md
docs/RELEASE_CHECKLIST.md   {instance_file}
docs/PROMO_SITE_PLAN.md     {site_plan}: this game's values and measurements
docs/DISCLOSURE.md          the single disclosure text (LP-09)
site/                       promo website (PW-02); per-game values in site/site.config.json
tools/build_all.sh          every preset, versioned output (BD-10)
tools/deploy_site.sh        site deploy (PW-10), reads site/site.config.json
```

### 8.2 Instance file skeleton

```markdown
# {Game} release checklist

Template: sops/09-game-release-checklist.md at {template_commit} (copied | shared repo | submodule). Audited {YYYY-MM-DD} at {commit}.

## Blockers and decisions for the author

1. {decision}: {options, with sources}. Blocks: {IDs}. Issue: {issue_id}.

## Status summary

| Phase | done | partial | missing | n/a |
|---|---|---|---|---|

## Checklist

| ID | Item | Status | Evidence | Owner | Notes |
|---|---|---|---|---|---|
| GC-01 | Milestone scopes | missing | {design_doc} | author | {issue_id} |
```

Status values: `done`, `partial`, `missing`, `n/a`. Owner: `author` for licences, money, accounts, legal posture and public text; `agent` for files, scripts and checks.

### 8.3 Starting a new game

Use this when the next game starts, before any public step. Nothing in sections 1 to 8 of this SOP, or in `templates/promo-site-plan.md`, names a particular game; all game data goes in the new repository's own files.

1. **Bring the SOPs into the new repository.** Pick one (author decides; record the choice and the source commit on the instance file's `Template:` line):
   - Copy `sops/` into the new repo. Simple; the copies drift, so note the source commit and carry improvements back by hand.
   - A shared SOP repository on `{forge_host}`, referenced from the new repo's agent instructions at a pinned commit. One place to improve the SOPs; every game reads the same text.
   - A git submodule at `sops/` pinned to a commit of that shared repository. Same as the shared repository, with the pin recorded by git; contributors must run `git submodule update --init`.
   See also "Adopting these SOPs in another project" in `sops/README.md`.
2. **Open the instance file** from section 8.2 at `docs/RELEASE_CHECKLIST.md`, every item "missing", and file one `{tracker}` issue per item that applies.
3. **Open the site plan.** Copy the "Per-game values" and "Measurements" sections of `templates/promo-site-plan.md` into `docs/PROMO_SITE_PLAN.md` and fill them. The generic design stays in the template.
4. **Start `site/`** from the site starter described in `templates/promo-site-plan.md` (section "Site starter"). Edit only `site/site.config.json`; the pages, worker and deploy script read every per-game value from it.
5. **Measure before choosing a host.** Export a web build of the new game and record every file size and the compressed total (BD-06, BD-13) before deciding where the site and build live.
6. **Carry the lessons.** Read section 10 and turn each lesson into a first-week check for the new game.

## 9. Reference implementation in persistint

- Instance file: `docs/RELEASE_CHECKLIST.md`; site values: `docs/PROMO_SITE_PLAN.md`; generic site plan: `sops/templates/promo-site-plan.md` (all on branch `sys-release`, first audit 2026-10-23 at 93870ee).
- Engine: Godot 4.6.3, GL Compatibility; one Web export preset in `project/export_presets.cfg`.
- Existing web deploy: `tools/deploy_web.sh` with `infra/nginx-persistint.conf` and `infra/nginx-persistint-tls.conf` (self-hosted). The planned public host is Cloudflare at persistint.gnpng.org (spelling to be confirmed).
- Provenance sources the checklist builds on: `art/reference/little_st_james/SOURCES.md`, `project/data/quotes/*.json` (SOP-06), `project/data/voices.json` (SOP-05), `prompts/` (SOP-03).
- Model licence case (LP-06): every voice clip, cloned or from a built-in studio voice, is Coqui XTTS v2 output under CPML, which is non-commercial only and has a notice clause that reaches output (https://huggingface.co/coqui/XTTS-v2/raw/main/LICENSE.txt); see decision 4 in `docs/RELEASE_CHECKLIST.md`.
- Planned: `LICENSE`, `THIRD_PARTY.md`, `CHANGELOG.md`, `docs/DISCLOSURE.md`, `site/` (with `site/site.config.json`), `tools/build_all.sh`, `tools/deploy_site.sh`, credits, options and pause screens.
- This SOP was written on branch `sys-release`, which predates `sops/README.md`; the index row and the reciprocal Related SOPs entries in SOP-03 to SOP-08 are to be added when the branch merges.

## 10. Lessons learned

Each lesson happened on persistint; the numbers are in `docs/RELEASE_CHECKLIST.md` ("Lessons: persistint data").

- Measure the engine's web file sizes before choosing a host. A default Godot web export's engine file was larger than a common static host's per-file cap, which ruled out a plain static upload.
- Set icon, splash and version before the first export. Without them, exports ship the engine's stock icon and splash.
- Write voice and media provenance when the clip is cut, not later. Config that records only a file path cannot be traced back to its source, and the file may not exist on the next machine.
- Headless imports rewrite project files. Run `git status` after any headless engine import and keep unrelated project-file diffs out of release commits.
- Search the whole data set for real people, not only the quote and voice files. Characters, art, level layouts and file names can name or depict people who have no quote file.
- A save written in place on every change can be lost to a crash mid-write, and a loader that treats a failed parse as "no save" hides the loss.
