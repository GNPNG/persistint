#!/usr/bin/env node
/**
 * Sync the coordination repository for the GitHub-only agents (bd uowd): the private GitHub
 * repository where Kiro and Grok, who cannot reach the forge, get their beads, the render
 * prompts and a place to talk (docs/engineering/github-agent-channel-proposal.md).
 *
 *   node tools/sync_agent_channel.mjs [--channel DIR] [--remote URL] [--beads DIR] [--dry-run]
 *                                     [--no-push] [--no-prompts]
 *
 * --channel DIR   the clone of the coordination repository this run reads and writes (default
 *                 .cache/agent-channel; cloned from the remote when missing)
 * --remote URL    the repository's git URL (default $AGENT_CHANNEL_REMOTE)
 * --beads DIR     the workspace whose beads are relayed (default: this repository)
 * --dry-run       pull and report what would be imported, exported and committed; write nothing
 *                 to the beads and commit nothing
 * --no-push       commit in the clone but do not push (the test's remote is a local bare repo,
 *                 so it pushes; this is for looking at a commit before it goes out)
 * --no-prompts    skip the prompt mirror
 * GH_TOKEN        the fine-grained token for the repository, sent to github.com as an
 *                 Authorization header on each git command; never written to disk or printed
 *
 * One run, in this order:
 *   pull     fast-forward the clone (clone it first when missing)
 *   import   the agents' changes from <channel>/.beads/issues.jsonl into the forge beads. Beads
 *            are append-mostly, and `bd import` overwrites a record whole, so each incoming record
 *            is rebuilt from the forge's copy and takes from the agent only: comments not yet on
 *            the bead (matched by author and text), a claim (status open -> in_progress, or back,
 *            or blocked; the assignee), and nothing else. A bead the forge has closed takes nothing;
 *            an agent cannot close a bead (fcxf rule 9: the team closes after the merge); a title,
 *            description or priority edit from the agent side is dropped. A record the forge does
 *            not have is a new bead from an agent: it is taken when it carries a relayed label,
 *            opened if it arrived closed.
 *   export   the relayed beads to <channel>/.beads/issues.jsonl: every bead with a label matching
 *            RELAY (contractor:* or channel), sorted by id so the file diffs cleanly. Nothing else
 *            from the forge: not the other beads, not memories.
 *   prompts  mirror the render prompts: prompts/QUEUE.md (regenerated with
 *            tools/render_all_assets.py --export-queue when python3 is on PATH), prompts/STYLE.md,
 *            prompts/README.md and every prompt file prompts/<kind>/<group>/<id>.md (not the
 *            rendered assets beside them), so the renderer has the exact text to paste
 *   intake   the renders: for each <channel>/done/<id>.json with no <channel>/landed/<id>.json,
 *            the prompt <id> is looked up in prompts/**\/*.md (front matter id, tool, drop, game);
 *            the file at <channel>/drop/<drop path> is checked (present, not empty, a PNG when the
 *            drop path says .png); then, in a worktree of this repository at origin/main, the
 *            render is put at its drop path and, when the game path has the same extension, at
 *            its game path too, committed on a branch render/<id> with the provenance (renderer, tool, model, time) from
 *            done/<id>.json, and the branch is pushed to origin. landed/<id>.json records the
 *            branch and commit (or the reason the render was refused), and the binary is removed
 *            from the channel: the branch holds it now. The land steps, the suite and the deploy
 *            run on that branch as for any contributor's branch (tools/land_wardrobe.mjs,
 *            tools/run_tests.sh); they are not run here.
 *   readme   <channel>/README.md from tools/agent_channel_README.md when it differs
 *   commit   one commit when anything changed, then push (unless --no-push)
 * Exit 0 when the run completed (changes or none), 1 on an error (the run stops at the first).
 * Logs one line per step to stdout. The test: node tools/test_sync_agent_channel.mjs.
 */
import { spawnSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { ROOT as REPO, rel, rglob, isFile, readText } from "./lib_paths.mjs";

/** Write a file, making its folders. */
function writeText(p, text) {
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, text);
}

