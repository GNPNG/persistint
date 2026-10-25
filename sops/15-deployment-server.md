# SOP-15: Deployment server (publication, replication and deploy pipelines)

Status: draft (author's concept 2026-10-25; awaiting his approval)
Owner: Brett Whitty
Applies to: any project
Last reviewed: 2026-10-25
Related SOPs: SOP-14 (14-asset-expiry-and-public-publication.md: the filtered publication is one pipeline run here); SOP-09 (release checklist: release stages run here); SOP-13 (evaluating the runner/UI and workflow engine choices); SOP-12 (who may change a pipeline)

## 1. Purpose

One place where every automated movement of a repository's content runs: filtered publication to a public forge, replication between forges, site deploys, release builds. The author's words: "all the orchestration and staging stuff has a single point of action and config on a reliable machine"; "So if we notice the web sites aren't being updated, and the github mirrors are stale... we know exactly where to look."

## 2. When to use / when not to

The release snapshots make the container the organisation's internal web archive: one point-in-time copy per public release of every mirrored repository and every deployed site tree, which the forge on the NAS cannot give. The author: "Which we can not do on the Gitea server on the NAS. Right, we're running our own internal web archive. And common crawl. I'd sleep better knowing that was happening." No public archive service is used: the author's decision, 2026-10-25: "No, no public. Private. Zero cost. I mean, not zero, but already paid cost." The archive is the container's snapshots and their dumps on the organisation's own archive server, nothing else.

The same loop is the organisation's repository backup: every listed repository is kept as a full bare mirror (every ref, including the beads data ref) in the container's state directory, which sits on its own ZFS dataset and is snapshotted. The author: "the benefit of that is, we have a backup if the git servers shit the bed, and one that lives on a ZFS-backed filesystem we can snapshot. So a very solid backup of the repos."

Use for any job triggered by a change in a repository that pushes content somewhere else. Not for interactive agent sessions, rendering jobs (SOP-04), or anything that needs the author's keyboard.

## 3. Inputs and prerequisites

A list of repositories; each repository's `.config/publish.toml` (its targets: `filtered`, `mirror`, `run`); credentials for the destinations, held only in the deployment user's credential store; a container to run in.

## 4. Roles and tools

- The author approves each new pipeline once; agents change `.config/publish.toml` through normal review. Instruction-file edits never come from relays.
- Runtime: an LXD container on the organisation's always-on host. The author: "runs inside a LXD container for the sole reason that we can snapshot it and have full traceability and isolation of the service from my own personal shit that I do on that machine. That's how things are supposed to work." Snapshot before every change to it.
- Minimal form: "it literally could be just a single shell script on a cron" (the author). One cron line, one list file, the driver; canned pipelines are the driver's modes, parameters live in each repository's config.
- Runner and UI: not home-made ("We don't want to reinvent the wheel, there's all sorts of dashboard web apps we could use to show status"). Candidates, in the author's order: his Bamboo instance ("I did have a bamboo instance running at one point. And I had a license for it"; "bamboo would just be the runner and the UI for the scripts"); the standard dashboards already set up on srv and unused; the forge's own Actions runner. A runner outside the forge "decouples us from Gitea, which is good."
- Multi-step workflows: Nextflow, the author's go-to engine, "for traceability" and "ease of workflow construction... composable, and use environment variables / config files". A `run` target invokes it; its trace, report and timeline files are the run record.

## 5. Procedure

1. Create the container; snapshot it (`pre-<change>`) before each change; install git, git-filter-repo, python3, Nextflow, the runner agent; put destination credentials in that user's git credential store only.
2. Add a repository: write its `.config/publish.toml`, add it to the list (or enable its workflow file), run once by hand with `--dry-run`, then for real, check the destination.
3. Every tick: fetch each repository; work out which refs moved since the last successful tick; if any did, check out `main` and run the handler with that list. A target runs only when a moved ref matches its trigger (`on`; default a version tag, a dev build is a second tag pattern such as `dev-*`; the author: "Tagging a release, tagging a dev build, or whatever"; the author: "more sensibly, it gets triggered by tagging"; `main` for publish-on-every-push). A `run` target checks out the tag that fired it. one JSON line per target run (time, repo, target, mode, destination, commit, version, ok, seconds, steps, error).
4. When a site is stale or a mirror is behind: look in the container (the cron log, `runs.jsonl`, the runner UI). Nowhere else.
5. **Release observer, on the host, outside the container.** A second cron line watches the public destinations with `git ls-remote --tags`; a tag that appears there for the first time is a release that reached the public, and the host takes `lxc snapshot <container> release-<repo>-<tag>-<date>`. The container never snapshots itself and holds no `lxc` rights; the trigger is the public fact, not the container's own log. The author: "an observer script outside of that container could actually watch the public repos, eg: Github, and on noticing a successful public release, do an 'lxc snapshot' on that container. Meaning that we have a snapshot of the repo of the release."
6. **Off-box archive, on the host.** Each release snapshot is shipped to the archive storage server with standard ZFS tools: either the snapshot stream itself (`zfs send`, incremental from the previous release snapshot, received or stored as a file) or a tarball of the image (`lxc export <container>/<snapshot>`), then stashed on the archive server. The author: "I can have a zfs clone process running using standard ZFS tools to archive those machine images, dump to tarballs, and stash them on my archive storage server." Verify each dump once by listing its contents; record its checksum beside it.
7. A failed target does not stop the others; it is retried on the next tick; a filtered publication is force-pushed whole or not at all.

## 6. Acceptance checks

A new tag reaches every destination within one tick; the bare mirror holds every ref the forge holds (compare `git ls-remote` counts); each target run has a record; a failure is visible in the log or UI and clears on the next successful tick; a snapshot exists from before the last container change; no credential is readable outside the container.

## 7. Hazard analysis, failure modes and recovery

| Hazard | Control point | Signal | Limit | Corrective action | Record | Anticipated / learned |
|---|---|---|---|---|---|---|
| Container changed without a snapshot | step 1 | no `pre-*` snapshot newer than the change | any | snapshot now; restore from the last one if the change broke it | snapshot list | anticipated |
| Trigger too broad (every push deploys a half-finished tree) | config review | `on` contains `main` for a deploy target | any | default to tags; `main` only for publication of the pace of work | review | anticipated |
| Two schedulers running the same pipeline | provisioning | a run record from both cron and runner for one commit | two | disable one; the cron is the fallback, not a second runner | runs.jsonl | anticipated |
| Destination URL wrong in a repository's config | step 2 | dry run lists an unexpected destination | one | fix before the first real run | review | anticipated |
| Force-push of a filtered copy fails half way | step 5 | push error in the run record | one | nothing landed (git push is atomic per ref set); retried next tick | runs.jsonl | anticipated |
| Forge mirror feature trusted for publication | design | a push mirror still configured | one | delete it; the pipeline is the only publisher (SOP-14 E4) | ca0 | learned 2026-10-24 (API/UI disagreed on the mirror's state) |
| Backup mirror missing refs (heads and tags only) | provisioning | `git ls-remote` of forge and mirror differ in ref count | any | clone with `--mirror`; fetch with `--prune` and no refspec | tick log | learned 2026-10-25 (first draft fetched heads and tags only) |
| Release snapshots accumulate without a retention rule | observer | snapshot count per container | set by the author | keep every release snapshot that corresponds to a supported version; prune the rest on his word | snapshot list | anticipated |
| Observer snapshots before the container finished every target for that tag | observer | run record for the tag incomplete at snapshot time | one | the snapshot still holds the full mirror of the tag; re-run the observer tick after the record completes if a second snapshot is wanted | observer.log | anticipated |
| Release dump never left the host | archive step | no dump on the archive server for a release snapshot | one | ship it; the observer's log lists every snapshot taken | archive server listing | anticipated |
| Credential outside the container | provisioning | token in a session env or a laptop file | present | move it into the container's credential store | provisioning note | anticipated |

## 8. Artifacts and templates

`.config/publish.toml` (one `[[target]]` per destination: name, mode, dest or command, refs, remove_paths, strip_blobs_file); the list file; the cron line; `runs.jsonl`; snapshot names `pre-<change>-<date>`.

## 9. Reference implementation in persistint

The infrastructure this SOP runs on already exists; the author stood it up about ten years ago (his words, 2026-10-25: "All the shit I'm describing already exists because I stood it up like 10 years ago."): the LXD host, the ZFS datasets, the archive storage server, the Bamboo instance and the standard dashboards on srv. The first build is therefore an inventory followed by wiring, not a provisioning job; nothing that exists is reinstalled.

`tools/publish.py` (the handler: three modes, run records; installed into the container beside the loop, the repository copy is the reference source and serves by-hand dry runs), `tools/publish_public_cron.sh` (the single script on a cron inside the container), `tools/release_observer.sh` (the host-side observer, its own cron line, no credentials), `.config/publish.toml` (github-public filtered target live; site deploy target drafted and disabled until the container exists), `.gitea/workflows/publish-public.yml` (fast path if a forge runner is registered). Host: srv, the NUC the author built "EXACTLY to host things like this". Tested 2026-10-25: a filtered publication of main and three tags into a throwaway bare repository, 53 s, zero removed paths left in the copy, one run record written. Beads: ck0 (publication path), the container build task filed with this SOP.

## 10. Lessons learned

The author ran the same pattern before git: production and development web sites in Robin's lab were updated from SVN commit hooks. The hosted forms (GitHub Pages, Netlify, Cloudflare Pages) are that hook as a service; GitHub itself has no filtered publication, so the filter must run on our side (git-filter-repo is the standard tool). Polling from a cron rather than a forge webhook survived the 2026-10-24 forge outage by design: the publisher does not depend on the forge being up to be told.
