#!/usr/bin/env node
/**
 * Every comment by an outside agent on a relayed bead that this tool has not shown before, read from the
 * tracker itself (bd efai). A coordinator check-in runs it after the relay: the PM2 relay job imports the
 * agents' comments every ten minutes, so a check-in that only reads its own relay run's output misses what
 * the job imported between check-ins (Kiro's 91a report of 2026-11-02 22:02 went unread for seven hours).
 *
 *   node tools/agent_comments_since.mjs [--beads DIR] [--seen FILE] [--since ISO] [--dry-run]
 *
 * Relayed beads are those labelled contractor:<agent> or channel (the relay's rule). An agent is any name
 * in a contractor:<agent> label, plus kiro, grok and codex. Shown comments are remembered by id in --seen
 * (default <beads>/.cache/agent-comments-seen.json), not by time: the relay keeps an agent's own comment
 * time, so a comment imported late carries an older timestamp than the last check-in. With no seen file
 * yet, only comments newer than --since (default 24 hours ago) are shown. --dry-run remembers nothing.
 * Prints one block per comment (bead, title, time, author, text) and "agent comments: N new"; exits 0.
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function parse(argv) {
  const a = { beads: REPO, seen: "", since: "", dryRun: false };
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    if (k === "--beads") a.beads = path.resolve(argv[++i]);
    else if (k === "--seen") a.seen = path.resolve(argv[++i]);
    else if (k === "--since") a.since = argv[++i];
    else if (k === "--dry-run") a.dryRun = true;
    else throw new Error(`unknown argument ${k}`);
  }
  if (!a.seen) a.seen = path.join(a.beads, ".cache", "agent-comments-seen.json");
  if (!a.since) a.since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
  return a;
}

function exportBeads(dir) {
  const r = spawnSync("bd", ["--no-color", "export"], { cwd: dir, encoding: "utf8", maxBuffer: 256 * 1024 * 1024 });
  if (r.status !== 0) throw new Error(`bd export exited ${r.status}: ${r.stderr}`);
  return r.stdout.split("\n").filter((l) => l.trim()).map((l) => JSON.parse(l)).filter((x) => x && x.id);
}

export function newAgentComments(records, seenIds, since) {
  const relayed = records.filter((r) => (r.labels || []).some((l) => l === "channel" || l.startsWith("contractor:")));
  const agents = new Set(["kiro", "grok", "codex"]);
  for (const r of relayed) for (const l of r.labels || []) if (l.startsWith("contractor:")) agents.add(l.slice("contractor:".length));
  const out = [];
  for (const r of relayed) {
    for (const c of r.comments || []) {
      const key = c.id || `${r.id}|${c.author}|${c.created_at}|${(c.text || "").slice(0, 40)}`;
      if (!agents.has(c.author) || seenIds.has(key)) continue;
      if (seenIds.size === 0 && since && (c.created_at || "") < since) continue;
      out.push({ key, bead: r.id, title: r.title || "", status: r.status || "", author: c.author, at: c.created_at || "", text: c.text || "" });
    }
  }
  return out.sort((x, y) => (x.at < y.at ? -1 : x.at > y.at ? 1 : 0));
}

function main() {
  const a = parse(process.argv.slice(2));
  let seen = [];
  try { seen = JSON.parse(fs.readFileSync(a.seen, "utf8")); } catch { seen = []; }
  const seenIds = new Set(seen);
  const records = exportBeads(a.beads);
  const fresh = newAgentComments(records, seenIds, a.since);
  for (const c of fresh) {
    console.log(`== ${c.bead} [${c.status}] ${c.title.slice(0, 90)}`);
    console.log(`   ${c.at} ${c.author}:`);
    for (const line of c.text.split("\n")) console.log(`   ${line}`);
  }
  console.log(`agent comments: ${fresh.length} new`);
  if (!a.dryRun) {
    // Remember every agent comment now in the tracker, shown or older than --since, so the next run shows only new ones.
    const all = newAgentComments(records, new Set(), "").map((c) => c.key);
    fs.mkdirSync(path.dirname(a.seen), { recursive: true });
    fs.writeFileSync(a.seen, JSON.stringify([...new Set([...seen, ...all])].sort(), null, 0) + "\n");
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(); } catch (e) { console.error(`agent_comments_since: ${e.message}`); process.exit(1); }
}
