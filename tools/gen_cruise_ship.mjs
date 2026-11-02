#!/usr/bin/env node
/**
 * Build the cruise ship's scenes from data/cruise_ship.json (bd ue6, eatw): the side-view
 * cross-section scenes/cruise/ship_section.tscn, where the player walks each deck's strip and
 * takes the stairs between decks, with a door per room; and one overhead scene per room that has
 * a floor, scenes/cruise/room_<id>.tscn, with a door back to the slice. Rooms with a 'scene' open
 * that scene (the minigames). Placeholder art (ImageMagick 7, like tools/gen_placeholder_art.sh)
 * goes to project/assets/cruise/ until the renders at prompts/image/cruise/ land at the same paths.
 *
 *   node tools/gen_cruise_ship.mjs [--no-art]
 *
 * Every scene uses scripts/map.gd (spawn markers, HUD) and scenes/maps/door.tscn, as the Florida
 * maps do; the walk areas are NavigationRegion2D polygons. Deterministic.
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { ROOT, PROJECT, readText, writeText } from "./lib_paths.mjs";

const DATA = JSON.parse(readText(path.join(PROJECT, "data/cruise_ship.json")));
const SCENES = path.join(PROJECT, "scenes/cruise");
const ART = path.join(PROJECT, "assets/cruise");
const MAGICK = process.env.MAGICK || "magick";
const SHIP = "res://scenes/cruise/ship_section.tscn";
const [W, H] = DATA.size;
const DECK_H = DATA.deck_h;
const TOP = DATA.top;
const STAIRS = DATA.stairs_x;
const noArt = process.argv.includes("--no-art");

const deckTop = (i) => TOP + i * DECK_H;
const walkY = (i) => deckTop(i) + DECK_H - 22;  // where feet stand on a deck
const v2 = (x, y) => `Vector2(${x}, ${y})`;
const pva = (pts) => `PackedVector2Array(${pts.flat().join(", ")})`;

function magick(args) {
  const r = spawnSync(MAGICK, args, { encoding: "utf8" });
  if (r.status !== 0) throw new Error(`${MAGICK} failed: ${(r.stderr || "").trim().slice(-300)}`);
}

/** The cross-section placeholder: hull, decks as pastel bands, a label per room, the stairs. */
function drawShip(file) {
  const args = ["-size", `${W}x${H}`, "xc:#bfe3f5", "-fill", "#fff7ec", "-stroke", "#8a5a5a", "-strokewidth", "3",
    "-draw", `roundrectangle 20,${TOP - 24} ${W - 20},${H - 30} 40,40`];
  const pastels = ["#fde2e4", "#e2f0cb", "#dbe7ff"];
  DATA.decks.forEach((d, i) => {
    args.push("-fill", pastels[i % pastels.length], "-stroke", "#8a5a5a", "-strokewidth", "2",
      "-draw", `rectangle 40,${deckTop(i)} ${W - 40},${deckTop(i) + DECK_H}`);
    args.push("-fill", "#593859", "-stroke", "none", "-pointsize", "16", "-gravity", "NorthWest",
      "-annotate", `+52+${deckTop(i) + 8}`, d.title);
    for (const r of d.rooms) {
      args.push("-fill", "#ffffff", "-stroke", "#8a5a5a", "-strokewidth", "2",
        "-draw", `roundrectangle ${r.x - 48},${deckTop(i) + 34} ${r.x + 48},${deckTop(i) + DECK_H - 8} 10,10`);
      args.push("-fill", "#593859", "-stroke", "none", "-pointsize", "12", "-gravity", "NorthWest",
        "-annotate", `+${r.x - 44}+${deckTop(i) + 40}`, r.title);
    }
  });
  args.push("-fill", "#f4a6ad", "-stroke", "#8a5a5a", "-strokewidth", "2",
    "-draw", `rectangle ${STAIRS - 26},${TOP} ${STAIRS + 26},${deckTop(DATA.decks.length)}`);
  args.push(file);
  magick(args);
}

/** A room's overhead floor placeholder. */
function drawRoom(file, room, [w, h]) {
  magick(["-size", `${w}x${h}`, "xc:#e9dccd", "-fill", "#fff7ec", "-stroke", "#8a5a5a", "-strokewidth", "3",
    "-draw", `roundrectangle 8,8 ${w - 8},${h - 8} 18,18`, "-fill", "#593859", "-stroke", "none", "-pointsize", "20",
    "-gravity", "North", "-annotate", "+0+18", room.title, "-pointsize", "13", "-annotate", "+0+44", room.what, file]);
}

