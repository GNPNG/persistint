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
  const edited = { id: "x-2", title: "T", status: "open", labels: ["contractor:kiro"], comments: [{ id: "c1", author: "cc", text: "moved to the dev log" }] };
  const stale = merge(edited, { ...edited, comments: [{ id: "c1", author: "cc", text: "the old text" }] }, "now");
  check(stale.record === null, "merge: a comment whose id the Gitea record already has is known, even if its text was edited there");
  const claimed = { id: "x-3", title: "T", status: "in_progress", assignee: "kiro", labels: ["contractor:kiro"], comments: [] };
  const staleCopy = { ...claimed, status: "open", assignee: "" };
  check(merge(claimed, staleCopy, "now", staleCopy).record === null,
    "merge: a status the channel still carries from the job's last export is not a claim (no revert of another channel's claim)");
  const real = merge(claimed, { ...staleCopy, status: "blocked" }, "now", staleCopy);
  check(real.record && real.record.status === "blocked", "merge: a status the agent changed since the last export is taken");
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

    // --- Intake: a passing render becomes a branch of the game repository; a bad one is refused.
    const wsRemote = path.join(tmp, "ws-remote.git");
    sh("git", ["init", "--quiet", "--bare", "--initial-branch=main", wsRemote], tmp);
    fs.writeFileSync(path.join(ws, "prompts/image/test/one.md"), "---\nid: one\ntool: Gemini image\ndrop: prompts/image/test/assets/one.png\ngame: project/assets/test/one.png\n---\n\n# one\n\n## Prompt\n\nA prompt.\n\n## Notes\n\nNone.\n");
    fs.writeFileSync(path.join(ws, "prompts/image/test/two.md"), "---\nid: two\ntool: Gemini image\ndrop: prompts/image/test/assets/two.png\ngame: project/assets/test/two.png\n---\n\n## Prompt\n\nAnother.\n");
    git(ws, ["add", "-A", "--", "prompts"]); git(ws, ["commit", "--quiet", "-m", "prompts"]); git(ws, ["branch", "-M", "main"]);
    git(ws, ["remote", "add", "origin", wsRemote]); git(ws, ["push", "--quiet", "-u", "origin", "main"]);
    git(agent, ["pull", "--quiet", "--ff-only", "origin", "main"]);
    const png = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.from("not really a png body")]);
    fs.mkdirSync(path.join(agent, "drop/prompts/image/test/assets"), { recursive: true });
    fs.mkdirSync(path.join(agent, "done"), { recursive: true });
    fs.writeFileSync(path.join(agent, "drop/prompts/image/test/assets/one.png"), png);
    fs.writeFileSync(path.join(agent, "done/one.json"), JSON.stringify({ id: "one", tool: "Gemini image", model: "test", rendered_at: now, notes: "fine", agent: "grok" }));
    fs.writeFileSync(path.join(agent, "drop/prompts/image/test/assets/two.png"), "this is text");
    fs.writeFileSync(path.join(agent, "done/two.json"), JSON.stringify({ id: "two" }));
    fs.writeFileSync(path.join(agent, "done/nosuch.json"), JSON.stringify({ id: "nosuch" }));
    git(agent, ["add", "-A"]); git(agent, ["commit", "--quiet", "-m", "agent: renders"]); git(agent, ["push", "--quiet", "origin", "main"]);
    out = sync(["--beads", ws, "--channel", chan, "--remote", remote]);
    check(/intake\s+one: render\/one \w+ pushed/.test(out), "a passing render lands on a branch render/<id>");
    const branches = sh("git", ["ls-remote", "--heads", wsRemote], tmp);
    check(branches.includes("refs/heads/render/one") && !branches.includes("refs/heads/render/two"), "the branch is on the game repository's origin, and only for the passing render");
    const tree = sh("git", ["ls-tree", "-r", "--name-only", "render/one"], ws);
    check(tree.includes("prompts/image/test/assets/one.png") && tree.includes("project/assets/test/one.png"), "the render is at its drop path and its game path");
    const msg = sh("git", ["log", "-1", "--format=%B", "render/one"], ws);
    check(msg.includes("Rendered by grok with Gemini image (test)") && msg.includes("Renderer's notes: fine"), "the commit carries the renderer's provenance");
    git(agent, ["pull", "--quiet", "--ff-only", "origin", "main"]);
    const landedOne = JSON.parse(fs.readFileSync(path.join(agent, "landed/one.json"), "utf8"));
    const landedTwo = JSON.parse(fs.readFileSync(path.join(agent, "landed/two.json"), "utf8"));
    const landedNo = JSON.parse(fs.readFileSync(path.join(agent, "landed/nosuch.json"), "utf8"));
    check(landedOne.status === "branch" && landedOne.branch === "render/one" && /^[0-9a-f]{7,}$/.test(landedOne.commit), "landed/one.json records the branch and commit");
    check(landedTwo.status === "refused" && landedTwo.why === "not a PNG", `a file that is not a PNG is refused with the reason (${landedTwo.why})`);
    check(landedNo.status === "refused" && landedNo.why === "no prompt with that id", `an unknown id is refused (${landedNo.why})`);
    check(!fs.existsSync(path.join(agent, "drop/prompts/image/test/assets/one.png")) && fs.existsSync(path.join(agent, "drop/prompts/image/test/assets/two.png")),
      "the landed render leaves the channel; the refused file stays for the renderer to see");
    out = sync(["--beads", ws, "--channel", chan, "--remote", remote]);
    check(/intake\s+nothing new/.test(out), "a second run lands nothing again");
    check(!fs.existsSync(path.join(ws, ".cache/agent-channel-land/one")), "the landing worktree is removed");

    // --- A re-delivery of the same id (a new render after a NEAR verdict, or another agent's render of
    // an id already landed) lands on its own branch instead of being taken for the first one.
    git(agent, ["pull", "--quiet", "--ff-only", "origin", "main"]);
    const png2 = Buffer.concat([png, Buffer.from(" the second render")]);
    const redeliver = (rendered_at) => {
      fs.mkdirSync(path.join(agent, "drop/prompts/image/test/assets"), { recursive: true });
      fs.writeFileSync(path.join(agent, "drop/prompts/image/test/assets/one.png"), png2);
      fs.writeFileSync(path.join(agent, "done/one.json"), JSON.stringify({ id: "one", tool: "Gemini image", model: "test", rendered_at, notes: "fixed", agent: "codex" }));
      git(agent, ["add", "-A"]); git(agent, ["commit", "--quiet", "-m", "agent: render one again"]); git(agent, ["push", "--quiet", "origin", "main"]);
    };
    redeliver(new Date(Date.now() + 60000).toISOString());
    out = sync(["--beads", ws, "--channel", chan, "--remote", remote]);
    check(/intake\s+one: render\/one-r2 \w+ pushed/.test(out), "a re-delivery lands on render/<id>-r2 instead of being dropped");
    let heads = sh("git", ["ls-remote", "--heads", wsRemote], tmp);
    check(heads.includes("refs/heads/render/one-r2"), "the re-delivery's branch is on the game repository's origin");
    check(sh("git", ["log", "-1", "--format=%B", "render/one-r2"], ws).includes("An earlier delivery of this id is on render/one"), "its commit points to the earlier delivery");
    git(agent, ["pull", "--quiet", "--ff-only", "origin", "main"]);
    const landedAgain = JSON.parse(fs.readFileSync(path.join(agent, "landed/one.json"), "utf8"));
    check(landedAgain.branch === "render/one-r2" && landedAgain.previous && landedAgain.previous.branch === "render/one", "landed/one.json records the new branch and keeps the earlier record");
    check(!fs.existsSync(path.join(agent, "drop/prompts/image/test/assets/one.png")), "the re-delivered render leaves the channel");
    // --- The same render delivered again (a run interrupted after its push) is recorded, not landed twice.
    redeliver(new Date(Date.now() + 120000).toISOString());
    out = sync(["--beads", ws, "--channel", chan, "--remote", remote]);
    heads = sh("git", ["ls-remote", "--heads", wsRemote], tmp);
    check(/intake\s+one: the same render is already on render\/one-r2/.test(out) && !heads.includes("refs/heads/render/one-r3"), "the same image again is recorded against its branch, with no new branch");
    git(agent, ["pull", "--quiet", "--ff-only", "origin", "main"]);
    check(!fs.existsSync(path.join(agent, "drop/prompts/image/test/assets/one.png")), "and its drop leaves the channel");

    // --- A run while another holds the channel's lock does nothing; a lock left by a dead run is taken over.
    fs.writeFileSync(`${chan}.lock`, `${process.pid}\n`);
    const held = git(chan, ["rev-parse", "HEAD"]).trim();
    bd(ws, ["comment", rules.id, "--actor", "forge", "a forge comment while the lock is held"]);
    out = sync(["--beads", ws, "--channel", chan, "--remote", remote]);
    check(/lock\s+another run/.test(out) && git(chan, ["rev-parse", "HEAD"]).trim() === held && fs.existsSync(`${chan}.lock`),
      "a run while another holds the lock does nothing and leaves the lock alone");
    fs.writeFileSync(`${chan}.lock`, "999999999\n");
    out = sync(["--beads", ws, "--channel", chan, "--remote", remote]);
    check(!/lock\s+another run/.test(out) && git(chan, ["rev-parse", "HEAD"]).trim() !== held && !fs.existsSync(`${chan}.lock`),
      "a stale lock from a dead run is taken over, the run does its work, and the lock is released");

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
