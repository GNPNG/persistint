# SOP-08: Issue tracking, memory, commits and session close

Status: active
Owner: Brett Whitty
Applies to: any project where coding agents work in a git repository with an issue tracker
Last reviewed: 2026-10-24
Related SOPs: SOP-01 (01-parallel-agents-worktrees.md: worktree notes, close reasons and cleanup follow this SOP); SOP-04 (04-generative-render-pipeline.md: generation-gap tickets follow the issue lifecycle here and are reported at each standup); SOP-07 (07-playtest-bug-triage.md: leftovers from bug fixing are filed under step 13); SOP-11 (11-versioning-and-playtest-cadence.md: sprint and playtest labels, the version commit and tag, the owner's reports as issues); SOP-12 (12-team-roles-and-dispatch.md: the owner's standup notes, status wording, which session writes what); SOP-16 (16-agent-secure-notes.md: agent notes and questions for the author go in the per-workspace encrypted folder)

## 1. Purpose

Keep every piece of work traceable from issue to commit to push, keep the author's standing rules in durable memory instead of in one session's context, and end every session with nothing stranded locally: work committed, pushed, tracked, and the workspace clean.

## 2. When to use / when not to

Use when:
- An agent session changes anything in a repository (code, docs, data, config).
- Work spans more than one session, more than one agent, or more than one branch.
- The author gives a rule that must hold in later sessions.

Do not use when:
- The session only reads and answers a question, with no file changes and no follow-up work. Skip the procedure; file an issue only if the answer reveals work to do.
- The repository has no issue tracker and the author has not asked for one. Ask before initialising one.

## 3. Inputs and prerequisites

- A git repository with a remote `{remote}` reachable over HTTPS (`https://{git_host}/{org}/{repo}.git`). No SSH remotes.
- An issue tracker that the agent can write to from the shell. This SOP uses `bd` (beads) backed by a Dolt database, with a Dolt remote for sync.
- A fixed actor name `{actor}` for every agent write to the tracker.
- The project's quality gates: test command(s), linters, build, pre-flight checkers `{gate_commands}`.
- A session scratchpad directory `{scratchpad}` outside the repository.
- The author's standing rules (commit format, wording, forbidden words), stored as tracker memories.
- Generated files kept out of git: before the first commit, list the tracker's export files (for example `.beads/*.jsonl`) and hook or agent log paths (for example `.claude/logs/`) in `.gitignore`. If they are already tracked, untrack them with `git rm --cached {path}` and commit that together with the `.gitignore` change. Check: `git ls-files {path}` prints nothing.

## 4. Roles and tools

| Role | Does | Does not |
|---|---|---|
| Author (human) | Sets rules, approves merges and pushes to shared branches, decides priorities. | Run the procedure steps. |
| Controller (main agent session) | Creates, claims, notes and closes issues; stores author rules with `bd remember`; commits; runs gates; pulls, pushes, syncs the tracker; removes merged worktrees; cleans stashes; writes the hand-off. | Add AI attribution anywhere; write memory files; leave work unpushed. |
| Sub-agent | Works one claimed issue in its own worktree; commits to its own branch with plain messages; reports leftover work in its report. | Push, merge, close issues it did not own, set tracker environment variables. |

Tools, by exact name:
- Tracker: `bd create`, `bd prime`, `bd update {id} --claim`, `bd update {id} --notes`, `bd update {id} --append-notes`, `bd close {id} --reason`, `bd list`, `bd ready`, `bd show`, `bd remember`, `bd memories`, `bd recall`, `bd forget`, `bd dolt commit`, `bd dolt pull`, `bd dolt push`, `bd dolt remote list`. Pass `--actor {actor}` on writes.
- Git: `git status`, `git add {paths}`, `git commit`, `git pull --rebase=merges`, `git push`, `git fetch --prune`, `git push {remote} --delete {branch}`, `git worktree list`, `git worktree remove`, `git branch -d`, `git cherry`, `git stash list`, `git stash show`, `git stash drop`.
- Forge: the forge's MCP server, or its official CLI with a named login (`{forge_cli}`). Not `curl` or ad-hoc HTTP scripts.