function shipScene() {
  const ext = [
    `[ext_resource type="Script" path="res://scripts/map.gd" id="1"]`,
    `[ext_resource type="Texture2D" path="res://assets/cruise/ship_section.png" id="2"]`,
    `[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="3"]`,
    `[ext_resource type="PackedScene" path="res://scenes/maps/door.tscn" id="4"]`,
  ];
  // One walk strip per deck plus the stair column joining them, as one navigation polygon set.
  const outlines = [];
  DATA.decks.forEach((d, i) => {
    const y0 = walkY(i) - 14, y1 = walkY(i) + 10;
    outlines.push([[50, y0], [W - 50, y0], [W - 50, y1], [50, y1]]);
  });
  outlines.push([[STAIRS - 22, walkY(0) - 14], [STAIRS + 22, walkY(0) - 14], [STAIRS + 22, walkY(DATA.decks.length - 1) + 10], [STAIRS - 22, walkY(DATA.decks.length - 1) + 10]]);
  let verts = [], polys = [];
  for (const o of outlines) { const base = verts.length; verts.push(...o); polys.push(`PackedInt32Array(${o.map((_, k) => base + k).join(", ")})`); }
  const sub = [`[sub_resource type="NavigationPolygon" id="navpoly"]`, `vertices = ${pva(verts)}`, `polygons = [${polys.join(", ")}]`,
    `outlines = [${outlines.map(pva).join(", ")}]`];
  const nodes = [`[node name="ShipSection" type="Node2D"]`, `y_sort_enabled = true`, `script = ExtResource("1")`, `map_size = ${v2(W, H)}`, ``,
    `[node name="Background" type="Sprite2D" parent="."]`, `position = ${v2(W / 2, H / 2)}`, `z_index = -10`, `texture = ExtResource("2")`, ``,
    `[node name="Nav" type="NavigationRegion2D" parent="."]`, `navigation_polygon = SubResource("navpoly")`, ``];
  let start = null;
  DATA.decks.forEach((d, i) => {
    for (const r of d.rooms) {
      if (r.start) start = [r.x, walkY(i)];
      nodes.push(`[node name="spawn_from_${r.id}" type="Marker2D" parent="."]`, `position = ${v2(r.x, walkY(i))}`, ``);
    }
  });
  if (!start) throw new Error("cruise_ship.json: no room has start: true");
  nodes.push(`[node name="spawn_default" type="Marker2D" parent="."]`, `position = ${v2(start[0], start[1])}`, ``,
    `[node name="Player" parent="." instance=ExtResource("3")]`, `position = ${v2(start[0], start[1])}`, ``);
  DATA.decks.forEach((d, i) => {
    for (const r of d.rooms) {
      const target = r.scene || `res://scenes/cruise/room_${r.id}.tscn`;
      const spawn = r.scene ? "spawn_default" : "spawn_default";
      nodes.push(`[node name="${pascal(r.id)}Door" parent="." instance=ExtResource("4")]`, `position = ${v2(r.x, walkY(i))}`,
        `target_scene = "${target}"`, `target_spawn = "${spawn}"`, `exit_label = "${r.title}"`, ``);
    }
  });
  return [`[gd_scene format=4]`, ``, ...ext, ``, ...sub, ``, ...nodes].join("\n");
}

function roomScene(room) {
  const [w, h] = room.floor;
  const ext = [
    `[ext_resource type="Script" path="res://scripts/map.gd" id="1"]`,
    `[ext_resource type="Texture2D" path="res://assets/cruise/room_${room.id}.png" id="2"]`,
    `[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="3"]`,
    `[ext_resource type="PackedScene" path="res://scenes/maps/door.tscn" id="4"]`,
  ];
  const o = [[24, 70], [w - 24, 70], [w - 24, h - 24], [24, h - 24]];
  const sub = [`[sub_resource type="NavigationPolygon" id="navpoly"]`, `vertices = ${pva(o)}`, `polygons = [PackedInt32Array(0, 1, 2, 3)]`, `outlines = [${pva(o)}]`];
  const nodes = [`[node name="${pascal(room.id)}" type="Node2D"]`, `y_sort_enabled = true`, `script = ExtResource("1")`, `map_size = ${v2(w, h)}`, ``,
    `[node name="Background" type="Sprite2D" parent="."]`, `position = ${v2(w / 2, h / 2)}`, `z_index = -10`, `texture = ExtResource("2")`, ``,
    `[node name="Nav" type="NavigationRegion2D" parent="."]`, `navigation_polygon = SubResource("navpoly")`, ``,
    `[node name="spawn_default" type="Marker2D" parent="."]`, `position = ${v2(w / 2, h - 60)}`, ``,
    `[node name="Player" parent="." instance=ExtResource("3")]`, `position = ${v2(w / 2, h - 60)}`, ``,
    `[node name="ShipDoor" parent="." instance=ExtResource("4")]`, `position = ${v2(w / 2, h - 36)}`,
    `target_scene = "${SHIP}"`, `target_spawn = "spawn_from_${room.id}"`, `exit_label = "Back to the ship"`, ``];
  return [`[gd_scene format=4]`, ``, ...ext, ``, ...sub, ``, ...nodes].join("\n");
}

const pascal = (s) => s.split("_").map((p) => p[0].toUpperCase() + p.slice(1)).join("");

function main() {
  fs.mkdirSync(SCENES, { recursive: true });
  fs.mkdirSync(ART, { recursive: true });
  if (!noArt) drawShip(path.join(ART, "ship_section.png"));
  writeText(path.join(SCENES, "ship_section.tscn"), shipScene() + "\n");
  let rooms = 0;
  for (const d of DATA.decks) for (const r of d.rooms) {
    if (r.scene) continue;
    if (!noArt) drawRoom(path.join(ART, `room_${r.id}.png`), r, r.floor);
    writeText(path.join(SCENES, `room_${r.id}.tscn`), roomScene(r) + "\n");
    rooms++;
  }
  console.log(`cruise ship: ship_section.tscn, ${rooms} room scene(s)${noArt ? "" : ", placeholder art"} in ${path.relative(ROOT, SCENES)}`);
}

main();
