# A private GitHub repository for the GitHub-only agents: proposal

Written 2026-11-02 for the author's approval; revised the same day for the asset intake and the
agents' beads. Nothing here exists yet.

## The problem

Two contractor agents (Kiro, Grok) run in the cloud and reach this project only through GitHub.
The GitHub copy (GNPNG/persistint) is a public, filtered publication (AGENTS.md, SOP-14), so
anything written there is public: issues, Discussions, pull-request comments, branches, commit
messages; gists are unlisted, not private. The team works on the forge: Gitea issues and beads,
whose Dolt database is on the forge too. The agents have `bd` but cannot reach that database, so
their beads are islands. Grok can also render graphics, and there is no private place for it to
hand renders in.

## The proposal in one line

One private GitHub repository that does three jobs: it relays the beads to and from the agents
as JSONL, it is the intake for rendered assets, and its issues are the place to talk. A scheduled
job on srv moves everything between the repository and the forge; the forge stays the source of
truth, and the asset land pipeline the team already has does the merging.

## 1. The repository

- `gnomatix/persistint-agents`, private, in the gnomatix organisation (where the Claude GitHub
  App is installed). It holds no game source: the files below, and the issues.
- Collaborators with write access: the author, the Kiro and Grok accounts, and a `cc-srv`
  machine account for srv. Settings stay with the author. Issues on; wiki, Discussions and
  Actions off (nothing runs in the repository; srv does the work).
- Layout:

```
README.md                      the rules below, and how to run the two bd commands
.beads/issues.jsonl            the relayed beads (bd export / bd import), see 2
prompts/QUEUE.md               every prompt not yet rendered: tool, aspect, exact Save-as path
prompts/STYLE.md               the style guide the prompts refer to
prompts/<kind>/<id>/prompt.txt one file per prompt, as the queue lists it
drop/<Save-as path>            a passing render, saved where the queue says
done/<id>.json                 its provenance: id, prompt_sha256, tool, model, rendered_at, notes
landed/<id>.json               written by srv when a drop has been merged (commit, tests, build)
```

## 2. Beads over the repository (the agents' tracker)

`bd export` writes issues with their labels, dependencies and comments as JSONL; `bd import`
upserts them. That is a sync that needs only a file in a git repository.

- srv exports the beads the agents may see, every 10 minutes: those labelled `contractor:kiro`,
  `contractor:grok` or `contractor:antigravity`, plus the contractor rules bead (fcxf) and
  anything labelled `channel`. The file is committed and pushed when it changed.
- An agent starts work with `git pull && bd import .beads/issues.jsonl`, claims its bead with its
  own actor name (fcxf rule 1), comments as it goes, and ends with `bd export --label
  contractor:<me> > .beads/issues.jsonl` (or the export filter the README gives), commit, push.
- srv pulls, imports the file into the forge database with the import's upsert, and the comments
  appear on the forge beads under the agent's actor name. Conflicts: beads are append-mostly;
  the one field both sides write is status, and the rule is that an agent may claim and comment
  but only the team closes (fcxf rule 9). The README says so; the job enforces it by never
  importing a status change from the file onto a bead the team has closed.
- What is not relayed: every other bead, the memories, the Dolt history. The agents see their
  queue and the rules, not the project's tracker.

## 3. Asset intake (Grok renders, srv lands)

The same contract the Antigravity render queue uses today, moved onto git:

- srv regenerates `prompts/QUEUE.md` from the repo (`tools/render_all_assets.py
  --export-queue`, 61 of 82 prompts unrendered on 2026-10-31) and commits it with the prompt
  files, so the agent always has the current list and the exact text to paste.
- Grok renders a prompt, keeps only a passing result (every listed item present, nothing
  cropped or touching, no text, the chroma background where the prompt says so), saves it as PNG
  at `drop/<Save-as path>`, writes `done/<id>.json`, commits both, pushes. A near miss is not
  saved; a note on why goes in the bead comment instead.
- srv's job sees a new `done/<id>.json`, copies the PNG to the repository's drop path and runs the
  existing landing steps for that kind of prompt (`sync_rendered_assets.py`, `land_wardrobe.mjs`
  or `land_species.mjs`, `bake_paper.sh`, the import, the suite, shots), on a branch named
  `grok/<id>`. A passing branch is merged to main and deployed as today; the result (commit,
  tests, build) is written to `landed/<id>.json` and commented on the bead. A failing one gets the
  failure in the bead comment and the branch stays for the team.
- Binary files in git: renders are a few MB each and the repository is an intake, not an archive;
  srv removes a drop from the repository once it has landed (the file lives on in the project's
  LFS), so the repository stays small. No Git LFS on the intake side, so the agent needs nothing
  beyond git.

## 4. Talking

Issues, for anything that is not a bead: a question about a prompt, a "Decision needed" for the
author (fcxf rule 6; label `decision-needed`, the only thing that pages the author), a report
that does not belong on a bead. One issue per thread; `to:kiro`, `to:grok`, `to:cc-srv`,
`to:author` say who it is for. srv mirrors an issue's comments to the forge as a comment on the
channel bead so nothing is missed, and answers in the issue.

## 5. What srv needs

A fine-grained personal access token scoped to this one repository (Contents read/write, Issues
read/write, Metadata read), created by the author, placed in srv's encrypted role env
(`~/.config/gnomatix/.env`, `GH_TOKEN`); `gh` and `git` read it from there. A `cc-srv` machine
account is recommended so srv's commits and comments carry its own name. The token is never
printed or committed.

## 6. What this does not do

- It gives the agents no credential, no forge access, no Dolt database and none of the
  project's private material: the relayed beads are a filtered export, the prompts are already
  written for outside renderers.
- It does not change the contractor rules (bead fcxf) or the landing rules in the gemini-assets
  skill; it gives both a place to run.
- It does not replace the public GitHub issues, which stay the public bug reports.

## 7. Cost and reversibility

One free private repository, one token, one PM2 job on srv (`tools/sync_agent_channel.mjs`:
export, import, intake, mirror; about two days with its tests, the intake reusing the land
tools). Reversible by deleting the repository and the token; the forge keeps every imported
comment and every landed asset.

## Decisions for the author

1. The repository name and the collaborator list.
2. Token account: a `cc-srv` machine account (recommended) or the author's own.
3. Which beads are relayed: all `contractor:*` beads plus `channel` (proposed), or a narrower set.
4. Whether Grok's landed renders merge to main automatically when the suite passes (proposed),
   or wait for the author's look at the shots first.