## 5. Procedure

### 5.1 Start of session

1. **Check the environment.** Confirm the tracker binary and version the repository expects: `command -v bd` and `bd version`. A shell that is not a login shell (a session started from another operating system, a hook, a cron job) can put a stale copy first on `PATH`; an old binary fails on the current schema with an error about unknown table fields. Confirm the tool manager and its MCP server are present (`{tool_manager} --version`; SOP-12 section 3). Check: `bd version` prints the version recorded in section 9; if not, call the tracker by its full path for the rest of the session.
2. **Orient.** Run `bd prime` first; it prints the tracker workflow context and injects the stored memories. Then run `bd ready` and `bd list --status in_progress`. Check: you have read the full `bd prime` output (if the host truncates it, read the persisted output), and you know which issues are open and which are already claimed.
3. **Load the author's rules.** Run `bd memories`; `bd recall {key}` for any rule that applies to today's work. Check: every rule that touches the planned output (wording, commits, naming, remotes) has been read in full.
4. **Check the workspace.** `git status`, `git stash list`, `git worktree list`. Check: you can say what each uncommitted change, stash entry and worktree is for. Do not touch what you cannot account for; ask.

### 5.2 For each work item

5. **Take the owner's notes verbatim.** A message from the author that arrives while work runs is product-owner input (SOP-12 step 1). Put the words unedited in a comment on the issue they concern, `bd comment {id} "Author {date} (verbatim): \"{text}\"" --actor {actor}`, before acting on them or paraphrasing them anywhere. Check: `bd show {id}` prints the author's words.
6. **One issue per work item.** `bd create "{title}" --actor {actor}` (type and priority as fits). Check: `bd show {id}` shows it. Do not use TODO lists, task tools or markdown checklists in place of issues.
7. **Claim it before working.** `bd update {id} --claim --actor {actor}`. Check: `bd show {id}` shows status IN_PROGRESS and `Assignee: {actor}`. (`bd list` does not print the assignee.)
8. **Link the workspace.** `bd update {id} --notes "Worktree {worktree_path} ({branch})" --actor {actor}`. Use `--notes` only this once: it replaces existing notes. Every later note on the issue uses `--append-notes`. Check: `bd show {id}` notes name the branch.
9. **Verify present-day facts with a tool before stating them.** Model ids, library and tool versions, API names, people's names and roles, prices, dates: check with a command, file read, search or MCP call first. Check: each such fact in the output has a tool result behind it in this session.
10. **Keep scratch files out of the repo.** Briefs, intermediate data, test scripts and downloads go in `{scratchpad}`. Check: `git status` shows no untracked scratch files.
11. **Commit with a plain message.** Stage by path (`git add {paths}`), never `git add -A` on a tree with logs or exports. Write a subject that says what changed. Check before every commit: `git diff --cached --stat` lists only intended files, and the message has no AI attribution line (no `Co-Authored-By:` naming an AI, no "Generated with", no session id or badge).
12. **Record author rules as they arrive.** When the author states a rule that should outlive the session: `bd remember "{rule}" --key {key} --actor {actor}`. Check: `bd memories` lists it. Do not write `MEMORY.md` or other memory files.
13. **File leftovers immediately.** Any bug, follow-up or blocker found along the way: `bd create` it now, link it with `bd dep` or a note. Check: nothing found during the work exists only in chat.
14. **Close on merge, with a reason.** After the branch is merged to `{main}`, the gates pass and the merge is pushed (SOP-01 steps 11 to 13): `bd close {id} --reason "Merged to {main} ({branch}), {gate_result}" --actor {actor}`. Check: `bd show {id}` shows CLOSED with the reason. Then remove the worktree and its branch right away: `git worktree remove {worktree_path}`, `git branch -d {branch}`, and, if the branch was pushed, `git push {remote} --delete {branch}`. Check: `git worktree list` no longer shows `{worktree_path}`.

