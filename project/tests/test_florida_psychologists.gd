extends SceneTree
## Headless check of the vacationing psychologists on the Florida beach (bd kge): they lounge
## under the beach umbrella with their conversation; it is optional (the first choice can end it);
## every line they speak is tagged in data/florida_psychologists.json's terms, its words exactly the
## entry's: [#cite=<id>] a claim verified against its source (verified=true, the DOI, the record
## checked, the source's own words, a check date; SOP-06) from the site's citations page or the
## author's references; a claim resting on survey or self-report data says so in its record and
## names the objective data it is set against, or that none was found (self_report_problem; the
## author, 2026-10-27: such sources may come in to show the disparity with objective data, such as
## .gov agency figures); [#author=<id>] a line the author wrote, as his words, with no source;
## [#interp=<id>] the psychologists' explanation, never marked as sourced; [#chat] their own talk.
## Every claim is spoken; meeting them is remembered; walking near them gets a bark and talking to
## them opens the conversation.
## Run: godot --headless --path project -s tests/test_florida_psychologists.gd
## The test run uses WorldState's test save (QA-04).

const DIALOGUE := "res://dialogue/florida_psychologists.dialogue"
const CLAIMS := "res://data/florida_psychologists.json"
const BEACH := "res://scenes/florida/beach.tscn"
const SPEAKERS := ["Woman with a Margarita", "Man with a Margarita"]
const SKIP := "I'll let you enjoy it."
## The author's reference collection (dev/, git-crypt), where works not on the citations page are listed.
const AUTHOR_REFS := "../dev/notebook/biological-and-social-foundations-of-the-covenant-hierarchy.md"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	ws.reset()
	var doc: Dictionary = _json(CLAIMS)
	var claims: Dictionary = doc.get("claims", {})
	_check(claims.size() > 0, "claims load")

	# Every claim is verified against its source and cites a work on the site's citations page or in
	# the author's references.
	var page := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../site/public/citations.html"))
	_check(page.contains("Further reading"), "the site's citations page is readable")
	var refs := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join(AUTHOR_REFS))
	var date := RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}$")
	var n_verified := 0
	for id: String in claims:
		var c: Dictionary = claims[id]
		var ok: bool = c.get("verified") is bool and c.get("verified") == true and c.get("aggregator") == false \
			and String(c.get("url", "")).begins_with("https://doi.org/") and String(c.get("checked_url", "")).begins_with("https://") \
			and String(c.get("text", "")) != "" and String(c.get("source", "")) != "" and String(c.get("evidence", "")).length() > 20 \
			and date.search(String(c.get("checked_on", ""))) != null
		_check(ok, "claim %s: verified, with its source, DOI, the record checked, the source's words and a date" % id)
		var doi := String(c.get("url", "")).trim_prefix("https://doi.org/")
		var listed: bool = page.contains(doi) if doi != "" else false
		if not listed and c.has("title"):
			listed = refs.contains(String(c["title"]))
		_check(listed, "claim %s cites a work on the citations page or in the author's references (%s)" % [id, doi])
		var problem := self_report_problem(id, c, doc)
		_check(problem == "", "claim %s: self-report data tagged and set against objective data%s"
			% [id, (" (" + problem + ")") if problem != "" else ""])
		if c.get("verified") == true:
			n_verified += 1
	_check_self_report_rule()
	var authors: Dictionary = doc.get("author_lines", {})
	for id: String in authors:
		var a: Dictionary = authors[id]
		_check(String(a.get("text", "")) != "" and String(a.get("author_words", "")).contains("Author")
			and not (a.has("support") or a.has("gap") or a.has("source") or a.has("url") or a.has("verified")),
			"author line %s: his words, with no source, support or gap record, not marked verified" % id)
	var interps: Dictionary = doc.get("interpretations", {})
	for id: String in interps:
		var i: Dictionary = interps[id]
		_check(i.get("kind") == "interpretation" and not i.has("verified") and not i.has("url") and String(i.get("note", "")) != "",
			"interpretation %s is never presented as sourced" % id)
	var meta: Dictionary = doc.get("_verification", {})
	_check(int(meta.get("total", -1)) == claims.size() and int(meta.get("verified", -1)) == n_verified,
		"_verification counts match the claims")

	# Every line they speak: a cited, verified claim, the author's line or an interpretation, in its exact words, or chat.
	var dm: Node = root.get_node("/root/DialogueManager")
	var res: Resource = load(DIALOGUE)
	_check(res != null, "the conversation loads")
	ws.set_flag("fl_met_psychologists", false)
	var lines: Array = []
	var asked: Array = []
	await _walk(dm, res, "start", lines, asked, {})
	_check(ws.has_flag("fl_met_psychologists"), "meeting them is remembered")
	_check(lines.size() >= claims.size() + 5, "the whole conversation was walked (%d lines)" % lines.size())
	var used := {}
	var untagged := 0
	for l: Array in lines:
		_check(l[0] in SPEAKERS, "only the two psychologists speak (%s)" % l[0])
		var cite := _tag_value(l[2], "cite")
		var author := _tag_value(l[2], "author")
		var interp := _tag_value(l[2], "interp")
		if author != "":
			_check(authors.has(author) and String(authors[author]["text"]) == String(l[1]).strip_edges(),
				"the author's line %s is spoken as he wrote it" % author)
			used["author:" + author] = true
		elif interp != "":
			_check(interps.has(interp) and String(interps[interp]["text"]) == String(l[1]).strip_edges(),
				"interpretation %s is spoken as written" % interp)
			used["interp:" + interp] = true
		elif cite != "":
			var c: Dictionary = claims.get(cite, {})
			_check(not c.is_empty() and c.get("verified") == true and String(c["text"]) == String(l[1]).strip_edges(),
				"the line citing %s says its verified claim's words exactly" % cite)
			used[cite] = true
		elif not l[2].has("chat"):
			untagged += 1
			print("  untagged line: %s: %s" % [l[0], l[1]])
	_check(untagged == 0, "every line they speak is tagged: claim, author line, interpretation or chat")
	for id: String in claims:
		_check(used.has(id), "claim %s is spoken" % id)
	for id: String in authors:
		_check(used.has("author:" + id), "author line %s is spoken" % id)
	for id: String in interps:
		_check(used.has("interp:" + id), "interpretation %s is spoken" % id)
	_check(lines.any(func(l: Array) -> bool: return _tag_value(l[2], "author") == "ipv_highest") and asked.has("Wait, how?"),
		"the author's line is spoken and the player can ask how")
	_check(not lines.any(func(l: Array) -> bool: return String(l[1]).contains("[#") or String(l[1]).contains("{{")),
		"no tag or {{...}} shows in a line")
	for want: String in [SKIP, "What do you two do, back home?", "Violence between partners?",
			"Wait, how?", "What about control, without hitting?", "That's enough research for one vacation."]:
		_check(asked.has(want), "the player can say: %s" % want)

	# Optional: the first choice can end it before any research, and a return visit is welcomed.
	var line = await dm.get_next_dialogue_line(res, "start")
	_check(line != null and String(line.text).contains("You're back"), "a return visit gets the welcome back")
	while line != null and line.responses.is_empty():
		line = await dm.get_next_dialogue_line(res, line.next_id)
	var skip = null
	if line != null:
		for r in line.responses:
			if r.text == SKIP:
				skip = r
	_check(skip != null, "the first choices include leaving them to it")
	if skip != null:
		var after = await dm.get_next_dialogue_line(res, skip.next_id)
		var said := 0
		while after != null and after.responses.is_empty() and said < 10:
			said += 1
			_check(_tag_value(after.tags, "cite") == "", "leaving them to it has no research in it")
			after = await dm.get_next_dialogue_line(res, after.next_id)
		_check(after == null and said >= 1, "leaving them to it ends the conversation")

	# On the beach: under the umbrella, a bark when you walk by, and talking opens the conversation.
	var beach: Node = load(BEACH).instantiate()
	root.add_child(beach)
	await process_frame
	var npc: Node = beach.get_node_or_null("Psychologists")
	_check(npc != null and npc.is_present() and npc.dialogue_path == DIALOGUE and ResourceLoader.exists(DIALOGUE),
		"the psychologists are on the beach with their conversation")
	if npc:
		_check((npc as Node2D).position.distance_to((beach.get_node("Umbrella") as Node2D).position) < 30.0,
			"they lounge under the beach umbrella")
		_check(npc.current_bark() != "..." and npc.current_bark() != "", "they have a bark for passers-by")
		npc.interact()
		for i in 4:
			await process_frame
		_check(not get_nodes_in_group("dialogue_balloon").is_empty(), "talking to them opens the conversation")
		for b in get_nodes_in_group("dialogue_balloon"):
			b.queue_free()
	beach.queue_free()
	await process_frame

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


