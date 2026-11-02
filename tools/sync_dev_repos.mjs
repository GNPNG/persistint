#!/usr/bin/env node
/**
 * Keeps the private GitHub dev repos (where the cloud agents work) in step with the private Gitea
 * repo, which stays the authoritative repo.
 *
 *   down  main and the v* tags of the Gitea repo are pushed to each dev repo (never forced: a dev
 *         repo's main is only ever fast-forwarded, and nothing is deleted there).
 *   up    every agent branch in a dev repo (kiro/*, grok/*, codex/*, agent/*) is fetched and pushed
 *         to the Gitea repo under the same name, where it is tested and merged. A branch that has
 *         diverged from the Gitea copy is reported and left alone.
 *
 * Usage: node tools/sync_dev_repos.mjs [--dry-run]
 * Run from the repo root of a Gitea clone (origin = the Gitea repo), by PM2 every ten minutes
 * (~/.config/pm2/ecosystem.config.cjs, "dev-repo-sync"), under `mise x --env claude-cli` so
 * GH_TOKEN is set. The token goes to git as an Authorization header, never into a URL or a file.
 */
import { spawnSync } from "node:child_process";

const DEV_REPOS = ["https://github.com/GNPNG/persistint-dev.git", "https://github.com/gnomatix/persistint-dev.git"];
const AGENT_PREFIXES = ["kiro", "grok", "codex", "agent"];
const dry = process.argv.includes("--dry-run");

function git(args, okToFail = false) {
  const pre = [];
  if (process.env.GH_TOKEN) {
    const basic = Buffer.from(`x-access-token:${process.env.GH_TOKEN}`).toString("base64");
    pre.push("-c", `http.https://github.com/.extraheader=AUTHORIZATION: basic ${basic}`);
  }
  const r = spawnSync("git", [...pre, ...args], { encoding: "utf8" });
  if (r.error) throw new Error(`git: ${r.error.message}`);
  if (r.status !== 0 && !okToFail) {
    throw new Error(`git ${args.join(" ")} exited ${r.status}: ${(r.stderr || "").trim().slice(-400)}`);
  }
  return r;
}

function refs(remote, patterns) {
  const r = git(["ls-remote", remote, ...patterns], true);
  const out = new Map();
  for (const line of (r.stdout || "").split("\n")) {
    const [sha, ref] = line.trim().split(/\s+/);
    if (sha && ref && !ref.endsWith("^{}")) out.set(ref, sha);
  }
  return out;
}

function isAncestor(a, b) {
  return git(["merge-base", "--is-ancestor", a, b], true).status === 0;
}

git(["fetch", "-q", "origin", "+refs/heads/*:refs/remotes/origin/*", "+refs/tags/v*:refs/tags/v*"]);
const giteaMain = git(["rev-parse", "refs/remotes/origin/main"]).stdout.trim();
const giteaBranches = refs("origin", AGENT_PREFIXES.map((p) => `refs/heads/${p}/*`));

for (const repo of DEV_REPOS) {
  const name = repo.replace(/^https:\/\/github\.com\//, "").replace(/\.git$/, "");
  const remoteMain = refs(repo, ["refs/heads/main"]).get("refs/heads/main");
  if (remoteMain === giteaMain) {
    console.log(`down  ${name}: main up to date (${giteaMain.slice(0, 7)})`);
  } else if (remoteMain && !isAncestor(remoteMain, giteaMain)) {
    console.log(`down  ${name}: main ${remoteMain.slice(0, 7)} is not behind the Gitea main; left alone`);
  } else if (dry) {
    console.log(`down  ${name}: would push main ${giteaMain.slice(0, 7)}`);
  } else {
    git(["push", "-q", repo, `refs/remotes/origin/main:refs/heads/main`]);
    console.log(`down  ${name}: main -> ${giteaMain.slice(0, 7)}`);
  }
  if (!dry) git(["push", "-q", repo, "refs/tags/v*:refs/tags/v*"], true);

  const agentRefs = refs(repo, AGENT_PREFIXES.map((p) => `refs/heads/${p}/*`));
  for (const [ref, sha] of agentRefs) {
    const branch = ref.replace("refs/heads/", "");
    const have = giteaBranches.get(ref);
    if (have === sha) continue;
    git(["fetch", "-q", repo, `+${ref}:refs/remotes/dev/${branch}`]);
    if (have && !isAncestor(have, sha)) {
      console.log(`up    ${name}: ${branch} has diverged from the Gitea copy (${have.slice(0, 7)} vs ${sha.slice(0, 7)}); left alone`);
      continue;
    }
    if (dry) {
      console.log(`up    ${name}: would push ${branch} ${sha.slice(0, 7)} to Gitea`);
      continue;
    }
    git(["push", "-q", "origin", `refs/remotes/dev/${branch}:${ref}`]);
    giteaBranches.set(ref, sha);
    console.log(`up    ${name}: ${branch} -> Gitea ${sha.slice(0, 7)}`);
  }
}
