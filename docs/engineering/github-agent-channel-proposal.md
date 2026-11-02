# A private GitHub channel for the GitHub-only agents: proposal

Written 2026-11-02 for the author's approval. Nothing here exists yet.

## The problem

Two contractor agents (Kiro, Grok) can reach the repository only through GitHub. The GitHub
copy of this project (GNPNG/persistint) is a public, filtered publication (AGENTS.md, SOP-14):
anything written there is public, including issues, Discussions, pull-request comments, branch
names and commit messages; gists are unlisted, not private. The team's own channel is the forge
(Gitea issues, beads), which those agents cannot see. There is no place today where the team and
the GitHub-only agents can talk that is not public.

## The proposal in one line

A private GitHub repository used as a message board, with issues as threads and labels as
addressing, and a small scheduled job on srv that mirrors the contractor beads into it and the
agents' comments back.

## 1. The repository

- Name: `gnomatix/persistint-agents` (private; under the gnomatix organisation, where the Claude
  GitHub App is already installed). No game content, no source: a README with the rules below
  and the issues. The public mirror's publication script never touches it.
- Collaborators: the author, the Kiro and Grok accounts, and the `cc-srv` account that srv acts
  under (see 3). Write access for all; the repository settings stay with the author.
- Protections: issues on, wiki and Discussions off (one channel, not three), no Actions
  (nothing runs in this repository; the sync runs on srv).

## 2. Conventions in the channel

- One issue per task or thread. A mirrored bead's issue title is the bead's title with its id in
  square brackets: `[persistint-game-g0va] Player side view: ...`. A free thread carries no id.
- Labels: `to:kiro`, `to:grok`, `to:cc-srv`, `to:author` say who a thread is for;
  `from:bead` marks a mirrored bead; `decision-needed` is the contractor rules' "Decision needed"
  (fcxf rule 6) and is the only label that pages the author.
- An agent's report at the end of a task is a comment: branch, commit, what was verified and what
  was not, as the contractor rules already require (fcxf rule 9). Closing an issue is the
  author's or cc-srv's call, after the merge.
- Nothing private about the infrastructure goes in a comment (no hostnames, addresses, paths
  outside the repository, credentials). The repository is private, but the agents' vendors read
  what the agents read.

## 3. What srv needs

- A fine-grained personal access token, scoped to this one repository, with Issues read/write,
  Contents read and Metadata read, created by the author and placed in the encrypted role env
  (`~/.config/gnomatix/.env`, key `GH_TOKEN`). `gh` is installed on srv and reads that variable;
  nothing is stored in a browser or keyring. The token is never printed or committed.
- The token identifies one GitHub account. If that is the author's own account, srv's comments
  appear under the author's name; a separate `cc-srv` machine account keeps the authorship
  honest and is the recommendation (the contractor rules ask every agent to act under its own
  name).

## 4. The sync (tools/sync_agent_channel.mjs, run by PM2 on srv every 10 minutes)

Beads stay the source of truth; the channel is a view of them for the agents who cannot see
the forge.

- Beads to issues: every open bead labelled `contractor:kiro` or `contractor:antigravity` (and a
  new `contractor:grok`) gets an issue if it has none, titled as in 2, with the bead's description
  and the current comments as the body, and the `to:` label for its contractor. The bead gets a
  comment with the issue URL. Later bead comments by the team are appended to the issue as
  comments (prefixed with the bead actor).
- Issues to beads: new comments by the agents are added to the bead as comments
  (prefixed `github:<login>`), so the team reads them where it works. A `decision-needed` label
  raised by an agent is added to the bead as a comment headed "Decision needed".
- Closing: when the bead closes, the issue gets the close reason as a comment and is closed.
  An issue closed by an agent does not close the bead; it adds a comment asking for the merge.
- State: the mapping bead id to issue number lives in the bead itself (the URL comment), so the
  job needs no database and can be rerun from nothing.
- Failure: the job logs to `.cache/sync-agent-channel/` and stops on the first API error; the
  next run retries. Nothing is deleted on either side, ever.

## 5. What this does not do

- It does not give the agents the forge, the private repository, the beads database or any
  credential. They see mirrored text and write comments.
- It does not change the contractor rules (bead fcxf); it gives them a place to be followed.
- It does not replace the public GitHub issues, which stay the public bug reports.

## 6. Cost and reversibility

One private repository (free on GitHub for organisations), one token, one PM2 job, about a day
of work for the sync with its tests. Reversible by deleting the repository and the token; the
beads keep every mirrored comment.

## Decisions for the author

1. Approve the repository name and the collaborator list.
2. Token: the author's account or a `cc-srv` machine account (recommended).
3. Which beads are mirrored: all `contractor:*` beads (proposed), or only ones also labelled
   `channel`.
