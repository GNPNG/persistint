#!/usr/bin/env node
/**
 * Bake the paper-cut edge and the drop shadow into sprite sheets (persistint-game-1dx, gsd).
 * Node port of tools/gen_paper_edges.py with the same output format; the image work is done by
 * ImageMagick 7 (`magick`, or the binary named by $MAGICK) through child_process.
 *
 * The overhead Paper Mario look is a light paper border around every cut-out and a soft shadow
 * on the ground under it. Baked once, offline, into sibling sheets, each costs one draw:
 *
 *   <name>_edge<E>_<paper>.png   the art with a paper border baked in, E world px nominal (MARGIN of it)
 *   <name>_ring<E>_<paper>.png   the border alone (paper over the grown silhouette, no art): the
 *                                paper-doll player draws one per worn part under the art stack
 *   <name>_shadow_soft.png       the silhouette (border included) as a blurred black shadow; the
 *   <name>_shadow_hard.png       engine draws it under the sprite with its own offset and modulate
 *   <name>.json                  the sidecar: the new frame grid (cols x rows of equal frames,
 *                                padded so border and shadow never spill into the next frame),
 *                                the padding, the feet line and the padded display height
 *
 * Frames and rows: the sheet is cut into --cols columns x --rows rows of equal frames and written
 * back on the same grid, so RigSheet.frames() (8 columns x 3 rows) reads a baked rig unchanged.
 * Every frame is resized to the bake scale (texture px per world px: --scale, capped by
 * --max-scale, else the source's own), padded by `pad` px on every side, and its alpha grown by
 * the border width with a slow noise wobble between two dilation radii, so it reads as cut paper.
 * How rough that edge is (the author, 2026-10-28: "the edges look a little too rough ... they need
 * to be more smooth"): ROUGHNESS scales the wobble (the inner radius is (1 - 0.4 ROUGHNESS) of the
 * border, so 1 is the first bakes' 0.6 and 0 one even border), KERNEL the shape the alpha grows by
 * (Disk: round; Square: the first bakes' blocky corners) and SMOOTH (world px) rounds the grown
 * outline (a blur and a 50% threshold) before its soften. How wide and how real (the author,
 * 2026-10-28: "reduce the margins of the paper effect a little bit", "could be a tiny bit more
 * subtle", "slightly unreal"): MARGIN is the border's width as a share of its nominal --edges width
 * (edge2 at 0.7 is a 1.4 world-px border; the sheets keep the nominal name and the padding comes
 * from it, so a narrower border bakes the same frame grid, sidecar and file names, and nothing
 * else changes), WHITE the white paper's tone (a warm off-white) and SOFTEN (texture px, an
 * anti-alias) the blur of its outer edge. --roughness, --kernel, --smooth, --margin, --white and
 * --soften set them for one bake; --roughness 1 --kernel Square --smooth 0 --margin 1 --white fffdf7
 * --soften 0.6 bakes as before. The shadow's offset and strength are the engine's (PaperBake).
 * The sidecar's feet = (pad + scaled frame h * --feet) / padded frame h and world_h_padded =
 * world_h * padded h / scaled h; SpriteFit.fit(node, world_h_padded, feet) shows a baked frame at
 * the source's size with its feet where they were.
 *
 *   node tools/gen_paper_edges.mjs SHEET [--layers MORE...] --cols 8 --rows 3 --world-h 52 \
 *       --feet 0.9615 --max-scale 4 --edges 2 --papers white --outputs edge shadow_soft \
 *       --out DIR --name NAME [--roughness R] [--kernel Disk|Square] [--smooth WORLD_PX]
 *       [--margin SHARE] [--white RRGGBB] [--soften PX]
 */
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

/** The white paper, #fbf6ea, a warm off-white (the first bakes': #fffdf7). */
const WHITE = [251, 246, 234];
const PAPERS = { white: WHITE, cream: [255, 240, 210] };
/** The cut-paper edge's roughness, 0 (even) to 1 (the first bakes'), its grow shape and how much
 *  its outline is rounded (world px); see the header. */
