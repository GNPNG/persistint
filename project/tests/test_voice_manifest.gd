extends SceneTree
## Every speaker the game hands lines to Voice.speak has them in the voice clip manifest
## (audio/voice/manifest.json, written by tools/export_voice_lines.mjs), so the clip generator can
## voice them. The speakers and their lines come from the game's own line sources with the speaker
## string each script passes (VoiceReview.build_roster: dialogue, villager barks, the cruise shows,
## the landing, the interview as "oprah", the Florida critters by kind, the ponies as "pony", the
## polar bear cubs, the clones' quotes, the title letters and their chime-ins). Each speaker with a
## spoken line is in the manifest, every such line is there under the key Voice.line_key gives it,
## and every manifest entry's key and clip path are Voice's own.
## Run: godot --headless --path project -s tests/test_voice_manifest.gd

## Loaded in _run, after the autoloads (Voice, Cast) exist: a const preload compiles
## voice_review.gd before them under -s and fails ('Identifier not found: Voice').
var VoiceReview: GDScript
var VoiceScript: GDScript
const MANIFEST := "res://audio/voice/manifest.json"
## The speakers tools/export_voice_lines.py left out; named so the test fails if a source is lost.
const ADDED := ["oprah", "crab", "gull", "dolphin", "mermaid", "pony", "polar_bear_clone", "silverman", "warren", "richter"]

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	VoiceReview = load("res://scripts/test/voice_review.gd")
	VoiceScript = load("res://scripts/autoload/voice.gd")
	await process_frame
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var manifest: Array = parsed if parsed is Array else []
	_check(not manifest.is_empty(), "the manifest loads (%d lines)" % manifest.size())
	var speakers := {}
	var keys := {}
	var bad_keys := 0
	for e: Variant in manifest:
		if not e is Dictionary:
			bad_keys += 1
			continue
		var speaker := str(e.get("speaker", ""))
		var text := str(e.get("text", ""))
		speakers[speaker] = true
		keys[str(e.get("key", ""))] = true
		if str(e.get("key", "")) != VoiceScript.line_key(speaker, text) or str(e.get("clip", "")) != VoiceScript.clip_path(speaker, text):
			bad_keys += 1
			print("  bad entry: %s: %s" % [speaker, text])
	_check(bad_keys == 0, "every manifest entry's key and clip are Voice.line_key / clip_path (%d wrong)" % bad_keys)

	var roster: Array = VoiceReview.build_roster()
	_check(roster.size() > 10, "the game's speakers are found (%d)" % roster.size())
	var found := {}
	for e: Dictionary in roster:
		var speaker: String = e["speaker"]
		var spoken := 0
		var missing: Array = []
		for l: Dictionary in e["lines"]:
			if VoiceScript.spoken_text(String(l["text"])) == "":
				continue  # sounds only ("[Mrrh.]"): Voice plays a vocalization, no clip
			spoken += 1
			if not keys.has(String(l["key"])):
				missing.append(String(l["text"]))
		if spoken == 0:
			continue
		found[speaker] = true
		_check(speakers.has(speaker), "%s (%d lines) is in the manifest" % [speaker, spoken])
		_check(missing.is_empty(), "all %d of %s's lines are in the manifest (%d missing%s)"
			% [spoken, speaker, missing.size(), (": " + String(missing[0])) if not missing.is_empty() else ""])
	for s: String in ADDED:
		_check(found.has(s) and speakers.has(s), "%s speaks and is in the manifest" % s)
	_check(not speakers.has("Oprah Winfrey") and speakers.has("oprah"), "Oprah's clips are keyed by her speaker id, oprah")

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)
