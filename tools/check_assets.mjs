#!/usr/bin/env node
/**
 * Node port of tools/check_assets.py, the asset conformance gate (bd 4wb), with the same checks
 * and the same messages: every asset, whatever its source, comes from a re-runnable generator or
 * a prompt drop at a stable path, with consistent import settings; animated things rigged with
 * documented frame layouts; no art drawn ad hoc in _draw code.
 *
 * Checks, each a failure when broken:
 *   provenance  every shipped asset has a row in its folder's SOURCES.md and none is "not traced";
 *               the generated SOURCES.md files are current (tools/gen_sources.mjs --check)
 *   gemini      no raw Gemini download (Gemini_Generated_Image_*) anywhere under project/
 *   paths       every res:// asset path written in a scene, resource, script, data or dialogue
 *               file exists (paths built at run time, with % or {}, are not checked)
 *   imports     every texture follows tools/set_texture_imports.py (lossy at or over 300 KB,
 *               lossless below), and every WAV imports compressed (QOA, compress/mode=2)
 *   rigs        every *_rig.png is made by a tool whose docstring (a Python \"\"\" docstring or
 *               the first JS /** block) documents its frame layout
 *   draw        no script outside scripts/test/ draws in _draw()
 *
 *   node tools/check_assets.mjs        # lists every failure; exit 1 if any
 */
import fs from "node:fs";
import path from "node:path";
import { ROOT, PROJECT, rel, rglob, isFile, readText, reEscape } from "./lib_paths.mjs";
import { main as genSources } from "./gen_sources.mjs";

const MEDIA = new Set([".png", ".jpg", ".jpeg", ".webp", ".svg", ".wav", ".mp3", ".ogg", ".ogv", ".mp4"]);
const LOSSY_MIN = 300 * 1024;
const failures = [];
const fail = (check, msg) => failures.push(`${check}: ${msg}`);
const ext = (p) => path.extname(p).toLowerCase();

function shippedMedia() {
  const out = [];
  for (const base of ["assets", "audio"]) {
    for (const p of rglob(path.join(PROJECT, base))) {
      const parts = rel(p, PROJECT).split("/");  // not shipped: test assets, staging sheets (a .gdignore)
      if (isFile(p) && MEDIA.has(ext(p)) && !parts.includes("test") && !parts.includes("sheets")) out.push(p);
    }
  }
  return out;
}

function checkProvenance(media) {
  const r = genSources(["--check"]);
  if (r.code !== 0) fail("provenance", "SOURCES.md out of date; run node tools/gen_sources.mjs\n    " + r.out.trim().split("\n").join("\n    "));
  const tables = new Map();
  for (const p of media) {
    const src = path.join(path.dirname(p), "SOURCES.md");
    if (!fs.existsSync(src)) { fail("provenance", `${rel(p)}: no SOURCES.md in its folder`); continue; }
    if (!tables.has(src)) tables.set(src, readText(src));
    const row = tables.get(src).match(new RegExp(`^\\| \`${reEscape(path.basename(p))}\` \\|([^\\n]*)$`, "m"));
    if (row === null) fail("provenance", `${rel(p)}: no row in ${rel(src)}`);
    else if (row[0].includes("| not traced |")) fail("provenance", `${rel(p)}: not traced to a prompt, a voice line or a tool`);
  }
}

function checkGemini() {
  for (const p of rglob(PROJECT)) {
    if (path.basename(p).startsWith("Gemini_Generated_Image_") && !rel(p, PROJECT).split("/").includes(".godot")) {
      fail("gemini", `${rel(p)}: a raw Gemini download; render it through a prompt drop:/game:`);
    }
  }
}

function checkPaths() {
  const pat = /res:\/\/((?:assets|audio)\/[^"'\s)\]}]+)/g;
  const all = rglob(PROJECT).filter(isFile);
  for (const e of [".tscn", ".tres", ".gd", ".json", ".dialogue"]) {
    for (const f of all.filter((p) => p.endsWith(e))) {
      const parts = rel(f, PROJECT).split("/");
      if (parts.includes(".godot") || parts.includes("test") || parts.includes("addons")) continue;
      if (path.basename(f) === "manifest.json") continue;
      for (const m of fs.readFileSync(f).toString("utf8").matchAll(pat)) {
        const p = m[1].replace(/[.,;:]+$/, "");
        if ([..."%{}*<"].some((ch) => p.includes(ch)) || p.endsWith("/")) continue;
        if (!fs.existsSync(path.join(PROJECT, p))) fail("paths", `${rel(f)}: res://${p} does not exist`);
      }
    }
  }
}

function checkImports(media) {
  for (const p of media) {
    if ([".svg", ".ogv", ".mp4"].includes(ext(p))) continue;
    const imp = p + ".import";
    if (!fs.existsSync(imp)) { fail("imports", `${rel(p)}: no .import file (not imported)`); continue; }
    const text = readText(imp);
    const mode = text.match(/^compress\/mode=(\d+)$/m);
    if (ext(p) === ".png") {
      const want = fs.statSync(p).size >= LOSSY_MIN ? "1" : "0";
      if (!mode || mode[1] !== want) fail("imports", `${rel(p)}: compress/mode=${mode ? mode[1] : "?"}, want ${want}; run tools/set_texture_imports.py`);
    } else if (ext(p) === ".wav" && (!mode || mode[1] !== "2")) {
      fail("imports", `${rel(p)}: WAV not imported compressed (compress/mode=2, QOA)`);
    }
  }
}

function docstring(text) {
  const py = text.split('"""');
  if (py.length > 2) return py[1];
  const js = text.match(/\/\*\*([\s\S]*?)\*\//);
  return js ? js[1] : "";
}

function checkRigs(media) {
  for (const p of media) {
    if (!path.basename(p).endsWith("_rig.png")) continue;
    const srcPath = path.join(path.dirname(p), "SOURCES.md");
    const src = fs.existsSync(srcPath) ? readText(srcPath) : "";
    const row = src.match(new RegExp(`^\\| \`${reEscape(path.basename(p))}\` \\| ([^|]*) \\|`, "m"));
    const tools = row ? [...row[1].matchAll(/`(tools\/[^`]+)`/g)].map((m) => m[1]) : [];
    let documented = false;
    for (const t of tools) {
      const tp = path.join(ROOT, t);
      const doc = fs.existsSync(tp) ? docstring(fs.readFileSync(tp).toString("utf8")) : "";
      if (/\bframes?\b/i.test(doc) && /\b(rows?|columns?)\b/i.test(doc)) documented = true;
    }
    if (!documented) fail("rigs", `${rel(p)}: its tool (${tools.join(", ") || "none"}) does not document the frame layout (frames, rows, columns)`);
  }
}

function checkDraw() {
  const scripts = path.join(PROJECT, "scripts");
  for (const f of rglob(scripts).filter((p) => p.endsWith(".gd") && isFile(p))) {
    if (rel(f, scripts).split("/").includes("test")) continue;
    if (/^func _draw\(/m.test(readText(f))) fail("draw", `${rel(f)}: draws art in _draw(); move it into a tools/gen_*.py generator`);
  }
}

const media = shippedMedia();
checkProvenance(media);
checkGemini();
checkPaths();
checkImports(media);
checkRigs(media);
checkDraw();
for (const f of failures) console.log("FAIL " + f);
console.log(`check_assets: ${media.length} assets, ${failures.length} failure(s)`);
process.exit(failures.length ? 1 : 0);
