# Visual sweep, 2026-11-02 09:45 UTC (main, local build)

Author's rule (09:38 UTC): every render and every live scene is inspected visually, and what was
judged and what was not looked at is recorded. Bar: the Codex/Astra sheets ("The Codex stuff is
nicer", 09:37). Screenshots: 26 shots via tools/shot_walk.sh (tools/shots/wso.json overview,
menu, interview and flashback-card shots, plus five scene-open shots of the mini-games and the
village), saved under the review share as `sweep-0940/`. The cruise slice is not in this sweep
(it is on branch srv/cruise-hub, not yet merged); its placeholders are ImageMagick labels by
design and need the renders at prompts/image/cruise/.

## Looked at and judged

| Shot | Verdict | What is wrong, with the file |
|---|---|---|
| ui-main_menu-default | Good. | Title, island, ship, sun all at the bar. Nothing to fix. |
| sweep-village-open | Good. | Sticker-sheet world, bunker faces, flowers. At the bar. |
| temple-temple-overview | Good. | Matches the Astra throne-room reference (same queen portraits, O medallion, skull). |
| florida-beach-overview | Good. | Rich; the pier (`assets/florida/pier*.png`) is a plain brown plank, acceptable. |
| ui-wardrobe-temple | Functional, thin. | Three slots (hair, dress, accessory), two choices visible, "None" accessory; the panel is a stock dialog. This is the dress-up the author means by "can't look like trash": the doll itself is fine, the wardrobe around it is a settings box. `scripts/ui/wardrobe.gd`. Fix needs the layered sheets (Codex follow-up) and a real closet UI (parts drawn as items you pick, not `<` `>` cycle buttons). |
| sweep-hottest_chains-open | Placeholder-grade set, menu-grade game. | Bed is two rectangles (`hottest_chains.gd` draws it); stations are a button bar; the whole "ship" is the right-hand task list. Doll and vanity are fine. See the gap report, M2. |
| sweep-hottest_of_the_hot-open | Layout wrong; hosts are stand-ins. | The doll floats on a pink hearts billboard above the runway instead of standing on it (`hottest_of_the_hot.gd`, doll placed in the backdrop panel). Chelsea and Tyra are generic kid figures from tools/gen_stage_hosts.py with nameplates; the Astra reference sheets exist for neither yet (not in the char_* set). Audience hair-blobs read fine. |
| sweep-next_top_comic-open | Set is good; hosts are stand-ins. | Brick wall, spotlight, mic, curtains all read. Chelsea and Silverman are the same stand-in figures. The player on stage wears the island temple outfit (braids, white gown) because the shot opened the scene directly; in play the flashback archives the island character, so this part is **not verified** in the real flow. |
| sweep-landing-open | Placeholder-grade ship. | The ship is pastel boxes with rows of rounded windows and label buttons; readable, not at the bar, and nothing like the cross-section the author asked for. `assets/ui/backdrops/ship_cutaway.png` (tools/gen_ui_art.py). Replace with a render from prompts/image/cruise/ once the cruise slice art exists; both should be the same ship. Command/task text is agent prose (gap report D1). |
| interview-interview-question | Layout bug. | The five answer buttons are stacked over the middle of the set, covering Oprah and the guest on the couch; only the sunset porthole and the nameplate show. The responses menu (`dialogue/interview.dialogue` balloon) needs to sit below or beside the stage, not on it. |
| ui-flashback_card-landing | Not judged for art (text card). | Text is the agent-written card (gap report). |

## Not looked at
ruins-* (6 shots), florida-garden/stable/aquarium overviews, ui-main_menu sunset/midnight/title_tapped, ui-settings-menu, interview intro/second. Files are in the review share for the author.

## Rules this adds
- A scene-open screenshot of every mini-game is part of the suite's visual pass from now on
  (add the five `sweep-*` shots to tools/shots/wso.json: follow-up bead).
- Stand-in host figures are placeholders and are listed as such until a character sheet lands.
