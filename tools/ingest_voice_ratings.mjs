#!/usr/bin/env node
/**
 * Merge the author's voice-review verdicts into dev/voice-ratings/ratings.jsonl and print, per
 * character, what they say about the voice: its verdict (good or sucks, or an older 1-10 rating),
 * the lines thumbed up and down, the thumbed-down lines, and whether the character is a re-clone
 * candidate (better source material, a new "interview"). Node successor of
 * tools/ingest_voice_ratings.py (bd dhn2), which reads only the older 1-10 saves; this reads those
 * too, and the JSONL stays readable by both.
 *
 *   node tools/ingest_voice_ratings.mjs [--jsonl PATH] [--threshold N] FILE.json [FILE.json ...]
 *   node tools/ingest_voice_ratings.mjs --summary          (report on what is already merged)
 *
 * A FILE is any of:
 *   the playtest export (Settings > Playtest > Export playtest, project/scripts/autoload/playtest.gd):
 *     {"kind": "persistint-playtest", "exported_at", "version", "build", "voice_review": REVIEW}
 *   REVIEW itself, the voice review's own file (user://voice_review.json) or its Export review
 *     (project/scripts/playtest/voice_review.gd): {"characters": {speaker: {verdict: "good" or
 *     "sucks", at, name}}, "lines": {key: {thumb: "up" or "down", at, speaker, text}}}; Export
 *     review adds build, date, counts and the roster
 *   the older ratings save: {"build", "date", "ratings": [{speaker, clip, text, rating, note}],
 *     "character_overall": {speaker: rating}}
 * Each verdict, thumb or rating becomes one record {date, build, kind ("character" or "line"),
 * speaker, clip, text, rating, verdict, note}: a rating has verdict "" and is keyed on (date, build,
 * speaker, clip, kind) as the Python tool keys it; a verdict or thumb has rating null, its own "at"
 * as its date, the line's key (Voice.line_key) as its clip, the export's build (or version) as its
 * build, and is keyed on (date, speaker, clip, kind), so the same verdict ingested again, from the
 * plain file or a later export, adds nothing, and a changed verdict adds a record. The summary
 * reads the latest record per character and per line. dev/ is git-crypt encrypted: the verdicts
 * stay on the private side.
 * Exit 0; 2 on a usage error or a FILE that is none of these (nothing is written then).
 */
import fs from "node:fs";
import path from "node:path";
import { ROOT, PROJECT, readText, rel } from "./lib_paths.mjs";

const JSONL = path.join(ROOT, "dev/voice-ratings/ratings.jsonl");
const MANIFEST = path.join(PROJECT, "audio/voice/manifest.json");
const THRESHOLD = 7.0;  // a 1-10 rating below this (mean line or overall) wants better source material
const PLAYTEST = "persistint-playtest";
const USAGE = "usage: node tools/ingest_voice_ratings.mjs [--jsonl PATH] [--threshold N] [--summary] [FILE.json ...]";

export const keyOf = (r) => JSON.stringify([r.date ?? "", r.verdict ? "" : r.build ?? "", r.speaker ?? "", r.clip ?? "", r.kind ?? ""]);

/** One JSONL line the way Python's json.dumps(rec, ensure_ascii=False) writes a flat record. */
const dumps = (rec) => "{" + Object.entries(rec).map(([k, v]) => `${JSON.stringify(k)}: ${JSON.stringify(v)}`).join(", ") + "}";

export function loadJsonl(p) {
  const out = new Map();
  if (fs.existsSync(p)) {
    for (const line of readText(p).split("\n")) {
      if (line.trim()) {
        const rec = JSON.parse(line);
        out.set(keyOf(rec), rec);
      }
    }
  }
  return out;
}

/** The records a parsed FILE gives; throws when it is none of the three kinds. */
export function recordsFrom(save) {
  if (save === null || typeof save !== "object" || Array.isArray(save)) throw new Error("not a JSON object");
  if (save.kind === PLAYTEST) {
    const review = save.voice_review;
    if (review === null || typeof review !== "object" || Array.isArray(review)) throw new Error("a playtest export without a voice_review object");
    return reviewRecords(review, String(save.build || save.version || ""));
  }
  if ("characters" in save || "lines" in save) return reviewRecords(save, String(save.build || ""));
  if ("ratings" in save || "character_overall" in save) return ratingRecords(save);
  throw new Error("not a playtest export, a voice review or a ratings save");
}

function reviewRecords(review, build) {
  const recs = [];
  for (const [speaker, v] of Object.entries(review.characters || {})) {
    if (v && (v.verdict === "good" || v.verdict === "sucks")) {
      recs.push({ date: String(v.at || ""), build, kind: "character", speaker, clip: "", text: "", rating: null, verdict: v.verdict, note: "" });
    }
  }
  for (const [key, l] of Object.entries(review.lines || {})) {
    if (l && (l.thumb === "up" || l.thumb === "down")) {
      recs.push({ date: String(l.at || ""), build, kind: "line", speaker: String(l.speaker || ""), clip: key, text: String(l.text || ""), rating: null, verdict: l.thumb, note: "" });
    }
  }
  return recs;
}

