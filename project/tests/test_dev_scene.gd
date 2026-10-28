extends SceneTree
## DevScene: the query-string / --scene= name is sanitised to a safe file name, and opens a scene
## from scenes/test/ or, failing that, scenes/playtest/ (the voice review ships in the player build,
## bd dhn2); any other name opens nothing.

func _init() -> void:
	var S = load("res://scripts/autoload/dev_scene.gd")
	var ok := true
	ok = _eq(S.sanitize("paper_look"), "paper_look") and ok
	ok = _eq(S.sanitize(" test/voice_review.tscn "), "voice_review") and ok
	ok = _eq(S.sanitize("../ui/main_menu"), "") and ok
	ok = _eq(S.sanitize("playtest/../ui/main_menu"), "") and ok
	ok = _eq(S.sanitize("Paper Look"), "") and ok
	ok = _eq(S.sanitize(""), "") and ok
	ok = _eq(S.sanitize("x".repeat(41)), "") and ok
	ok = _check(S.path_for("voice_review") == "res://scenes/playtest/voice_review.tscn", "voice_review opens from scenes/playtest/ (%s)" % S.path_for("voice_review")) and ok
	ok = _check(S.path_for("paper_look") == "res://scenes/test/paper_look.tscn", "paper_look still opens from scenes/test/ (%s)" % S.path_for("paper_look")) and ok
	ok = _check(S.path_for("main_menu") == "" and S.path_for("") == "", "a name with no scene in those folders opens nothing") and ok
	# Autoloads join the tree after _init, so the live check waits one frame.
	process_frame.connect(func():
		var ds = root.get_node_or_null("DevScene")
		ok = _check(ds != null, "DevScene autoload present") and ok
		ok = _check(ds != null and ds.requested_scene() == "", "no scene requested in tests") and ok
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1), CONNECT_ONE_SHOT)

func _eq(got: String, want: String) -> bool:
	return _check(got == want, "sanitize -> '%s' (want '%s')" % [got, want])

func _check(c: bool, what: String) -> bool:
	print(("  ok   " if c else "  FAIL ") + what)
	return c
