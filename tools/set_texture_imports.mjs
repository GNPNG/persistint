#!/usr/bin/env node
/**
 * Node port of tools/set_texture_imports.py, same rule and same edits: lossy import for the big
 * textures, so the web build stays small.
 *
 * Every PNG under project/assets at or over --min-bytes (default 300 KB) gets compress/mode=1
 * (Lossy: WebP) at compress/lossy_quality (default 0.9) in its .import file; smaller ones stay
 * lossless (mode 0). Run `godot --headless --path project --import` afterwards. Idempotent.
 *
 *   node tools/set_texture_imports.mjs [--min-bytes N] [--quality Q] [--dry-run]
 */
import fs from "node:fs";
import path from "node:path";
import { PROJECT, ROOT, rel, rglob, readText, writeText, reEscape } from "./lib_paths.mjs";

const ASSETS = path.join(PROJECT, "assets");

export function setOption(text, key, value) {
  const pat = new RegExp(`^${reEscape(key)}=[^\\n]*$`, "m");
  if (pat.test(text)) return text.replace(new RegExp(pat.source, "gm"), `${key}=${value}`);
  return text.replace("[params]\n", `[params]\n\n${key}=${value}\n`);
}

// Python's f"{q:g}" for the usual qualities (0.9 -> 0.9, 1.0 -> 1).
const g = (q) => String(Number(q.toPrecision(6)));

function main() {
  const argv = process.argv.slice(2);
  const opt = (k, d) => (argv.includes(k) ? Number(argv[argv.indexOf(k) + 1]) : d);
  const minBytes = opt("--min-bytes", 300 * 1024), quality = opt("--quality", 0.9), dry = argv.includes("--dry-run");
  let changed = 0;
  for (const png of rglob(ASSETS).filter((p) => p.endsWith(".png"))) {
    const imp = png + ".import";
    if (!fs.existsSync(imp)) continue;
    const text = readText(imp);
    const big = fs.statSync(png).size >= minBytes;
    let next = setOption(text, "compress/mode", big ? "1" : "0");
    if (big) next = setOption(next, "compress/lossy_quality", g(quality));
    if (next !== text) {
      changed++;
      console.log(`${dry ? "would set" : "set"} ${big ? "lossy" : "lossless"} ${rel(png, ROOT)}`);
      if (!dry) writeText(imp, next);
    }
  }
  console.log(`${changed} import files changed`);
}

main();
