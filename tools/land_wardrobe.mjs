#!/usr/bin/env node
/**
 * Land the Gemini wardrobe renders (bd lg5w.2) with one command, from a passing render at a
 * wardrobe prompt's drop: path to parts the game can wear. These are the post-steps of
 * .claude/skills/gemini-assets/SKILL.md (section 3, sync to import) for wardrobe sheets.
 *
 *   node tools/land_wardrobe.mjs [ID ...] [--dry-run] [--skip STEP[,STEP...]]
 *
 * Sheets: every prompts/image/wardrobe/<id>.md (or each ID given) whose render is at its drop:
 * path, or already at its game: path (project/assets/sheets/wardrobe/<id>.png, staging). Each one
 * needs its parts file, prompts/image/wardrobe/<id>.parts.json, measured on the render:
 *   { "doll": "WxH+X+Y",                       the bald reference doll at the far left (needed by
 *                                              top_, bottom_ and shoes_ parts)
 *     "white_threshold": 232,                  optional, as in paperdoll_parts.json
 *     "parts": { "<id>": { "crop": "WxH+X+Y",  each part's box on the sheet
 *                          "anchor": [x, y], "scale": s,   hat_ and acc_ parts (anchor needed)
 *                          "offset": [dx, dy], "collar": n } } }   optional, any part / dresses
 * The ids are the ones the prompt's Notes list ("Parts on this sheet, left to right after the
 * doll: ..."), each prefix the slot the Notes name (hat_, top_, bottom_, shoes_, dress_, hair_,
 * acc_ for the accessory). A part already cut from another sheet is an error, not a duplicate.
 *
 * Steps (the names --skip takes), per sheet:
 *   sync      copy the drop to the game: path when that is missing, or older and different
 *   key       key the green to white beside it, <id>_white.png, with the skill's ImageMagick
 *             command (MAGICK names the binary); skipped while the keyed copy is newer
 *   cut       tools/cut_paperdoll.py --sheet <id> (the art Python) into project/assets/canon/,
 *             with paperdoll_parts.json plus the sheet as it will be registered
 *   register  the sheet under "sheets" and its parts under "parts" in
 *             project/data/paperdoll_parts.json, each part under its slot in
 *             project/data/outfits.json (after the slot's "none"), and a row for the sheet and
 *             for each part in project/assets/canon/SOURCES.md (hand-written, so check_assets
 *             wants the rows). A file is written only when its content changes, so a second run
 *             changes nothing.
 * then once, when a sheet landed:
 *   rig       tools/gen_player_rig.py (the art Python; every part's player rig)
 *   bake      tools/bake_paper.sh characters (the paper ring of every player rig; ImageMagick 7)
 *   import    godot --headless --path project --import (GODOT names the binary), then
 *             node tools/set_texture_imports.mjs, then the import again if that changed a file
 *   sources   node tools/gen_sources.mjs
 * The art Python (numpy, scipy and Pillow: tools/requirements-art.txt) is ART_PYTHON when that is
 * set, else the art venv ~/.local/share/persistint/art-venv, else the repo's .venv, else python3
 * on PATH (lib_paths.mjs artPython, the order the tests use).
 *
 * --dry-run checks every sheet and its parts file and prints what each step would change or run;
 * it writes nothing and runs no step. A summary ends every run. Exit 0 when every sheet found
 * landed, 1 when one could not (no parts file, a bad part, a step failed), 2 on a usage error.
 * The test: node tools/test_land_wardrobe.mjs (synthetic sheets; --stage puts them at the drop
 * paths of a scratch clone for a run with every step).
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { ROOT, rel, isFile, readText, writeText, artPython, isLfsPointer } from "./lib_paths.mjs";

const WARDROBE = path.join(ROOT, "prompts/image/wardrobe");
const PARTS_JSON = path.join(ROOT, "project/data/paperdoll_parts.json");
const OUTFITS_JSON = path.join(ROOT, "project/data/outfits.json");
const CANON = path.join(ROOT, "project/assets/canon");
const CANON_SOURCES = path.join(CANON, "SOURCES.md");
/** Part prefix -> the PaperDoll slot it is worn in: tools/cut_paperdoll.py SLOTS
 *  (tools/test_land_wardrobe.mjs checks that they agree). */
