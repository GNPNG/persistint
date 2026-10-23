extends SceneTree
## Headless check of the celebrity quote V&V (issue 84u): every quote in data/quotes/*.json carries
## the verification fields, and every quote the game can speak is verified=true (checked verbatim
## against a primary source) and not excluded_from_game (Handmaid's Tale content: author rule).
## In-game uses: The Interview (Oprah's intro and prompts), the emcee's mini-game intros (Chelsea
## Clinton), Next Top Comic's setups (Sarah Silverman), Hottest of the HOT's verdicts (Tyra Banks;
## a verdict may also be DESIGN.md's own wording), the clone children's spoken lines
## (ZombieChild.quote_pool), and any quote text appearing in dialogue/*.dialogue, data/*.json,
## scripts/**/*.gd or scenes/**/*.tscn.
## Run: godot --headless --path project -s tests/test_quotes_vv.gd

const QUOTES_DIR := "res://data/quotes/"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var files := _quote_files()
	_check(files.size() > 0, "quote files found")

	# Every quote carries the V&V fields.
	var verified := {}  # file id -> {text: true}
	var usable := {}  # file id -> {text: true}: verified and not excluded_from_game
	var unverified := []  # [file id, text] never allowed in game
	var fields_ok := true
	for id: String in files:
		verified[id] = {}
		usable[id] = {}
		for q: Dictionary in files[id]["quotes"]:
			var ok: bool = q.get("verified") is bool and String(q.get("checked_url", "")).begins_with("https://") \
				and String(q.get("url", "")).begins_with("https://") and q.has("note")
			if q.has("primary_source"):
				ok = ok and String(q["primary_source"]).begins_with("https://")
			if q.has("was"):
				ok = ok and q.get("verified") == true
				unverified.append([id, String(q["was"])])
			var blob := (String(q.get("text", "")) + " " + String(q.get("source", ""))).to_lower()
			if ("handmaid" in blob or "gilead" in blob or "nolite" in blob) and q.get("excluded_from_game") != true:
				print("  Handmaid's Tale content not excluded_from_game: %s: %s" % [id, q.get("text", "")])
				ok = false
			if not ok:
				print("  missing/invalid V&V fields: %s: %s" % [id, q.get("text", "")])
			fields_ok = fields_ok and ok
			if q.get("verified") == true:
				verified[id][String(q["text"])] = true
			if q.get("verified") == true and q.get("excluded_from_game") != true:
				usable[id][String(q["text"])] = true
			else:
				unverified.append([id, String(q["text"])])
		var meta: Dictionary = files[id].get("_verification", {})
		_check(int(meta.get("total", -1)) == files[id]["quotes"].size() \
			and int(meta.get("verified", -1)) == verified[id].size(), "%s: _verification counts match the quotes" % id)
	_check(fields_ok, "every quote has verified, https checked_url/url, note; corrected quotes are verified; Handmaid's Tale content is excluded_from_game")

	# The Interview: Oprah's every line.
	var iv: Dictionary = _json("res://data/interview.json")
	var oprah_lines: Array = iv.get("intro", []).duplicate()
	for q: Dictionary in iv.get("questions", []):
		oprah_lines.append(q["prompt"])
	_check(oprah_lines.size() > 0 and _all_in(oprah_lines, usable.get("oprah", {}), "interview"),
		"interview: every Oprah line is a verified quote")

	# Emcee intros: Chelsea Clinton's every line.
	var emcee: Dictionary = _json("res://data/emcee.json")
	var emcee_lines: Array = []
	for lines: Array in emcee.get("intros", {}).values():
		emcee_lines.append_array(lines)
	_check(emcee_lines.size() > 0 and _all_in(emcee_lines, usable.get(emcee.get("emcee", ""), {}), "emcee"),
		"emcee: every intro line is a verified quote")

	# Next Top Comic: Sarah Silverman speaks every setup.
	var comic: Dictionary = _json("res://data/next_top_comic.json")
	var setups: Array = []
	for st: Dictionary in comic.get("setups", []):
		setups.append(st.get("setup", ""))
	_check(setups.size() > 0 and _all_in(setups, usable.get(comic.get("host", ""), {}), "comic"),
		"comic: every Silverman setup is a verified quote")

	# Hottest of the HOT: Tyra Banks's verdicts are her verified quotes or DESIGN.md's own example wording.
	var hot: Dictionary = _json("res://data/hottest_of_the_hot.json")
	var design := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../docs/DESIGN.md"))
	design = RegEx.create_from_string("\\s+").sub(design, " ", true)  # DESIGN.md wraps lines mid-sentence
	var verdicts_ok: bool = design != "" and hot.get("verdicts", []).size() > 0
	for v: String in hot.get("verdicts", []):
		if not usable.get(hot.get("host", ""), {}).has(v) and not design.contains(v):
			print("  hottest: verdict is neither a verified quote nor DESIGN.md wording: %s" % v)
			verdicts_ok = false
	_check(verdicts_ok, "hottest: every Tyra verdict is a verified quote or DESIGN.md's wording")

	# Clone children speak from their original's quote file: only verified lines are in the pool.
	# (loaded at run time: the script uses the Cast autoload)
	var ZombieChild: GDScript = load("res://scripts/ruins/zombie_child.gd")
	var originals: Dictionary = ZombieChild.data().get("originals", {})
	var pools_ok := true
	var spoken := 0
	for orig: String in originals:
		var id: String = originals[orig].get("quotes", "")
		var pool: Array = ZombieChild.quote_pool(orig)
		if not files.has(id):
			pools_ok = pools_ok and pool.is_empty()
			continue
		spoken += 1
		pools_ok = pools_ok and pool.size() == usable[id].size() and _all_in(pool, usable[id], "clone " + orig)
	_check(spoken > 0 and pools_ok, "clone children: spoken pool is exactly the usable verified quotes of their original")

	# No unverified (or pre-correction) quote text anywhere in shipped dialogue or data.
	var content := {}
	for path: String in _files("res://dialogue/", ".dialogue") + _files("res://data/", ".json") \
			+ _files_deep("res://scripts/", ".gd") + _files_deep("res://scenes/", ".tscn"):
		content[path] = FileAccess.get_file_as_string(path)
	var leaks := 0
	for pair: Array in unverified:
		var text: String = pair[1]
		for path: String in content:
			if content[path].contains(text) or content[path].contains(JSON.stringify(text).trim_prefix("\"").trim_suffix("\"")):
				print("  unverified quote in game content: %s (%s) in %s" % [text, pair[0], path])
				leaks += 1
	_check(leaks == 0, "no unverified, excluded or pre-correction quote text in dialogue, data, scripts or scenes")

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _quote_files() -> Dictionary:
	var out := {}
	for path: String in _files(QUOTES_DIR, ".json"):
		out[path.get_file().get_basename()] = _json(path)
	return out


func _files(dir: String, ext: String) -> Array:
	var out: Array = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir + f)
	return out


func _files_deep(dir: String, ext: String) -> Array:
	var out: Array = _files(dir, ext)
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_files_deep(dir + sub + "/", ext))
	return out


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _all_in(lines: Array, allowed: Dictionary, where: String) -> bool:
	var ok := true
	for line: Variant in lines:
		if not allowed.has(String(line)):
			print("  %s: not a verified quote: %s" % [where, line])
			ok = false
	return ok


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
