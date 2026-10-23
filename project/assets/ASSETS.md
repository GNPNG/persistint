# Assets

One row per art file the game loads: where it lives, what makes it, how it is laid out, and the
prompt it stands in for (a Gemini render synced to that path replaces it). Paths are relative to
`project/`. Sorted by path.

| path | id | generator | frame layout | stands in for |
|---|---|---|---|---|
| `assets/ui/backdrops/comedy_stage.png` | comedy_stage | tools/gen_ui_art.py | static; Next Top Comic backdrop, 2560x1440 (4x the 640x360 viewport) | - |
| `assets/ui/backdrops/fog_sea.png` | fog_sea | tools/gen_ui_art.py | static; The Landing backdrop, 2560x1440 (4x the 640x360 viewport) | - |
| `assets/ui/backdrops/runway.png` | runway | tools/gen_ui_art.py | static; Hottest of the HOT backdrop, 2560x1440 (4x the 640x360 viewport) | - |
| `assets/ui/backdrops/ship_cabin.png` | ship_cabin | tools/gen_ui_art.py | static; get-ready chains backdrop, 2560x1440 (4x the 640x360 viewport) | - |
| `assets/ui/backdrops/ship_cutaway.png` | ship_cutaway | tools/gen_ui_art.py | static; The Landing station map, 2400x600 (4x its 600x150 on-screen size) | - |
| `assets/ui/backdrops/talk_show_set.png` | talk_show_set | tools/gen_ui_art.py | static; The Interview backdrop, 2560x1440 (4x the 640x360 viewport) | - |
| `assets/ui/backdrops/temple_altar.png` | temple_altar | tools/gen_ui_art.py | static; ritual puzzle backdrop, 2560x1440 (4x the 640x360 viewport) (canon prop_pillar_orb) | - |
| `assets/ui/brand/gnpng_pingpong.png` | gnpng_pingpong | tools/gen_imprint_mark.py (renders the author's art/brand/gnpng-pingpong.svg in EB Garamond) | static; 1008x632 still of the GNPNG Ping Pong imprint mark, the rally at t = 0; boot splash | - |
| `assets/ui/brand/gnpng_pingpong_sheet.png` | gnpng_pingpong_sheet | tools/gen_imprint_mark.py | sheet; frames 504x316, 6 columns x 6 rows, 36 frames row-major, one animation idle (paddles and ball rally), 12 fps, loop; SpriteFrames built by scripts/ui/imprint_mark.gd, main menu lower left | - |
| `assets/ui/chapter_cards/chapter_card_before_the_wreck.png` | chapter_card_before_the_wreck | tools/gen_ui_art.py (stand-in) | static; 2560x1440 (4x the 640x360 viewport), white gold-trimmed ship low right, clear of the centred lines, behind chapter_end and flashback_card text | `prompts/image/ui/chapter_cards/chapter_card_before_the_wreck.md` |
| `assets/ui/chrome/altar_tile_gold.png` | altar_tile_gold | tools/gen_ui_art.py | static; ritual puzzle altar tile, gold (9-slice, margin 7) | - |
| `assets/ui/chrome/altar_tile_rose.png` | altar_tile_rose | tools/gen_ui_art.py | static; ritual puzzle altar tile, rose (9-slice, margin 7) | - |
| `assets/ui/chrome/altar_tile_selected.png` | altar_tile_selected | tools/gen_ui_art.py | static; ritual puzzle altar tile, selected (9-slice, margin 7) | - |
| `assets/ui/chrome/altar_tile_sky.png` | altar_tile_sky | tools/gen_ui_art.py | static; ritual puzzle altar tile, sky (9-slice, margin 7) | - |
| `assets/ui/chrome/bar_bg.png` | bar_bg | tools/gen_ui_art.py | static; ProgressBar background (9-slice, margin 4) | - |
| `assets/ui/chrome/bar_fill.png` | bar_fill | tools/gen_ui_art.py | static; ProgressBar fill (9-slice, margin 4) | - |
| `assets/ui/chrome/bubble.png` | bubble | tools/gen_ui_art.py | static; BarkBubble speech bubble (9-slice, margin 6) | - |
| `assets/ui/chrome/bubble_tail.png` | bubble_tail | tools/gen_ui_art.py | static; speech bubble tail under BarkBubble | - |
| `assets/ui/chrome/button_disabled.png` | button_disabled | tools/gen_ui_art.py | static; Button disabled (9-slice, margin 5) | - |
| `assets/ui/chrome/button_focus.png` | button_focus | tools/gen_ui_art.py | static; Button focus ring (9-slice, margin 5) | - |
| `assets/ui/chrome/button_hover.png` | button_hover | tools/gen_ui_art.py | static; Button hover (9-slice, margin 5) | - |
| `assets/ui/chrome/button_normal.png` | button_normal | tools/gen_ui_art.py | static; Button normal (9-slice, margin 5) | - |
| `assets/ui/chrome/button_pressed.png` | button_pressed | tools/gen_ui_art.py | static; Button pressed (9-slice, margin 5) | - |
| `assets/ui/chrome/continue_heart.png` | continue_heart | tools/gen_ui_art.py | static; dialogue 'more' indicator, bobbed by AnimationPlayer in dialogue_balloon.tscn | - |
| `assets/ui/chrome/dialogue.png` | dialogue | tools/gen_ui_art.py | static; DialoguePanel box (9-slice, margin 11, tiled) | - |
| `assets/ui/chrome/nametag.png` | nametag | tools/gen_ui_art.py | static; NameTag speaker tag (9-slice, margin 6) | - |
| `assets/ui/chrome/panel.png` | panel | tools/gen_ui_art.py | static; Panel / PanelContainer / HudPanel / tooltip (9-slice, margin 7) | - |
| `assets/ui/chrome/ribbon.png` | ribbon | tools/gen_ui_art.py | static; HeaderLabel ribbon (9-slice, margins 6/4) | - |
| `assets/ui/chrome/scroll_bg.png` | scroll_bg | tools/gen_ui_art.py | static; VScrollBar track (9-slice, margin 3) | - |
| `assets/ui/chrome/scroll_grabber.png` | scroll_grabber | tools/gen_ui_art.py | static; VScrollBar grabber (9-slice, margin 3) | - |
| `assets/ui/title/title_screen_plain.png` | title_screen_plain | tools/gen_ui_art.py (stand-in; composes canon prop_ship, prop_bunker, deco_*) | static; 2560x1440 (4x the 640x360 viewport), main menu background | `prompts/image/ui/title/title_screen_plain.md` |
