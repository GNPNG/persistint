extends SceneTree
## Paper look test scene (1dx): the baked sheets exist on a uniform grid that matches their sidecar,
## the scene builds three columns of the same subjects, the shaders load, and the live settings
## re-apply without error.

const BAKE_DIR := "res://assets/test/paper_look/"
const NAMES := ["tree_a", "tree_b", "flowers", "fence_a", "sign_a", "npc_mother", "player", "npc_initiate"]


func _init() -> void:
	var ok := true
	for n: String in NAMES:
		var side_path: String = BAKE_DIR + n + ".json"
		ok = _check(FileAccess.file_exists(side_path), "sidecar " + n) and ok
		if not FileAccess.file_exists(side_path):
			continue
		var side: Dictionary = JSON.parse_string(FileAccess.open(side_path, FileAccess.READ).get_as_text())
		var frame: Array = side["frame"]
		for key in side["files"]:
			var path: String = BAKE_DIR + String(side["files"][key])
			var tex: Texture2D = load(path)
			var good := tex != null and tex.get_width() == int(frame[0]) * int(side["cols"]) and tex.get_height() == int(frame[1]) * int(side["rows"])
			ok = _check(good, "%s %s is %dx%d frames of %sx%s" % [n, key, side["cols"], side["rows"], frame[0], frame[1]]) and ok
		ok = _check(side["files"].has("edge1_white") and side["files"].has("edge3_cream") and side["files"].has("shadow_soft"), n + " has edge 1-3 in both papers and the shadows") and ok
	for sh in ["res://shaders/paper_flat.gdshader", "res://shaders/pixelate.gdshader"]:
		var s: Shader = load(sh)
		ok = _check(s != null and s.code.length() > 40, "shader loads " + sh) and ok
	var scene: PackedScene = load("res://scenes/test/paper_look.tscn")
	ok = _check(scene != null, "scene loads") and ok
	var inst := scene.instantiate()
	root.add_child(inst)
	# Children of the root become ready after _init, on the first frame; the live checks run then.
	process_frame.connect(_live.bind(inst, ok), CONNECT_ONE_SHOT)


func _live(inst: Node, ok: bool) -> void:
	for c in ["A", "B", "C"]:
		var col := inst.get_node_or_null("Column" + c)
		ok = _check(col != null, "column " + c) and ok
		if col:
			var count := 0
			for ch in col.get_children():
				if ch is Node2D and not ch is Label:
					count += 1
			ok = _check(count == NAMES.size(), "column %s has %d subjects (%d)" % [c, count, NAMES.size()]) and ok
	var b: Array = inst.subjects.filter(func(e): return e["column"] == "B")
	ok = _check(b.size() == NAMES.size() and b[0]["outline"].size() == 8, "B subjects carry eight border copies") and ok
	var cc: Array = inst.subjects.filter(func(e): return e["column"] == "C")
	ok = _check(cc.size() == NAMES.size() and cc.all(func(e): return not e["bake"].is_empty() and e["shadow"] != null), "C subjects use their baked sheets and shadows") and ok
	inst.edge_px = 3
	inst.paper = "cream"
	inst.shadow_soft = false
	inst.filter_linear = true
	inst.walking = true
	inst._apply_all()
	var main: Node2D = cc[0]["sprites"][0]
	ok = _check(main.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "filter switch applies") and ok
	inst.pixelate(cc[0])
	ok = _check(main.material is ShaderMaterial, "tap sets the pixelate material") and ok
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _check(c: bool, what: String) -> bool:
	print(("  ok   " if c else "  FAIL ") + what)
	return c
