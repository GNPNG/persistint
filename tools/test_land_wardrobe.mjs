#!/usr/bin/env node
/**
 * Checks for tools/land_wardrobe.mjs (bd lg5w.2) on small synthetic wardrobe sheets, drawn here (a
 * green background, warm fills and outlines, the bald reference doll at the left, as the Gemini
 * sheets are) so no big binary is committed.
 *
 *   node tools/test_land_wardrobe.mjs           the checks, in a temp copy of what the driver reads
 *                                               and writes; prints "ok"/"FAIL" per check and
 *                                               "RESULT: PASS|FAIL (n failures)", exits 0 or 1
 *   node tools/test_land_wardrobe.mjs --stage   put the two synthetic sheets at their drop paths
 *                                               and their parts files beside the prompts, in this
 *                                               clone (a scratch clone: commit none of it), for a
 *                                               run of the driver with every step
 *
 * The temp copy: the driver, lib_paths.mjs and cut_paperdoll.py under tools/, paperdoll_parts.json,
 * outfits.json and the canon SOURCES.md as they are, the wardrobe_tops, _hats and _shoes prompts,
 * and a drawn body_base.png (the frame: 200x300, head top y 25, soles y 275). The sheets are the
 * tops and the hats (720x300; the doll at half the body's size, head top y 20, soles y 145), their
 * green drops and, since this laptop runs no ImageMagick, their keys to white drawn alongside (the
 * driver runs with --skip key,rig,bake,import,sources here; cc-srv runs every step).
 * Checked: a dry run changes no file; a run lands both sheets (the sheets and parts registered with
 * the prompt's ids, each part once under its slot in outfits.json after "none", a row each in the
 * canon SOURCES.md, the drops synced to their game: paths); the cut parts are on the frame, the tops
 * at the doll's scale, centred on the body where they stand beside her and the hats at their
 * anchors; a second run changes nothing; a sheet with no parts file, a part the prompt does not
 * list, a hat with no anchor and a part already cut from another sheet fail and write nothing; an
 * unknown sheet or step is a usage error. Also: the driver writes paperdoll_parts.json and
 * outfits.json as the repository has them (byte for byte), its slots are cut_paperdoll.py's, and
 * every wardrobe prompt's Notes name parts of its slot.
 * The cut needs the art Python (lib_paths.mjs artPython, as test_paperdoll_tools.gd looks): without
 * it the checks FAIL, unless PERSISTINT_SKIP_ART_TESTS=1, which skips the cut checks only.
 */
import { spawnSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import zlib from "node:zlib";
import { ROOT, artPython, readText } from "./lib_paths.mjs";
import { SLOTS, formatParts, formatOutfits, notesOf } from "./land_wardrobe.mjs";

const FILL = [240, 196, 200], INK = [138, 90, 90], GREEN = [0, 255, 0], WHITE = [255, 255, 255];
let failures = 0;
const check = (ok, what) => {
  console.log(`${ok ? "ok   " : "FAIL "}${what}`);
  if (!ok) failures++;
};

// --- PNG: 8-bit RGB / RGBA, no interlace (what this test draws and Pillow writes).

const CRC = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
const crc32 = (buf) => {
  let c = 0xffffffff;
  for (const b of buf) c = CRC[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};
function chunk(type, data) {
  const head = Buffer.alloc(4), tail = Buffer.alloc(4), body = Buffer.concat([Buffer.from(type, "latin1"), data]);
  head.writeUInt32BE(data.length);
  tail.writeUInt32BE(crc32(body));
  return Buffer.concat([head, body, tail]);
}
function encodePng(img) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(img.w, 0);
  ihdr.writeUInt32BE(img.h, 4);
  ihdr[8] = 8;
  ihdr[9] = img.ch === 4 ? 6 : 2;
  const stride = img.w * img.ch, raw = Buffer.alloc((stride + 1) * img.h);
  for (let y = 0; y < img.h; y++) Buffer.from(img.px.subarray(y * stride, (y + 1) * stride)).copy(raw, y * (stride + 1) + 1);
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]);
}
function decodePng(buf) {
  let off = 8, w = 0, h = 0, depth = 0, type = 0, inter = 0;
  const idat = [];
  while (off < buf.length) {
    const len = buf.readUInt32BE(off), t = buf.toString("latin1", off + 4, off + 8), d = buf.subarray(off + 8, off + 8 + len);
    off += 12 + len;
    if (t === "IHDR") [w, h, depth, type, inter] = [d.readUInt32BE(0), d.readUInt32BE(4), d[8], d[9], d[12]];
    else if (t === "IDAT") idat.push(d);
    else if (t === "IEND") break;
  }
  const ch = { 0: 1, 2: 3, 4: 2, 6: 4 }[type];
  if (depth !== 8 || inter !== 0 || !ch) throw new Error(`unsupported PNG (depth ${depth}, colour type ${type}, interlace ${inter})`);
  const raw = zlib.inflateSync(Buffer.concat(idat)), stride = w * ch, px = new Uint8Array(h * stride);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)], line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= ch ? px[y * stride + x - ch] : 0, b = y ? px[(y - 1) * stride + x] : 0;
      const c = x >= ch && y ? px[(y - 1) * stride + x - ch] : 0;
      let v = line[x];
      if (f === 1) v += a;
      else if (f === 2) v += b;
      else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) {
        const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
        v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      }
      px[y * stride + x] = v & 255;
    }
  }
  return { w, h, ch, px };
}
/** The box of the pixels with alpha over `level`: [x0, y0, x1, y1], or null. */
function alphaBox(img, level = 128) {
  let x0 = Infinity, y0 = Infinity, x1 = -1, y1 = -1;
  for (let y = 0; y < img.h; y++) for (let x = 0; x < img.w; x++) {
    const a = img.ch === 4 ? img.px[(y * img.w + x) * 4 + 3] : img.ch === 2 ? img.px[(y * img.w + x) * 2 + 1] : 255;
    if (a > level) [x0, y0, x1, y1] = [Math.min(x0, x), Math.min(y0, y), Math.max(x1, x), Math.max(y1, y)];
  }
  return x1 < 0 ? null : [x0, y0, x1, y1];
}

// --- Drawing: filled shapes with a 2 px outline, boxes inclusive (as Pillow's ImageDraw).

const canvas = (w, h, bg) => {
  const img = { w, h, ch: bg.length, px: new Uint8Array(w * h * bg.length) };
  for (let i = 0; i < w * h; i++) img.px.set(bg, i * bg.length);
  return img;
};
const put = (img, x, y, c) => {
  if (x >= 0 && y >= 0 && x < img.w && y < img.h) img.px.set(img.ch === 4 ? [...c, 255] : c, (y * img.w + x) * img.ch);
};
function rect(img, x0, y0, x1, y1) {
  [x0, y0, x1, y1] = [x0, y0, x1, y1].map(Math.round);
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
    put(img, x, y, x - x0 < 2 || x1 - x < 2 || y - y0 < 2 || y1 - y < 2 ? INK : FILL);
  }
}
function ellipse(img, x0, y0, x1, y1) {
  const cx = (x0 + x1 + 1) / 2, cy = (y0 + y1 + 1) / 2, rx = (x1 - x0 + 1) / 2, ry = (y1 - y0 + 1) / 2;
  for (let y = Math.floor(y0); y <= Math.ceil(y1); y++) for (let x = Math.floor(x0); x <= Math.ceil(x1); x++) {
    const dx = x + 0.5 - cx, dy = y + 0.5 - cy;
    if ((dx / rx) ** 2 + (dy / ry) ** 2 > 1) continue;
    put(img, x, y, (dx / (rx - 2)) ** 2 + (dy / (ry - 2)) ** 2 <= 1 ? FILL : INK);
  }
}
/** The body shape (head top at oy, soles at oy + 250 k), drawn at scale k from (ox, oy): the
 *  doll of tools/test_paperdoll_tools.py. */
function doll(img, ox, oy, k) {
  const b = (x0, y0, x1, y1) => [ox + x0 * k, oy + y0 * k, ox + x1 * k, oy + y1 * k];
  ellipse(img, ...b(0, 0, 100, 100));
  rect(img, ...b(40, 96, 60, 118));
  rect(img, ...b(20, 118, 80, 190));
  rect(img, ...b(25, 190, 45, 250));
  rect(img, ...b(55, 190, 75, 250));
}