### 5.3 Session close

15. **File remaining work as issues.** Every unfinished item, open question and known defect becomes an issue (step 13). Check: `bd list --status open` covers it.
16. **Run the quality gates** if anything changed: `{gate_commands}`. Check: all pass, or each failure has its own issue.
17. **Update statuses.** Close finished issues with reasons; leave unfinished ones `in_progress` with `bd update {id} --append-notes "{date}: {where it stands}" --actor {actor}`. Do not use `--notes` here; it would delete the worktree link from step 8. Check: no issue is `in_progress` without a current note.
18. **Sync the tracker.** `bd dolt commit`, `bd dolt pull`, `bd dolt push`. Check: each exits 0.
19. **Push the code.** `git pull --rebase=merges`, then `git push`, then `git status`. Use `--rebase=merges`, not a plain `--rebase`: a plain rebase flattens any local `--no-ff` merge commit (SOP-01 7.9). Check: `git status` reports "Your branch is up to date with '{remote}/{main}'". If the push fails, resolve and retry until it succeeds; the session is not done before this.
20. **Sweep merged worktrees and branches.** Step 14 removes each one at merge; this step catches anything missed. For each remaining worktree and branch: `git cherry {main} {branch}`; no `+` lines means merged. This test holds for merge and rebase merges only. On a project that squash-merges, `git cherry` and `git branch -d` report every merged branch as unmerged; check the forge's PR state instead, or confirm `git diff {main}...{branch}` shows nothing missing from `{main}`, then delete with `git branch -D {branch}`. Remove merged ones with `git worktree remove {path}` and `git branch -d {branch}`. Then prune remote branches: `git fetch --prune` (or `git remote prune {remote}`) to drop stale remote-tracking refs, and `git push {remote} --delete {branch}` for each merged branch still on the remote. Check: `git worktree list` shows only the main checkout and worktrees still in use, and `git branch -r --merged {remote}/{main}` lists no work branches.
21. **Clean stashes.** `git stash list`; for each entry, `git stash show --stat stash@{n}` and confirm its changes are on `{main}` before `git stash drop stash@{n}`. Check: the list is empty, or each remaining entry is named in the hand-off.
22. **Hand off.** Write a short hand-off: what landed (commit hashes), what is open (issue ids), anything left in the workspace and why; when the author is the product owner, end with the agreed status line (SOP-12 section 8.4). Check: the next session can start from `bd ready` and the hand-off alone.

## 6. Acceptance checks

The session is closed when all of these hold:

```bash
# Code pushed
git status                       # "Your branch is up to date with '{remote}/{main}'", nothing to commit
git log {remote}/{main}..{main}  # empty

# No AI attribution in this session's commits
git log {start_commit}..{main} --format='%B' | grep -ciE 'co-authored-by|generated with|claude-session'   # 0

# Tracker
bd list --status in_progress     # only items deliberately left open, each with a current note
bd list --status open            # includes every leftover filed this session
bd dolt push                     # exits 0

# Workspace
git worktree list                # main checkout plus worktrees still in use
git fetch --prune && git branch -r --merged {remote}/{main}   # no merged work branches left on the remote
git ls-files {export_paths} {log_paths}                        # empty: exports and logs are untracked
git stash list                   # empty, or each entry named in the hand-off
git status --porcelain           # no scratch files, no staged logs or tracker exports
```

## 7. Failure modes and recovery

7.1 **The documented sync command does not exist.** A tracker version drops or renames a command that docs and instructions still mention (`bd sync` returns "unknown command"). Recovery: `bd --help` and `bd dolt --help`; use `bd dolt commit`, `bd dolt pull`, `bd dolt push`. Prevention: check the tool's own help for the installed version before writing it into an SOP or brief.

