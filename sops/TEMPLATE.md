# SOP-NN: {Title}

Status: {draft | active}
Owner: Brett Whitty
Applies to: {any project | game projects | ...}
Last reviewed: {YYYY-MM-DD}
Related SOPs: SOP-NN (NN-slug.md: {how they connect}); SOP-NN (NN-slug.md: {how they connect})

<!--
File: sops/NN-slug.md (Markdown).
Sections 1-8 are project-agnostic: use {placeholders}, no project names, paths or commits.
Project specifics go only in sections 9 and 10.
Style: plain, direct, imperative. No marketing language.
Related SOPs must be reciprocal: add this SOP to the Related SOPs line of each SOP listed above.
Delete this comment when the SOP is filled in.
-->

## 1. Purpose

{Two or three lines: what this procedure produces and why it exists.}

## 2. When to use / when not to

Use when:
- {situation}
- {situation}

Do not use when:
- {situation}; {what to do instead}
- {situation}; {what to do instead}

## 3. Inputs and prerequisites

- {input or prerequisite, with placeholder name, e.g. `{test_cmd}`: headless test command that exits non-zero on failure}
- {input or prerequisite}

## 4. Roles and tools

| Role | Does | Does not |
|---|---|---|
| Author (human) | {decisions and approvals} | {what the author is not asked to do} |
| Controller agent | {steps it owns} | {what it never does} |
| Sub-agents | {scoped work, if any} | {limits} |

Tools, by exact name:
- {tool or command, e.g. `git worktree add -b`}
- {tool or command}

## 5. Procedure

1. **{Imperative step title}.** {What to do, with exact commands.}
   Check: {how to confirm the step worked}.
2. **{Imperative step title}.** {What to do.}
   Check: {how to confirm}.

## 6. Acceptance checks

The work is done when all of these hold:

```bash
{command}   # expected result
{command}   # expected result
```

- {check that needs reading rather than a command}

## 7. Failure modes and recovery

| Failure | How it shows | Recovery |
|---|---|---|
| {what goes wrong} | {symptom or error text} | {steps to recover; how to prevent it} |

## 8. Artifacts and templates

Layout:

```
{dir}/
  {file}        {purpose}
```

{Schemas, file templates and snippets, generic, with {placeholders}.}

## 9. Reference implementation in persistint

- {repo path, tool or command, with commit hash where known}
- {where the brief and the repo disagree: what the repo shows; the repo wins}
- Planned: {anything designed but not built}

## 10. Lessons learned

- {only lessons that actually happened, with evidence: commit, issue id or file}
