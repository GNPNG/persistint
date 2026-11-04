# PERSISTINT agents: the coordination repository

This private repository is how the agents who work through GitHub (Kiro, Grok) share work with
the team, whose tracker and forge they cannot reach. It is written by a job on the team's build
machine (`tools/sync_agent_channel.mjs` in the game repository) and by the agents. It holds no
game source.

## Assignments (2026-11-02)

Each of you has beads in `.beads/issues.jsonl` labelled with your name. Start with the first one;
claim it; report in comments. Nothing else is expected of you until it is done.

| Agent | Label | First task |
|---|---|---|
| Kiro | `contractor:kiro` | **Planning and text, not code.** First **persistint-game-c0e**: the design for Fallout-style branching dialogue built from the verified quote databases (a written design with a worked example, on a branch of the GitHub mirror). Then 91a (quest framework), 0w3 (the Atwood skull quest), h3j (classroom module). |
| Grok | `contractor:grok` (persistint-game-4odz) | **Render the wardrobe sheets** (11 `wardrobe_*` prompts in `prompts/QUEUE.md`), then the title, loading and app-icon images. One passing render at a time into `drop/` + `done/`. |
| Codex | `contractor:codex` (persistint-game-fv68) | **Render the characters** (11 `char_*` prompts), then the temple set (8 `temple_*`), the props (6 `prop_*`) and the key art (8 `key_art_*`). Same intake. |

The 9 video prompts (Veo) are not assigned; say in a bead comment if you can render video.

**Quality bar (the author, 2026-11-02): high-quality work.** Read before you act and cite the file for every claim. One task finished and verified beats three started. A near-miss render is never saved. A design without a worked example is not done. Say plainly what you did not verify.

## What is here

| Path | What | Who writes it |
|---|---|---|
| `.beads/issues.jsonl` | the beads you may work on, with their comments | the job (from the forge) and you (your comments and claims) |
| `prompts/QUEUE.md` | every prompt not yet rendered: tool, aspect ratio, exact Save-as path | the job |
| `prompts/STYLE.md`, `prompts/**/*.md` | the style guide and the prompt files, exactly as the team wrote them | the job |
| `drop/`, `done/`, `landed/` | the render intake (coming next): a passing render at its Save-as path, its provenance, and what the team did with it | you, then the job |
| Issues | anything that is not a bead: a question, a "Decision needed" for the author | everyone |

## Your name

Every agent acts under its own name, whatever credentials it pushes with: **Kiro is `kiro`, Grok is `grok`,
Codex is `codex`**. That name goes in every `bd` write (`--actor kiro`, `--actor grok`, `--actor codex`) and in the git
identity of every commit you make in this repository (`git -c user.name=grok -c
user.email=grok@agents.persistint commit ...`, or set it once with `git config` in your clone).
A comment or commit under the owner's name is his, not yours; the team reads the names.

## Working a bead

1. `git pull`, then `bd import .beads/issues.jsonl` into your own beads workspace (`bd init` once if
   you have none). The import upserts: new beads appear, known ones update, your own comments stay.
2. Claim your bead with your own actor name: `bd update <id> --claim --actor <kiro|grok>`. Work on
   a branch `contractor/<tool>/<bead-id>` of the game's GitHub mirror; never push to its main.
3. Comment as you go: `bd comment <id> --actor <you> "..."`. Findings, blockers and the end-of-task
   report (branch, commit, what was verified and what was not) are comments.
4. `bd export -o .beads/issues.jsonl`, commit, push. The job imports your comments and your claim
   to the forge within ten minutes, under your actor name.

What the job takes from your file: your new comments, your claim (status `open`, `in_progress` or
`blocked`, and the assignee). What it does not take: a close (the team closes after the merge), a
title, description or priority edit, and anything on a bead the forge has closed. A new bead you
create is taken when it carries a `contractor:*` or `channel` label.

## Rendering (Grok, Codex)

**If `prompts/QUEUE.md` is a render hold notice, render nothing from it.** The job refuses those
renders while the hold stands; the notice says why and what ends it.

Pick a prompt from `prompts/QUEUE.md`. Paste its text as written. Keep only a passing render: every
listed item present, nothing cropped or touching, no text, the chroma background where the prompt
asks for one. Save it as PNG at `drop/<Save-as path>` and write `done/<id>.json`
(`{"id","agent","prompt_sha256","tool","model","rendered_at","notes"}`; `agent` is your name), commit, push. A near miss is not
saved; say why in a bead comment instead. The team lands the render on a branch `render/<id>` of the game repository and writes `landed/<id>.json`.

## Rules

The contractor rules are the bead labelled `channel` titled "Contractor rules". In short: act
under your own name; read the repository docs before changing anything; no invented game content;
plain commit messages with no AI attribution lines; anything that needs the author's decision is an
issue labelled `decision-needed`; nothing about the team's infrastructure (hosts, addresses, paths
outside the repositories, credentials) in a comment or a commit.
