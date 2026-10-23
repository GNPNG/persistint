# SOP-06: Sourcing and verifying real-person quotes before they ship

Status: draft
Owner: Brett Whitty
Applies to: any project that puts a real person's words in shipped content (dialogue, UI text, voice clips, marketing copy)
Last reviewed: 2026-10-23
Related SOPs: SOP-02 (02-content-from-sources.md: content that uses real people's lines takes them from the quote store); SOP-05 (05-voice-cloning-pipeline.md: voice clips are generated only from quote text this SOP marks verified)

## 1. Purpose

Ship a real person's words only when they have been checked character by character against a primary source. Keep a record of where each line came from, how it was checked, and what changed. Record unverified claims about people as unverified and do nothing based on them.

## 2. When to use / when not to

Use when:
- Content attributes words to a real, named person.
- A line from a quote database will appear in dialogue, a menu, a voice clip or any other shipped asset.
- A research tool reports a fact about a real person (death, arrest, quote, title) that could change content.
- Variant: a public-domain work quoted as a work (a title, a book passage with full citation). Steps 5 and 6 apply; the aggregator rules in step 4 do not.

Do not use when:
- The lines are original writing for a fictional character with no real-world counterpart.
- The text is a paraphrase not presented as the person's words. Such a line still needs review under the project's own content rules.

## 3. Inputs and prerequisites

- The author's list of people, with names spelled exactly as the author gave them. Names are never changed from the author's source.
- A quote store: one JSON file per person, `{data_dir}/quotes/{person}.json` (schema in section 8).
- A way to fetch raw page text (HTML or PDF bytes, not a summary): `curl`, a browser, or a saved copy.
- An issue tracker entry for the verification work, linked as a blocker on any content issue that will use the lines.
- A test runner that can read the quote store and the content files that use it.

## 4. Roles and tools

| Role | Does | Does not |
|---|---|---|
| Author | Names the people and spellings; approves which lines ship; decides on any line whose attribution is contested. | Get asked to confirm facts the tools can check. |
| Controller agent | Owns the quote store and the issue; assigns people to sub-agents; merges results; runs the checker and the test; reports counts. | Mark a line verified without a raw-text comparison. |
| Sub-agent (one per person or batch) | Gathers candidate lines with source and url; flags aggregator-only lines; does the verbatim pass on assigned lines. | Edit content files; change names; act on biographical claims. |

Tools, by capability (names in parentheses are examples from one agent harness; use whatever the project's harness provides):
- A search tool (e.g. `WebSearch`): finds candidate pages. Results are leads, not sources.
- A model-mediated page reader (e.g. `WebFetch`): reads a page through a model and returns an extraction. Use it for discovery only. Its output is never the text a quote is checked against.
- A raw-text fetcher: `curl` first; then a browser text extractor (e.g. `mcp__claude-in-chrome__get_page_text`) for pages that need JavaScript, a login or a human-looking client; then a saved PDF or an archive snapshot (e.g. web.archive.org). Retrieves the raw page text for the verbatim pass.
- `{checker}`: a script (for example `python3 -I tools/verify_quotes.py`) that reports per-file counts and fails on unverified lines in use.
- `{test}`: an automated test that fails the build if any shipped line is not marked verified.
- Issue tracker (`bd` in projects that use beads): records the work and any unverified claims.

## 5. Procedure

1. **Open the issue.** Create a verification issue and make every content issue that will use quotes depend on it.
   Check: the content issue shows the verification issue under its dependencies.

2. **Gather candidates.** For each person, collect lines with `text`, `source` (speaker, title, outlet, date), `url`, and `aggregator` (true when the url is a quote-collection site and not the original speech, article, book, interview or recording).
   Check: every entry has all four fields; the file-level `_verification` block (section 8) says the lines are unchecked.

3. **Record attribution caveats.** When a line is widely misattributed, predates the person, or is a reporter's paraphrase, write that in the entry's `note`.
   Check: every entry with a known caveat has a `note`; such entries are not used as the person's own words unless the author decides otherwise.

4. **Find a primary source for aggregator-only lines.** Search for the original speech, article, book page, transcript or recording. Put it in `primary_source`. If none is found, the line stays unverified.
   Check: no entry has `aggregator: true` and `verified: true` without `primary_source`.

5. **Do the verbatim pass.** Fetch the raw text of `primary_source` (or `url` when it is already primary). Use this order, moving on when a method returns no quote text (JavaScript-rendered page, paywall, 403 from bot blocking, scanned PDF): `curl`; a browser text extractor; a saved PDF or an archive snapshot of the page. Save a copy of what was compared (an archive snapshot url, or a file under `{data_dir}/quotes/snapshots/`) and record it in `archived_copy`. Compare character by character after normalizing only whitespace and curly vs straight quotes. For audio or video, compare against the recording or its captions and say so in `note`.
   Check: the line occurs in the raw text, or the difference is recorded in step 6; every compared line has `archived_copy`.

6. **Fix and record differences.** If the source wording differs, replace `text` with the source wording and keep the old wording in `was`. Set `checked_url` to the page actually compared and `verified` to the check date as `YYYY-MM-DD` (always a date, never `true`). Then search every content file for each `was` string and replace it with the new `text`. List any voice clip generated from the old text for regeneration under SOP-05.
   Check: every changed line has `was`; every verified line has `checked_url` and a date in `verified`; no content file contains a `was` string; the clips to regenerate are listed in the issue.

7. **Handle claims about people.** A tool result that says something about a person (died, arrested, resigned, said X) is recorded as unverified metadata: in the issue, or in a file-level note marked unverified. Do not change content, cast, dialogue or names because of it until a primary source confirms it and the author decides.
   Check: no content commit cites an unverified claim as its reason.

8. **Update file-level metadata.** Set `_verification.method` to what was actually done and recount `total`, `aggregator_only` and `verified_count`. Set `_verification.verified` to the date of this pass and `expires` to the re-check date (step 12). Remove any file note that claims more checking than was done.
   Check: `total`, `aggregator_only` and `verified_count` match the entries; the file's prose and `_verification` block agree.

9. **Gate the consumers.** Content may only use lines with `verified` set. The `{test}` loads every content file that draws from the quote store and fails on any line that is missing from the store or not verified. Voice-clip generation (SOP-05) should read only verified `text`.
   Check: the test fails when one verified flag is removed by hand, and passes again when it is restored.

10. **Get author approval.** Give the author the list of verified lines that content will use, plus every line with a `note` caveat (step 3). The author approves which lines ship and decides each contested attribution. Record the approval and each decision in the issue.
    Check: the issue has a comment from or for the author listing the approved lines and the decision on each caveated line.

11. **Close out.** Run `{checker}` and `{test}`, paste the counts into the issue, close it, and unblock the content issues.
    Check: the issue shows the final counts and the author approval, and the content issue is unblocked.

12. **Re-check before release.** Before each release, and whenever a file's `_verification.expires` date has passed, rerun step 5 for every line in use from that file (sources move, get edited or disappear). Then repeat steps 6 and 8.
    Check: no file used by the release has an `expires` date in the past.

## 6. Acceptance checks

- Every line used in shipped content has `verified` (a date), `checked_url`, `archived_copy`, and (if aggregator-only) `primary_source`.
- The issue records the author's approval of the lines that ship.
- No quote file used by the release is past its `expires` date.
- No line has `aggregator: true` and `verified` without `primary_source`.
- Every changed line has `was`.
- File prose (`_note`) does not claim checking that `_verification.method` does not describe.
- Unverified claims about people appear only in the issue or in metadata marked unverified.

Commands (adapt names):

```bash
{checker}   # per-file totals; non-zero exit if a used line is unverified
{test}      # build gate
# files with no verified quote entries yet (ignores the file-level _verification.verified date)
for f in {data_dir}/quotes/*.json; do
  jq -r --arg f "$f" '[.quotes[] | select(has("verified"))] | length | select(. == 0) | $f' "$f"
done
```

Example for a Godot project: `{test}` is `godot --headless --path {project_dir} -s {tests_dir}/{test_quotes_vv}.gd`.

Mutation check for the gate: remove `verified` from one used line, run the test, confirm it fails, restore.

## 7. Failure modes and recovery

| Failure | How it shows | Recovery |
|---|---|---|
| Discovery tool output treated as source text | Lines read as the person's words but were produced by a model summarizing the page; wording drifts. | Re-fetch raw text and redo step 5 for every line gathered that way. Set `_verification.method` to what was actually done in the meantime. |
| Aggregator-only lines | Url is a quote-collection site; the line may be misattributed or reworded. | Step 4. If no primary source exists, keep the line unverified and out of content. |
| File note overstates checking | A `_note` says lines were checked against the page; the method field says they were not. | Trust the method field; rewrite the note; treat all lines as unverified. |
| Membership test mistaken for verification | Tests pass because each in-game line exists in the store, but nothing checks it was verified. | Add the verified check (step 9) to the same test. |
| Unverified biographical claim | A search result reports an event about a person. | Record it in the issue as unverified. Do nothing to content. Ask for a primary source only if the content depends on it. |
| Name "corrected" by a tool or agent | A person's name in content no longer matches the author's spelling. | Revert to the author's spelling. Names come from the author's source only. |
| Voice clip of an unverified line | Generated audio says words not yet checked. | Delete or regenerate the clip from verified text (SOP-05). |

## 8. Artifacts and templates

Layout:

```
{data_dir}/quotes/{person}.json      one file per person
{data_dir}/quotes/snapshots/         saved copies of compared pages (if not using an archive service)
{tools_dir}/{verify_quotes}.py       checker
{tests_dir}/{test_quotes_vv}         build gate
```

Quote file schema:

```json
{
  "_note": "{Person}'s own words only. See _verification for what was checked.",
  "_verification": {
    "method": "{how lines were gathered and how wording was checked}",
    "verified": "{YYYY-MM-DD of the last verification pass}",
    "expires": "{YYYY-MM-DD after which step 12 must be rerun}",
    "total": {n},
    "aggregator_only": {n},
    "verified_count": {n}
  },
  "quotes": [
    {
      "text": "{exact wording from the primary source}",
      "source": "{Person}, '{title}', {outlet}, {YYYY-MM-DD}",
      "url": "{where the line was found}",
      "aggregator": {true|false},
      "primary_source": "{url or citation of the original; required if aggregator}",
      "checked_url": "{url whose raw text was compared}",
      "archived_copy": "{archive snapshot url or snapshots/ path of what was compared}",
      "verified": "{YYYY-MM-DD; always a date, never true}",
      "was": "{previous wording, only if changed}",
      "note": "{attribution caveat or comparison method, optional}"
    }
  ]
}
```

Unverified claim record (issue description or comment):

```
Unverified, not in any content file: {tool} result on {date} said {claim} about {person}.
No primary source found. No content change made.
```

Gate test outline:

```
for each content file that uses quotes:
    for each line attributed to {person}:
        entry = find(quotes/{person}.json, text == line)
        fail if entry is missing
        fail if entry.verified is not a YYYY-MM-DD date
        fail if entry.aggregator and not entry.primary_source
```

## 9. Reference implementation in persistint

Where the repo and the brief for this SOP disagree, the repo is described here and the difference is stated.

Built (on `main`):
- `project/data/quotes/{atwood,chelsea,ellen,hillary,kate,oprah,silverman,steinem,tyra}.json`: 9 files, 317 quotes, 141 flagged `aggregator: true`. Per-quote fields are `text`, `source`, `url`, `aggregator` (`chelsea.json` has no `aggregator` field and needs it backfilled before step 2's check can pass; `steinem.json` has `note` on three entries recording attribution caveats, such as a line widely misattributed to Steinem).
- File-level `_verification` blocks (`method`, `verified`, `expires`, `aggregator_only`, `total`) were added in commit 6538b1b. Each `method` reads: "WebFetch/WebSearch extraction on 2026-10-23 (tool output, not raw page text); wording not character-checked against the original page".
- Contradiction in the files: each `_note` says "each checked against the page in 'url' on 2026-10-23", while `_verification.method` says the wording was not character-checked. The `_verification` block is accurate; the `_note` text is stale.
- Consumers of the quote store: `project/data/interview.json` (Oprah lines), `project/data/emcee.json` (Chelsea Clinton lines), `project/data/ruins.json` (clone lines via `"quotes": "<file>"`, read by `project/scripts/ruins/zombie_child.gd`).
- Existing tests are membership checks only: `project/tests/test_interview.gd` (lines 29-40) and `project/tests/verify_slice.gd` (lines 168-174) assert that in-game lines appear in `oprah.json` and `chelsea.json`. Nothing checks a verified flag yet.
- Test convention: headless Godot scripts in `project/tests/`, run as `godot --headless --path project -s tests/<name>.gd`.

On branch `sys-clone-voices` (commit f84a22a, not merged to main at the time of writing):
- Three more files, `epstein.json`, `bill_clinton.json`, `bill_gates.json` (26 quotes, none aggregator-only). Only `bill_gates.json` records a wording check, against the captions of the talk recording (YouTube 6Af6b_wyiwI).
- `tools/verify_voice_clips.py` checks that each clip says its intended text (transcription) in its speaker's voice (embedding similarity). It does not check whether the intended text is a verified quote. SOP-05 step 2 now requires the `verified` date; no tool enforces it yet.

Tracking:
- Beads issue `persistint-game-84u` ("V&V: character-check quote databases against original pages before lines go in-game"), status IN_PROGRESS. It blocks `persistint-game-c0e` (branching dialogue for every celebrity, lines from their sourced quotes).
- The issue description holds the one recorded unverified claim: "Unverified, not in any file: a search result said Gloria Steinem died Sept 2026." It is not in `steinem.json` or any content file.

Planned (not built; branch `sys-quotes` has no commits beyond main as of 2026-10-23):
- Per-quote fields `verified`, `checked_url`, `archived_copy`, `primary_source`, `note`, `was`; file-level `verified_count`.
- `tools/verify_quotes.py` (checker).
- `project/tests/test_quotes_vv.gd`: asserts every in-game quote is verified. The brief names it `tests/test_quotes_vv.gd`; repo convention puts tests under `project/tests/`.

## 10. Lessons learned

- `WebFetch` returns a model extraction of a page, not the page text. Lines gathered with it are leads until checked verbatim against the source.
- Aggregator-only lines need a primary source before use.
- A claim about a real person from a search result (here, that someone had died) is recorded as unverified metadata and not acted on without a primary source.
- Celebrity names stay exactly as the author's source gives them.
- Voice clips speak only verified quote text, so quote verification comes before clip generation. The first draft of SOP-05 asked only for a source and url; SOP-05 step 2 now requires the `verified` date.