export const SLOTS = { body: "body", shoes: "shoes", bottom: "bottom", top: "top", dress: "dress", hair: "hair", hat: "hat", acc: "accessory" };
const DOLL_PLACED = new Set(["top", "bottom", "shoes"]);
const ANCHORED = new Set(["hat", "acc"]);
const PART_KEYS = ["crop", "anchor", "scale", "offset", "collar"];
export const STEPS = ["sync", "key", "cut", "register", "rig", "bake", "import", "sources"];
const CROP = /^\d+x\d+\+\d+\+\d+$/;
const MAGICK = process.env.MAGICK || "magick";
const GODOT = process.env.GODOT || "godot";
export const SPRITES_HEADER = "| Sprite | Tool | Sheet | Crop (WxH+X+Y on the sheet) |";
export const SHEETS_HEADER = "| Sheet | Made with | Prompt | Keyed copy the cutter reads |";

// --- Reading the prompts and the parts files.

export function frontMatter(text) {
  const fm = {};
  const m = text.match(/^---\n([\s\S]*?)\n---\n/);
  for (const line of m ? m[1].split("\n") : []) {
    const kv = line.match(/^([A-Za-z_]+):\s*(.*)$/);
    if (kv) fm[kv[1]] = kv[2].trim();
  }
  return fm;
}

