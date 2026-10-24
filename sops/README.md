# SOPs

Standard operating procedures developed on persistint and written to be reused on other projects. Each SOP describes one method: when to use it, the steps with a check for each, how to know it is done, what goes wrong and how to recover, and the file layouts and templates it needs.

Sections 1 to 8 of every SOP are project-agnostic and use `{placeholders}`. Section 9 records how persistint implements the SOP (paths, tools, commits, and what is still planned). Section 10 lists lessons that actually happened on persistint.

## Index

| SOP | Status | Use it when |
|---|---|---|
| [SOP-01](01-parallel-agents-worktrees.md) Parallel sub-agent development with git worktrees | active | Several coding agents work at once on independent systems, each in its own worktree and branch, with one controller merging, testing and pushing. |
| [SOP-02](02-content-from-sources.md) Writing game content from the author's source material | draft | Content slots (dialogue, barks, quiz questions, item text) must be filled from the author's own writing, with names, voice and vocabulary kept intact. |
| [SOP-03](03-asset-style-bible-and-prompts.md) Style bible and self-contained generator prompts | active | A project needs more than a handful of generated images, video or music that must match one style, and prompts must work pasted as is. |
| [SOP-04](04-generative-render-pipeline.md) Rendering assets through generator web apps and APIs | draft | Finished prompt files need rendering across sessions, with every attempt tracked, retries by error class and daily quotas respected. |
| [SOP-05](05-voice-cloning-pipeline.md) Cloned character voices for spoken lines | draft | Scripted spoken lines need pre-rendered clips in each character's voice, with platform text-to-speech as the fallback. |
| [SOP-06](06-quote-sourcing-vv.md) Sourcing and verifying real-person quotes | draft | Shipped content puts a real person's words on screen or in audio, or a tool reports a fact about a real person. |
| [SOP-07](07-playtest-bug-triage.md) Turning playtest reports into reproduced, tested fixes | draft | A tester reports symptoms in their own words and each needs to be located, reproduced, fixed for its whole class and held by a test. |
| [SOP-08](08-session-hygiene-tracking.md) Issue tracking, memory, commits and session close | active | Any agent session that changes a repository: issues, author rules in tracker memory, plain commits, and a clean, pushed close. |
| [SOP-10](10-audio-levels.md) Audio levels | active | Loudness targets for music, voices and effects, fixed in the samples and plain bus volumes (no real-time effects); the gate on every deploy and a fresh full measurement on each minor release. |

How they connect: SOP-08 applies to every session. SOP-01 and SOP-07 use it for issues, commits and cleanup. SOP-02 feeds names and vocabulary to SOP-03, whose prompts feed SOP-04. SOP-06 verifies the quotes that SOP-02 content and SOP-05 voice clips use.

## Adopting these SOPs in another project

1. Choose how to bring them in:
   - Copy: copy `sops/` into the new repository. Use this when the project will change the procedures.
   - Reference: link to this directory (or a pinned commit of it) from the new project's agent instructions. Use this when the project follows the procedures unchanged.
2. Pick the SOPs that apply. SOP-08 applies to any repository with agent sessions; the others apply only when their "When to use" section matches.
3. Fill the placeholders for the new project: test and setup commands, branch prefix, tracker, actor name, data paths. Put these bindings in section 9 of the copied SOP, or in a project file that the agent instructions point to.
4. Replace section 9 with the new project's reference implementation, and start section 10 empty. Keep sections 1 to 8 free of project specifics; if a step does not fit, change the generic step and record why.
5. Point the agent instructions (for example `CLAUDE.md`) at the SOPs, so every session and every sub-agent brief names the ones that apply.
6. Mark anything not yet built as "planned" in section 9 until it exists.

## Writing a new SOP

Copy [TEMPLATE.md](TEMPLATE.md) to `sops/NN-slug.md` with the next free number. Fill sections 1 to 8 in project-agnostic terms. Ground every claim in section 9 in the repository (paths, commands, commit hashes); where a brief and the repository disagree, the repository wins and section 9 says so. Add the new SOP to the index above and to the "Related SOPs" line of every SOP it relates to, in both directions.

Style: plain, direct, imperative. No marketing language. Every step ends with a check.
