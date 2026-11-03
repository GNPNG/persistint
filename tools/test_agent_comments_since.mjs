#!/usr/bin/env node
/**
 * Checks for tools/agent_comments_since.mjs (bd efai) in a scratch beads workspace of its own (bd init):
 * the first run shows the agents' comments on relayed beads (contractor:* or channel) and not the team's
 * or those on a plain bead; a second run shows nothing; a new agent comment is shown once; a comment that
 * arrives with an older timestamp than the last run (as the relay imports them) is still shown; --dry-run
 * remembers nothing. newAgentComments() is also checked on its own.
 *
 *   node tools/test_agent_comments_since.mjs    prints ok/FAIL per check and "RESULT: PASS|FAIL (n failures)"
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { newAgentComments } from "./agent_comments_since.mjs";

const TOOL = path.join(path.dirname(fileURLToPath(import.meta.url)), "agent_comments_since.mjs");
let failures = 0;
const check = (ok, what) => { console.log((ok ? "ok   " : "FAIL ") + what); if (!ok) failures++; };
function sh(cmd, args, cwd) {
  const r = spawnSync(cmd, args, { cwd, encoding: "utf8", env: { ...process.env, BEADS_ACTOR: "forge" } });
  if (r.status !== 0) throw new Error(`${cmd} ${args.join(" ")} exited ${r.status}\n${r.stdout}\n${r.stderr}`);
  return r.stdout;
}

function unit() {
  const recs = [
    { id: "a", title: "A", labels: ["contractor:kiro"], comments: [{ id: "1", author: "kiro", created_at: "2026-11-02T22:02:00Z", text: "late" }, { id: "2", author: "cc-srv-lxd", created_at: "2026-11-02T23:00:00Z", text: "team" }] },
    { id: "b", title: "B", labels: [], comments: [{ id: "3", author: "kiro", created_at: "2026-11-03T00:00:00Z", text: "plain bead" }] },
  ];
  check(newAgentComments(recs, new Set(), "").map((c) => c.key).join() === "1", "unit: only agent comments on relayed beads");
  check(newAgentComments(recs, new Set(["9"]), "2026-11-03T00:00:00Z").length === 1, "unit: with a seen list, an older timestamp is still new (late import)");
  check(newAgentComments(recs, new Set(), "2026-11-03T00:00:00Z").length === 0, "unit: with no seen list, --since bounds the first run");
}

function main() {
  unit();
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "agent-comments-"));
  const ws = path.join(tmp, "ws"), seen = path.join(tmp, "seen.json");
  try {
    sh("git", ["init", "--quiet", ws], tmp);
    sh("bd", ["init", "--quiet"], ws);
    const id = (title) => JSON.parse(sh("bd", ["--no-color", "create", title, "-t", "task", "-p", "2", "--json", ...(title === "Kiro's" ? ["-l", "contractor:kiro"] : title === "Rules" ? ["-l", "channel"] : [])], ws)).id;
    const kiroBead = id("Kiro's"), rules = id("Rules"), plain = id("Plain");
    sh("bd", ["comment", kiroBead, "--actor", "kiro", "design delivered"], ws);
    sh("bd", ["comment", rules, "--actor", "grok", "a question"], ws);
    sh("bd", ["comment", kiroBead, "--actor", "cc-srv-lxd", "the coordinator's answer"], ws);
    sh("bd", ["comment", plain, "--actor", "kiro", "on a plain bead"], ws);
    const run = (...extra) => sh("node", [TOOL, "--beads", ws, "--seen", seen, "--since", "2000-01-01T00:00:00Z", ...extra], tmp);
    let out = run("--dry-run");
    check(/agent comments: 2 new/.test(out) && out.includes("design delivered") && out.includes("a question") && !out.includes("on a plain bead") && !out.includes("coordinator's answer"),
      "the first run shows kiro's and grok's comments on relayed beads, not the team's or a plain bead's");
    check(!fs.existsSync(seen), "--dry-run remembers nothing");
    out = run();
    check(/agent comments: 2 new/.test(out) && fs.existsSync(seen), "a real run shows them and remembers them");
    out = run();
    check(/agent comments: 0 new/.test(out), "the next run shows nothing");
    sh("bd", ["comment", kiroBead, "--actor", "kiro", "a follow-up"], ws);
    out = run();
    check(/agent comments: 1 new/.test(out) && out.includes("a follow-up"), "a new agent comment is shown once");
    out = run("--since", "2999-01-01T00:00:00Z");
    check(/agent comments: 0 new/.test(out), "once a seen list exists, --since does not hide or re-show anything");
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
  console.log(`RESULT: ${failures === 0 ? "PASS" : "FAIL"} (${failures} failures)`);
  process.exit(failures === 0 ? 0 : 1);
}

try { main(); } catch (e) { console.log(`FAIL ${e.message}`); console.log("RESULT: FAIL (1 failures)"); process.exit(1); }