## Plays the dialogue from title and every response branch once (the topics menu returns to
## itself, so each response is followed only the first time); appends [character, text, tags]
## per line to out and each response's text to asked.
func _walk(dm: Node, res: Resource, title: String, out: Array, asked: Array, seen: Dictionary) -> void:
	if seen.has(title) or seen.size() > 200:
		return
	seen[title] = true
	var line = await dm.get_next_dialogue_line(res, title)
	var steps := 0
	while line != null and steps < 80:
		steps += 1
		out.append([line.character, line.text, line.tags])
		if line.responses.size() > 0:
			for r in line.responses:
				if not asked.has(r.text):
					asked.append(r.text)
				await _walk(dm, res, r.next_id, out, asked, seen)
			return
		line = await dm.get_next_dialogue_line(res, line.next_id)


## The rule on self-report data (the author, 2026-10-27): a claim may rest on survey or self-report
## data (its population or evidence says survey, self-report, questionnaire or peer nomination, or
## its record says so) only when its record carries evidence_kind "self-report" and objective: the
## id of a record in the same file with the objective data it is set against (an objective_data
## record with its source and a .gov url, or a claim that is not self-report itself), or "none
## found". Returns "" when claim `id` keeps the rule, else what is missing.
static func self_report_problem(id: String, c: Dictionary, doc: Dictionary) -> String:
	var survey := RegEx.create_from_string("(?i)survey|self-report|questionnaire|peer nomination")
	var tagged: bool = c.get("evidence_kind", "") == "self-report"
	if not tagged and survey.search("%s %s" % [c.get("population", ""), c.get("evidence", "")]) == null:
		return ""
	if not tagged:
		return "rests on survey or self-report data, but evidence_kind is not \"self-report\""
	var against := String(c.get("objective", ""))
	if against == "none found":
		return ""
	if against == "" or against == id:
		return "no objective: give the id of the objective data it is set against, or \"none found\""
	var objective: Dictionary = doc.get("objective_data", {})
	if objective.has(against):
		var o: Dictionary = objective[against]
		var host := String(o.get("url", "")).trim_prefix("https://").get_slice("/", 0)
		if String(o.get("source", "")) == "" or not host.ends_with(".gov"):
			return "objective record %s needs its source and a .gov url" % against
		return ""
	var claims: Dictionary = doc.get("claims", {})
	if claims.has(against):
		var other: Dictionary = claims[against]
		if other.get("evidence_kind", "") == "self-report" \
				or survey.search("%s %s" % [other.get("population", ""), other.get("evidence", "")]) != null:
			return "set against %s, which is self-report data too" % against
		return ""
	return "objective %s is not a record in this file" % against