7.2 **Tracker writes carry the wrong actor.** An issue shows the git user (or an empty actor) as owner instead of `{actor}`. Recovery: pass `--actor {actor}` on every write from then on; do not rewrite history. Prevention: put `--actor {actor}` in every command template; do not set the tracker's actor environment variable, because it silently applies to every later process. Without either, the tracker may fall back to the git user name.

7.3 **AI attribution slips into a commit.** A harness default or template adds a trailer. Recovery, before push: `git commit --amend` (last commit) or an interactive-free rewrite of the unpushed range, removing the line. After push, ask the author before rewriting shared history. Prevention: step 11 check on every commit; acceptance grep in section 6.

7.4 **Tracker exports or logs get committed.** A tracked JSONL export or a hook log changes on every run and rides along with `git add -A`. Recovery: `git restore --staged {path}` before commit; if already committed and unpushed, amend. Prevention: list exports and logs in `.gitignore` before the first commit, and untrack any that are already tracked (`git rm --cached {path}`), as in section 3; stage by path (step 11).

7.5 **A forge call is blocked by a hook.** A PreToolUse hook refuses `curl` or piped scripts against the forge API. Recovery: use the forge's MCP server or its official CLI with a named login (`{forge_cli}`). Do not work around the hook.

7.6 **TLS verification fails against the forge.** Recovery: confirm the served certificate (`openssl s_client`), have the host owner fix it, and track the temporary workaround (disabled verification) as its own issue so it is removed when the cert is fixed. Do not switch the remote to SSH.

7.7 **Push rejected.** Recovery: `git pull --rebase=merges`, resolve conflicts, re-run the gates, `git push`. Repeat until `git status` is up to date.

7.7a **Push of a large payload fails.** A push carrying media or many generated files ends with `RPC failed`, `HTTP 408`, a reset connection, or a `504` from the forge's proxy, although small pushes work. Recovery: `git config http.postBuffer 524288000` and `git config http.version HTTP/1.1` in the repository (not globally), then push again; a `504` from the proxy after the upload finished usually means the forge took the push, so `git fetch` and compare before pushing again. If it still fails, push in parts (`git push {remote} {old_commit}:refs/heads/{main}` for an earlier commit, then the rest). Prevention: keep rendered media small in the repository (re-encode game copies, SOP-04 step 10) and push after each merge rather than once a day.

7.7b **Wrong tracker binary on `PATH`.** `bd` fails with an error naming a table with unknown fields, or prints an older version than section 9 records. A non-login shell put a stale copy first. Recovery: call the tracker by the full path of the installed version for the session; remove or rename the stale copy when the author agrees. Prevention: step 1.

7.8 **A stash outlives the session.** An autostash or a "WIP" stash stays in `git stash list` long after its work landed. Recovery: `git stash show --stat` each entry, confirm its changes are on `{main}` (`git log -p {main} -- {file}`), then drop it. Prevention: step 21 at every close.

7.9 **A stated fact is out of date.** A model id, version or name from training data is wrong today. Recovery: check with a tool, correct the file, commit the fix. Prevention: step 9.

7.10 **A status line reads as a brush-off.** The owner objects to a hand-off or status sentence (for example one that says nothing needs them). Recovery: use the agreed line (SOP-12 section 8.4) and store the rule as a tracker memory (step 12). Prevention: step 22.

## 8. Artifacts and templates

### 8.1 Issue lifecycle

```
bd create "{title}" -t {type} -p {priority} --actor {actor}
bd update {id} --claim --actor {actor}
bd update {id} --notes "Worktree {worktree_path} ({branch})" --actor {actor}
# ... work, commit on {branch}, merge to {main}, gates pass ...
bd close {id} --reason "Merged to {main} ({branch}), {gate_result}" --actor {actor}
# remove the worktree and branch at once (step 14)
git worktree remove {worktree_path} && git branch -d {branch}
# later status notes: append, never replace
bd update {id} --append-notes "{date}: {status}" --actor {actor}
```

### 8.2 Memory entry

```
bd remember "User instruction: {rule, one or two sentences, in the author's terms}" --key {kebab-key} --actor {actor}
```

