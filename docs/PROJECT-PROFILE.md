# Project profile: persistint

Written 2026-10-24 as the first instance of the applicability mechanism (sops/templates/PROJECT-PROFILE.md).

```yaml
project: persistint
owner: the author (product owner, project lead, playtester)
openness:
  code: partially-closed          # public via a filtered publication to GitHub; dev/ encrypted (git-crypt)
  content: partially-closed       # novel material, canon art and the thematic framing are private (dev/); game assets ship
  history: private-kept           # the private forge keeps full history; the public repository is a filtered publication (SOP-14)
licences: [see LICENSE, content all rights reserved unless stated]
data_sensitivity: none            # no player accounts, no analytics with personal data; ratings files are the author's own
obligations: [real quotes only for real people, with verified sources; celebrity names unchanged; the message by construction, never stated]
audience: [teenagers in a grade-11 classroom, adults, a playtester on an iPad]
team:
  humans: [author]
  agents: [coordinator session (repo, game, headless harvest), Windows session (browser, Gemini dispatch, playtesting), srv PM session (planned), forks and subagents in worktrees]
  external: []
deployment: [web (Cloudflare Pages), old phones and tablets]
stage: 0.2.1 shipped; next gate 0.3.0 (title screen, touch controls, remaining music, clone lines)
```

SOPs that apply because of this profile (to be encoded as `applies_when` on each SOP): the content
gates (verified quotes, the comedy audit, the name kept private), the privacy gates (git-crypt check
before push, expiry sweep, filtered publication), the device gate (old phones, the iPad playtest),
the audio-level gate, and the team and dispatch rules. Not applicable here: human-subjects, PHI,
export-control and funder data-sharing SOPs.
