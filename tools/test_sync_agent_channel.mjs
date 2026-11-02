#!/usr/bin/env node
/**
 * Checks for tools/sync_agent_channel.mjs (bd uowd), in a temp tree of the test's own: a bare
 * repository standing in for GitHub, a scratch beads workspace (bd init) with three beads, and a
 * second clone standing in for an agent.
 *
 *   node tools/test_sync_agent_channel.mjs    prints "ok"/"FAIL" per check and
 *                                             "RESULT: PASS|FAIL (n failures)"; exits 0 or 1
 *
 * Checked: the first run clones the empty remote and pushes issues.jsonl with the contractor and
 * channel beads and not the plain one, plus the README; the agent's comment and claim come back
 * to the forge under the agent's name, while its title edit and its close of the channel bead are
 * dropped; a run with nothing new commits nothing; a bead closed on the forge is relayed closed and
 * takes no further comment from the agent; a new bead from the agent with a contractor label is
 * created on the forge, one without is not; a dry run writes nothing. merge() is also checked on
 * its own. Needs bd, git and node on PATH; the scratch workspace is the only beads it touches.
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { merge, RELAY_FILE } from "./sync_agent_channel.mjs";

const TOOLS = path.dirname(fileURLToPath(import.meta.url));
const SYNC = path.join(TOOLS, "sync_agent_channel.mjs");
let failures = 0;
const check = (ok, what) => { console.log((ok ? "ok   " : "FAIL ") + what); if (!ok) failures++; };

function sh(cmd, args, cwd, env = {}) {
  const r = spawnSync(cmd, args, { cwd, encoding: "utf8", env: { ...process.env, BEADS_ACTOR: "forge", ...env } });
  if (r.status !== 0) throw new Error(`${cmd} ${args.join(" ")} in ${cwd} exited ${r.status}\n${r.stdout}\n${r.stderr}`);
  return r.stdout;
}
const bd = (ws, args) => sh("bd", ["--no-color", ...args], ws);
const git = (dir, args) => sh("git", args, dir, { GIT_AUTHOR_NAME: "agent", GIT_AUTHOR_EMAIL: "agent@test", GIT_COMMITTER_NAME: "agent", GIT_COMMITTER_EMAIL: "agent@test" });
const sync = (args) => sh("node", [SYNC, ...args], TOOLS);
const readJsonl = (p) => fs.readFileSync(p, "utf8").split("\n").filter((l) => l.trim()).map((l) => JSON.parse(l));
const exportMap = (ws) => new Map(bd(ws, ["export"]).split("\n").filter((l) => l.trim()).map((l) => JSON.parse(l)).map((r) => [r.id, r]));
const byTitle = (ws, title) => [...exportMap(ws).values()].find((r) => r.title === title);

function checkMerge() {
  const forge = { id: "x-1", title: "T", status: "open", labels: ["contractor:kiro"], comments: [{ author: "forge", text: "a" }] };
  let m = merge(forge, { ...forge, title: "changed", status: "in_progress", assignee: "kiro", comments: [...forge.comments, { author: "kiro", text: "b" }] }, "now");
  check(m.record && m.record.title === "T" && m.record.status === "in_progress" && m.record.assignee === "kiro" && m.record.comments.length === 2 && m.record.updated_at === "now",
    "merge: takes the agent's comment and claim, keeps the forge's title");
  m = merge(forge, { ...forge, status: "closed" });
  check(m.record === null && m.why === "nothing new", "merge: an agent's close is not a change");
  m = merge({ ...forge, status: "closed" }, { ...forge, comments: [...forge.comments, { author: "kiro", text: "late" }] });
  check(m.record === null && m.why === "closed on the forge", "merge: a bead closed on the forge takes nothing");
  m = merge(undefined, { id: "x-9", title: "new", status: "closed", labels: ["contractor:grok"], comments: [] }, "now");
  check(m.record && m.record.status === "open", "merge: a new agent bead with a relayed label is taken, opened");
  check(merge(undefined, { id: "x-8", title: "new", status: "open", labels: ["other"] }).record === null, "merge: a new bead without a relayed label is not");
  m = merge(forge, forge);
  check(m.record === null, "merge: an identical record is nothing new");
}

function main() {
  checkMerge();
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "agent-channel-"));
  try {
    const remote = path.join(tmp, "remote.git"), ws = path.join(tmp, "ws"), chan = path.join(tmp, "chan"), agent = path.join(tmp, "agent");
    sh("git", ["init", "--quiet", "--bare", "--initial-branch=main", remote], tmp);
    fs.mkdirSync(ws);
    sh("git", ["init", "--quiet", ws], tmp);
    sh("bd", ["init", "--quiet"], ws);
    fs.mkdirSync(path.join(ws, "prompts/image/test"), { recursive: true });
    fs.writeFileSync(path.join(ws, "prompts/image/test/one.md"), "---\nid: one\n---\nA prompt.\n");
    fs.writeFileSync(path.join(ws, "prompts/STYLE.md"), "Style.\n");
    fs.mkdirSync(path.join(ws, "prompts/image/test/assets"));
    fs.writeFileSync(path.join(ws, "prompts/image/test/assets/one.md"), "not mirrored\n");
    bd(ws, ["create", "A contractor bead", "-t", "task", "-p", "2", "-l", "contractor:kiro", "--actor", "forge"]);
    bd(ws, ["create", "A plain bead", "-t", "task", "-p", "2", "--actor", "forge"]);
    bd(ws, ["create", "Contractor rules", "-t", "task", "-p", "1", "-l", "channel", "--actor", "forge"]);
    const kiroBead = byTitle(ws, "A contractor bead"), rules = byTitle(ws, "Contractor rules");
    bd(ws, ["comment", kiroBead.id, "--actor", "forge", "from the forge"]);

    // --- First run: clone, relay, README, prompts, push.
    let out = sync(["--beads", ws, "--channel", chan, "--remote", remote]);
    check(/push\s+origin\/main/.test(out), "first run pushes origin/main");
    sh("git", ["clone", "--quiet", remote, agent], tmp);
    const relayed = readJsonl(path.join(agent, RELAY_FILE));
    const ids = relayed.map((r) => r.id).sort();
    check(ids.length === 2 && ids.includes(kiroBead.id) && ids.includes(rules.id), `the contractor and channel beads are relayed, the plain one is not (${ids})`);
    check(relayed.find((r) => r.id === kiroBead.id).comments.some((c) => c.text === "from the forge"), "the forge's comment travels with the bead");
    check(fs.existsSync(path.join(agent, "README.md")) && fs.existsSync(path.join(agent, "prompts/image/test/one.md")) && fs.existsSync(path.join(agent, "prompts/STYLE.md")),
      "the README and the prompt files are in the channel");
    check(!fs.existsSync(path.join(agent, "prompts/image/test/assets/one.md")), "a prompt's assets folder is not mirrored");

    // --- The agent comments, claims, edits the title, and tries to close the rules bead.
    const now = new Date().toISOString();
    const edited = relayed.map((r) => {
      if (r.id === kiroBead.id) return { ...r, title: "renamed by the agent", status: "in_progress", assignee: "kiro", updated_at: now, comments: [...r.comments, { author: "kiro", text: "claimed, starting", created_at: now }] };
      if (r.id === rules.id) return { ...r, status: "closed", updated_at: now };
      return r;
    });
    fs.writeFileSync(path.join(agent, RELAY_FILE), edited.map((r) => JSON.stringify(r)).join("\n") + "\n");
    git(agent, ["add", "-A"]); git(agent, ["commit", "--quiet", "-m", "agent: claim and comment"]); git(agent, ["push", "--quiet", "origin", "main"]);
    out = sync(["--beads", ws, "--channel", chan, "--remote", remote]);
    let forge = exportMap(ws);
    const k = forge.get(kiroBead.id), r = forge.get(rules.id);
    check(k.status === "in_progress" && k.assignee === "kiro", `the agent's claim reaches the forge (${k.status}, ${k.assignee})`);
    check(k.comments.some((c) => c.author === "kiro" && c.text === "claimed, starting"), "the agent's comment reaches the forge under its name");
    check(k.title === "A contractor bead", "the agent's title edit is dropped");
    check(r.status !== "closed", `the agent's close of the rules bead is dropped (${r.status})`);
    check(/import\s+1 record\(s\) imported/.test(out), "one record imported");

    // --- Nothing new: no commit.
    const head = git(chan, ["rev-parse", "HEAD"]).trim();
    out = sync(["--beads", ws, "--channel", chan, "--remote", remote]);
    check(/commit\s+nothing changed/.test(out) && git(chan, ["rev-parse", "HEAD"]).trim() === head, "a run with nothing new commits nothing");

    // --- Closed on the forge: relayed closed, takes no more comments.
    bd(ws, ["close", kiroBead.id, "--actor", "forge", "--reason", "merged", "--force"]);  // the team closes an agent's bead
    sync(["--beads", ws, "--channel", chan, "--remote", remote]);
    git(agent, ["pull", "--quiet", "--ff-only", "origin", "main"]);
    let agentView = readJsonl(path.join(agent, RELAY_FILE));
    check(agentView.find((x) => x.id === kiroBead.id).status === "closed", "a bead closed on the forge is relayed closed");
    const late = agentView.map((x) => x.id === kiroBead.id ? { ...x, updated_at: new Date().toISOString(), comments: [...x.comments, { author: "kiro", text: "too late" }] } : x);
    // --- And a new bead from the agent, with and without a relayed label.
    late.push({ _type: "issue", id: "ws-agent1", title: "Agent's own bead", status: "open", priority: 2, issue_type: "task", labels: ["contractor:kiro"], comments: [], created_at: now, updated_at: now });
    late.push({ _type: "issue", id: "ws-agent2", title: "Unlabelled bead", status: "open", priority: 2, issue_type: "task", labels: [], comments: [], created_at: now, updated_at: now });
    fs.writeFileSync(path.join(agent, RELAY_FILE), late.map((x) => JSON.stringify(x)).join("\n") + "\n");
    git(agent, ["add", "-A"]); git(agent, ["commit", "--quiet", "-m", "agent: late comment and new beads"]); git(agent, ["push", "--quiet", "origin", "main"]);
    out = sync(["--beads", ws, "--channel", chan, "--remote", remote]);
    forge = exportMap(ws);
    check(!forge.get(kiroBead.id).comments.some((c) => c.text === "too late"), "a comment on a closed bead is not imported");
    check(byTitle(ws, "Agent's own bead") !== undefined, "a new bead from the agent with a contractor label is created on the forge");
    check(byTitle(ws, "Unlabelled bead") === undefined, "a new bead without a relayed label is not");

    // --- Dry run writes nothing.
    const before = git(chan, ["rev-parse", "HEAD"]).trim();
    bd(ws, ["comment", rules.id, "--actor", "forge", "a forge comment after the dry run starts"]);
    out = sync(["--beads", ws, "--channel", chan, "--remote", remote, "--dry-run"]);
    check(/would commit \(dry run\)/.test(out) && git(chan, ["rev-parse", "HEAD"]).trim() === before, "a dry run reports the change and commits nothing");
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
  console.log(`RESULT: ${failures === 0 ? "PASS" : "FAIL"} (${failures} failures)`);
  process.exit(failures === 0 ? 0 : 1);
}

try { main(); } catch (e) { console.log(`FAIL ${e.message}`); console.log("RESULT: FAIL (1 failures)"); process.exit(1); }