/** The part ids (left to right) and the slot a wardrobe prompt's Notes give (null when absent). */
export function notesOf(text) {
  const notes = text.split(/^## Notes[ \t]*$/m)[1] ?? "";
  const list = notes.match(/Parts on this sheet, left to right after the doll: ([^.]+)\./);
  const slot = notes.match(/\bSlot: ([a-z]+)/);
  return { ids: list ? list[1].split(",").map((s) => s.trim()).filter(Boolean) : null, slot: slot ? slot[1] : null };
}

function wardrobePrompts() {
  return fs.readdirSync(WARDROBE).filter((f) => f.endsWith(".md")).sort().map((f) => {
    const md = path.join(WARDROBE, f), text = readText(md), fm = frontMatter(text);
    const id = fm.id || path.basename(f, ".md");
    const game = fm.game ? path.join(ROOT, fm.game) : null;
    return {
      id, md, tool: fm.tool || "", drop: fm.drop ? path.join(ROOT, fm.drop) : null, game,
      white: game && game.endsWith(".png") ? game.slice(0, -4) + "_white.png" : null,
      partsFile: path.join(WARDROBE, `${id}.parts.json`), ...notesOf(text),
    };
  });
}

const isNum = (v) => typeof v === "number" && Number.isFinite(v);
const isPair = (v) => Array.isArray(v) && v.length === 2 && v.every(isNum);

/** The sheet's parts file, checked against its prompt and what is registered: {spec, errors, warnings}. */
function readParts(sheet, reg, claimed) {
  const errors = [], warnings = [];
  const want = sheet.ids ? sheet.ids.join(", ") : "the prompt's part ids";
  if (!isFile(sheet.partsFile)) {
    errors.push(`no parts file ${rel(sheet.partsFile)}: measure the render and write {"doll": "WxH+X+Y", "parts": {...}} for ${want}`);
    return { errors, warnings };
  }
  let spec;
  try { spec = JSON.parse(readText(sheet.partsFile)); } catch (e) {
    errors.push(`${rel(sheet.partsFile)}: not JSON (${e.message})`);
    return { errors, warnings };
  }
  const bad = (msg) => errors.push(`${rel(sheet.partsFile)}: ${msg}`);
  for (const k of Object.keys(spec)) if (!["doll", "white_threshold", "parts", "_note"].includes(k)) bad(`unknown key "${k}"`);
  if (spec.doll !== undefined && !CROP.test(String(spec.doll))) bad(`"doll" ${JSON.stringify(spec.doll)} is not WxH+X+Y`);
  if (spec.white_threshold !== undefined && !isNum(spec.white_threshold)) bad(`"white_threshold" is not a number`);
  const parts = spec.parts && typeof spec.parts === "object" && !Array.isArray(spec.parts) ? spec.parts : null;
  if (!parts || !Object.keys(parts).length) { bad(`no "parts"`); return { errors, warnings }; }
  for (const [id, p] of Object.entries(parts)) {
    const kind = id.split("_")[0];
    if (!(kind in SLOTS) || kind === "body") bad(`${id}: the prefix ${JSON.stringify(kind)} is not a wardrobe slot (${Object.keys(SLOTS).filter((k) => k !== "body").join(", ")})`);
    else if (sheet.slot && SLOTS[kind] !== sheet.slot) bad(`${id}: a ${SLOTS[kind]} part on a sheet of the ${sheet.slot} slot`);
    if (sheet.ids && !sheet.ids.includes(id)) bad(`${id}: not one of the prompt's parts (${want})`);
    if (!p || typeof p !== "object" || Array.isArray(p)) { bad(`${id}: not an object`); continue; }
    for (const k of Object.keys(p)) if (!PART_KEYS.includes(k)) bad(`${id}: unknown key "${k}"`);
    if (!CROP.test(String(p.crop))) bad(`${id}: "crop" ${JSON.stringify(p.crop)} is not WxH+X+Y`);
    if (ANCHORED.has(kind) && !isPair(p.anchor)) bad(`${id}: a ${kind}_ part needs "anchor": [x, y] (px from the head's centre and top)`);
    if (p.anchor !== undefined && !isPair(p.anchor)) bad(`${id}: "anchor" is not [x, y]`);
    if (p.scale !== undefined && !isNum(p.scale)) bad(`${id}: "scale" is not a number`);
    if (p.offset !== undefined && !isPair(p.offset)) bad(`${id}: "offset" is not [dx, dy]`);
    if (p.collar !== undefined && !isNum(p.collar)) bad(`${id}: "collar" is not a number`);
    if (DOLL_PLACED.has(kind) && spec.doll === undefined) bad(`${id}: a ${kind}_ part is placed by the reference doll: give "doll"`);
    const on = reg.parts?.[id] ? (reg.parts[id].sheet ?? "canon") : null;
    if (on !== null && on !== sheet.id) bad(`${id}: already cut from the ${on} sheet; one part, one sheet`);
    if (claimed.has(id) && claimed.get(id) !== sheet.id) bad(`${id}: also in ${claimed.get(id)}.parts.json`);
    claimed.set(id, sheet.id);
  }
  const missing = (sheet.ids || []).filter((id) => !(id in parts));
  if (missing.length) warnings.push(`not in the parts file, so not landed: ${missing.join(", ")}`);
  const stale = Object.entries(reg.parts || {}).filter(([id, p]) => p.sheet === sheet.id && !(id in parts)).map(([id]) => id);
  if (stale.length) warnings.push(`registered from this sheet but not in its parts file (left as they are): ${stale.join(", ")}`);
  return { spec, errors, warnings };
}

// --- Registering: paperdoll_parts.json, outfits.json and the canon SOURCES.md, as text.

const inline = (v) => Array.isArray(v) ? `[${v.map(inline).join(", ")}]`
  : v && typeof v === "object" ? (Object.keys(v).length ? `{ ${Object.entries(v).map(([k, x]) => `${JSON.stringify(k)}: ${inline(x)}`).join(", ")} }` : "{}")
  : JSON.stringify(v);
const isBlock = (v) => v && typeof v === "object" && !Array.isArray(v) && Object.keys(v).length > 0
  && Object.values(v).every((x) => x && typeof x === "object" && !Array.isArray(x));

/** paperdoll_parts.json as the repository writes it: tabs, one line per sheet and per part,
 *  the part objects lined up. */
export function formatParts(obj) {
  const lines = Object.entries(obj).map(([k, v]) => {
    if (!isBlock(v)) return `\t${JSON.stringify(k)}: ${inline(v)}`;
    const w = Math.max(...Object.keys(v).map((n) => JSON.stringify(n).length + 1));
    return `\t${JSON.stringify(k)}: {\n` + Object.entries(v).map(([n, x]) => `\t\t${(JSON.stringify(n) + ":").padEnd(w)} ${inline(x)}`).join(",\n") + "\n\t}";
  });
  return "{\n" + lines.join(",\n") + "\n}\n";
}

/** outfits.json as the repository writes it: tabs, one line per slot. */
export function formatOutfits(obj) {
  return "{\n" + Object.entries(obj).map(([k, v]) => `\t${JSON.stringify(k)}: ${inline(v)}`).join(",\n") + "\n}\n";
}

const firstCell = (row) => row.split("|")[1].trim();

/** `text` with `row` in the Markdown table whose header row is `header`: the row with the same
 *  first cell replaced, or `row` put in sorted order. */
export function upsertRow(text, header, row) {
  const lines = text.split("\n");
  const h = lines.indexOf(header);
  if (h < 0) throw new Error(`no table "${header}"`);
  let end = h + 2;
  while (end < lines.length && lines[end].startsWith("|")) end++;
  const key = firstCell(row);
  for (let j = h + 2; j < end; j++) {
    const k = firstCell(lines[j]);
    if (k === key) {
      if (lines[j] === row) return text;
      lines[j] = row;
      return lines.join("\n");
    }
    if (k > key) {
      lines.splice(j, 0, row);
      return lines.join("\n");
    }
  }
  lines.splice(end, 0, row);
  return lines.join("\n");
}

function withSheetsTable(text) {
  if (text.includes(SHEETS_HEADER)) return text;
  const section = "\n## Wardrobe sheets\n\n"
    + "Gemini renders of the wardrobe prompts (`prompts/image/wardrobe/`), staged at their `game:` path in\n"
    + "`project/assets/sheets/wardrobe/` (not shipped) and keyed to white beside it; each cut in the\n"
    + "Sprites table names its sheet and crop. `tools/land_wardrobe.mjs` writes these rows.\n\n"
    + `${SHEETS_HEADER}\n|---|---|---|---|\n`;
  const at = text.indexOf("\n## Sprites");
  return at < 0 ? text + section : text.slice(0, at) + section + text.slice(at);
}

const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

/** The registration with `sheet` in it: {reg, outfits, sources, changes}. Inputs are not changed. */
function registerSheet(reg0, outfits0, sources0, sheet) {
  const reg = structuredClone(reg0), outfits = structuredClone(outfits0);
  const changes = { parts: { added: [], changed: [], same: [] }, outfits: [], rows: 0 };
  const entry = { path: rel(sheet.white) };
  if (sheet.spec.doll !== undefined) entry.doll = sheet.spec.doll;
  if (sheet.spec.white_threshold !== undefined) entry.white_threshold = sheet.spec.white_threshold;
  if (!reg.sheets) {  // "sheets" goes in before "parts"
    const next = {};
    for (const [k, v] of Object.entries(reg)) {
      if (k === "parts") next.sheets = {};
      next[k] = v;
    }
    if (!next.sheets) next.sheets = {};
    Object.keys(reg).forEach((k) => delete reg[k]);
    Object.assign(reg, next);
  }
  const sheetChanged = !same(reg.sheets[sheet.id], entry);
  reg.sheets[sheet.id] = entry;
  reg.parts = reg.parts || {};
  let sources = withSheetsTable(sources0);
  sources = upsertRow(sources, SHEETS_HEADER, `| \`${sheet.id}\` | ${sheet.tool || "Gemini image"} | \`${rel(sheet.md)}\` | \`${rel(sheet.white)}\` |`);
  for (const [id, p] of Object.entries(sheet.spec.parts)) {
    const part = { sheet: sheet.id };
    for (const k of PART_KEYS) if (p[k] !== undefined) part[k] = p[k];
    const was = reg.parts[id];
    changes.parts[was === undefined ? "added" : same(was, part) ? "same" : "changed"].push(id);
    reg.parts[id] = part;
    const slot = SLOTS[id.split("_")[0]];
    if (!outfits[slot]) outfits[slot] = [];
    if (!outfits[slot].includes(id)) {
      outfits[slot].push(id);
      changes.outfits.push([slot, id]);
    }
    sources = upsertRow(sources, SPRITES_HEADER, `| \`${id}.png\` | \`tools/cut_paperdoll.py\` | \`${sheet.id}\` | ${p.crop} |`);
  }
  changes.sheet = sheetChanged;
  const old = new Set(sources0.split("\n"));
  changes.rows = sources.split("\n").filter((l) => l.startsWith("| `") && !old.has(l)).length;
  return { reg, outfits, sources, changes };
}

// --- Running the steps.

const shown = (cmd, args) => [cmd, ...args].map((a) => (/^[\w@%+=:,./-]+$/.test(a) ? a : `'${a.replace(/'/g, "'\\''")}'`)).join(" ");

function run(cmd, args, capture) {
  console.log(`$ ${shown(cmd, args)}`);
  const r = spawnSync(cmd, args, { cwd: ROOT, encoding: "utf8", maxBuffer: 1 << 26, stdio: capture ? ["ignore", "pipe", "pipe"] : ["ignore", "inherit", "inherit"] });
  const why = r.error ? (r.error.code === "ENOENT" ? `${cmd} not found` : r.error.message) : `exit ${r.status}`;
  return { ok: !r.error && r.status === 0, why, out: r.stdout || "", err: r.stderr || "" };
}

const mtime = (p) => fs.statSync(p).mtimeMs;
const sameBytes = (a, b) => fs.readFileSync(a).equals(fs.readFileSync(b));

function parseArgs(argv) {
  const o = { ids: [], dry: false, skip: new Set(), help: false, error: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--dry-run" || a === "-n") o.dry = true;
    else if (a === "-h" || a === "--help") o.help = true;
    else if (a === "--skip" || a.startsWith("--skip=")) {
      const v = a === "--skip" ? argv[++i] : a.slice(7);
      for (const s of String(v ?? "").split(",").filter(Boolean)) {
        if (!STEPS.includes(s)) o.error = `unknown step "${s}" (steps: ${STEPS.join(", ")})`;
        o.skip.add(s);
      }
    } else if (a.startsWith("-")) o.error = `unknown option ${a}`;
    else o.ids.push(a);
  }
  return o;
}

export function main(argv = process.argv.slice(2)) {
  const o = parseArgs(argv);
  if (o.help) {
    console.log("Usage: node tools/land_wardrobe.mjs [ID ...] [--dry-run] [--skip STEP[,STEP...]]\n"
      + `Steps: ${STEPS.join(", ")}. The parts file, the steps and the environment are in the header of tools/land_wardrobe.mjs.`);
    return 0;
  }
  const prompts = wardrobePrompts();
  const unknown = o.ids.filter((id) => !prompts.some((p) => p.id === id));
  if (o.error || unknown.length) {
    console.error(`land_wardrobe: ${o.error || `no wardrobe prompt ${unknown.join(", ")} in ${rel(WARDROBE)}`}`);
    return 2;
  }
  const dry = o.dry, skip = o.skip;
  const verb = (now, done) => (dry ? `would ${now}` : done);
  const reg0 = JSON.parse(readText(PARTS_JSON)), outfits0 = JSON.parse(readText(OUTFITS_JSON)), sources0 = readText(CANON_SOURCES);
  let reg = reg0, outfits = outfits0, sources = sources0;
  const results = [], ready = [], claimed = new Map();

  for (const s of o.ids.length ? prompts.filter((p) => o.ids.includes(p.id)) : prompts) {
    const r = { id: s.id, status: "", notes: [], errors: [] };
    results.push(r);
    s.r = r;
    if (!s.game || !s.white) { r.status = "failed"; r.errors.push(`${rel(s.md)}: its game: path is not a .png`); continue; }
    s.source = [s.drop, s.game].find((p) => p && isFile(p));
    if (!s.source) {
      r.status = o.ids.length ? "failed" : "not rendered";
      if (o.ids.length) r.errors.push(`no render at ${s.drop ? rel(s.drop) : "its drop: path"} or ${rel(s.game)}`);
      continue;
    }
    if (isLfsPointer(s.source)) { r.status = "failed"; r.errors.push(`${rel(s.source)} is a Git LFS pointer: git lfs pull it first`); continue; }
    const { spec, errors, warnings } = readParts(s, reg0, claimed);
    r.notes.push(...warnings);
    if (errors.length) { r.status = "failed"; r.errors.push(...errors); continue; }
    s.spec = spec;
    ready.push(s);
  }

  // What the steps need.
  const needPython = ready.length && (!skip.has("cut") || !skip.has("rig"));
  const py = needPython ? artPython() : { python: null, tried: [] };
  const body = path.join(CANON, "body_base.png");
  const blocker = needPython && !py.python
    ? `no art Python (numpy, scipy and Pillow; tried ${py.tried.join(", ")}): set ART_PYTHON or make the repo's .venv (tools/requirements-art.txt)`
    : ready.length && !skip.has("cut") && (!isFile(body) || isLfsPointer(body))
      ? `${rel(body)} ${isFile(body) ? "is a Git LFS pointer: git lfs pull it" : "is missing"} (the frame the parts are cut on)` : null;
  if (blocker) for (const s of ready.splice(0)) { s.r.status = "failed"; s.r.errors.push(blocker); }
  if (py.python) console.log(`land_wardrobe: art Python ${py.python}`);

  const tmp = !dry && ready.length && !skip.has("cut") ? fs.mkdtempSync(path.join(os.tmpdir(), "land_wardrobe-")) : null;
  try {
    for (const s of ready) {
      const r = s.r;
      console.log(`== ${s.id} (${rel(s.source)})`);
      const fail = (msg) => { r.status = "failed"; r.errors.push(msg); };
      // sync
      let synced = false;
      if (!skip.has("sync") && s.source === s.drop) {
        if (!isFile(s.game) || (!sameBytes(s.drop, s.game) && mtime(s.drop) > mtime(s.game))) {
          r.notes.push(`${verb("copy", "copied")} ${rel(s.drop)} to ${rel(s.game)}`);
          if (!dry) {
            fs.mkdirSync(path.dirname(s.game), { recursive: true });
            fs.copyFileSync(s.drop, s.game);
            const st = fs.statSync(s.drop);
            fs.utimesSync(s.game, st.atime, st.mtime);
          }
          synced = true;
        } else if (!sameBytes(s.drop, s.game)) r.notes.push(`${rel(s.game)} is newer than the drop and differs: kept`);
      }
      const sheetFile = isFile(s.game) ? s.game : s.source;
      // key
      if (!skip.has("key")) {
        if (synced || !isFile(s.white) || mtime(s.white) < mtime(sheetFile)) {
          const args = [sheetFile, "-fuzz", "12%", "-fill", "white", "-opaque", "#00FF00", "-channel", "G", "-fx", "min(u.g,max(u.r,u.b))", "+channel", s.white];
          if (dry) r.notes.push(`would key: ${shown(MAGICK, args.map((a) => (path.isAbsolute(a) ? rel(a) : a)))}`);
          else {
            fs.mkdirSync(path.dirname(s.white), { recursive: true });
            const k = run(MAGICK, args.map((a) => (path.isAbsolute(a) ? rel(a) : a)), true);
            if (!k.ok) { fail(`key: ${k.why} ${k.err.trim().split("\n").slice(-3).join(" ")}`.trim()); continue; }
            r.notes.push(`keyed ${rel(s.white)}`);
          }
        } else r.notes.push(`${rel(s.white)} is current`);
      }
      if (!dry && !isFile(s.white)) { fail(`no keyed copy ${rel(s.white)}${skip.has("key") ? " (key skipped)" : ""}`); continue; }
      const next = registerSheet(reg, outfits, sources, s);
      const ids = Object.keys(s.spec.parts);
      // cut
      if (!skip.has("cut")) {
        if (dry) r.notes.push(`would cut ${ids.length} parts into ${rel(CANON)}: ${ids.join(", ")}`);
        else {
          const parts = path.join(tmp, `${s.id}.json`);
          fs.writeFileSync(parts, formatParts(next.reg));
          const c = run(py.python, ["-I", "-B", "tools/cut_paperdoll.py", "--sheet", s.id, "--parts", parts], true);
          for (const line of c.out.trim().split("\n").filter(Boolean)) console.log(`  ${line}`);
          const warn = c.err.split("\n").filter((l) => l.startsWith("cut_paperdoll:"));
          r.notes.push(...warn.map((l) => `warning: ${l}`));
          const lost = ids.filter((id) => !isFile(path.join(CANON, `${id}.png`)));
          if (!c.ok || lost.length) {
            fail(`cut: ${c.ok ? `no ${lost.join(", ")}` : c.why} ${c.err.trim().split("\n").filter((l) => !warn.includes(l)).slice(-3).join(" ")}`.trim());
            continue;
          }
          r.notes.push(`cut ${ids.length} parts: ${ids.join(", ")}`);
        }
      }
      // register
      if (!skip.has("register")) {
        const ch = next.changes;
        const what = [ch.sheet ? `the sheet ${s.id}` : "", ch.parts.added.length ? `the parts ${ch.parts.added.join(", ")}` : "",
          ch.parts.changed.length ? `new settings for ${ch.parts.changed.join(", ")}` : ""].filter(Boolean);
        r.notes.push(`paperdoll_parts.json: ${what.length ? `${verb("register", "registered")} ${what.join("; ")}` : "unchanged"}`);
        const bySlot = {};
        for (const [slot, id] of ch.outfits) (bySlot[slot] ||= []).push(id);
        r.notes.push(`outfits.json: ${ch.outfits.length ? `${verb("add", "added")} ${Object.entries(bySlot).map(([slot, ids]) => `${ids.join(", ")} to ${slot}`).join("; ")}` : "unchanged"}`);
        r.notes.push(`canon SOURCES.md: ${ch.rows ? `${verb("write", "wrote")} ${ch.rows} rows` : "unchanged"}`);
        ({ reg, outfits, sources } = next);
      }
      r.status = "landed";
    }
  } finally {
    if (tmp) fs.rmSync(tmp, { recursive: true, force: true });
  }

  // Write what changed.
  const writes = [];
  if (!same(reg, reg0)) writes.push([PARTS_JSON, formatParts(reg)]);
  if (!same(outfits, outfits0)) writes.push([OUTFITS_JSON, formatOutfits(outfits)]);
  if (sources !== sources0) writes.push([CANON_SOURCES, sources]);
  for (const [p, text] of writes) {
    if (!dry) writeText(p, text);
    console.log(`land_wardrobe: ${verb("write", "wrote")} ${rel(p)}`);
  }

  // The steps after the cut, once.
  const landed = results.filter((r) => r.status === "landed");
  const after = [];
  let stepFailed = false;
  const step = (name, cmd, args, capture = false) => {
    if (dry) { after.push(`would run ${shown(cmd, args)}`); return { ok: true, out: "" }; }
    const r = run(cmd, args, capture);
    if (capture && r.out) process.stdout.write(r.out);
    if (!r.ok) {
      after.push(`${name} FAILED (${r.why}) ${r.err.trim().split("\n").slice(-3).join(" ")}`.trim());
      stepFailed = true;
    }
    return r;
  };
  if (landed.length) {
    for (const name of ["rig", "bake", "import", "sources"]) {
      if (stepFailed) break;
      if (skip.has(name)) { after.push(`${name} skipped`); continue; }
      if (name === "rig") step(name, py.python, ["-I", "-B", "tools/gen_player_rig.py"]);
      if (name === "bake") step(name, "bash", ["tools/bake_paper.sh", "characters"]);
      if (name === "import") {
        if (!step(name, GODOT, ["--headless", "--path", "project", "--import"]).ok) break;
        const t = step(name, process.execPath, ["tools/set_texture_imports.mjs"], true);
        const n = Number((t.out.match(/^(\d+) import files changed/m) || [0, 0])[1]);
        if (t.ok && n > 0) step(name, GODOT, ["--headless", "--path", "project", "--import"]);
      }
      if (name === "sources") step(name, process.execPath, ["tools/gen_sources.mjs"], true);
      if (!dry && !stepFailed) after.push(`${name} ok`);
    }
  }

  // Summary.
  const count = (st) => results.filter((r) => r.status === st).length;
  console.log(`\nland_wardrobe${dry ? " (dry run)" : ""}: ${count("landed")} sheet(s) ${dry ? "would land" : "landed"}, ${count("failed")} failed, ${count("not rendered")} not rendered yet`);
  for (const r of results.filter((x) => x.status !== "not rendered")) {
    console.log(`  ${r.id}: ${r.status.toUpperCase()}`);
    for (const e of r.errors) console.log(`    error: ${e}`);
    for (const n of r.notes) console.log(`    ${n}`);
  }
  if (after.length) console.log(`  then: ${after.join("; ")}`);
  return count("failed") || stepFailed ? 1 : 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1"))) {
  process.exit(main());
}