export const RELAY = /^(contractor:.+|channel)$/;
export const RELAY_FILE = ".beads/issues.jsonl";
/** Statuses an agent may set (a claim, a release, a block); anything else is the forge's. */
export const AGENT_STATUSES = new Set(["open", "in_progress", "blocked"]);
const README_SRC = path.join(REPO, "tools/agent_channel_README.md");

function parse(argv) {
  const a = { channel: path.join(REPO, ".cache/agent-channel"), remote: process.env.AGENT_CHANNEL_REMOTE || "",
    beads: REPO, dryRun: false, push: true, prompts: true };
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    if (k === "--channel") a.channel = path.resolve(argv[++i]);
    else if (k === "--remote") a.remote = argv[++i];
    else if (k === "--beads") a.beads = path.resolve(argv[++i]);
    else if (k === "--dry-run") a.dryRun = true;
    else if (k === "--no-push") a.push = false;
    else if (k === "--no-prompts") a.prompts = false;
    else if (k === "-h" || k === "--help") { console.log(readText(new URL(import.meta.url)).split("*/")[0]); process.exit(0); }
    else throw new Error(`unknown option ${k}`);
  }
  return a;
}

// --- Running things.

function run(cmd, args, opts = {}) {
  const r = spawnSync(cmd, args, { encoding: "utf8", ...opts });
  if (r.error) throw new Error(`${cmd}: ${r.error.message}`);
  if (r.status !== 0 && !opts.okToFail) {
    // The Authorization header git gets as -c is never written to a log.
    const shown = args.map((x) => (String(x).startsWith("http.https://github.com/.extraheader=") ? "http.https://github.com/.extraheader=<redacted>" : x));
    throw new Error(`${cmd} ${shown.join(" ")} exited ${r.status}: ${(r.stderr || "").trim().slice(-400)}`);
  }
  return r;
}

/** git in `dir`, with the token as an Authorization header for github.com when GH_TOKEN is set
 *  (the way GitHub's own checkout action sends it); the token is never part of a URL or a file. */
export function git(dir, args, opts = {}) {
  const pre = [];
  const token = process.env.GH_TOKEN;
  if (token) {
    const basic = Buffer.from(`x-access-token:${token}`).toString("base64");
    pre.push("-c", `http.https://github.com/.extraheader=AUTHORIZATION: basic ${basic}`);
  }
  return run("git", [...pre, ...args], { cwd: dir, ...opts });
}

function bd(beads, args, opts = {}) {
  return run("bd", ["-C", beads, "--no-color", ...args], opts);
}

/** Every regular bead of the workspace, as `bd export` writes it (one JSON record each). */
export function exportBeads(beads) {
  return bd(beads, ["export"]).stdout.split("\n").filter((l) => l.trim()).map((l) => JSON.parse(l));
}

export const isRelayed = (r) => Array.isArray(r.labels) && r.labels.some((l) => RELAY.test(l));
const commentKey = (c) => `${c.author || ""}\n${c.text || ""}`;

// --- Import: the agents' changes, rebuilt on the forge's record.

/** The record to import for an incoming one, or null with the reason to skip it. */
export function merge(forge, incoming, now = new Date().toISOString()) {
  if (!forge) {
    if (!isRelayed(incoming)) return { record: null, why: "new bead without a relayed label" };
    const record = { ...incoming, updated_at: now };
    if (!AGENT_STATUSES.has(record.status)) record.status = "open";
    return { record, why: "new bead from an agent" };
  }
  if (forge.status === "closed") return { record: null, why: "closed on the forge" };
  const record = { ...forge };
  const have = new Set((forge.comments || []).map(commentKey));
  const added = (incoming.comments || []).filter((c) => !have.has(commentKey(c)));
  let changed = added.length > 0;
  if (added.length) record.comments = [...(forge.comments || []), ...added];
  if (incoming.status !== forge.status && AGENT_STATUSES.has(incoming.status)) { record.status = incoming.status; changed = true; }
  if ((incoming.assignee || "") !== (forge.assignee || "") && incoming.assignee) { record.assignee = incoming.assignee; changed = true; }
  if (!changed) return { record: null, why: "nothing new" };
  record.updated_at = now;
  return { record, why: `${added.length} comment(s)${record.status !== forge.status ? `, status ${forge.status} -> ${record.status}` : ""}` };
}

