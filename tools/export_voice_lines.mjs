#!/usr/bin/env node
/**
 * List every spoken line with its speaker, for generating impersonated voice clips. Node port of
 * tools/export_voice_lines.py: the same sources give the same manifest, byte for byte, and the
 * lines the Python tool missed follow them (below).
 *
 *   node tools/export_voice_lines.mjs [--out PATH] [--check]
 *     --out PATH  write the manifest there instead of project/audio/voice/manifest.json
 *     --check     write nothing; exit 1 if the manifest would change
 *
 * Writes project/audio/voice/manifest.json: [{speaker, text, key, clip}]. Generate each clip
 * (tools/generate_voice_clips.py: `speaker` reading `text`) and save it as `clip`; Voice.speak
 * plays it. key = md5("speaker|text"), matching Voice.line_key in project/scripts/autoload/voice.gd;
 * bracketed sounds ("[Uuunnngh.]") are not part of a line's text (Voice plays them as generated
 * vocalizations from audio/sfx). speaker is the exact string the game hands to Voice.speak.
 *
 * Sources, in this order (a line already listed is not listed again):
 *   from the Python tool: data/emcee.json intros (the emcee's name), data/hottest_of_the_hot.json
 *   verdicts (the host's name), data/landing.json commands (first_mate), data/barks.json (each
 *   villager's name), dialogue/*.dialogue (the character's resolved name), the clones' usable
 *   quotes (data/quotes/<file>.json, under the cast id), Margaret Atwood's usable quotes and
 *   speech habits (her name);
 *   added: data/interview.json intro and questions (interview.gd speaks as data.host, "oprah"),
 *   data/florida.json critters' surprise lines (critter.gd speaks as the kind), data/ponies.json
 *   lines (pony.gd speaks as "pony"), data/ruins.json clone_children.cubs barks, bump_barks, nom
 *   and nap (polar_cub.gd speaks as cubs.cast), data/title_letters.json tiers' lines and chime-ins
 *   (title_letters.gd speaks as speakers[role]). The same list as VoiceReview.build_roster
 *   (scripts/playtest/voice_review.gd).
 * "usable" quote: verified is true, excluded_from_game is not true, no fragment.
 */
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { PROJECT, readText, writeText } from "./lib_paths.mjs";

// Python's \s and str.strip() whitespace (str.isspace), which JS \s and trim() differ from.
const WS = "\\t\\n\\v\\f\\r \\x1c-\\x1f\\x85\\xa0\\u1680\\u2000-\\u200a\\u2028\\u2029\\u202f\\u205f\\u3000";
const WS_RUN = new RegExp(`[${WS}]+`, "gu");
const STRIP = new RegExp(`^[${WS}]+|[${WS}]+$`, "gu");
const BRACKETS = /\[[^\]]*\]/gu;
// str.splitlines() boundaries (the text is read with universal newlines, so \r is already \n).
const LINES = new RegExp("\\r\\n|[\\n\\r\\v\\f\\x1c\\x1d\\x1e\\x85\\u2028\\u2029]", "u");
// Python's \w on str: Unicode letters, digits and the underscore.
const W = "[\\p{L}\\p{N}_]";
const CAST_REF = new RegExp(`\\{\\{Cast\\.(full|short)\\("(${W}+)"\\)\\}\\}`, "gu");
const LINE = new RegExp(`^[${WS}]*(\\{\\{Cast\\.full\\("${W}+"\\)\\}\\}|[A-Z][^:{]*):[${WS}]*(.+)$`, "u");

const has = (o, k) => o !== null && typeof o === "object" && Object.hasOwn(o, k);
const get = (o, k, dflt) => (has(o, k) ? o[k] : dflt);
// Python truthiness of a JSON value.
const truthy = (v) => !(v === undefined || v === null || v === false || v === 0 || v === "" ||
  (Array.isArray(v) && v.length === 0) || (typeof v === "object" && !Array.isArray(v) && v !== null && Object.keys(v).length === 0));
const json = (rel) => JSON.parse(readText(path.join(PROJECT, rel)));

const cast = json("data/cast.json");
const name = (cid) => get(get(cast, cid, {}), "name", cid);
const short = (cid) => get(get(cast, cid, {}), "short", name(cid));
const lines = [];
// Celebrity clones speak their original's quotes (data/quotes/<file>.json), keyed by cast id.
const QUOTE_SPEAKERS = { epstein: "epstein", bill_clinton: "bill_clinton", hillary: "hillary_clinton", bill_gates: "bill_gates" };

function add(speaker, text) {
  // A sound in square brackets ("[Uuunnngh.] Shamble.") is a vocalization Voice plays from
  // audio/sfx, never read: the clip and its key cover the words alone (Voice.spoken_text).
  text = (truthy(text) ? String(text) : "").replace(BRACKETS, " ").replace(WS_RUN, " ").replace(STRIP, "");
  if (truthy(speaker) && text && !`${speaker}${text}`.includes("{{")) {
    const key = crypto.createHash("md5").update(`${speaker}|${text}`, "utf8").digest("hex");
    lines.push({ speaker, text, key, clip: `res://audio/voice/${key}.wav` });
  }
}