## The rule fires: in-memory records (the shipped data has no self-report claim, so the check on it
## passes without exercising the rule).
func _check_self_report_rule() -> void:
	var doc := {
		"claims": {
			"review": {"population": "review of the research", "evidence": "A review says so, in its own words."},
			"poll": {"population": "512 students; self-report questionnaires", "evidence": "Students were surveyed."},
		},
		"objective_data": {
			"agency": {"source": "Fixture agency table", "url": "https://records.example.gov/fixture"},
			"elsewhere": {"source": "Fixture page", "url": "https://example.com/fixture"},
		},
	}
	var c: Dictionary = {"population": "640 adults; self-report survey", "evidence": "Adults were surveyed by self-report."}
	_check(self_report_problem("fx", c, doc) != "", "self-report rule fires: survey data without evidence_kind")
	c["evidence_kind"] = "self-report"
	_check(self_report_problem("fx", c, doc) != "", "self-report rule fires: no objective")
	for bad: String in ["missing", "elsewhere", "poll", "fx"]:
		c["objective"] = bad
		_check(self_report_problem("fx", c, doc) != "", "self-report rule fires: objective %s" % bad)
	for good: String in ["agency", "review", "none found"]:
		c["objective"] = good
		_check(self_report_problem("fx", c, doc) == "", "self-report rule passes: objective %s" % good)
	var tagged: Dictionary = {"population": "a panel", "evidence": "The panel said so.", "evidence_kind": "self-report"}
	_check(self_report_problem("fx", tagged, doc) != "", "self-report rule fires: tagged self-report with no objective")
	_check(self_report_problem("review", doc["claims"]["review"], doc) == "", "self-report rule leaves other claims alone")


func _tag_value(tags: PackedStringArray, key: String) -> String:
	for t: String in tags:
		if t.begins_with(key + "="):
			return t.substr(key.length() + 1).strip_edges()
	return ""


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