function importFromChannel(a, forge) {
  const file = path.join(a.channel, RELAY_FILE);
  if (!isFile(file)) { console.log("import   no issues.jsonl in the channel yet"); return 0; }
  const byId = new Map(forge.map((r) => [r.id, r]));
  const out = [];
  for (const line of readText(file).split("\n").filter((l) => l.trim())) {
    let incoming;
    try { incoming = JSON.parse(line); } catch { console.log("import   skipped a line that is not JSON"); continue; }
    if (incoming._type && incoming._type !== "issue") continue;
    const { record, why } = merge(byId.get(incoming.id), incoming);
    if (record) { out.push(record); console.log(`import   ${incoming.id}: ${why}`); } else if (why !== "nothing new") console.log(`import   ${incoming.id}: skipped (${why})`);
  }
  if (!out.length) { console.log("import   nothing to import"); return 0; }
  if (a.dryRun) { console.log(`import   would import ${out.length} record(s)`); return out.length; }
  const tmp = path.join(a.channel, ".cache-import.jsonl");
  fs.writeFileSync(tmp, out.map((r) => JSON.stringify(r)).join("\n") + "\n");
  try { bd(a.beads, ["import", "-i", tmp]); } finally { fs.rmSync(tmp, { force: true }); }
  console.log(`import   ${out.length} record(s) imported`);
  return out.length;
}

// --- Export: the relayed beads.

export function relayText(records) {
  return records.filter(isRelayed).sort((x, y) => (x.id < y.id ? -1 : x.id > y.id ? 1 : 0)).map((r) => JSON.stringify(r)).join("\n") + "\n";
}

function exportToChannel(a, forge) {
  const text = relayText(forge);
  const n = text.trim() ? text.trim().split("\n").length : 0;
  const file = path.join(a.channel, RELAY_FILE);
  const same = isFile(file) && readText(file) === text;
  console.log(`export   ${n} bead(s) relayed${same ? " (unchanged)" : ""}`);
  if (!a.dryRun && !same) writeText(file, text);
  return { n, changed: !same };
}

// --- Prompts and the README.

function mirrorPrompts(a) {
  const src = path.join(a.beads, "prompts");
  if (!fs.existsSync(src)) { console.log("prompts  no prompts/ in the beads workspace"); return 0; }
  const py = spawnSync("python3", ["--version"], { encoding: "utf8" }).status === 0;
  if (py && isFile(path.join(a.beads, "tools/render_all_assets.py")) && !a.dryRun) {
    const r = spawnSync("python3", ["-I", "tools/render_all_assets.py", "--export-queue"], { cwd: a.beads, encoding: "utf8" });
    if (r.status !== 0) console.log(`prompts  QUEUE.md not regenerated (${(r.stderr || "").trim().split("\n").pop()}); mirroring the committed one`);
  }
  const files = rglob(src).filter((p) => p.endsWith(".md") && !rel(p, src).split("/").includes("assets"));
  let changed = 0;
  for (const p of files) {
    const dst = path.join(a.channel, "prompts", rel(p, src));
    const text = readText(p);
    if (isFile(dst) && readText(dst) === text) continue;
    changed++;
    if (!a.dryRun) writeText(dst, text);
  }
  console.log(`prompts  ${files.length} file(s) mirrored, ${changed} changed`);
  return changed;
}

function readme(a) {
  if (!isFile(README_SRC)) return;
  const dst = path.join(a.channel, "README.md");
  const text = readText(README_SRC);
  if (isFile(dst) && readText(dst) === text) return false;
  console.log("readme   README.md updated");
  if (!a.dryRun) writeText(dst, text);
  return true;
}

// --- Intake: the renders, onto branches of this repository.

