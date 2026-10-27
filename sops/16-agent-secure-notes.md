# SOP-16: Agent secure notes in a per-workspace encrypted folder

Status: draft
Owner: Brett Whitty
Applies to: any repository where agents keep working notes, audits or questions for the author
Last reviewed: 2026-10-27
Related SOPs: SOP-08 (08-session-hygiene-tracking.md: notes are committed by path under its commit rules)

## 1. Purpose

Give each agent workspace its own encrypted notes folder inside the repository, so working notes, audits and questions for the author are kept and versioned without ever appearing in public files, and without the agent holding the project's main encryption key.

## 2. When to use / when not to

Use when:
- An agent writes anything meant for the author or for itself rather than for the public: audits, checklists of open items, questions, research notes.
- The repository's main private folder (`{private_dir}`) is encrypted with a key the agent does not hold.

Do not use when:
- The content is public by design (README, site pages, SOPs, docs meant for readers). Public files carry finished, settled text only; no open questions, no speculation, no notes to the author.
- The content is task state: that goes in the tracker (SOP-08).

## 3. Inputs and prerequisites

- `git-crypt` and `gpg` on the agent's host.
- The agent's own GPG key (`{agent_gpg_fpr}`), secret key on the agent's host only.
- The agent's account password (`{agent_password}`), known to the author, stored encrypted in the agent's role env.
- A workspace identifier `{workspace_id}`: `{agent}-{host}-{machine_id8}`, where `{host}` is the host or container name (for an LXD container, the last segment of its ZFS dataset, `findmnt -no SOURCE /`) and `{machine_id8}` the first 8 characters of `/etc/machine-id`.

## 4. Roles and tools

| Role | Does | Does not |
|---|---|---|
| Author | Reads any agent's notes with `{agent_password}` and the folder name; decides what is settled. | Need the agent's GPG key. |
| Agent | Creates its key and folder once, writes notes there, keeps public files free of notes. | Write notes into public files; hold or ask for the main `{private_dir}` key. |

Tools: `git-crypt init -k`, `git-crypt add-gpg-user -k -n`, `git-crypt export-key -k`, `git-crypt unlock`, `gpg --symmetric`, `git show :{path}`.

## 5. Procedure

1. **Name the workspace.** Build `{workspace_id}` (section 3). Check: it contains only letters, digits and `-`.
2. **Create the key.** `git-crypt init -k {workspace_id}`. Check: `git config --get filter.git-crypt-{workspace_id}.clean` prints a command.
3. **Route the folder to the key.** Append to the repository's `.gitattributes`, after any `{private_dir}/**` rule so it takes precedence:
   `{private_dir}/agents/{workspace_id}/** filter=git-crypt-{workspace_id} diff=git-crypt-{workspace_id}`
   Check: `git check-attr filter -- {private_dir}/agents/{workspace_id}/x` prints `git-crypt-{workspace_id}`.
4. **Seal the key, factor one: the agent's GPG key.** `git-crypt add-gpg-user -k {workspace_id} -n --trusted {agent_gpg_fpr}` (`-n`: stage and commit yourself, by path). Check: `.git-crypt/keys/{workspace_id}/0/{agent_gpg_fpr}.gpg` exists.
5. **Seal the key, factor two: the password the author knows.** Export the key (`git-crypt export-key -k {workspace_id} {key_file}`, mode 0600, outside the repo) and write `.git-crypt/keys/{workspace_id}/passphrase.key.gpg` with `gpg --symmetric --cipher-algo AES256`, passphrase `{agent_password}:{workspace_id}`, fed on a file descriptor, never on the command line. Check: decrypting it with that passphrase reproduces `{key_file}` byte for byte, and a wrong passphrase fails.
6. **Write notes only inside the folder.** New files: create them there, then `git add {path}`. Moved files: `git mv` keeps the old plaintext blob, so after any move run `git rm -f --cached {path}` then `git add {path}`. Check before every commit: `git show :{path} | head -c 9` prints `GITCRYPT` for every staged file in the folder.
7. **Keep public files clean.** When a note leaves a public file, remove every reference to it from README, docs and site pages in the same commit.

## 6. Acceptance checks

```bash
git check-attr filter -- {private_dir}/agents/{workspace_id}/x      # git-crypt-{workspace_id}
for f in $(git ls-files {private_dir}/agents/{workspace_id}); do git show HEAD:"$f" | head -c 9; echo " $f"; done   # every line starts GITCRYPT
ls .git-crypt/keys/{workspace_id}/                                   # 0/{agent_gpg_fpr}.gpg and passphrase.key.gpg
```

## 7. Failure modes and recovery

7.1 **A note is staged in plaintext.** `git mv` or a missing `.gitattributes` rule bypasses the filter. Recovery before commit: `git rm -f --cached {path}`, fix the rule, `git add {path}`, re-check the header. After a push: treat as a leak; the history scrub needs the author.

7.2 **The repository is a partial or sparse clone.** `git-crypt add-gpg-user` without `-n` and `git-crypt status` touch every file and fetch missing blobs, which can stall on a slow forge. Use `-n` and check staged files individually (step 6).

7.3 **The agent's host is lost.** The GPG secret key goes with it; the author (or a new agent) unlocks with factor two: decrypt `passphrase.key.gpg` with `{agent_password}:{workspace_id}`, then `git-crypt unlock {decrypted_key_file}`.

## 8. Artifacts and templates

### 8.1 Author: reading an agent's notes

```bash
gpg -d .git-crypt/keys/{workspace_id}/passphrase.key.gpg > /tmp/{workspace_id}.key   # passphrase: {agent_password}:{workspace_id}
git-crypt unlock /tmp/{workspace_id}.key && shred -u /tmp/{workspace_id}.key
```

## 9. Reference implementation in persistint

- Workspace: claude-cli on LXD container `gemini-exec-host` (ZFS dataset `ssdpool/ROOT/lxd/containers/gemini-exec-host`), machine-id prefix `f2f8932c`: `{workspace_id}` = `claude-cli-gemini-exec-host-f2f8932c`.
- Folder: `dev/agents/claude-cli-gemini-exec-host-f2f8932c/`; `{private_dir}` is `dev/`, whose own key the agent does not hold.
- First note moved in: the release checklist audit, formerly the public `docs/RELEASE_CHECKLIST.md`; its legal commentary and open questions also left `README.md`, `docs/PROMO_SITE_PLAN.md` and the site's citations page.

## 10. Lessons learned

- `git mv` into an encrypted folder staged the plaintext blob; caught by the step 6 header check before commit.
- On a partial clone, `git-crypt add-gpg-user` (auto-commit) and `git-crypt status` stalled fetching unrelated blobs; `-n` plus per-file checks avoid it.
