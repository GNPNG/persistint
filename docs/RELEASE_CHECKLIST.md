# PERSISTINT release checklist

Template: [`sops/09-game-release-checklist.md`](../sops/09-game-release-checklist.md) (SOP-09), at the same commit as this file (copied in this repo; for later games see SOP-09 section 8.3). Site values: [`docs/PROMO_SITE_PLAN.md`](PROMO_SITE_PLAN.md); generic site plan: [`sops/templates/promo-site-plan.md`](../sops/templates/promo-site-plan.md). Audited 2026-10-23 at commit 93870ee on branch `sys-release`; rows changed by later commits on main are marked. Status values: done, partial, missing, n/a. Owner: author for licences, money, accounts, legal posture and public text; agent for files, scripts and checks. Issue ids are beads issues under epic `persistint-game-d15`. Legal notes are neutral summaries with sources, not legal advice.

## Blockers and decisions for the author

1. **Domain spelling.** The request said "persitint.gnpng.org" (no second "s"). This plan assumes **persistint.gnpng.org**. Neither name has a DNS record yet. `dig +short NS gnpng.org` returned `dom.ns.cloudflare.com` and `gwen.ns.cloudflare.com` on 2026-10-23, so the zone is already on Cloudflare; what is needed is the spelling and access to that Cloudflare account. Blocks: PW-01 to PW-14. Issue: `persistint-game-d15.2`.
2. **Code licence.** No `LICENSE` at the repo root; the only licence file is `project/addons/dialogue_manager/LICENSE` (MIT). Choose a licence for the code (for example MIT or GPL). Blocks: LP-01, PR-01. Issue: `persistint-game-d15.3`.
3. **Asset licence.** Choose a separate licence for art, audio, video and text (for example all rights reserved, or a Creative Commons licence). Human authorship of AI-assisted work may limit what an asset licence can grant; see the US Copyright Office's 2025 report (https://copyright.gov/newsnet/2025/1060.html). Blocks: LP-02. Issue: `persistint-game-d15.4`.
4. **XTTS v2 licence vs any revenue.** All 28 shipped clips in `project/audio/voice/` come from Coqui XTTS v2 (`tools/generate_voice_clips.py`): cloned voices for real people and XTTS built-in studio voices ("Daisy Studious", "Ana Florence", "Gracie Wise", "Andrew Chipper", "Damien Black" in `project/data/voices.json`) for fictional characters. Its licence, CPML, grants rights only for a "non-commercial purpose", applies to "the model or its output", says use "for revenue-generating activity ... is not a non-commercial purpose", and requires its terms or URL to go to anyone who receives the output (https://huggingface.co/coqui/XTTS-v2/raw/main/LICENSE.txt). So every clip, built-in voice or cloned, carries the notice. Per the discussion at https://github.com/coqui-ai/TTS/discussions/4145, Coqui has shut down and no commercial licence appears to be available. `README.md` describes the game as "Promotional/fundraising" and "Not-for-profit". Options: keep the release free with no fundraising link in or around the game; or move to a different voice model before any paid or fundraising release. Blocks: LP-06, GC-08. Issue: `persistint-game-d15.5`.
5. **Real people: names, likeness, voices, and placement.** `dev/DESIGN.md` ("Legal/brand rules") has celebrities appear under their real names. Real people found in the repo (LP-08 has the full list): nine quoted (`project/data/quotes/*.json`), five of them with cloned voices (`project/data/voices.json`; the `kate.wav` reference is missing from the main checkout); and Jeffrey Epstein, Bill Clinton, Hillary Clinton and Bill Gates as cast entries in `project/data/cast.json` (`epstein`, `bill_clinton`, `hillary_clinton`, `bill_gates`) with clone sprites in `project/assets/canon/` (`clone_epstein.png`, `clone_bill_clinton.png`, `clone_hillary_clinton.png`, `clone_bill_gates.png`) and "Epstein clone" barks (`project/scripts/ruins/zombie_child.gd:7`). The island is built from OpenStreetMap data for Little Saint James (`tools/project_osm_island.py` writes `project/data/island_layout.json`). Points to review with counsel, stated neutrally, as separate questions:
   - Parody and emotional distress: Hustler v. Falwell (1988) bars emotional-distress recovery for parody that cannot reasonably be read as fact, absent a false statement of fact made with actual malice; it does not address publicity statutes (https://www.law.cornell.edu/supremecourt/text/485/46), and it does not settle defamation for content that could be read as stating fact.
   - Defamation and false light: placing real living people beside Jeffrey Epstein, on a map of his island, can raise the question whether the content implies a false fact about them. Public figures must show actual malice (New York Times v. Sullivan, https://www.law.cornell.edu/supremecourt/text/376/254); there is no separate blanket protection for "opinion", and the question is whether a statement implies a provably false fact (Milkovich v. Lorain Journal, https://www.law.cornell.edu/supremecourt/text/497/1).
   - Likeness in games: Hart v. Electronic Arts, 717 F.3d 141 (3d Cir. 2013), found a realistic avatar not transformative (https://law.justia.com/cases/federal/appellate-courts/ca3/11-3750/11-3750-2013-05-21.html).
   - Voice: Midler v. Ford (9th Cir. 1988) held deliberate imitation of a distinctive voice for commercial purposes actionable under California common law (https://law.justia.com/cases/federal/appellate-courts/F2/849/460/37485/). Tennessee's ELVIS Act (in force 2024-07-01) covers simulated voice and exempts satire and parody protected by the First Amendment (https://www.manatt.com/insights/newsletters/client-alert/tennessees-elvis-act-expands-publicity-rights-for).
   - Federal bills, not law as of this audit; check status: the NO FAKES Act of 2025, S.1367 (https://www.congress.gov/bill/119th-congress/senate-bill/1367) and H.R.2794 (https://www.congress.gov/bill/119th-congress/house-bill/2794), referred to the Judiciary committees; and the NO FAKES Act of 2026, S.4591 (https://www.congress.gov/bill/119th-congress/senate-bill/4591) with H.R.8915, introduced 2026-05-20 per the Copyright Office's legislation page (https://www.copyright.gov/legislation/). congress.gov blocked automated reads during this audit, so the sponsor and committee of S.4591 are not confirmed here.
   - EU AI Act Art. 50: primary source Regulation (EU) 2024/1689 (https://eur-lex.europa.eu/eli/reg/2024/1689/oj). Secondary guidance (Future of Life Institute, https://artificialintelligenceact.eu/transparency-rules-article-50/, 2026-05-14) says realistic depictions of real people must be disclosed as AI-generated, that for evidently satirical work the duty is lighter but not removed, and that a notice only in documentation or buried menus is not enough. Deepfake labelling under Art. 50(4) applies from 2026-08-02; the Digital Omnibus is reported to delay Art. 50(2) machine-readable marking to 2026-12-02 for systems already on the market, and sources disagree on when the Omnibus was adopted (for example https://usercentrics.com/knowledge-hub/eu-ai-act-high-risk-delay-article-50-transparency-consent/), so check its status before relying on the later date.
   - Google's generative AI use policy bars impersonating an individual "without explicit disclosure, in order to deceive" (https://policies.google.com/terms/generative-ai/use-policy).
   Blocks: LP-08, LA-08, LP-09, GC-09, PW-06. Issue: `persistint-game-d15.6`.
6. **GitHub mirror.** Only `origin` (the project's Gitea instance) exists. Decide yes or no; if yes, Gitea push mirror, and templates in `.github/` serve both (https://docs.gitea.com/usage/issues-prs/issue-pull-request-templates/). Blocks: PR-09, PW-10 route 3. Issue: `persistint-game-d15.7`.
7. **Stores and platforms.** Steam needs a $100 fee, a 30-day wait and a 2-week Coming Soon page (https://partner.steamgames.com/steamdirect), plus Deck review if it is to be Deck Verified (https://partner.steamgames.com/doc/steamhardware/compat); notarized macOS needs an Apple Developer ID. itch.io plus the web site avoids both. Blocks: BD-01 (desktop presets), BD-08, BD-09, BD-12, QA-14, SP-02, SP-03. Issue: `persistint-game-d15.8`.
8. **Public tracking of internal files.** At 93870ee, `.beads/` (10 files, including `interactions.jsonl`) and `.claude/logs/actually-im-the-ahole-violations.jsonl` were tracked. Main at 1c1dac3 has since untracked and gitignored `.beads/interactions.jsonl`, `.beads/issues.jsonl`, `.claude/logs/` and `tools/deploy_web.env`, and removed internal host details; 9 `.beads/` files remain tracked (`.gitignore`, `README.md`, `config.yaml`, `metadata.json`, five hooks). Decide whether those stay public and whether history needs rewriting before the repo goes public. Blocks: PR-06. Issue: `persistint-game-d15.9`.
9. **Disclosure text, content advisory and public copy.** Write the single disclosure text (`docs/DISCLOSURE.md`), the content advisory, the one-line pitch and store copy. The tool list in existing docs disagrees with the tools used (LP-09). Blocks: LP-09, LP-10, GC-09, PW-06, PR-08, SP-01, SP-08. Issue: `persistint-game-d15.10`.
10. **Data collection.** Choose crash and error capture (none, local log file, or a service), analytics (none or cookieless) and signup (none, hosted, or self-hosted); the privacy policy follows. Blocks: QA-15, LP-11, PW-07, PW-11, PW-12. Issue: `persistint-game-d15.11`.
11. **Milestones, version and release date.** Write the content-complete and release-candidate scopes, pick the first public version number and, later, the date. Blocks: GC-01, BD-03, LA-01. Issue: `persistint-game-d15.12`.
12. **Complaints and takedown route.** Choose the public contact for rights and content complaints and a copyright notice route (for example a DMCA designated agent: https://www.copyright.gov/dmca-directory/), and approve the removal plan in LA-06. Blocks: LA-06, PW-06. Issue: `persistint-game-d15.13`.
13. **Account ownership and recovery.** Record owners, recovery routes and 2FA for the DNS, Cloudflare, Gitea, itch.io (and any store or mirror) accounts, outside the repo. Blocks: LA-10. Issue: `persistint-game-d15.14`.
14. **What data ships.** `include_filter="*.dialogue,*.json"` in `project/export_presets.cfg` ships every JSON under `project`, including `_note` fields (for example the one in `project/data/voices.json` that describes the voice pipeline), the `aggregator` flags in `project/data/quotes/*.json`, and `project/data/island_layout.json`. Confirm that is intended or name what to exclude. Blocks: BD-14. Issue: `persistint-game-d15.15`.
15. **Localisation scope.** English only for this release, or translation-ready. Blocks: QA-10. Issue: `persistint-game-d15.16`.
16. **Screen reader.** Whether to turn on Godot's experimental AccessKit support. Blocks: QA-09. Issue: `persistint-game-d15.17`.
17. **Community.** Whether outside contributions are accepted, which code of conduct, which community space and announcement channel (or none). Blocks: PR-02, PR-03, LA-02, LA-03. Issue: `persistint-game-d15.18`.
18. **Release playtester.** Who plays the release candidate (someone other than the developer). Blocks: QA-12. Issue: `persistint-game-d15.19`.
19. **Where the SOPs live for the next game ("seedfall").** Copy `sops/` into each new repo, keep a shared SOP repository, or add it as a submodule (SOP-09 section 8.3). Blocks: nothing in this release; blocks starting the next game's checklist. Issue: `persistint-game-d15.1`.

## Status summary

| Phase | done | partial | missing | n/a |
|---|---|---|---|---|
| Game complete (GC) | 0 | 5 | 9 | 0 |
| Quality and accessibility (QA) | 0 | 6 | 10 | 1 |
| Builds and distribution (BD) | 0 | 4 | 9 | 1 |
| Legal and provenance (LP) | 0 | 3 | 9 | 0 |
| Public repo (PR) | 0 | 2 | 7 | 0 |
| Promo website (PW) | 0 | 1 | 11 | 2 |
| Store pages and press (SP) | 0 | 2 | 4 | 2 |
| Launch and after (LA) | 0 | 0 | 9 | 1 |
| **Total (98)** | **0** | **23** | **68** | **7** |

## Checklist

### Phase 1: Game complete

| ID | Item | Status | Evidence | Owner | Notes |
|---|---|---|---|---|---|
| GC-01 | Milestone scopes written | partial | `dev/DESIGN.md` "Vertical slice scope (current milestone)" | author | Content-complete and release-candidate scopes not written. Decision 11, `persistint-game-d15.12`. |
| GC-02 | Main menu complete | partial | `project/scenes/ui/main_menu.tscn`, `project/scripts/ui/main_menu.gd` | agent | Continue (shown only with a saved `_location`) and New Game only. No Options, Credits or Quit. `persistint-game-d15.20` |
| GC-03 | Pause menu | missing | no pause code in `project/scripts` or `project/scenes` | agent | `persistint-game-d15.21` |
| GC-04 | Options menu | missing | `AudioServer` and `InputMap` unused in scripts | agent | Needs volume, text size, subtitles, fullscreen, remapping. `persistint-game-d15.22` |
| GC-05 | Audio buses | missing | no `default_bus_layout.tres`; `project/scripts/autoload/voice.gd:19` sets `bus = "Master"` | agent | Add Master/Music/SFX/Voice. `persistint-game-d15.23` |
| GC-06 | Input actions | missing | no `[input]` in `project/project.godot`; raw `KEY_P` (wardrobe) and `KEY_J` (journal) in `project/scripts/map.gd:65,67` | agent | `persistint-game-d15.24` |
| GC-07 | Save system | partial | `project/scripts/autoload/world_state.gd` `save()` (line 43) and `load_save()` (line 49) | agent | Failure path: `save()` runs on every flag change and opens `user://save.json` with `FileAccess.WRITE`, which empties the file before writing, so a crash or tab close mid-write leaves it empty or cut short. `load_save()` keeps the result only if the parse `is Dictionary`; otherwise it returns silently and the game starts as new, with no message and no backup. Also one slot, no schema version, no migration. Needs atomic write (temp file plus rename) and a backup before overwrite. `persistint-game-d15.25` |
| GC-08 | Credits and licences screen | missing | no "credit" in scripts or scenes | agent | Must carry Godot licence text, Dialogue Manager MIT, the CPML notice for every voice clip (decision 4), and the OSM ODbL attribution and derived-database notice (LP-03). `persistint-game-d15.26` |
| GC-09 | In-game disclosure | missing | none in game | author (text), agent (screen) | Satire, real names, cloned voices, generated media. Text: decision 9, `persistint-game-d15.10`. Screen: `persistint-game-d15.27` |
| GC-10 | Application metadata | partial | `project/project.godot` has `config/name`, `run/main_scene` | agent | No `config/icon`, `config/version`, `config/description`, `boot_splash/*`; web export ships the stock icon and splash. `persistint-game-d15.28` |
| GC-11 | Placeholders gone | missing | `project/assets/placeholder/` (from `tools/gen_placeholder_art.sh`); `tools/render_all_assets.py --status` reported 0/45 rendered | agent | Title, icon, loading screens, music, stingers, videos all pending (SOP-04). `persistint-game-d15.29` |
| GC-12 | Web audio start | partial | main menu needs a click before gameplay; `main_menu.gd` plays no audio | agent | Not tested in a browser; add an explicit click-to-start if title music is added. `persistint-game-d15.30` |
| GC-13 | Web save persistence | missing | no `is_userfs_persistent` call in `project/scripts`; no save export or import | agent | The site plan's `/play/` iframe is same-origin, so saves follow normal browser rules there; an itch.io embed is cross-origin and needs third-party cookies. The self-hosted host, persistint.gnpng.org and itch.io would each keep separate saves (`docs/PROMO_SITE_PLAN.md` section 3). `persistint-game-d15.31` |
| GC-14 | End of content | missing | none | agent | The vertical slice (`dev/DESIGN.md`) needs a "demo ends here" screen. `persistint-game-d15.32` |

### Phase 2: Quality and accessibility

| ID | Item | Status | Evidence | Owner | Notes |
|---|---|---|---|---|---|
| QA-01 | One test command | partial | 10 scripts in `project/tests/` (9 `test_*.gd` + `verify_slice.gd`), all `RESULT: PASS` | agent | Run one at a time; no runner script. `persistint-game-d15.33` |
| QA-02 | CI | missing | no `.github/`, `.gitea/`, `.forgejo/`, `.woodpecker*` | agent | Gitea Actions and a runner not confirmed on the project's Gitea instance. `persistint-game-d15.34` |
| QA-03 | Clean test output | partial | `test_hottest_chains`, `verify_slice` print "resources still in use at exit"; `test_ruins` prints leaked TextServer RID errors | agent | `persistint-game-d15.35` |
| QA-04 | Tests isolated from player data | partial | `project/tests/verify_slice.gd` header: real `user://save.json` backed up and restored | agent | A crash mid-test could leave the real save changed. `persistint-game-d15.36` |
| QA-05 | Subtitles | partial | Dialogue Manager balloon and `BarkBubble` in `project/scripts/npc.gd` show text; `project/scripts/ruins/zombie_child.gd:106-109` shows the spoken quote in the bubble | agent | Direct `Voice.speak` calls outside the dialogue system need an on-screen text check: `project/scripts/minigames/ritual_puzzle.gd:24,74`, `next_top_comic.gd:61,79`, `landing.gd:160`, `hottest_of_the_hot.gd:74,92`, `interview.gd:52,65`, `project/scripts/florida/critter.gd:54`, `project/scripts/ruins/polar_cub.gd:97`, `project/scripts/autoload/name_it.gd:98`. `persistint-game-d15.37` |
| QA-06 | Readable text | missing | fixed font sizes as low as 5 px (`project/scripts/florida/clickable.gd:24`, `project/scenes/maps/door.tscn:22`) | agent | No text-size option. `persistint-game-d15.38` |
| QA-07 | Input coverage | missing | `README.md`: "click to walk"; only P and J keys | agent | No keyboard-only path. `persistint-game-d15.39` |
| QA-08 | Accessibility list | missing | none | agent | Use Steam's categories (https://partner.steamgames.com/doc/accessibility_features). `persistint-game-d15.40` |
| QA-09 | Screen reader evaluated | missing | none | author | Godot 4.5+ AccessKit is experimental (https://godotengine.org/releases/4.5/). Project TTS is on (`[audio] general/text_to_speech=true`). Decision 16, `persistint-game-d15.17`. |
| QA-10 | Localisation ready | partial | committed `project/project.godot` POT list has 2 of 5 `.dialogue` files; no `tr()` calls; text in `project/data/*.json` | agent | An uncommitted diff in this worktree (present after the audit's headless import) lists all five. Scope: decision 15, `persistint-game-d15.16`. `persistint-game-d15.41` |
| QA-11 | Performance measured | missing | none | agent | `index.wasm` 37,700,666 B, `index.pck` 2,345,160 B (test export 2026-10-23). `persistint-game-d15.42` |
| QA-12 | Release playtest | partial | SOP-07 (`sops/07-playtest-bug-triage.md`) defines triage | author | Cross-branch reference: SOP-07 is on main, not in this worktree at 93870ee. No release-candidate playthrough recorded. Decision 18, `persistint-game-d15.19`. |
| QA-13 | Gamepad | missing | no joypad code in `project/scripts` (no `JOY_`, `InputEventJoypad*`); `project/scripts/map.gd` reads raw keys | agent | Needs input actions first (GC-06). Web: pad detected only after a button press; mapping varies by browser. `persistint-game-d15.43` |
| QA-14 | Steam Deck | n/a | Steam not chosen | author | Becomes missing if decision 7 picks Steam. |
| QA-15 | Crash and error capture | missing | none | author | Decision 10, `persistint-game-d15.11`. |
| QA-16 | First ten minutes | missing | none | agent | Run on Chromium, Firefox and Safari (and desktop builds once they exist). `persistint-game-d15.44` |
| QA-17 | Speech fallback | missing | `project/data/voices.json` `_note`: speakers with neither `ref` nor `builtin` use system text-to-speech; `project/scripts/autoload/voice.gd:50-53` calls `DisplayServer.tts_speak` | agent | Browser speech support and voices vary; not tested. `persistint-game-d15.45` |

### Phase 3: Builds and distribution

| ID | Item | Status | Evidence | Owner | Notes |
|---|---|---|---|---|---|
| BD-01 | Export presets | partial | `project/export_presets.cfg`: one preset, "Web" | agent | Desktop presets depend on decision 7. `persistint-game-d15.46` |
| BD-02 | Export templates | partial | the build machine holds Godot 4.6.3 web templates only (not in the repo) | agent | `persistint-game-d15.47` |
| BD-03 | Version number | missing | no `config/version` in `project/project.godot` | author (number), agent | Number: decision 11, `persistint-game-d15.12`. Field and display: `persistint-game-d15.48` |
| BD-04 | Changelog | missing | no `CHANGELOG.md` | agent | `persistint-game-d15.49` |
| BD-05 | Tags and releases | missing | `git tag` empty | agent | `persistint-game-d15.50` |
| BD-06 | Size limits | missing | `index.wasm` 37,700,666 B > 26,214,400 B (Cloudflare 25 MiB, https://developers.cloudflare.com/workers/platform/limits/) | agent | Plan: wasm via R2 (`docs/PROMO_SITE_PLAN.md`). itch.io: 200 MB per file, 1,000 files, 500 MB total extracted (https://itch.io/docs/creators/html5). `persistint-game-d15.51` |
| BD-07 | Web serving | partial | `infra/nginx-persistint.conf` (wasm MIME, gzip), `infra/nginx-persistint-tls.conf` (443) | agent | At 93870ee, `tools/deploy_web.sh` contained plain `http[:]//` literals for a LAN address (lines 3 and 10), which the old https-only grep (`*.md`, `*.html`, `*.toml`) could not catch; SOP-09 section 6 now also greps `*.sh`, `*.gd`, `*.py` and `*.cfg`. Main at 1c1dac3 replaced them with `$DEPLOY_URL` from the untracked `tools/deploy_web.env`, which must hold an https URL. Threads off, so no COOP/COEP needed. `persistint-game-d15.52` |
| BD-08 | Windows signing | missing | no Windows preset | author | Decision 7, `persistint-game-d15.8`. |
| BD-09 | macOS notarization | missing | no macOS preset | author | Decision 7, `persistint-game-d15.8`. |
| BD-10 | One build command | partial | `tools/deploy_web.sh` exports Web only | agent | `persistint-game-d15.53` |
| BD-11 | itch.io upload | missing | no butler config | agent | `persistint-game-d15.54` |
| BD-12 | Steam Direct | n/a | Steam not chosen | author | Becomes missing if decision 7 picks Steam. |
| BD-13 | Download budget | missing | measured: about 9.0 MB brotli for wasm plus pck (`docs/PROMO_SITE_PLAN.md` section 2); no target set; no loading-progress check | agent | Voice clips: 28 WAVs, 5,842,086 B on disk, imported with `compress/mode=2` (Quite OK Audio, the Godot default), so they ship compressed; 45 assets still to render will add music and video. `persistint-game-d15.55` |
| BD-14 | Export contents reviewed | missing | `project/export_presets.cfg:10` `include_filter="*.dialogue,*.json"` | agent | Ships every `project/data` JSON, including `_note` fields and quote `aggregator` flags. List: `persistint-game-d15.56`. Confirm: decision 14, `persistint-game-d15.15`. |

### Phase 4: Legal and provenance

| ID | Item | Status | Evidence | Owner | Notes |
|---|---|---|---|---|---|
| LP-01 | Code licence | missing | no root `LICENSE` | author | Decision 2, `persistint-game-d15.3`. |
| LP-02 | Asset licence | missing | none | author | Decision 3, `persistint-game-d15.4`. |
| LP-03 | Third-party notices | partial | `project/addons/dialogue_manager/LICENSE` (MIT, Nathan Hoad and contributors, v3.10.4 per `plugin.cfg`); `art/reference/little_st_james/SOURCES.md` (OSM ODbL) | agent | No `THIRD_PARTY.md`; Godot licence and XTTS v2 CPML not recorded. ODbL: `project/data/island_layout.json` is a database derived from OSM and ships (export filter includes `*.json`), so ODbL's share-alike terms for derived databases are a consideration, not only attribution (https://opendatacommons.org/licenses/odbl/1-0/). Fonts: no `.ttf`, `.otf` or `.woff` file is tracked, so the default Godot font is used, covered by the engine licence text. `persistint-game-d15.57` |
| LP-04 | Generated asset provenance | partial | `prompts/` give generator and target per asset; `art/reference/little_st_james/SOURCES.md` complete | agent | No sources file for `art/canon/gemini/` (7 images), `art/canon/notebooklm/` (1), the 57 sprites in `project/assets/canon/`, or `project/audio/sfx/` (5 wavs). `persistint-game-d15.58` |
| LP-05 | Voice reference provenance | missing | `project/data/voices.json` has only `ref` paths, no source URL, span or date (SOP-05 steps 4-5 require them); no YouTube URL anywhere in the repo | agent | `kate` references `art/voice_refs/kate.wav`, absent from the main checkout. `persistint-game-d15.59` |
| LP-06 | Model and tool licences | missing | XTTS v2 loaded in `tools/generate_voice_clips.py`; licence not recorded | author | Decision 4, `persistint-game-d15.5`. The CPML notice must ship with every clip, built-in studio voices included. |
| LP-07 | Generator terms | missing | `tools/render_all_assets.py` uses the Gemini API; terms not recorded | agent | Gemini API terms (https://ai.google.dev/gemini-api/terms); use policy (https://policies.google.com/terms/generative-ai/use-policy). `persistint-game-d15.60` |
| LP-08 | Real-person content | partial | see the list below | author | Every real person depicted or named, not only those quoted or voiced. Quoted (`project/data/quotes/*.json`, every entry has `url` and an `aggregator` flag): Margaret Atwood, Chelsea Clinton, Ellen DeGeneres, Hillary Clinton, Kate McCue, Oprah Winfrey, Sarah Silverman, Gloria Steinem, Tyra Banks. Voiced (`project/data/voices.json` `ref`): Chelsea Clinton, Tyra Banks, Oprah Winfrey, Sarah Silverman, Kate McCue. Depicted or named in `project/data/cast.json`: Chelsea Clinton, Tyra Banks, Kate McCue ("Cap'n Kate"), Sarah Silverman, Oprah Winfrey, Jeffrey Epstein, Bill Clinton, Hillary Clinton, Bill Gates; clone sprites for Epstein, Bill Clinton, Hillary Clinton and Bill Gates in `project/assets/canon/`; "Clinton" also appears in `project/data/emcee.json`, `project/data/ruins.json`, `project/scripts/ruins/clone_lab.gd`, `project/scripts/minigames/next_top_comic.gd`, `project/scripts/minigames/hottest_of_the_hot.gd` and three `project/scenes/ruins/` scenes. Place: Little Saint James, from OSM (`project/data/island_layout.json`). Aggregator-sourced quote entries (counted 2026-10-23): tyra 33/33, silverman 29/34, steinem 29/44, oprah 22/36, ellen 20/35, atwood 7/40, hillary 1/44, chelsea 0/24, kate 0/27. Counsel review, including defamation and false light, per decision 5, `persistint-game-d15.6`. |
| LP-09 | AI disclosure text | missing | none; tool list disagrees: `README.md` line 13 says "NotebookLM/Stable-Diffusion canon pipeline", `dev/DESIGN.md` mentions a style LoRA, `tools/render_all_assets.py` uses Gemini | author | Reconcile to tools actually used for shipped content. itch.io's disclosure is encouraged, not required, for games (https://itch.io/t/4309690/generative-ai-disclosure-tagging). Decision 9, `persistint-game-d15.10`. |
| LP-10 | Content advisory and ratings | missing | none | author | IARC storefronts do not include Steam or itch.io (https://www.globalratings.com/storefronts/), and a self-hosted site is not one; write a self-declared advisory. Decision 9, `persistint-game-d15.10`. |
| LP-11 | Privacy policy | missing | game stores only local `user://save.json` | author | Needed once crash capture, analytics or signup is added. Decision 10, `persistint-game-d15.11`. |
| LP-12 | Human authorship record | missing | `dev/STYLE.md` and per-asset prompts show direction; `tools/cut_canon_sprites.sh` shows edits | agent | Nothing ties a shipped asset to its human edits. `persistint-game-d15.61` |

### Phase 5: Public repo

| ID | Item | Status | Evidence | Owner | Notes |
|---|---|---|---|---|---|
| PR-01 | README | partial | `README.md` (engine, design link, run commands, controls) | agent | No screenshot, play link, licence, advisory or AI disclosure; line 3 says "fundraising" (decision 4). `persistint-game-d15.62` |
| PR-02 | CONTRIBUTING.md | missing | none | author | Decision 17, `persistint-game-d15.18`. |
| PR-03 | CODE_OF_CONDUCT.md | missing | none | author | Decision 17, `persistint-game-d15.18`. |
| PR-04 | SECURITY.md | missing | none | agent | `persistint-game-d15.63` |
| PR-05 | Issue and PR templates | missing | no `.github/` | agent | `persistint-game-d15.64` |
| PR-06 | Internal files reviewed | partial | at 93870ee: `.beads/` (10 tracked files), `.claude/logs/actually-im-the-ahole-violations.jsonl` tracked | author | Main at 1c1dac3 untracked the logs and exports and removed internal hosts; 9 `.beads/` files remain. Decision 8, `persistint-game-d15.9`. |
| PR-07 | Secrets scan | missing | not run | agent | `persistint-game-d15.65` |
| PR-08 | Repo metadata | missing | none | author | Social preview 1280x640 (`sops/templates/promo-site-plan.md` section 5). Decision 9, `persistint-game-d15.10`. |
| PR-09 | Mirror | missing | only `origin` (Gitea) | author | Decision 6, `persistint-game-d15.7`. |

### Phase 6: Promo website

| ID | Item | Status | Evidence | Owner | Notes |
|---|---|---|---|---|---|
| PW-01 | Domain | partial | gnpng.org NS are Cloudflare (dig, 2026-10-23); no record for either spelling | author | Decision 1, `persistint-game-d15.2`. |
| PW-02 | Site source | missing | no `site/`, `wrangler.toml`, `_headers` | agent | Build the game-free site starter with `site/site.config.json` (schema in `sops/templates/promo-site-plan.md` section 6), then fill persistint values from `docs/PROMO_SITE_PLAN.md`. `persistint-game-d15.66` |
| PW-03 | Landing page | missing | none | agent | `persistint-game-d15.67` |
| PW-04 | Play page | missing | none | agent | `persistint-game-d15.68` |
| PW-05 | Press page | missing | none | agent | `persistint-game-d15.69` |
| PW-06 | About page | missing | none | author (text), agent | Text: decisions 9 and 12. Page: `persistint-game-d15.70` |
| PW-07 | Privacy page | missing | none | author | Decision 10, `persistint-game-d15.11`. |
| PW-08 | Icons and share images | missing | no icon in repo; `prompts/image/ui/icon/app_icon.md` exists | agent | `persistint-game-d15.71` |
| PW-09 | Headers and caching | missing | none | agent | `persistint-game-d15.72` |
| PW-10 | Deploy | missing | `tools/deploy_web.sh` targets the self-hosted host only | agent | `persistint-game-d15.73` |
| PW-11 | Analytics (optional) | n/a | optional | author | Decision 10. |
| PW-12 | Signup (optional) | n/a | optional | author | Decision 10. |
| PW-13 | Link check | missing | none | agent | Stale link found in the first draft of these docs and fixed: the `dev.twitter.com` card-size link redirected to developer.twitter.com, and X's developer docs have since moved (developer.x.com now redirects to docs.x.com, which has no cards page at the old address), so the template cites an archived copy of the card spec. The drafts held no `twitter.com` intent URLs; any share links added to the site should use x.com directly. `persistint-game-d15.74` |
| PW-14 | Error and fallback pages | missing | none | agent | 404 page; WebGL 2 and mobile check on the play page. `persistint-game-d15.75` |

### Phase 7: Store pages and press

| ID | Item | Status | Evidence | Owner | Notes |
|---|---|---|---|---|---|
| SP-01 | itch.io page | missing | none | author | AI disclosure encouraged for games (https://itch.io/t/4309690/generative-ai-disclosure-tagging). Decision 9, `persistint-game-d15.10`. |
| SP-02 | Steam assets | n/a | Steam not chosen | author | Decision 7. |
| SP-03 | Steam Content Survey | n/a | Steam not chosen | author | Decision 7. |
| SP-04 | Trailer | missing | `prompts/video/ui/intro_cinematic.md` is 8 s, 1280x720, silent | agent | Trailer is a new edit: gameplay capture plus intro plus `prompts/audio/music/ui/title_theme.md`. Needed before any announcement (LA-01). `persistint-game-d15.76` |
| SP-05 | Screenshots and loops | partial | `project/tools/screenshot_scenes.gd` captures 18 scenes (needs a display) | agent | Output size is the window size; capture at 1920x1080. `persistint-game-d15.77` |
| SP-06 | Logo and key art | partial | 8 `prompts/image/levels/*/key_art_*.md` and `prompts/image/ui/title/` at 1920x1080; none rendered | agent | No logo prompt or file. `persistint-game-d15.78` |
| SP-07 | Press kit | missing | none | agent | `persistint-game-d15.79` |
| SP-08 | Store copy | missing | none | author | Decision 9, `persistint-game-d15.10`. |

### Phase 8: Launch and after

| ID | Item | Status | Evidence | Owner | Notes |
|---|---|---|---|---|---|
| LA-01 | Release date | missing | none | author | Depends on SP-04 and LA-08. Steam events: https://partner.steamgames.com/doc/marketing/upcoming_events (on 2026-10-23 it lists Next Fest October 19-26, 2026, already under way, then February 22 - March 1, 2027 and June 14-21, 2027). Decision 11, `persistint-game-d15.12`. |
| LA-02 | Announcement channel | missing | none | author | Decision 17, `persistint-game-d15.18`. |
| LA-03 | Community space | missing | none | author | Decision 17, `persistint-game-d15.18`. |
| LA-04 | Feedback intake | missing | none | agent | `persistint-game-d15.80` |
| LA-05 | Patch process | missing | none | agent | `persistint-game-d15.81` |
| LA-06 | Complaints and takedown | missing | none | author | One person's content can be removed by data change: their `project/data/quotes/<id>.json`, their `project/data/cast.json` entry, their `project/data/voices.json` entry and clips in `project/audio/voice/`, and their sprites in `project/assets/canon/`, then rebuild and redeploy. Decision 12, `persistint-game-d15.13`. |
| LA-07 | Retrospective | n/a | after launch | agent | |
| LA-08 | Real-person line review | missing | none | author | Author reads every line, image and situation for each person in LP-08 in the release candidate. Blocks LA-01. Decision 5, `persistint-game-d15.6`. |
| LA-09 | Monitoring | missing | none | agent | Uptime check on the site and play page; per-deploy file sizes. `persistint-game-d15.82` |
| LA-10 | Account recovery | missing | none | author | Decision 13, `persistint-game-d15.14`. |

## Lessons: persistint data

The numbers behind SOP-09 section 10:

- The default Godot 4.6.3 web export's `index.wasm` was 37,700,666 B (about 36 MiB), over Cloudflare's 25 MiB per-file cap (export of 93870ee, 2026-10-23).
- Exports shipped the stock engine icon and splash because `project/project.godot` had no icon or splash settings (same export).
- `project/data/voices.json` records only `ref` paths, with no source URL or span, and references `art/voice_refs/kate.wav`, which the main checkout does not have.
- After the audit's headless `godot --import`, this worktree carried an uncommitted `project/project.godot` diff (a new `[dialogue_manager]` section, all five dialogue files in the POT list where the committed file lists two, reordered sections) that is not part of the release work.
- The first audit listed only the 9 quoted and 5 voiced people; `project/data/cast.json` also names Jeffrey Epstein, Bill Clinton, Hillary Clinton and Bill Gates.
- `world_state.gd` writes the save in place on every flag change, and `load_save()` treats a failed parse as no save (GC-07).

## Notes for the next audit

- This worktree has an uncommitted change to `project/project.godot` that predates this checklist (present after the audit's headless `--import`). It is not part of this work and is not committed with it.
- Main advanced to 1c1dac3 after this audit's base (93870ee). That commit affects BD-07 (deploy script now reads `$DEPLOY_URL` from an untracked env file), PR-06 and decision 8 (logs and beads exports untracked), and removed internal hosts and addresses from tracked files; these docs avoid them too. Re-audit those rows after merging.
- SOP-07 (`sops/07-playtest-bug-triage.md`) and `sops/README.md` exist on main but not in this worktree; references to them are cross-branch until `sys-release` merges.
- The test web export used for sizes is outside the repo and is not reproducible from a committed script yet (BD-10).
- Author word rules are checked on whole words (`grep -rniwE 'l[a]yer|i[d]yll|g[u]ardrail'`); a substring search matches "player", which appears in these docs.