/** Every prompt of the repository by id: {id, tool, drop, game, file, prompt}. */
export function prompts(repo) {
  const out = new Map();
  const dir = path.join(repo, "prompts");
  if (!fs.existsSync(dir)) return out;
  for (const p of rglob(dir).filter((f) => f.endsWith(".md") && path.dirname(f) !== dir && !rel(f, dir).split("/").includes("assets"))) {
    const text = readText(p);
    const fm = text.match(/^---\n([\s\S]*?)\n---\n/);
    if (!fm) continue;
    const meta = {};
    for (const line of fm[1].split("\n")) { const m = line.match(/^(\w+):\s*(.*)$/); if (m) meta[m[1]] = m[2].trim(); }
    if (!meta.id || !meta.drop) continue;
    const body = text.match(/\n## Prompt\n([\s\S]*?)(?:\n## |\s*$)/);
    out.set(meta.id, { ...meta, file: p, prompt: body ? body[1].trim() : "" });
  }
  return out;
}

const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

/** Why a drop is refused, or "" when it passes. */
export function refuse(prompt, file) {
  if (!prompt) return "no prompt with that id";
  if (!isFile(file)) return `no file at drop/${prompt.drop}`;
  const size = fs.statSync(file).size;
  if (size === 0) return "the file is empty";
  if (prompt.drop.toLowerCase().endsWith(".png")) {
    const head = Buffer.alloc(8);
    const fd = fs.openSync(file, "r");
    try { fs.readSync(fd, head, 0, 8, 0); } finally { fs.closeSync(fd); }
    if (!head.equals(PNG)) return "not a PNG";
  }
  return "";
}

function intake(a) {
  const doneDir = path.join(a.channel, "done");
  if (!fs.existsSync(doneDir)) return 0;
  const known = prompts(a.beads);
  let landed = 0;
  for (const f of fs.readdirSync(doneDir).filter((n) => n.endsWith(".json")).sort()) {
    const id = f.slice(0, -5);
    const landedFile = path.join(a.channel, "landed", `${id}.json`);
    if (isFile(landedFile)) continue;
    let done;
    try { done = JSON.parse(readText(path.join(doneDir, f))); } catch { done = {}; }
    const prompt = known.get(id);
    const dropFile = prompt ? path.join(a.channel, "drop", prompt.drop) : "";
    const why = refuse(prompt, dropFile);
    const record = { id, received_at: new Date().toISOString(), agent: done.agent || "", tool: done.tool || "", model: done.model || "", rendered_at: done.rendered_at || "" };
    if (why) {
      console.log(`intake   ${id}: refused (${why})`);
      if (!a.dryRun) writeText(landedFile, JSON.stringify({ ...record, status: "refused", why }, null, 2) + "\n");
      continue;
    }
    if (a.dryRun) { console.log(`intake   ${id}: would land on render/${id}`); landed++; continue; }
    const branch = `render/${id}`;
    const wt = path.join(a.beads, ".cache", "agent-channel-land", id);
    git(a.beads, ["fetch", "--quiet", "origin", "main"]);
    if (git(a.beads, ["ls-remote", "--exit-code", "--heads", "origin", branch], { okToFail: true }).status === 0) {
      console.log(`intake   ${id}: branch ${branch} is already on origin; recording it`);
      writeText(landedFile, JSON.stringify({ ...record, status: "branch", branch, note: "the branch existed already" }, null, 2) + "\n");
      continue;
    }
    fs.rmSync(wt, { recursive: true, force: true });
    git(a.beads, ["worktree", "prune"]);
    // The landing worktree only adds a render and its provenance, and a worktree has no git-crypt
    // key of its own, so the smudge filter (dev/*.md) is a no-op here or 'worktree add' aborts.
    git(a.beads, ["-c", "filter.git-crypt.smudge=cat", "-c", "filter.git-crypt.required=false", "worktree", "add", "--quiet", "--detach", wt, "origin/main"]);
    try {
      git(wt, ["checkout", "--quiet", "-b", branch]);
      const targets = [prompt.drop];
      if (prompt.game && path.extname(prompt.game).toLowerCase() === path.extname(prompt.drop).toLowerCase()) targets.push(prompt.game);
      for (const t of targets) { fs.mkdirSync(path.join(wt, path.dirname(t)), { recursive: true }); fs.copyFileSync(dropFile, path.join(wt, t)); }
      git(wt, ["add", "--", ...targets]);
      const sha = prompt.prompt ? (sha256(prompt.prompt)) : "";
      const prov = [`Render ${id} from the coordination repository (bd uowd)`, "",
        `Rendered by ${record.agent || "?"} with ${record.tool || "?"} (${record.model || "?"}), ${record.rendered_at || "?"}.`,
        `Prompt: ${rel(prompt.file, a.beads)}${sha && done.prompt_sha256 && sha !== done.prompt_sha256 ? " (the renderer's prompt_sha256 differs from the prompt file's)" : ""}.`,
        done.notes ? `Renderer's notes: ${String(done.notes).slice(0, 500)}` : "",
        `At ${targets.join(" and ")}. Land steps, suite and deploy follow on this branch.`].filter((l) => l !== "").join("\n");
      git(wt, ["-c", "user.name=cc-srv", "-c", "user.email=cc-srv@gnomatix.com", "commit", "--quiet", "-m", prov]);
      const commit = git(wt, ["rev-parse", "--short", "HEAD"]).stdout.trim();
      git(wt, ["push", "--quiet", "origin", branch]);
      writeText(landedFile, JSON.stringify({ ...record, status: "branch", branch, commit, paths: targets }, null, 2) + "\n");
      git(a.channel, ["rm", "--quiet", "--", path.join("drop", prompt.drop)]);
      console.log(`intake   ${id}: ${branch} ${commit} pushed; drop removed from the channel`);
      landed++;
    } finally {
      git(a.beads, ["worktree", "remove", "--force", wt], { okToFail: true });
    }
  }
  if (!landed) console.log("intake   nothing new");
  return landed;
}

function sha256(text) {
  return crypto.createHash("sha256").update(text).digest("hex");
}

// --- The clone, the commit, the push.

function pull(a) {
  if (!fs.existsSync(path.join(a.channel, ".git"))) {
    if (!a.remote) throw new Error("no clone at --channel and no --remote / AGENT_CHANNEL_REMOTE to clone from");
    fs.mkdirSync(path.dirname(a.channel), { recursive: true });
    git(path.dirname(a.channel), ["-c", "init.defaultBranch=main", "clone", "--quiet", a.remote, a.channel]);
    const branch = git(a.channel, ["rev-parse", "--abbrev-ref", "HEAD"], { okToFail: true }).stdout.trim();
    if (branch !== "main") git(a.channel, ["checkout", "-q", "-B", "main"]);
    console.log(`pull     cloned ${a.remote.replace(/\/\/[^@]+@/, "//")}`);
    return;
  }
  const r = git(a.channel, ["pull", "--quiet", "--ff-only", "origin", "main"], { okToFail: true });
  console.log(r.status === 0 ? "pull     up to date with origin/main" : "pull     origin/main not there yet (first push pending)");
}

function commit(a, summary, wouldChange) {
  if (a.dryRun) { console.log(wouldChange ? "commit   would commit (dry run)" : "commit   nothing changed"); return false; }
  git(a.channel, ["add", "-A"]);
  const dirty = git(a.channel, ["status", "--porcelain"]).stdout.trim() !== "";
  if (!dirty) { console.log("commit   nothing changed"); return false; }
  const when = new Date().toISOString().slice(0, 16) + "Z";
  git(a.channel, ["-c", "user.name=cc-srv", "-c", "user.email=cc-srv@gnomatix.com", "commit", "--quiet", "-m", `sync ${when}: ${summary}`]);
  console.log(`commit   ${summary}`);
  if (a.push) { git(a.channel, ["push", "--quiet", "-u", "origin", "main"]); console.log("push     origin/main"); }
  return true;
}

export function main(argv = process.argv.slice(2)) {
  const a = parse(argv);
  fs.mkdirSync(path.join(a.beads, ".cache"), { recursive: true });
  pull(a);
  const before = exportBeads(a.beads);
  const imported = importFromChannel(a, before);
  const forge = imported && !a.dryRun ? exportBeads(a.beads) : before;
  const relayed = exportToChannel(a, forge);
  const mirrored = a.prompts ? mirrorPrompts(a) : 0;
  const landed = intake(a);
  const readmeChanged = readme(a);
  commit(a, `${relayed.n} bead(s) relayed, ${imported} imported, ${mirrored} prompt file(s) changed, ${landed} render(s) landed`,
    relayed.changed || mirrored > 0 || landed > 0 || readmeChanged);
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(new URL(import.meta.url).pathname)) {
  try { main(); } catch (e) { console.error(`sync_agent_channel: ${e.message}`); process.exit(1); }
}
