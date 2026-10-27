# Third-party components

Everything in PERSISTINT that is not the author's own work, with its licence, source and notice.
The game ships the same list: **Credits & Licences** on the main menu
(`project/scenes/ui/credits.tscn`) shows it from `project/data/credits.json`, with every licence
text in full, plus the engine's own licence and the licences of the parts built into the engine,
read from the engine at run time (`Engine.get_license_text()`, `Engine.get_copyright_info()`,
`Engine.get_license_info()`; see
[Complying with licenses](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html)).
`project/tests/test_credits.gd` checks that the two lists name the same components. Checklist
items LP-03 and GC-08 in [sops/09-game-release-checklist.md](sops/09-game-release-checklist.md).

Entries marked *to confirm* are not yet verified against their source.

## Shipped in the game

| Component | Used for | Licence | Source | Notice |
|---|---|---|---|---|
| Godot Engine 4.6 | The game engine | MIT (Expat) | [godotengine.org](https://godotengine.org), [licence](https://godotengine.org/license) | The engine's licence text is [below](#godot-engine). The engine contains third-party parts under their own licences (FreeType, ENet, mbed TLS and others), listed in its [COPYRIGHT.txt](https://github.com/godotengine/godot/blob/4.6-stable/COPYRIGHT.txt); the credits screen lists them and shows their licence texts from the engine. |
| Dialogue Manager 3.10.4 | The dialogue system, `project/addons/dialogue_manager/` | MIT | [nathanhoad/godot_dialogue_manager](https://github.com/nathanhoad/godot_dialogue_manager) | Copyright (c) 2022-present Nathan Hoad and Dialogue Manager contributors. Full text: [project/addons/dialogue_manager/LICENSE](project/addons/dialogue_manager/LICENSE), copied word for word into `project/data/credits.json`. One local change, taken from upstream: `get_line` in `dialogue_manager.gd` copies a line's data before it sets `resource` on it (in 3.10.4 the resource was written into its own `lines`, a reference cycle that kept every dialogue resource alive to exit). |
| Coqui XTTS v2 | Every voice clip in the game (`project/audio/voice/`): voices cloned from public recordings and the model's built-in studio voices alike are output of this model | Coqui Public Model License 1.0.0 (CPML); non-commercial use of the model and its output only | [coqui/XTTS-v2](https://huggingface.co/coqui/XTTS-v2), [terms](https://coqui.ai/cpml.txt) ([as published with the model](https://huggingface.co/coqui/XTTS-v2/raw/main/LICENSE.txt)) | The CPML's notice clause: "You must ensure that anyone who gets a copy of any part of the model, or any modification of the model, or their output, from you also gets a copy of these terms or the URL for them above." The credits screen carries the full terms (fetched 2026-10-27) and the URL. Commercial use is an author decision (LP-06). |
| OpenStreetMap data | The island map | Open Database License 1.0 (ODbL) | Overpass API extract, data timestamp 2026-05-31T22:37:44Z; see [art/reference/little_st_james/SOURCES.md](art/reference/little_st_james/SOURCES.md) | © OpenStreetMap contributors, [openstreetmap.org/copyright](https://www.openstreetmap.org/copyright). `project/data/island_layout.json` is a database derived from this data (`tools/project_osm_island.py`) and ships in the game (the web export includes `*.json`). ODbL sets share-alike terms for derived databases ([ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/)); how this file is offered: *to confirm (author)*. The raw extract `osm_raw.json` is not shipped. |
| Default font | All text in the game | Covered by the engine's notices | Built into the engine | No font file is shipped in `project/`; the game draws its text with the engine's default font, which is covered by the engine's licence and copyright notices (Godot's COPYRIGHT.txt lists `thirdparty/fonts/OpenSans*.woff2`, Open Sans, OFL-1.1). That Open Sans is the face the export draws: *to confirm*. |
| Fredoka | Drawn into images: the PERSISTINT wordmark and title letters (`tools/gen_brand_art.py`) and the GNPNG Ping Pong mark (`tools/gen_imprint_mark.py`) | SIL Open Font License 1.1 | [hafontia/Fredoka-One](https://github.com/hafontia/Fredoka-One); `art/brand/fonts/Fredoka-VF.ttf` | Copyright 2016 The Fredoka Project Authors; [art/brand/fonts/OFL-Fredoka.txt](art/brand/fonts/OFL-Fredoka.txt). The font file is not shipped in the game, only images drawn with it. The promo site serves it (`site/public/fonts/fredoka.woff2`, with `site/public/fonts/OFL.txt`). |

## In the repository, not shipped in the game

| Component | Used for | Licence | Source | Notice |
|---|---|---|---|---|
| EB Garamond | The brand art source `art/brand/gnpng-pingpong.svg` | SIL Open Font License 1.1 | [octaviopardo/EBGaramond12](https://github.com/octaviopardo/EBGaramond12); `art/brand/fonts/EBGaramond-VF.ttf` | Copyright 2017 The EB Garamond Project Authors; [art/brand/fonts/OFL.txt](art/brand/fonts/OFL.txt). That no shipped image is drawn with it: *to confirm*. |
| Island reference photos | Visual reference for the island map | Public domain (U.S. Virgin Islands government) | Wikimedia Commons; see [art/reference/little_st_james/SOURCES.md](art/reference/little_st_james/SOURCES.md) | Not shipped. |
| Art tools | Cutting and generating sprites and brand art (`tools/`) | *To confirm* (not shipped) | Pillow 10.4.0, NumPy 2.4.4, SciPy 1.14.1 ([tools/requirements-art.txt](tools/requirements-art.txt)); ImageMagick 7.1.2-31; librsvg 2.62.3 | Build-time only; none of their code ships in the game. |

Generated art, music and video come from services rather than licensed components: Google Gemini
(image, Lyria and Veo, as named in each prompt's `tool:` field under `prompts/`) and NotebookLM
(the canon reference sheets). Their terms are checklist item LP-07. That every shipped music
track and the studio intro video are renders of those prompts: *to confirm*.

## Notices

### Godot Engine

This game uses Godot Engine, available under the following license
([LICENSE.txt](https://github.com/godotengine/godot/blob/4.6-stable/LICENSE.txt) at 4.6-stable):

```
Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Dialogue Manager

See [project/addons/dialogue_manager/LICENSE](project/addons/dialogue_manager/LICENSE) (MIT).

### Coqui XTTS v2

Every voice clip in this game is output of Coqui XTTS v2, a model made available under the Coqui
Public Model License 1.0.0: <https://coqui.ai/cpml.txt>. The full terms ship in the game
(`project/data/credits.json`, shown on the credits screen).

### OpenStreetMap

Map data © OpenStreetMap contributors, available under the Open Database License:
<https://www.openstreetmap.org/copyright>.