function ratingRecords(save) {
  const base = { date: save.date ?? "", build: save.build ?? "" };
  const recs = [];
  for (const r of save.ratings || []) {
    recs.push({ ...base, kind: "line", speaker: r.speaker ?? "", clip: r.clip ?? "", text: r.text ?? "",
      rating: Math.trunc(Number(r.rating ?? 0)), verdict: "", note: r.note ?? "" });
  }
  for (const [speaker, rating] of Object.entries(save.character_overall || {})) {
    recs.push({ ...base, kind: "character", speaker, clip: "", text: "", rating: Math.trunc(Number(rating)), verdict: "", note: "" });
  }
  return recs;
}

function texts() {
  if (!fs.existsSync(MANIFEST)) return new Map();
  return new Map(JSON.parse(readText(MANIFEST)).map((e) => [e.key, e.text]));
}

const later = (a, b) => (a.date ?? "") > (b.date ?? "") || ((a.date ?? "") === (b.date ?? "") && (a.build ?? "") >= (b.build ?? ""));

export function summary(records, threshold = THRESHOLD) {
  const byText = texts();
  const latest = new Map();  // [kind, speaker, clip] -> the latest record
  for (const r of records) {
    const k = JSON.stringify([r.kind, r.speaker, r.clip]);
    if (!latest.has(k) || later(r, latest.get(k))) latest.set(k, r);
  }
  const voice = new Map(), lines = new Map();
  for (const r of latest.values()) {
    if (r.kind === "character") voice.set(r.speaker, r);
    else if (r.kind === "line") lines.set(r.speaker, [...(lines.get(r.speaker) || []), r]);
  }
  const speakers = [...new Set([...voice.keys(), ...lines.keys()])].sort();
  if (!speakers.length) return "no ratings yet";
  const out = ["speaker                  voice    up   down mean  verdict"];
  for (const s of speakers) {
    const ls = lines.get(s) || [];
    const v = voice.get(s);
    const said = v ? (v.verdict || String(v.rating)) : "-";
    const rated = ls.filter((r) => typeof r.rating === "number");
    const m = rated.length ? rated.reduce((a, r) => a + r.rating, 0) / rated.length : null;
    const up = ls.filter((r) => r.verdict === "up").length, down = ls.filter((r) => r.verdict === "down");
    const low = (v && (v.verdict === "sucks" || (typeof v.rating === "number" && v.rating < threshold))) || (m !== null && m < threshold);
    const verdict = low ? "re-clone candidate: better source material" : "keep";
    out.push(`${s.padEnd(24)} ${said.padEnd(8)} ${String(up).padEnd(4)} ${String(down.length).padEnd(4)} ${(m !== null ? m.toFixed(1) : "-").padEnd(5)} ${verdict}`);
    const text = (r) => (r.text || byText.get(r.clip) || r.clip).slice(0, 90);
    for (const r of down) out.push(`    down  ${text(r)}`);
    for (const r of rated.filter((r) => r.rating < threshold).sort((a, b) => a.rating - b.rating).slice(0, 3)) {
      out.push(`    ${String(r.rating).padStart(4)}  ${text(r)}${r.note ? ` (${r.note})` : ""}`);
    }
  }
  return out.join("\n");
}

export function main(argv = process.argv.slice(2)) {
  let jsonl = JSONL, threshold = THRESHOLD, onlySummary = false;
  const files = [];
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const [flag, inline] = a.startsWith("--") && a.includes("=") ? [a.slice(0, a.indexOf("=")), a.slice(a.indexOf("=") + 1)] : [a, null];
    const value = () => inline ?? argv[++i];
    if (flag === "--jsonl") jsonl = path.resolve(value() ?? "");
    else if (flag === "--threshold") threshold = Number(value());
    else if (flag === "--summary") onlySummary = true;
    else if (flag === "-h" || flag === "--help") return { code: 0, out: USAGE };
    else if (flag.startsWith("--")) return { code: 2, out: `unknown option ${a}\n${USAGE}` };
    else files.push(a);
  }
  if (!Number.isFinite(threshold)) return { code: 2, out: `--threshold wants a number\n${USAGE}` };
  if (!files.length && !onlySummary) return { code: 2, out: USAGE };
  const merged = loadJsonl(jsonl);
  const incoming = [];
  for (const f of files) {
    try {
      incoming.push(...recordsFrom(JSON.parse(readText(f))));
    } catch (e) {
      return { code: 2, out: `${f}: ${e.message}; nothing written` };
    }
  }
  const lines = [];
  if (files.length) {
    let added = 0;
    for (const rec of incoming) {
      const k = keyOf(rec);
      if (!merged.has(k)) added++;
      merged.set(k, rec);
    }
    fs.mkdirSync(path.dirname(jsonl), { recursive: true });
    fs.writeFileSync(jsonl, [...merged.values()].map((r) => dumps(r) + "\n").join(""));
    const where = jsonl.startsWith(ROOT + path.sep) ? rel(jsonl) : jsonl;
    lines.push(`${added} new record(s); ${merged.size} in ${where}`);
  }
  lines.push(summary([...merged.values()], threshold));
  return { code: 0, out: lines.join("\n") };
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1"))) {
  const r = main();
  console.log(r.out);
  process.exit(r.code);
}