/** The synthetic sheets: id -> {draw(bg), parts file}. Items at the doll's heights. */
const SHEETS = {
  wardrobe_tops: {
    draw: (bg) => {
      const img = canvas(720, 300, bg);
      doll(img, 20, 20, 0.5);
      for (const x of [150, 250, 350]) rect(img, x, 79, x + 30, 115);  // the torso: 118-190 at 0.5
      return img;
    },
    parts: { doll: "70x140+10+10", parts: {
      top_tee_heart: { crop: "50x50+140+70" }, top_cardigan_butter: { crop: "50x50+240+70" }, top_hoodie_lilac: { crop: "50x50+340+70" } } },
  },
  wardrobe_hats: {
    draw: (bg) => {
      const img = canvas(720, 300, bg);
      doll(img, 20, 20, 0.5);
      for (const x of [150, 250, 350]) ellipse(img, x, 20, x + 50, 40);
      return img;
    },
    parts: { doll: "70x140+10+10", parts: {
      hat_straw: { crop: "70x34+140+13", anchor: [0, 30], scale: 2.0 },
      hat_beret_rose: { crop: "70x34+240+13", anchor: [-10, 25], scale: 1.5 },
      hat_sailor: { crop: "70x34+340+13", anchor: [10, 35], scale: 1.0 } } },
  },
};
const BODY = { w: 200, h: 300, ox: 50, top: 25, feet: 275, cx: 100 };

function writeSheet(root, id, withWhite) {
  const prompt = readText(path.join(root, `prompts/image/wardrobe/${id}.md`));
  const drop = prompt.match(/^drop: (.*)$/m)[1].trim(), game = prompt.match(/^game: (.*)$/m)[1].trim();
  fs.mkdirSync(path.dirname(path.join(root, drop)), { recursive: true });
  fs.writeFileSync(path.join(root, drop), encodePng(SHEETS[id].draw(GREEN)));
  fs.writeFileSync(path.join(root, `prompts/image/wardrobe/${id}.parts.json`), JSON.stringify(SHEETS[id].parts, null, 2) + "\n");
  if (withWhite) {  // what the skill's key (green to white, then the despill) makes of it: these fills keep their green
    const white = path.join(root, game.replace(/\.png$/, "_white.png"));
    fs.mkdirSync(path.dirname(white), { recursive: true });
    fs.writeFileSync(white, encodePng(SHEETS[id].draw(WHITE)));
    const later = new Date(Date.now() + 2000);
    fs.utimesSync(white, later, later);
  }
  return { drop, game };
}

// --- The temp copy and the runs.

function tempRoot() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "land_wardrobe-test-"));
  const copy = (rel) => {
    fs.mkdirSync(path.dirname(path.join(root, rel)), { recursive: true });
    fs.copyFileSync(path.join(ROOT, rel), path.join(root, rel));
  };
  for (const rel of ["tools/land_wardrobe.mjs", "tools/lib_paths.mjs", "tools/cut_paperdoll.py", "project/data/paperdoll_parts.json",
    "project/data/outfits.json", "project/assets/canon/SOURCES.md", "prompts/image/wardrobe/wardrobe_tops.md",
    "prompts/image/wardrobe/wardrobe_hats.md", "prompts/image/wardrobe/wardrobe_shoes.md"]) copy(rel);
  const body = canvas(BODY.w, BODY.h, [0, 0, 0, 0]);
  doll(body, BODY.ox, BODY.top, 1.0);
  fs.writeFileSync(path.join(root, "project/assets/canon/body_base.png"), encodePng(body));
  return root;
}

function snapshot(root) {
  const out = {};
  const walk = (d) => {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      const p = path.join(d, e.name);
      if (e.isDirectory()) walk(p);
      else out[path.relative(root, p)] = crypto.createHash("sha1").update(fs.readFileSync(p)).digest("hex");
    }
  };
  walk(root);
  return out;
}
const changedFiles = (a, b) => [...new Set([...Object.keys(a), ...Object.keys(b)])].filter((k) => a[k] !== b[k]).sort();

