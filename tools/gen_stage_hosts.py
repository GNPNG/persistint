"""Draw the cruise show hosts as generic stand-in figures: who is on stage in The Interview, Next
Top Comic and Hottest of the HOT.

Usage: python3 -I tools/gen_stage_hosts.py

The shows' celebrities are named in the game text (data/cast.json, through the nameplate under
each figure, scripts/minigames/stage_figure.gd); the art never depicts a real person
(prompts/STYLE.md 7.5). So each host here is a generic canon kawaii figure: the canon paper-doll
body turnaround's front view (the same canon base the Florida people stand on, tools/
gen_florida_cast.py, which supplies the drawing kit) with plain made-up hair and a show outfit in
the cruise palette, no likeness intended or attempted. A role, not a person:
  host_talk.png    the talk-show host: long brown hair, lavender dress with a heart brooch,
                   a cue card in one hand
  host_emcee.png   the emcee who introduces every show: a chestnut bob with bangs, butter dress
                   with a mint sash, a microphone
  host_comic.png   the comedy show's host: dark hair in a high ponytail, mint dress, a microphone
  host_runway.png  the fashion show's host: long waves, a pink gown with a gold belt, a scorecard
Outputs (project/assets/ui/stage/), each a 4-frame idle sheet, one row: rest, breath (the figure
one world px lower at the top), rest, blink. Frame 320x520 px: the 32x52 world-px figure frame at
10 px per world px (the figure is shown about 110 px tall on a 640x360 stage, so about 4.7x),
feet on the bottom edge less 10 px. Deterministic.
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I leaves tools/ off the path
import florida_draw as fd  # noqa: E402
from gen_florida_cast import INK, Person, a_dress, hair_cap  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "project/assets/ui/stage"


def mic(p, x, y):
    """A hand-held microphone, head up, in the hand at (x, y)."""
    p.L([(x, y + 6), (x + 4, y + 44)], "#6b5a7a", 10)
    p.E(x - 2, y - 6, 13, 13, "#d8d0e6", 5)
    p.L([(x - 10, y - 8), (x + 6, y - 8)], fd.mix("#d8d0e6", INK, 0.3), 2)


class Host(Person):
    HAIR, HI, DRESS = fd.HAIR_BROWN, "#ffffff", "#c9b8f2"

    def front(self):
        im, origin = self.render("front")
        W, H = im.size
        breath = Image.new("RGBA", (W, H))
        breath.alpha_composite(im.resize((W, H - round(self.F)), Image.LANCZOS), (0, round(self.F)))
        blink = self.blink(im, "front", origin)
        sheet = Image.new("RGBA", (W * 4, H))
        for i, fr in enumerate((im, breath, im, blink)):
            sheet.alpha_composite(fr, (i * W, 0))
        return sheet


class TalkHost(Host):
    name = "host_talk"
    HAIR = "#7a5440"
    HI = fd.mix("#7a5440", "#ffffff", 0.4)
    DRESS = "#c9b8f2"

    def behind(self, p, v):
        for s in (-1, 1):
            x = 98 + s * 88
            p.P([(x, 110), (x + s * 18, 170), (x + s * 14, 250), (x - s * 16, 262), (x - s * 22, 170)], self.HAIR)

    def clothes(self, p, v):
        a_dress(p, v, self.DRESS, hem=392, flare=30)
        p.P([(80, 204), (99, 230), (118, 204), (112, 200), (99, 214), (86, 200)], "#ffffff", 4)  # collar
        p.L([(60, 292), (138, 292)], fd.mix(self.DRESS, INK, 0.25), 4)
        p.heart(124, 246, 9, fd.HEART, 2)

    def hair(self, p, v):
        hair_cap(p, v, self.HAIR, self.HI, bangs=False)

    def front_props(self, p, v):
        x = 18
        p.rect(x, 300, x + 34, 346, "#fff8ec", rad=4, width=4)  # cue card
        for y in (314, 326):
            p.L([(x + 7, y), (x + 27, y)], "#e3cfe0", 3)


class Emcee(Host):
    name = "host_emcee"
    HAIR = "#b98a5e"
    HI = fd.mix("#b98a5e", "#ffffff", 0.45)
    DRESS = "#ffe08a"

    def clothes(self, p, v):
        a_dress(p, v, self.DRESS, hem=384, flare=26, scallop=7)
        p.P([(60, 214), (78, 206), (140, 284), (128, 296)], "#a8e6a0", 4)  # sash
        p.L([(60, 296), (138, 296)], fd.mix(self.DRESS, INK, 0.2), 4)

    def hair(self, p, v):
        hair_cap(p, v, self.HAIR, self.HI, bangs=True)
        for s in (-1, 1):  # the bob's ends at the jaw
            x = 98 + s * 90
            p.P([(x, 100), (x + s * 8, 176), (x - s * 26, 186), (x - s * 18, 120)], self.HAIR)

    def front_props(self, p, v):
        mic(p, 172, 300)


class ComicHost(Host):
    name = "host_comic"
    HAIR = "#5a3c34"
    HI = fd.mix("#5a3c34", "#ffffff", 0.35)
    DRESS = "#a8e6a0"

    def behind(self, p, v):
        p.P([(130, 10), (176, 0), (196, 60), (188, 150), (166, 120), (160, 50)], self.HAIR)  # ponytail

    def clothes(self, p, v):
        a_dress(p, v, self.DRESS, hem=380, flare=22)
        p.L([(60, 290), (138, 290)], fd.mix(self.DRESS, INK, 0.25), 4)
        for x, y in ((80, 330), (120, 352), (100, 250)):
            p.sparkle(x, y, 9, width=2)

    def hair(self, p, v):
        hair_cap(p, v, self.HAIR, self.HI, bangs=True)
        p.E(150, 28, 14, 12, "#ff9ad0", 4)  # the ponytail's tie

    def front_props(self, p, v):
        mic(p, 22, 296)


class RunwayHost(Host):
    name = "host_runway"
    HAIR = "#6a4636"
    HI = fd.mix("#6a4636", "#ffffff", 0.4)
    DRESS = "#ffb3c8"

    def behind(self, p, v):
        for s in (-1, 1):  # long waves over the shoulders
            x = 98 + s * 90
            p.P([(x, 104), (x + s * 22, 160), (x + s * 10, 210), (x + s * 24, 268), (x - s * 10, 280),
                 (x - s * 20, 200), (x - s * 24, 150)], self.HAIR)

    def clothes(self, p, v):
        a_dress(p, v, self.DRESS, hem=396, flare=40, scallop=6)
        p.L([(60, 288), (138, 288)], "#ffe08a", 6)  # gold belt
        p.E(99, 288, 9, 8, "#ffe08a", 3)

    def hair(self, p, v):
        hair_cap(p, v, self.HAIR, self.HI, bangs=False)

    def front_props(self, p, v):
        x = 160
        p.rect(x, 300, x + 30, 342, "#fff8ec", rad=4, width=4)  # the scorecard
        p.heart(x + 15, 321, 8, fd.HEART, 2)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for cls in (TalkHost, Emcee, ComicHost, RunwayHost):
        sheet = cls().front()
        sheet.save(OUT / f"{cls.name}.png", optimize=False)
        print(cls.name, sheet.size)


if __name__ == "__main__":
    main()
