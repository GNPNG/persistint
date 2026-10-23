"""Project the OpenStreetMap Little Saint James data onto the village's 32 px grid.

Usage: python3 -I tools/project_osm_island.py
Reads art/reference/little_st_james/osm_raw.json (ODbL, (c) OpenStreetMap contributors) and writes
project/data/island_layout.json: the land mask (north up, 24 m per cell) and feature cell positions.
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
D = json.loads((ROOT / "art/reference/little_st_james/osm_raw.json").read_text())
W, H, M = 40, 38, 24.0
LAT0, LON0 = 18.2985, -64.8265
X0, Y1 = -295.0 - 2 * M, 596.0 + 2 * M  # metres at the map's top-left


def cell(p):
    x = (p["lon"] - LON0) * 111320 * math.cos(math.radians(LAT0))
    y = (p["lat"] - LAT0) * 110574
    return ((x - X0) / M, (Y1 - y) / M)


def cen(e):
    c = [cell(p) for p in e["geometry"]]
    return [round(sum(x for x, _ in c) / len(c), 2), round(sum(y for _, y in c) / len(c), 2)]


els = D["elements"]
S = 8
img = Image.new("L", (W * S, H * S), 0)
for e in els:
    if e.get("tags", {}).get("natural") == "coastline" and e["id"] == 157804855:
        ImageDraw.Draw(img).polygon([(x * S, y * S) for x, y in map(cell, e["geometry"])], fill=255)
mask = []
for y in range(H):
    row = ""
    for x in range(W):
        frac = sum(img.getpixel((x * S + i, y * S + j)) > 0 for i in range(S) for j in range(S)) / (S * S)
        row += "L" if frac > 0.5 else "w"
    mask.append(row)


for _ in range(2):  # close one-cell notches so the shore reads as a beach rim, not noise
    mask = ["".join("L" if mask[y][x] == "w" and sum(
        0 <= x + i < W and 0 <= y + j < H and mask[y + j][x + i] == "L" for i, j in ((-1, 0), (1, 0), (0, -1), (0, 1))) >= 3
        else mask[y][x] for x in range(W)) for y in range(H)]


def near_land(x, y, r):
    return any(0 <= x + i < W and 0 <= y + j < H and mask[y + j][x + i] == "L"
               for i in range(-r, r + 1) for j in range(-r, r + 1))


raw = list(mask)
mask = list(raw)
for y in range(H):
    row = ""
    for x in range(W):
        if raw[y][x] == "L":
            edge = any(not (0 <= x + i < W and 0 <= y + j < H) or raw[y + j][x + i] != "L"
                       for i, j in ((-1, 0), (1, 0), (0, -1), (0, 1)))
            row += "S" if edge else "L"
        else:
            row += "F" if near_land(x, y, 1) else "w"
    mask[y] = row

out = {"w": W, "h": H, "m_per_cell": M, "mask": mask, "paths": [], "buildings": [], "sheds": [], "pools": [], "piers": [],
       "gardens": []}
paths = set()
for e in els:
    t = e.get("tags", {})
    g = e.get("geometry", [])
    if t.get("highway") in ("service", "pedestrian") and "man_made" not in t:
        pts = [cell(p) for p in g]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            n = max(1, int(math.hypot(bx - ax, by - ay) * 3))
            for i in range(n + 1):
                paths.add((int(ax + (bx - ax) * i / n), int(ay + (by - ay) * i / n)))
    elif t.get("building") == "temple":
        out["temple"] = cen(e)
    elif t.get("building") == "ruins":
        out["ruins"] = cen(e)
    elif t.get("building") == "shed":
        out["sheds"].append(cen(e))
    elif t.get("building") in ("yes", "roof"):
        out["buildings"].append(cen(e))
    elif t.get("leisure") == "swimming_pool":
        out["pools"].append(cen(e))
    elif t.get("leisure") == "pitch":
        out["pitch"] = cen(e)
    elif t.get("leisure") == "garden":
        out["gardens"].append(cen(e))
    elif t.get("aeroway") == "helipad":
        out["helipad"] = cen(e)
    elif t.get("man_made") == "pier":
        out["piers"].append(cen(e))
    elif t.get("man_made") == "tower":
        out["tower"] = cen(e)
out["paths"] = sorted([x, y] for x, y in paths if 0 <= x < W and 0 <= y < H and mask[y][x] in "LS")
(ROOT / "project/data/island_layout.json").write_text(json.dumps(out))
print("\n".join(
    "".join("#" if [x, y] in out["paths"] else c for x, c in enumerate(r)) for y, r in enumerate(mask)))
for k, v in out.items():
    if k not in ("mask", "paths"):
        print(k, v)