const ROUGHNESS = 0.2;
const KERNEL = "Disk";
const SMOOTH = 0.5;
/** The border's width as a share of its nominal --edges width (the first bakes': 1) and the blur
 *  of its outer edge, texture px (the first bakes': 0.6). */
const MARGIN = 0.7;
const SOFTEN = 1.0;
const MAGICK = process.env.MAGICK || "magick";

function parse(argv) {
  const a = { layers: [], cols: 1, rows: 1, worldH: 0, feet: 1.0, scale: 0, maxScale: 0, edges: [1, 2, 3],
    papers: [], outputs: ["edge", "shadow_soft", "shadow_hard"], shadowBlur: 1.5, seed: 7, out: "", name: "", sheet: "",
    roughness: ROUGHNESS, kernel: KERNEL, smooth: SMOOTH, margin: MARGIN, white: WHITE, soften: SOFTEN };
  const lists = { "--layers": "layers", "--edges": "edges", "--papers": "papers", "--outputs": "outputs" };
  const nums = { "--cols": "cols", "--rows": "rows", "--world-h": "worldH", "--feet": "feet", "--scale": "scale",
    "--max-scale": "maxScale", "--shadow-blur": "shadowBlur", "--seed": "seed", "--roughness": "roughness", "--smooth": "smooth",
    "--margin": "margin", "--soften": "soften" };
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    if (lists[k]) {
      const vals = [];
      while (i + 1 < argv.length && !argv[i + 1].startsWith("--")) vals.push(argv[++i]);
      a[lists[k]] = k === "--edges" ? vals.map(Number) : vals;
    } else if (nums[k]) a[nums[k]] = Number(argv[++i]);
    else if (k === "--out") a.out = argv[++i];
    else if (k === "--name") a.name = argv[++i];
    else if (k === "--kernel") a.kernel = argv[++i];
    else if (k === "--white") {
      const h = String(argv[++i]).replace(/^#/, "");
      if (!/^[0-9a-fA-F]{6}$/.test(h)) throw new Error(`--white ${h}: RRGGBB`);
      a.white = [0, 2, 4].map((j) => parseInt(h.slice(j, j + 2), 16));
    }
    else if (k === "-h" || k === "--help") { console.log(fs.readFileSync(new URL(import.meta.url)).toString().split("*/")[0]); process.exit(0); }
    else if (k.startsWith("--")) throw new Error(`unknown option ${k}`);
    else a.sheet = k;
  }
  if (!a.sheet || !a.worldH || !a.out || !a.name) throw new Error("need SHEET, --world-h, --out and --name");
  if (!(a.roughness >= 0 && a.roughness <= 1)) throw new Error(`--roughness ${a.roughness}: 0 to 1`);
  if (!(a.smooth >= 0)) throw new Error(`--smooth ${a.smooth}: 0 or more world px`);
  if (!["Disk", "Square"].includes(a.kernel)) throw new Error(`--kernel ${a.kernel}: Disk or Square`);
  if (!(a.margin > 0)) throw new Error(`--margin ${a.margin}: a share of the nominal width, more than 0`);
  if (!(a.soften >= 0)) throw new Error(`--soften ${a.soften}: 0 or more texture px`);
  return a;
}

const magick = (args) => execFileSync(MAGICK, args, { stdio: ["ignore", "pipe", "inherit"] }).toString();
const size = (p) => magick(["identify", "-format", "%w %h", p]).trim().split(" ").map(Number);
const rgb = (c) => `rgb(${c.join(",")})`;
// Python-style JSON floats (4.0, not 4) so the sidecar reads like the .py tool's.
const fl = (v) => (Number.isInteger(v) ? `${v}.0` : String(v));