function main() {
  const py = artPython();
  const skipArt = !py.python && process.env.PERSISTINT_SKIP_ART_TESTS === "1";
  if (process.argv.includes("--stage")) {
    const there = Object.keys(SHEETS).flatMap((id) => [`prompts/image/wardrobe/${id}.parts.json`, `prompts/image/wardrobe/assets/${id}.png`])
      .filter((p) => fs.existsSync(path.join(ROOT, p)));
    if (there.length) { console.error(`test_land_wardrobe: ${there.join(", ")} exist already; stage in a scratch clone`); return 2; }
    for (const id of Object.keys(SHEETS)) {
      const { drop } = writeSheet(ROOT, id, false);
      console.log(`staged ${drop} and prompts/image/wardrobe/${id}.parts.json`);
    }
    console.log("now: node tools/land_wardrobe.mjs (every step), then tools/run_tests.sh; commit none of it");
    return 0;
  }
  if (!py.python && !skipArt) check(false, `an art Python for the cut (tried ${py.tried.join(", ")}; set ART_PYTHON or PERSISTINT_SKIP_ART_TESTS=1)`);
  if (skipArt) console.log(`SKIP: the cut checks (no art Python: ${py.tried.join(", ")}; PERSISTINT_SKIP_ART_TESTS=1)`);
  const doCut = Boolean(py.python);

  // What does not need a run: the formats, the slots, the prompts' Notes.
  for (const f of ["project/data/paperdoll_parts.json", "project/data/outfits.json"]) {
    const text = readText(path.join(ROOT, f));
    const again = f.endsWith("outfits.json") ? formatOutfits(JSON.parse(text)) : formatParts(JSON.parse(text));
    check(again === text, `the driver writes ${f} as the repository has it`);
  }
  const cp = readText(path.join(ROOT, "tools/cut_paperdoll.py")).match(/^SLOTS = (\{[^}]*\})/m);
  const cpSlots = cp ? Object.fromEntries([...cp[1].matchAll(/"([a-z]+)": "([a-z]+)"/g)].map((m) => [m[1], m[2]])) : {};
  check(JSON.stringify(cpSlots) === JSON.stringify(SLOTS), `the driver's slots are cut_paperdoll.py's (${JSON.stringify(cpSlots)})`);
  const wardrobe = path.join(ROOT, "prompts/image/wardrobe");
  const offSlot = [];
  for (const f of fs.readdirSync(wardrobe).filter((x) => x.endsWith(".md"))) {
    const n = notesOf(readText(path.join(wardrobe, f)));
    if (!n.ids || !n.slot) offSlot.push(`${f}: no part list or slot`);
    else for (const id of n.ids) if (SLOTS[id.split("_")[0]] !== n.slot) offSlot.push(`${f}: ${id} (${n.slot})`);
  }
  check(!offSlot.length, `every wardrobe prompt's Notes list parts of its slot (${offSlot.join("; ")})`);

  const root = tempRoot();
  const env = { ...process.env, ...(doCut ? { ART_PYTHON: py.python } : {}) };
  const skip = `key,rig,bake,import,sources${doCut ? "" : ",cut"}`;
  const land = (...args) => {
    const r = spawnSync(process.execPath, [path.join(root, "tools/land_wardrobe.mjs"), ...args], { cwd: root, env, encoding: "utf8" });
    return { code: r.status, out: (r.stdout || "") + (r.stderr || "") };
  };
  const tail = (r) => r.out.trim().split("\n").slice(-6).join(" | ");
  try {
    const sheets = Object.fromEntries(Object.keys(SHEETS).map((id) => [id, writeSheet(root, id, true)]));
    const regPath = path.join(root, "project/data/paperdoll_parts.json"), outPath = path.join(root, "project/data/outfits.json");
    const srcPath = path.join(root, "project/assets/canon/SOURCES.md");
    const reg0 = JSON.parse(readText(regPath)), outfits0 = JSON.parse(readText(outPath));

    // A dry run.
    let before = snapshot(root);
    let r = land("--dry-run", "--skip", skip);
    check(r.code === 0 && r.out.includes("2 sheet(s) would land") && r.out.includes("would add top_tee_heart, top_cardigan_butter, top_hoodie_lilac to top"),
      `a dry run plans both sheets (exit ${r.code}: ${tail(r)})`);
    let changed = changedFiles(before, snapshot(root));
    check(!changed.length, `and changes no file (${changed.join(", ")})`);

    // Landing.
    r = land("--skip", skip);
    check(r.code === 0 && r.out.includes("2 sheet(s) landed, 0 failed"), `a run lands both sheets (exit ${r.code}: ${tail(r)})`);
    const reg = JSON.parse(readText(regPath)), outfits = JSON.parse(readText(outPath)), sources = readText(srcPath);
    check(Object.keys(reg).indexOf("sheets") === Object.keys(reg).indexOf("parts") - 1
      && JSON.stringify(reg.sheets.wardrobe_tops) === JSON.stringify({ path: "project/assets/sheets/wardrobe/wardrobe_tops_white.png", doll: "70x140+10+10" }),
      `the sheet is registered before the parts, with its keyed copy and its doll (${JSON.stringify(reg.sheets)})`);
    const want = { ...Object.fromEntries(Object.entries(SHEETS.wardrobe_tops.parts.parts).map(([k, v]) => [k, { sheet: "wardrobe_tops", ...v }])),
      ...Object.fromEntries(Object.entries(SHEETS.wardrobe_hats.parts.parts).map(([k, v]) => [k, { sheet: "wardrobe_hats", ...v }])) };
    check(Object.entries(want).every(([k, v]) => JSON.stringify(reg.parts[k]) === JSON.stringify(v)), "each part is registered with its sheet, crop, anchor and scale");
    check(Object.entries(reg0.parts).every(([k, v]) => JSON.stringify(reg.parts[k]) === JSON.stringify(v))
      && Object.keys(reg.parts).length === Object.keys(reg0.parts).length + 6, "the canon parts are as they were, and nothing else is added");
    check(JSON.stringify(outfits.top) === JSON.stringify(["none", "top_tee_heart", "top_cardigan_butter", "top_hoodie_lilac"])
      && JSON.stringify(outfits.hat) === JSON.stringify(["none", "hat_straw", "hat_beret_rose", "hat_sailor"]),
      `outfits.json has each part once under its slot, after "none" (top ${outfits.top}; hat ${outfits.hat})`);
    check(Object.keys(outfits0).every((k) => k === "top" || k === "hat" || JSON.stringify(outfits[k]) === JSON.stringify(outfits0[k])), "the other slots are as they were");
    const rows = Object.keys(want).map((k) => `| \`${k}.png\` | \`tools/cut_paperdoll.py\` | \`${reg.parts[k].sheet}\` | ${reg.parts[k].crop} |`);
    const table = sources.split("\n").filter((l) => /^\| `[a-z_]+\.png` \| /.test(l));
    check(rows.every((row) => table.includes(row)) && JSON.stringify(table) === JSON.stringify([...table].sort()),
      "the canon SOURCES.md has a row per part, the table still sorted");
    check(sources.includes("| `wardrobe_tops` | Gemini image | `prompts/image/wardrobe/wardrobe_tops.md` | `project/assets/sheets/wardrobe/wardrobe_tops_white.png` |"),
      "and a row per sheet");
    check(Object.values(sheets).every(({ drop, game }) => fs.readFileSync(path.join(root, drop)).equals(fs.readFileSync(path.join(root, game)))),
      "the drops are synced to their game: paths");

    if (doCut) {
      const cut = (id) => decodePng(fs.readFileSync(path.join(root, `project/assets/canon/${id}.png`)));
      const ids = Object.keys(want);
      const sizes = ids.map((id) => { const im = cut(id); return `${im.w}x${im.h}`; });
      check(sizes.every((s) => s === `${BODY.w}x${BODY.h}`), `every part is cut on the ${BODY.w}x${BODY.h} frame (${sizes.join(", ")})`);
      const k = (BODY.feet - BODY.top) / 125;
      for (const id of Object.keys(SHEETS.wardrobe_tops.parts.parts)) {
        const b = alphaBox(cut(id));
        check(b && Math.abs((b[0] + b[2]) / 2 - BODY.cx) <= 2 && Math.abs(b[1] - (BODY.top + 59 * k)) <= 3 && Math.abs(b[3] - b[1] - 36 * k) <= 4,
          `${id} takes the doll's scale and stands on the torso, centred (box ${b}; want top y ${BODY.top + 59 * k}, height ${36 * k})`);
      }
      for (const [id, p] of Object.entries(SHEETS.wardrobe_hats.parts.parts)) {
        const b = alphaBox(cut(id));
        check(b && Math.abs((b[0] + b[2]) / 2 - (BODY.cx + p.anchor[0])) <= 2 && Math.abs((b[1] + b[3]) / 2 - (BODY.top + p.anchor[1])) <= 2,
          `${id} sits at its anchor (box ${b}; want centre ${BODY.cx + p.anchor[0]}, ${BODY.top + p.anchor[1]})`);
      }
    }

    // Again: nothing changes.
    before = snapshot(root);
    r = land("--skip", skip);
    changed = changedFiles(before, snapshot(root)).filter((f) => !f.startsWith("project/assets/canon/") || f.endsWith(".md"));
    check(r.code === 0 && !changed.length && (r.out.match(/outfits\.json: unchanged/g) || []).length === 2,
      `a second run changes nothing and lists nothing twice (exit ${r.code}; changed ${changed.join(", ")})`);

    // Failures write nothing.
    const fails = (what, setup, undo, expect, args = []) => {
      setup();
      const b = snapshot(root);
      const x = land("--skip", skip, ...args);
      const ch = changedFiles(b, snapshot(root)).filter((f) => !f.startsWith("project/assets/canon/") || f.endsWith(".md"));
      check(x.code === 1 && x.out.includes(expect) && !ch.length, `${what} fails and writes nothing (exit ${x.code}; changed ${ch.join(", ")}; ${tail(x)})`);
      undo();
    };
    const shoesDrop = path.join(root, "prompts/image/wardrobe/assets/wardrobe_shoes.png");
    fails("a sheet with no parts file", () => fs.writeFileSync(shoesDrop, encodePng(SHEETS.wardrobe_tops.draw(GREEN))),
      () => fs.rmSync(shoesDrop), "no parts file prompts/image/wardrobe/wardrobe_shoes.parts.json", ["wardrobe_shoes"]);
    const topsParts = path.join(root, "prompts/image/wardrobe/wardrobe_tops.parts.json"), hatsParts = path.join(root, "prompts/image/wardrobe/wardrobe_hats.parts.json");
    const keep = { tops: readText(topsParts), hats: readText(hatsParts), reg: readText(regPath) };
    const edit = (file, fn) => () => { const j = JSON.parse(readText(file)); fn(j); fs.writeFileSync(file, JSON.stringify(j, null, 2) + "\n"); };
    fails("a part the prompt does not list", edit(topsParts, (j) => { j.parts.top_mystery = { crop: "10x10+1+1" }; }),
      () => fs.writeFileSync(topsParts, keep.tops), "top_mystery: not one of the prompt's parts", ["wardrobe_tops"]);
    fails("a hat with no anchor", edit(hatsParts, (j) => { delete j.parts.hat_straw.anchor; }),
      () => fs.writeFileSync(hatsParts, keep.hats), "hat_straw: a hat_ part needs \"anchor\"", ["wardrobe_hats"]);
    fails("a part already cut from another sheet", edit(regPath, (j) => { j.parts.top_tee_heart.sheet = "wardrobe_hats"; }),
      () => fs.writeFileSync(regPath, keep.reg), "top_tee_heart: already cut from the wardrobe_hats sheet", ["wardrobe_tops"]);
    r = land("wardrobe_nosuch");
    check(r.code === 2 && r.out.includes("no wardrobe prompt wardrobe_nosuch"), `an unknown sheet is a usage error (exit ${r.code})`);
    r = land("--skip", "bakery");
    check(r.code === 2 && r.out.includes("unknown step"), `an unknown step is a usage error (exit ${r.code})`);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
  console.log(`RESULT: ${failures === 0 ? "PASS" : "FAIL"} (${failures} failures)`);
  return failures === 0 ? 0 : 1;
}

process.exit(main());