const emcee = json("data/emcee.json");
for (const intro of Object.values(get(emcee, "intros", {}))) for (const t of intro) add(name(emcee.emcee), t);
const hot = json("data/hottest_of_the_hot.json");
for (const t of get(hot, "verdicts", [])) add(name(hot.host), t);
const landing = json("data/landing.json");
for (const c of get(landing, "commands", [])) add(get(landing, "first_mate", ""), c.text);
const barks = json("data/barks.json");
for (const [npcId, entries] of Object.entries(barks)) {
  for (const e of Array.isArray(entries) ? entries : []) add(name(npcId), get(e, "text", ""));
}
const resolve = (s) => s.replace(CAST_REF, (_, kind, id) => (kind === "full" ? name : short)(id));
const dialogueDir = path.join(PROJECT, "dialogue");
const dialogues = fs.readdirSync(dialogueDir).filter((f) => f.endsWith(".dialogue")).sort();
for (const f of dialogues) {
  for (const raw of readText(path.join(dialogueDir, f)).split(LINES)) {
    const m = raw.match(LINE);
    if (m) add(resolve(m[1]), resolve(m[2]));
  }
}
const usable = (q) => get(q, "verified") === true && get(q, "excluded_from_game") !== true && !truthy(get(q, "fragment"));
// Clones speak their original's usable quotes (data/quotes/<file>.json), keyed by cast id, as
// ZombieChild.quote_pool picks them (verified, not excluded_from_game).
for (const [stem, cid] of Object.entries(QUOTE_SPEAKERS)) {
  for (const q of get(json(`data/quotes/${stem}.json`), "quotes", [])) if (usable(q)) add(cid, q.text);
}
// Real people who speak only their own sourced words (data/quotes/<cast id>.json): every usable quote
// (verified, not excluded_from_game) and every verified, whole-line speech habit, under their display name.
for (const cid of ["atwood"]) {
  const qf = json(`data/quotes/${cid}.json`);
  for (const q of [...get(qf, "quotes", []), ...get(qf, "speech_habits", [])]) if (usable(q)) add(name(cid), q.text);
}

// ---- Lines the Python tool missed, each under the speaker string its script hands Voice.speak.
// The interview: interview.gd speaks the intro and each question as data.host, the cast id ("oprah").
const interview = json("data/interview.json");
const host = String(get(interview, "host", ""));
for (const t of get(interview, "intro", [])) add(host, t);
for (const q of get(interview, "questions", [])) add(host, get(q, "prompt", ""));
// Florida critters: critter.gd speaks a surprise's lines as its kind (crab, gull, dolphin, mermaid).
for (const [kind, critter] of Object.entries(get(json("data/florida.json"), "critters", {}))) {
  for (const s of get(critter, "surprises", [])) for (const t of get(s, "lines", [])) add(kind, t);
}
// Ponies: pony.gd speaks every pony's line as "pony".
for (const list of Object.values(get(json("data/ponies.json"), "lines", {}))) for (const t of list) add("pony", t);
// The polar bear cubs: polar_cub.gd speaks its barks, bump barks, nom and nap sounds as cubs.cast.
const cubs = get(get(json("data/ruins.json"), "clone_children", {}), "cubs", {});
for (const list of ["barks", "bump_barks", "nom", "nap"]) {
  for (const t of get(cubs, list, [])) add(String(get(cubs, "cast", "polar_bear_clone")), t);
}
// The title screen: title_letters.gd speaks the letters' tier lines as speakers.letters and each
// chime-in as speakers[its speaker role].
const title = json("data/title_letters.json");
const speakers = get(title, "speakers", {});
for (const tier of get(title, "tiers", [])) {
  for (const t of get(tier, "lines", [])) add(String(get(speakers, "letters", "letters")), t);
}
for (const c of get(title, "chime_ins", [])) {
  const role = String(get(c, "speaker", "reason"));
  add(String(get(speakers, role, role)), get(c, "line", ""));
}

const seen = new Set();
const out = lines.filter((l) => (seen.has(l.key) ? false : (seen.add(l.key), true)));
const argv = process.argv.slice(2);
const at = argv.indexOf("--out");
const dest = at >= 0 ? path.resolve(argv[at + 1]) : path.join(PROJECT, "audio/voice/manifest.json");
const text = JSON.stringify(out, null, 2) + "\n";
if (argv.includes("--check")) {
  const same = fs.existsSync(dest) && readText(dest) === text;
  console.log(same ? `${out.length} lines, ${dest} is current` : `${dest} would change (${out.length} lines)`);
  process.exit(same ? 0 : 1);
}
writeText(dest, text);
console.log(`${out.length} lines -> ${dest}`);
