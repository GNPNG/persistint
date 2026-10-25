#!/usr/bin/env python3
"""SOP-14/SOP-15 (org vault) pipeline driver: runs every target in a repository's .config/publish.toml.

Usage: python3 -I tools/publish.py [--repo PATH] [--only NAME] [--dry-run] [--changed REF ...]
Trigger: each target has `on`, the ref patterns that fire it (default: version tags, refs/tags/v*; add
"main" for a target that should run on every push). With --changed (the loop passes the refs that moved
since its last tick) a target runs only if a changed ref matches; without it every target runs.
Target modes (canned pipelines; the repository only fills in parameters):
  filtered  fresh mirror clone, git filter-repo removing remove_paths and the blobs in strip_blobs_file
            from every commit, force-push of `refs` (default main and v* tags). The private repository
            is never rewritten; the destination is regenerated each run.
  mirror    git push --mirror of every ref: a replica, or a migration between forges.
  run       a command from the repository (a site deploy, a build) run in the checkout.
Each target appends one JSON line (time, repo, target, mode, dest, commit, version, ok, seconds, steps,
error) to $PUBLISH_STATE/runs.jsonl when PUBLISH_STATE is set; the status page is rendered from it.
Credentials come from the git credential store of the user running this, never from arguments.
"""
import argparse, fnmatch, json, os, shutil, subprocess, sys, tempfile, time, tomllib
from pathlib import Path


def sh(cmd, cwd=None) -> str:
    p = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True)
    if p.returncode:
        raise RuntimeError(f"{' '.join(map(str, cmd))} failed:\n{p.stderr.strip()[-2000:]}")
    return p.stdout


def refs_matching(repo, patterns) -> list:
    have = sh(["git", "for-each-ref", "--format=%(refname)"], cwd=repo).split()
    out = []
    for r in patterns:
        full = r if r.startswith("refs/") else f"refs/heads/{r}"
        out += [h for h in have if fnmatch.fnmatch(h, full) and h not in out]
    return out


def filtered(repo, t, dry, steps) -> None:
    work = Path(tempfile.mkdtemp()); pub = work / "pub.git"
    try:
        sh(["git", "clone", "-q", "--mirror", "--no-local", str(repo), str(pub)]); steps.append("mirror clone of the private repository")
        globs = t.get("remove_paths", [])
        args = ["git", "filter-repo", "--force"]
        for g in globs:
            args += ["--path-glob", g]
        if globs:
            args.append("--invert-paths")
        sb = t.get("strip_blobs_file")
        if sb and (repo / sb).is_file() and (repo / sb).stat().st_size:
            args += ["--strip-blobs-with-ids", str(repo / sb)]
        sh(args, cwd=pub); steps.append(f"filter-repo: {len(globs)} path globs removed, blobs file {sb or 'none'}")
        push = refs_matching(pub, t.get("refs", ["main", "refs/tags/v*"]))
        if not push:
            raise RuntimeError("nothing to publish: no ref matches " + str(t.get("refs")))
        steps.append(f"push --force {len(push)} refs to {t['dest']}: " + " ".join(push))
        if not dry:
            sh(["git", "push", "--force", t["dest"]] + [f"{h}:{h}" for h in push], cwd=pub)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def mirror(repo, t, dry, steps) -> None:
    steps.append(f"push --mirror (every ref) to {t['dest']}")
    if not dry:
        sh(["git", "push", "--mirror", t["dest"]], cwd=repo)


def run(repo, t, dry, steps, at=None) -> None:
    if at:
        sh(["git", "checkout", "-q", at], cwd=repo); steps.append(f"checkout {at}")
    steps.append("run: " + " ".join(t["command"]))
    if not dry:
        out = sh(t["command"], cwd=repo)
        steps.append("output (tail):\n" + out[-2000:])


MODES = {"filtered": filtered, "mirror": mirror, "run": run}


def record(repo, t, ok, steps, err, t0) -> None:
    state = os.environ.get("PUBLISH_STATE")
    if not state:
        return
    try:
        name = Path(sh(["git", "remote", "get-url", "origin"], cwd=repo).strip()).name.removesuffix(".git")
    except RuntimeError:
        name = repo.name
    try:
        version = sh(["git", "describe", "--tags", "--match", "v*", "--abbrev=0"], cwd=repo).strip()
    except RuntimeError:
        version = ""
    rec = {"time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "repo": name, "target": t["name"],
           "mode": t["mode"], "dest": t.get("dest") or " ".join(t.get("command", [])),
           "commit": sh(["git", "rev-parse", "--short", "HEAD"], cwd=repo).strip(), "version": version,
           "ok": ok, "seconds": round(time.time() - t0, 1), "steps": steps, "error": err}
    Path(state).mkdir(parents=True, exist_ok=True)
    with open(Path(state) / "runs.jsonl", "a") as f:
        f.write(json.dumps(rec) + "\n")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--only")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--changed", nargs="*", help="refs that moved; a target runs only if one matches its `on`")
    a = ap.parse_args()
    repo = Path(a.repo).resolve()
    cfg = repo / ".config" / "publish.toml"
    if not cfg.is_file():
        sys.exit(f"no {cfg}")
    failed = 0
    for t in tomllib.loads(cfg.read_text()).get("target", []):
        if a.only and t.get("name") != a.only:
            continue
        on = [r if r.startswith("refs/") else f"refs/heads/{r}" for r in t.get("on", ["refs/tags/v*"])]
        hit = None if a.changed is None else [c for c in a.changed if any(fnmatch.fnmatch(c, o) for o in on)]
        if hit is not None and not hit:
            print(f"{t['name']} ({t['mode']}): skipped, no changed ref matches {t.get('on', ['refs/tags/v*'])}")
            continue
        steps, t0, err = [], time.time(), ""
        try:
            if t["mode"] == "run":
                run(repo, t, a.dry_run, steps, at=sorted(hit)[-1] if hit else None)
            else:
                MODES[t["mode"]](repo, t, a.dry_run, steps)
            print(f"{t['name']} ({t['mode']}): ok")
        except Exception as e:  # noqa: BLE001  (one failed target must not stop the others)
            err = str(e); failed += 1
            print(f"{t['name']} ({t['mode']}): FAILED {err}", file=sys.stderr)
        if not a.dry_run:
            record(repo, t, not err, steps, err, t0)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
