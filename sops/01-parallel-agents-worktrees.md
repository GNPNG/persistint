# SOP-01: Parallel sub-agent development with git worktrees

Status: active
Owner: Brett Whitty
Applies to: any project in a git repository where several coding agents work at the same time
Last reviewed: 2026-10-23
Related SOPs: SOP-07 (07-playtest-bug-triage.md: root-causing a flaky test instead of retrying it); SOP-08 (08-session-hygiene-tracking.md: issue notes, close reasons, worktree and stash cleanup at session close)

## 1. Purpose

Run several coding sub-agents at once, each on one independent system, without them overwriting, stashing or merging each other's work. Each agent gets its own git worktree and branch. One controller merges, tests and pushes, one branch at a time.

## 2. When to use / when not to

Use when:
- The work splits into two or more systems that touch mostly different files.
- Each system can be checked by its own automated test.
- One person (the author) is available to approve merges and pushes.

Do not use when:
- The tasks edit the same files (one screen or level file, one data file, one config). Run them one after another, or give one agent ownership of the shared file.
- The task is small enough for one agent to finish faster than writing a brief.
- There is no automated test suite. Build that first; without it the controller cannot check an agent's claims.

## 3. Inputs and prerequisites

- A git repository with a clean `{main}` branch that passes the full test suite.
- A remote that the controller can push to.
- A test command `{test_cmd} {test_file}` for each test file, runnable headless (no editor, no window), that exits non-zero when a check fails.
- A setup command `{setup_cmd}` that makes a fresh checkout ready to test (install dependencies, build, or run the engine's asset import), and the list of tracked files it rewrites (`{config_file}`).
- An issue tracker that agents and controller can both write to (this SOP uses `bd`, beads).
- A written brief (section 8.2) saved where every sub-agent can read it.
- A list of work items, each with: a system name `{name}`, its goal, the files it owns, and the test file it adds.

## 4. Roles and tools

| Role | Does | Does not |
|---|---|---|
| Author (human) | Sets goals, approves each merge and push, reviews the result. | |
| Controller (main agent session) | Splits work, writes the brief, creates and prepares worktrees and branches, creates and assigns issues, dispatches sub-agents, merges one branch at a time, runs the full suite, pushes, removes worktrees and branches, closes issues. | Edit system code that a sub-agent owns while that agent runs. |
| Sub-agent (one per system) | Works only inside its own worktree, commits to its own branch, adds its own test file, reports in five lines. | Push, merge, rebase onto `{main}`, edit the shared main checkout, edit files another agent owns. |

Tools, by exact name:
- `git worktree add -b`, `git worktree list`, `git worktree remove`, `git branch -d`, `git branch -D`, `git merge --no-ff`, `git fetch`, `git pull --rebase=merges`, `git reset --hard ORIG_HEAD`, `git revert -m 1`, `git cherry`, `git stash list`.
- `bd create`, `bd update --claim`, `bd update --notes`, `bd close`, `bd list`, each write with `--actor {actor}` (SOP-08).
- The project's setup command `{setup_cmd}` and headless test runner `{test_cmd}`. Example (Godot): setup `godot --headless --path {project_dir} --import`; test `godot --headless --path {project_dir} -s {test_file}`.
- The agent harness's sub-agent launcher. Do not rely on a harness worktree hook; create worktrees by hand (section 7.1).

## 5. Procedure

1. **Split the work.** List the systems. For each, name the files it will create or edit. Check: no file appears under two systems, except files marked read-only for everyone.
2. **Write the brief.** Fill in the template in section 8.2: author rules, file ownership, read-only shared files, test rules, commit rules, report format. Check: every shared file (global singletons, config, shared data) is either owned by exactly one agent or marked read-only.
3. **Confirm `{main}` is green.** In the main checkout, run `git pull --ff-only`, then the full test suite (section 6). Check: every test passes. Do not start agents on a red base.
4. **Create one issue per system.** `bd create "{goal}" --actor {actor}`, then `bd update {id} --claim --actor {actor}` and `bd update {id} --notes "Worktree ../{repo}-wt-{name} ({branch_prefix}-{name})" --actor {actor}` (`--notes` replaces existing notes; use it only here, and `--append-notes` afterwards). Check: `bd list --status in_progress` shows each issue with the worktree in its notes.
5. **Create one worktree per system.** From the main checkout:
   `git worktree add -b {branch_prefix}-{name} ../{repo}-wt-{name} {main}`
   Check: `git worktree list` shows the new path on the new branch at the current `{main}` commit.
6. **Prepare each worktree.** A new worktree has no build output, import cache or installed dependencies. In it, run `{setup_cmd}`, then `git checkout -- {config_file}` for each tracked file the setup rewrote, then run the golden test. Check: `git status` in the worktree is clean and the golden test passes there. Do not dispatch an agent into a worktree that fails this check.
7. **Dispatch the sub-agents.** Give each agent: the absolute worktree path, the issue id, its goal, and the brief. Check: the prompt names the worktree path and says "work only here".
8. **Wait for reports.** Each agent ends with a five-line report (section 8.3). Treat each report as a claim, not a result.
9. **Review one branch.** In the main checkout: `git log --oneline {main}..{branch_prefix}-{name}` and `git diff --stat {main}...{branch_prefix}-{name}`. Check: the diff touches only files that agent owns, plus its new test file. If it touches someone else's files or a read-only file, send it back.
10. **Get approval.** Show the author the summary and diff stat. Check: the author has approved this merge and push.
11. **Merge that one branch.** `git merge --no-ff {branch_prefix}-{name}`. Resolve conflicts in the main checkout. Check: `git status` is clean after the merge commit.
12. **Run the full suite on the merge result.** Every test file, not only the new one (section 6). Restore any tracked file the setup or test run rewrote (`git checkout -- {config_file}`). Check: every test passes. If one fails, fix it on `{main}`, or undo the merge before going on:
    - Not yet pushed: `git reset --hard ORIG_HEAD` right after the merge (or `git reset --hard HEAD^1` while the merge commit is still `HEAD`).
    - Already pushed: `git revert -m 1 {merge_commit}`, run the suite, push the revert.
13. **Push.** `git fetch`, then `git log --oneline HEAD..origin/{main}`. Check: the log is empty, then `git push`. If it is not empty, the remote moved: run `git pull --rebase=merges` (a plain `git pull --rebase` flattens or drops the merge commit), run step 12 again, then push. Check: `git status` reports up to date with the remote.
14. **Remove the worktree and branch now.** `git worktree remove ../{repo}-wt-{name}`, then `git branch -d {branch_prefix}-{name}`. If the branch reached `{main}` by rebase or cherry-pick, `-d` refuses because the hashes differ; once `git cherry {main} {branch_prefix}-{name}` shows no `+` lines, use `git branch -D {branch_prefix}-{name}`. Check: `git worktree list` and `git branch --list '{branch_prefix}-{name}'` no longer show it. Do not defer this step.
15. **Close the issue.** `bd close {id} --reason "Merged to {main} ({branch_prefix}-{name}), all {N} test files PASS" --actor {actor}`. Check: `bd show {id}` shows it closed.
16. **Repeat steps 9 to 15 for the next branch.** Before merging a branch that was rebased or cherry-picked elsewhere, run `git cherry {main} {branch}`; lines starting with `-` are already on `{main}`, lines starting with `+` are not. If there are no `+` lines, skip the merge and go to step 14.

## 6. Acceptance checks

The run is done when all of these hold:

```bash
# Every system branch from this run is on main
for b in {branch_list}; do echo "$b: $(git cherry {main} $b | grep -c '^+') unmerged"; done   # all 0

# No leftover worktrees or branches from this run
git worktree list                      # main checkout, plus only worktrees still in use, each named
git branch --list '{branch_prefix}-*'  # only the branches of those in-use worktrees, each named

# Full suite passes on main. Each test must exit non-zero on failure;
# if the runner does not, grep its output for the failure marker instead.
for t in {tests_dir}/{test_glob} {tests_dir}/{golden_test}; do
  {test_cmd} "$t" || echo "FAIL $t"
done                                   # no FAIL lines
git status --short                     # empty (tracked config restored)

# Pushed
git status        # "Your branch is up to date with 'origin/{main}'"

# Issues closed; no stray stashes
bd list --status open,in_progress      # none of this run's issue ids
git stash list    # empty, or every entry accounted for
```

Example (Godot) test loop, with `{test_cmd}` as `godot --headless --path {project_dir} -s` and test paths relative to `{project_dir}`:

```bash
for t in {project_dir}/tests/test_*.gd {project_dir}/tests/{golden_test}.gd; do
  godot --headless --path {project_dir} -s "${t#{project_dir}/}" || echo "FAIL $t"
done
```

## 7. Failure modes and recovery

7.1 **Harness worktree hook fails.** The agent launcher's built-in worktree creation did not work. Recovery: create worktrees by hand with `git worktree add -b` (step 5) and pass the absolute path to the agent.

7.2 **A sub-agent works in the shared main checkout.** Another process in that checkout stashes or overwrites its uncommitted files (for example an autostash pull or a session switch). Recovery:
1. `git stash list` and `git show --stat stash@{n}` to find the entry holding the work.
2. Create and prepare a new worktree and branch for that system (steps 5 and 6).
3. In it, `git stash apply stash@{n}` (or check out the stash's files), commit, and continue from step 9.
4. Drop the stash only after the branch is merged and tests pass.
Prevention: the brief forbids edits to the main checkout; only the controller works there.

7.3 **A sub-agent asked to merge or push is refused.** An automated permission check may block a sub-agent from pushing to the shared `{main}`. Recovery: do not try to route around it. The controller does merges and pushes itself, after author approval (steps 10 to 13).

7.4 **Stale worktrees pile up.** Merged branches keep their worktrees in the parent directory, and later agents or people open the wrong copy. Recovery: `git worktree list`, then for each branch with `git cherry {main} {branch}` showing no `+` lines, `git worktree remove` and `git branch -d` (or `git branch -D` when `-d` refuses a rebased or cherry-picked branch). Prevention: step 14 runs right after each push.

7.5 **A rebased branch looks unmerged.** `git branch --merged` does not list it because its commit hashes changed. Recovery: `git cherry {main} {branch}`; no `+` lines means its changes are already on `{main}`.

7.6 **A setup or build step rewrites a tracked file.** Running `{setup_cmd}` or a test changes a tracked config file, and the change ends up in a commit. Recovery: `git checkout -- {config_file}` after each setup or test run and before each commit. Put this rule in the brief.

7.7 **A test passes in the agent's report but fails after merge.** Two branches each pass alone and fail together, or a test is timing-dependent (it queries asynchronous work before that work has finished) and fails only on some runs. Recovery: the controller re-runs the full suite after every merge (step 12); a flaky test gets its own issue, a failure count over repeated runs, and a fix that waits for the condition instead of a fixed delay (SOP-07).

7.8 **Two agents edit one shared file.** Recovery: keep one side, re-apply the other agent's change by hand in the main checkout, re-run the suite. Prevention: step 1 ownership check; one owner per shared file.

7.9 **A pull after the merge flattens it.** `git pull --rebase` after a local `git merge --no-ff` drops the merge commit and replays the branch's commits when the remote has moved. Recovery: if not yet pushed, `git reset --hard ORIG_HEAD` (or reflog to the merge commit), then follow step 13 with `git pull --rebase=merges`. Prevention: step 13.

## 8. Artifacts and templates

### 8.1 Layout

```
{parent_dir}/
  {repo}/                       main checkout, branch {main}; controller only
  {repo}-wt-{name_a}/           worktree, branch {branch_prefix}-{name_a}; agent A only
  {repo}-wt-{name_b}/           worktree, branch {branch_prefix}-{name_b}; agent B only
{scratchpad}/agent-brief.md     shared brief, read by every agent
{repo}/{tests_dir}/test_{name}.{ext}   one new test file per system
```

### 8.2 Brief template (`agent-brief.md`)

```markdown
# Agent brief: {project}

## Author rules
- {style and wording rules the author has set}
- No AI attribution in commits, docs or any other output.

## Where you work
- Only in your worktree: {absolute path}. Never edit {absolute path of main checkout}.
- Commit to your branch. Never push, merge, rebase onto {main}, or pull.

## File ownership
- {file or dir}: owned by {name} only.
- {file or dir}: owned by {name} only.
- Read-only for everyone: {shared singletons / globals}, {config file}, {golden test file}.
- Need a change in a file you do not own? Say so in your report; do not make it.

## Tests
- Add tests in a NEW file {tests_dir}/test_{name}.{ext}. Do not edit {golden test file}.
- Run your test and {golden test file} with {test_cmd} before your last commit.
- After {setup_cmd} or a test run, restore {config_file}: git checkout -- {config_file}

## Report (exactly five lines)
1. Branch and last commit hash
2. What was built
3. Files touched
4. Test command and result
5. Open issues or requests for the controller
```

### 8.3 Sub-agent report example

```
1. {branch_prefix}-{name} @ {short_hash}
2. {one-line description of the system}
3. {paths}
4. {test_cmd} {tests_dir}/test_{name}.{ext}: PASS ({k} checks)
5. Needs {owner} to add {key} to {shared file}
```

### 8.4 Issue note

```
Worktree ../{repo}-wt-{name} ({branch_prefix}-{name})
```

Close reason: `Merged to {main} ({branch_prefix}-{name}), all {N} test files PASS`.

## 9. Reference implementation in persistint

- Engine and tests: Godot project in `project/`. Golden test `project/tests/verify_slice.gd`; per-system tests `project/tests/test_*.gd` (at `93870ee`: calendar, chapters, exits, florida, hottest_chains, interview, island_maps, landing_crew, ruins). Each runs with `godot --headless --path project -s tests/{file}.gd`, as stated in its header comment, and ends with `quit(0 if _failures == 0 else 1)` (`test_landing_crew.gd` uses `quit(_failures)`), so the exit code carries the result.
- Setup: `godot --headless --path project --import` builds the `.godot/` import cache that a fresh worktree lacks; `project/project.godot` is restored after it.
- Shared, read-only autoloads (from `project/project.godot`): `WorldState`, `GameClock`, `Voice`, `SceneRouter`, `Cast`, `NameIt`, `DialogueManager`.
- Single-owner files named in the brief: `project/scenes/maps/village.tscn` and `project/scenes/maps/temple.tscn` (one agent only); `project/data/barks.json` (calendar agent only). `verify_slice.gd` is never edited; `project/project.godot` is restored after a headless `--import`.
- Worktrees: `../persistint-game-wt-{name}` on branches `sys-{name}`, made with `git worktree add -b` from `main`.
- Brief: `agent-brief.md` in the controller session's scratchpad (not in the repo; not found on disk when this SOP was written).
- Merges on `main` (2026-10-23): `f43adbf` sys-island-maps, `5a9802b` sys-florida, `500cae7` sys-chapters, `381f2c9` sys-zombies, `307313b` sys-exits (which itself merged sys-ui-scale in `f81af46`), `93870ee` sys-prompts.
- Issue tracking: beads issue `persistint-game-cqz` (Exits) carries the note "Worktree ../persistint-game-wt-exits (sys-exits)" and the close reason "Merged to main (sys-exits incl. sys-ui-scale), all 10 test files PASS". Flaky test filed as `persistint-game-zk2`. Its title blames the first run after a headless `--import`; its close reason gives the cause as Godot 4.6 navigation async iterations syncing maps on worker threads ("reproduced 2/8 runs, unrelated to import"). Fixed in `e0574a1`: `test_island_maps` now waits until the map returns the region's own polygon.
- Stash incident: `git stash list` in the main checkout still shows `stash@{0}: On main: Teleport auto-stash`. It holds `project/tests/test_exits.gd`, `project/tests/test_island_maps.gd`, `project/tests/_repro_exit.gd` and `.uid`, `.beads/interactions.jsonl`, `.beads/issues.jsonl` and `.claude/logs/actually-im-the-ahole-violations.jsonl`; the test work landed in `e0574a1`. The brief attributes the stash to `git pull --rebase --autostash`; the stash message reads "Teleport auto-stash", so the command that made it is not confirmed from the repo. It has not been dropped. `stash@{1}: WIP on main: 998da48 prompts/STYLE.md ...` also exists; it holds map, florida and ruins scene files plus `project/scripts/door.gd` and `map.gd`. The brief does not say where it came from, so it is not accounted for here and has not been dropped.
- Cleanup state when this SOP was written: `sys-quotes` and `sys-release` show 0 unmerged commits by `git cherry main`, but both branches still exist and both `../persistint-game-wt-quotes` and `../persistint-game-wt-release` are still worktrees. Step 14 has not been applied to them. Other worktrees (`sys-forbidden`, `sys-pony`, `sys-clone-voices`, `game-systems` with `+` lines; `sys-web-render`, `sys-sops` at `main`) are in use.
- Planned: a script that runs the full suite (`verify_slice.gd` plus every `tests/test_*.gd`) and restores `project.godot`; a script that lists and removes merged worktrees. Neither exists in `tools/` yet.

## 10. Lessons learned

- The harness worktree hook did not work in this environment; manual `git worktree add -b` did.
- An agent that worked in the shared main checkout lost its uncommitted work to another agent's stash; it was recovered from `git stash` into a new worktree. No agent edits the shared checkout.
- The harness permission check refused a sub-agent set up to merge and push to shared `main`. Merges and pushes stay with the controller, after the author approves.
- The author found 14 stale worktrees in the parent directory. Remove each worktree and branch right after its merge is pushed.
- Agent reports are claims. Only the controller's full-suite run after the merge counts.
- `git cherry main {branch}` tells whether a rebased branch has already landed when `git branch --merged` does not.
- A test that passed in an agent's report failed intermittently (2 of 8 runs) because Godot's navigation sync runs asynchronously (`persistint-game-zk2`). The fix waits for the condition instead of retrying (`e0574a1`). How the failure was first caught is not recorded.