function bake(a) {
  fs.mkdirSync(a.out, { recursive: true });
  fs.mkdirSync(path.resolve(".cache"), { recursive: true });
  const tmp = fs.mkdtempSync(path.join(path.resolve(".cache"), "paper_edges-"));
  try {
    // Composite the layers (same size), then cut into frames, row-major.
    const [sw, sh] = size(a.sheet);
    for (const l of a.layers) {
      const [lw, lh] = size(l);
      if (lw !== sw || lh !== sh) throw new Error(`${l}: size ${lw}x${lh} differs from ${a.sheet} ${sw}x${sh}`);
    }
    const srcFw = Math.floor(sw / a.cols), srcFh = Math.floor(sh / a.rows);
    if (srcFw * a.cols !== sw || srcFh * a.rows !== sh) throw new Error(`sheet ${sw}x${sh} does not divide into ${a.cols}x${a.rows} frames`);
    const srcScale = srcFh / a.worldH;
    let scale = a.scale || srcScale;
    if (a.maxScale) scale = Math.min(scale, a.maxScale);
    const k = scale / srcScale;
    const fw = Math.max(1, Math.round(srcFw * k)), fh = Math.max(1, Math.round(srcFh * k));
    // The padding from the nominal width (a narrower border keeps the frame grid).
    const maxEdge = Math.max(...a.edges) * Math.max(1, a.margin) * scale;
    const blurSoft = a.shadowBlur * scale;
    const pad = Math.ceil(maxEdge + blurSoft * 3) + 2;
    const pw = fw + 2 * pad, ph = fh + 2 * pad;
    const cw = Math.max(2, Math.floor(pw / 6)), ch = Math.max(2, Math.floor(ph / 6));
    const stack = [a.sheet];
    for (const l of a.layers) stack.push(l, "-compose", "Over", "-composite");
    magick([...stack, "-crop", `${srcFw}x${srcFh}`, "+repage", path.join(tmp, "f_%03d.png")]);
    const n = a.cols * a.rows;
    const tones = { ...PAPERS, white: a.white };
    const papers = Object.keys(tones).filter((p) => !a.papers.length || a.papers.includes(p));
    const widest = Math.max(...a.edges);
    const cells = {}; // key -> [cell paths]
    const push = (key, p) => (cells[key] ||= []).push(p);
    for (let i = 0; i < n; i++) {
      const f = path.join(tmp, `f_${String(i).padStart(3, "0")}.png`);
      for (const e of a.edges) {
        const r = e * a.margin * scale, rs = Math.max(1, r * (1 - 0.4 * a.roughness));
        // Square takes whole px (the first bakes'); Disk a radius.
        const grow = (radius) => `${a.kernel}:${a.kernel === "Square" ? Math.max(1, Math.ceil(radius)) : +Math.max(1, radius).toFixed(3)}`;
        const smooth = a.smooth > 0 ? ["-blur", `0x${+(a.smooth * scale).toFixed(3)}`, "-threshold", "50%"] : [];
        const cell = (kind, p) => path.join(tmp, `${kind}_e${e}_${p}_${String(i).padStart(3, "0")}.png`);
        const args = [f, "-filter", "Lanczos", "-resize", `${fw}x${fh}!`, "-background", "none", "-gravity", "center",
          "-extent", `${pw}x${ph}`, "+repage", "-write", "mpr:art", "+delete",
          // The ring: the alpha grown by r or by rs, picked by a coarse noise field; its outline
          // rounded (SMOOTH), then softened (SOFTEN).
          "mpr:art", "-alpha", "extract", "-morphology", "Dilate", grow(rs),
          "(", "mpr:art", "-alpha", "extract", "-morphology", "Dilate", grow(r), ")",
          "(", "-size", `${cw}x${ch}`, "xc:gray", "-seed", String(a.seed * 100003 + e * 1009 + i), "+noise", "Random",
          "-colorspace", "gray", "-filter", "Catrom", "-resize", `${pw}x${ph}!`, "-threshold", "46.3%", ")",
          "-compose", "Over", "-composite", ...smooth, "-blur", `0x${+a.soften.toFixed(3)}`, "-write", "mpr:ring", "+delete"];
        for (const p of papers) {
          const paper = ["(", "-size", `${pw}x${ph}`, `xc:${rgb(tones[p])}`, "mpr:ring", "-alpha", "off", "-compose", "CopyOpacity", "-composite", ")"];
          if (a.outputs.includes("ring")) {
            const out = cell("ring", p);
            args.push(...paper, "-depth", "8", "-write", out, "+delete");
            push(`ring${e}_${p}`, out);
          }
          if (a.outputs.includes("edge")) {
            const out = cell("edge", p);
            args.push(...paper, "mpr:art", "-compose", "Over", "-composite", "-depth", "8", "-write", out, "+delete");
            push(`edge${e}_${p}`, out);
          }
        }
        // Shadows from the widest border, so the shadow hugs it.
        if (e === widest) {
          for (const [kind, blur] of [["soft", blurSoft], ["hard", 0.5]]) {
            if (!a.outputs.includes(`shadow_${kind}`)) continue;
            const out = cell(`shadow_${kind}`, "black");
            args.push("(", "-size", `${pw}x${ph}`, "xc:black", "(", "mpr:ring", "-blur", `0x${blur}`, ")", "-alpha", "off",
              "-compose", "CopyOpacity", "-composite", ")", "-depth", "8", "-write", out, "+delete");
            push(`shadow_${kind}`, out);
          }
        }
        args.push("-size", "1x1", "xc:none", "null:");
        magick(args);
      }
    }
    // Assemble the sheets on the frame grid.
    const order = [];
    for (const e of a.edges) for (const p of papers) for (const kind of ["edge", "ring"]) order.push(`${kind}${e}_${p}`);
    order.push("shadow_soft", "shadow_hard");
    const written = {};
    for (const key of order) {
      if (!cells[key]) continue;
      const name = `${a.name}_${key}.png`;
      const rows = [];
      for (let r = 0; r < a.rows; r++) {
        const row = path.join(tmp, `row_${key}_${r}.png`);
        magick([...cells[key].slice(r * a.cols, (r + 1) * a.cols), "-background", "none", "+append", row]);
        rows.push(row);
      }
      magick([...rows, "-background", "none", "-append", "-depth", "8", "-define", "png:color-type=6",
        "-define", "png:compression-level=9", path.join(a.out, name)]);
      written[key] = name;
    }
    const feet = (pad + fh * a.feet) / ph;
    const side = [
      `  "source": ${JSON.stringify([a.sheet, ...a.layers])}`, `  "cols": ${a.cols}`, `  "rows": ${a.rows}`,
      `  "src_frame": [${srcFw}, ${srcFh}]`, `  "scaled_frame": [${fw}, ${fh}]`, `  "frame": [${pw}, ${ph}]`,
      `  "pad": ${pad}`, `  "scale": ${fl(scale)}`, `  "world_h": ${fl(a.worldH)}`, `  "feet": ${fl(feet)}`,
      `  "world_h_padded": ${fl(a.worldH * ph / fh)}`, `  "edges": [${a.edges.join(", ")}]`,
      `  "files": {\n${Object.entries(written).map(([k2, v]) => `    "${k2}": "${v}"`).join(",\n")}\n  }`,
    ];
    fs.writeFileSync(path.join(a.out, `${a.name}.json`), `{\n${side.join(",\n")}\n}\n`);
    console.log(`${a.name}: ${a.cols}x${a.rows} frames ${srcFw}x${srcFh} -> ${pw}x${ph} (pad ${pad}, ${+scale.toFixed(4)} px/world px; `
      + `edge roughness ${a.roughness}, ${a.kernel}, smooth ${a.smooth}, margin ${a.margin}, soften ${a.soften}, white ${rgb(a.white)}); `
      + `${Object.keys(written).length} sheets`);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
}

bake(parse(process.argv.slice(2)));