One rule per key. Start with who set it ("User instruction:", "Author {date}:"). Running `bd remember` again with the same `--key` updates the rule in place; `bd forget {key}` removes it.

### 8.3 Commit message

```
{area}: {what changed, in plain words}

{optional body: why, and anything a reviewer needs; no attribution lines}
```

### 8.4 Session close script (controller)

```bash
{gate_commands}
bd dolt commit && bd dolt pull && bd dolt push
git pull --rebase=merges && git push && git status
git fetch --prune
git worktree list
# merge or rebase merges only; on squash-merge projects check PR state or git diff {main}...{branch}
for b in $(git branch --format='%(refname:short)' --list '{branch_prefix}-*'); do
  echo "$b: $(git cherry {main} "$b" | grep -c '^+') unmerged"
done
git branch -r --merged {remote}/{main}
git stash list
```

### 8.5 Hand-off

```
Landed: {short_hash} {subject}; {short_hash} {subject}
Closed: {id}, {id}
Open: {id} ({one line}), {id} ({one line})
Left in workspace: {worktree or stash}, because {reason}
```

## 9. Reference implementation in persistint

- Tracker binaries: the repository uses the Homebrew beads, `/home/linuxbrew/.linuxbrew/bin/bd` (`bd version 1.2.2 (Homebrew)`). A stale `/home/brett/.local/bin/bd` (`bd version 1.0.4`, built 2026-05-09) is still on disk; a non-login shell started from Windows (`wsl.exe`) puts `~/.local/bin` first, and that binary fails on the current schema with `table local_metadata: Error 1105: table has unknown fields`. Rule (author, 2026-10-24): from any non-login shell call `/home/linuxbrew/.linuxbrew/bin/bd`.
- Tracker: beads `bd version 1.2.2 (Homebrew)`, Dolt backend in embedded mode (`.beads/metadata.json`: `"backend": "dolt"`, `"dolt_mode": "embedded"`, database `persistint_game`). Issue prefix `persistint-game-`. Initialised in `16ad549` ("bd init: initialize beads issue tracking"), which also installed the hooks in `.beads/hooks/` (post-checkout, post-merge, pre-commit, pre-push, prepare-commit-msg; "BEADS INTEGRATION v1.2.2").
- Dolt remote (`bd dolt remote list`): `origin git+https://{forge_host}/{org}/{repo}.git`, the same forge repository as the git remote. `bd sync` returns `Error: unknown command "sync" for "bd"`; `bd dolt --help` lists `commit`, `pull`, `push`, `remote`.
- Actor: issues written by the agent show `Owner: {agent_actor}` (for example `persistint-game-cqz`). `persistint-game-d6d` shows `Owner: Brett Whitty:`, which matches the git user name. `bd --help` documents the `--actor` default as `$BEADS_ACTOR, git user.name, $USER`; `.beads/config.yaml` leaves `actor` unset. The brief names the variable not to set as `BD_ACTOR`; the installed bd reads `BEADS_ACTOR` (and `.beads/config.yaml` says "BD_* prefix" for settings in general). Set neither; pass `--actor {agent_actor}`.
- Close reasons: `persistint-game-cqz` "Merged to main (sys-exits incl. sys-ui-scale), all 10 test files PASS", with the note "Worktree ../persistint-game-wt-exits (sys-exits) ...". Leftover filed during the same work: `persistint-game-zk2` (flaky `test_island_maps`), fixed in `e0574a1`.
- Memories: `bd memories` lists 77 entries at 2026-10-24 (29 on 2026-10-23), including `gitea-https-not-ssh`, `gitea-ops-mcp-or-tea`, `scratch-outside-repo`, `worktree-cleanup`, `design-vocabulary`, `no-email-to-outside-services`, `product-owner-standup`, `sprint-and-versioning`, `team-structure-windows-peer`. There is no `MEMORY.md` in the repo.
- Verbatim author notes as comments: `persistint-game-qqx` (four notes), `j89`, `xrc`, `fwn`, each headed "Author 2026-10-24 (verbatim)".
- Large pushes: the repository has `http.postBuffer 524288000` and `http.version HTTP/1.1` set (`git config --get`), after pushes carrying rendered music and voice clips failed against the forge on 2026-10-24 and a `504` from its proxy had to be retried.
- Versioning and labels: SOP-11; `tools/version.py`, `CHANGELOG.md`, tags `v0.2.0` and `v0.2.1`.
- Forge: Gitea, reached through its MCP server or the forge CLI with the agent's login; a pre-tool hook blocks ad-hoc HTTP clients against it.
- Commit authorship rule: `the user-level CLAUDE.md` ("Commit authorship — ABSOLUTE RULE"). `git log --all --format='%B' | grep -ciE "co-authored|generated with"` returns 0 at `93870ee`.
- Session-close steps: `the user-level CLAUDE.md` "Session Completion" (file issues, gates, statuses, `git pull --rebase`, `git push`, `git status`, clean stashes and branches, hand off). CLAUDE.md says plain `git pull --rebase`; this SOP uses `git pull --rebase=merges` so that `--no-ff` merges from SOP-01 survive the pull. The two agree when there is no local merge commit.
- Repo and brief disagree on exports and logs: the brief says not to commit `.beads/*.jsonl` exports or `.claude/logs`. In the repo, `.beads/interactions.jsonl` is tracked (since `16ad549`) and `.claude/logs/actually-im-the-ahole-violations.jsonl` is tracked (since `0d87e37`). Both show as modified in the main checkout. Until they are untracked, the rule in practice is: never stage their changes (step 9). Untracking them (`git rm --cached` plus `.gitignore`, section 3) is not done; no issue filed (`bd search untrack` finds none).
- Worktree cleanup rule: memory `worktree-cleanup` ("Remove each agent worktree (../persistint-game-wt-*) and its branch right after it is merged into main"), which step 14 implements.
- Workspace state when this SOP was written (main checkout): `git stash list` shows `stash@{0}: On main: Teleport auto-stash` and `stash@{1}: WIP on main: 998da48 ...`; `git worktree list` shows eight worktrees besides the main checkout. Step 20 and 21 cleanup has not been applied to all of them.
- The SOP's own issue, `persistint-game-f8f` ("sops/: methodological SOPs ..."), was open and not claimed in `bd list` at the time of writing, although work on it had started in `../persistint-game-wt-sops` (branch `sys-sops`). Step 7 was not applied.
- Not done; no issue filed: a session-close script in `tools/` implementing section 8.4, and a commit-msg check that rejects attribution lines. Neither exists, and `bd search session-close` and `bd search commit-msg` find no issue for either.

## 10. Lessons learned

- `bd sync`, named in older beads instructions, does not exist in bd 1.2.2; the Dolt subcommands do the sync.
- The tracker falls back to the git user name when no actor is given, so ownership in the tracker is only reliable with `--actor` on every write.
- A pre-tool hook blocks ad-hoc HTTP clients against the forge; the Gitea MCP server and `{forge_cli}` (forge CLI with the agent's login) work.
- A TLS workaround on the forge was tracked as its own issue and removed once the renewed cert was served.
- Stashes and worktrees outlived their work in this repo; cleanup belongs in every session close, not later.
- Tracked JSONL exports and hook logs show as modified in the main checkout; staging by path keeps them out of commits. (`.beads/interactions.jsonl`, `.beads/issues.jsonl` and `.claude/logs/` were untracked and ignored on 2026-10-24.)
- Two beads binaries on one machine cost a session: a shell started from Windows ran the May build, which cannot read the current schema. The environment check (step 1) is the first step of every session now.
- Pushes carrying media failed until the HTTP buffer and version were set in the repository config; small pushes had hidden the problem for a day.
- The author's notes during work are input. One status line that could be read as "stop sending notes" was rejected; the agreed wording is in SOP-12.
