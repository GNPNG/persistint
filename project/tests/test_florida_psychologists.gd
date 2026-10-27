extends SceneTree
## Headless check of the vacationing psychologists on the Florida beach (bd kge): they lounge
## under the beach umbrella with their conversation; it is optional (the first choice can end it);
## every line they speak is tagged, [#chat] for their own talk or [#cite=<id>] naming a claim in
## data/florida_psychologists.json whose words are the line's exactly; every claim is verified
## against its source (verified=true, the DOI, the record checked, the source's own words, a check
## date; SOP-06), is spoken somewhere, and cites a work on the site's citations page; meeting them
## is remembered; walking near them gets a bark and talking to them opens the conversation.
## Run: godot --headless --path project -s tests/test_florida_psychologists.gd
## The test run uses WorldState's test save (QA-04).

const DIALOGUE := "res://dialogue/florida_psychologists.dialogue"
const CLAIMS := "res://data/florida_psychologists.json"
const BEACH := "res://scenes/florida/beach.tscn"
const SPEAKERS := ["Woman with a Margarita", "Man with a Margarita"]
const SKIP := "I'll let you enjoy it."

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

	# Every claim is verified against its source and cites a work on the site's citations page.
	var page := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../site/public/citations.html"))
	_check(page.contains("Further reading"), "the site's citations page is readable")
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
		_check(doi != "" and page.contains(doi), "claim %s cites a work on the citations page (%s)" % [id, doi])
		if c.get("verified") == true:
			n_verified += 1
	var meta: Dictionary = doc.get("_verification", {})
	_check(int(meta.get("total", -1)) == claims.size() and int(meta.get("verified", -1)) == n_verified,
		"_verification counts match the claims")

	# Every line they speak: a cited, verified claim in its exact words, or chat.
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
		if cite != "":
			var c: Dictionary = claims.get(cite, {})
			_check(not c.is_empty() and c.get("verified") == true and String(c["text"]) == String(l[1]).strip_edges(),
				"the line citing %s says its verified claim's words exactly" % cite)
			used[cite] = true
		elif not l[2].has("chat"):
			untagged += 1
			print("  untagged line: %s: %s" % [l[0], l[1]])
	_check(untagged == 0, "every line they speak is a cited claim or chat")
	for id: String in claims:
		_check(used.has(id), "claim %s is spoken" % id)
	_check(not lines.any(func(l: Array) -> bool: return String(l[1]).contains("[#") or String(l[1]).contains("{{")),
		"no tag or {{...}} shows in a line")
	for want: String in [SKIP, "What do you two do, back home?", "Violence between partners?",
			"Wait, more than straight women? How?", "Why don't I ever hear about this?", "That's enough research for one vacation."]:
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
