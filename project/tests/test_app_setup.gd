extends SceneTree
## Project setup items from the release checklist (sops/09):
##   GC-05 the bus layout has Master, Music, Voice, Clones (into Voice) and SFX, and every
##         AudioStreamPlayer node in a scene names its bus (none left on Master by default);
##   GC-10 name, version, description, icon and boot splash are set, and the files exist;
##   BD-03 the version is SemVer and the main menu shows it.
## Run: godot --headless --path project -s tests/test_app_setup.gd

const MENU := "res://scenes/ui/main_menu.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame

	# --- GC-05 buses. ---
	for bus: String in ["Master", "Music", "Voice", "Clones", "SFX"]:
		_check(AudioServer.get_bus_index(bus) >= 0, "bus %s exists" % bus)
	_check(AudioServer.get_bus_send(AudioServer.get_bus_index("Clones")) == &"Voice", "Clones sends into Voice")
	var unbused: Array[String] = []
	for path in _files("res://scenes", ".tscn"):
		var text := FileAccess.get_file_as_string(path)
		var blocks := text.split("\n[")
		for b in blocks:
			if b.begins_with("node ") and "type=\"AudioStreamPlayer" in b.get_slice("\n", 0):
				if not "\nbus = " in b:
					unbused.append("%s:%s" % [path.get_file(), b.get_slice("name=\"", 1).get_slice("\"", 0)])
	_check(unbused.is_empty(), "every AudioStreamPlayer in a scene names its bus (%s)" % ", ".join(unbused))

	# --- GC-10 application metadata. ---
	for key: String in ["application/config/name", "application/config/version", "application/config/description"]:
		_check(str(ProjectSettings.get_setting(key, "")).strip_edges() != "", "%s is set" % key)
	var icon: String = ProjectSettings.get_setting("application/config/icon", "")
	_check(icon != "" and icon != "res://icon.svg" and ResourceLoader.exists(icon), "the app icon is set and exists (%s)" % icon)
	var splash: String = ProjectSettings.get_setting("application/boot_splash/image", "")
	_check(splash != "" and FileAccess.file_exists(splash), "the boot splash is set and exists (%s)" % splash)

	# --- GC-06 input actions: every control is a named action in project settings, and no
	# script tests raw key codes or mouse buttons. ---
	for action: String in ["move_left", "move_right", "move_up", "move_down", "toggle_wardrobe",
			"toggle_journal", "dismount", "toggle_fullscreen", "click", "interact"]:
		_check(ProjectSettings.has_setting("input/" + action) and not InputMap.action_get_events(action).is_empty(), "input action %s is in project settings with a binding" % action)
	var raw := RegEx.create_from_string("\\b(KEY_[A-Z0-9_]+|MOUSE_BUTTON_[A-Z]+|JOY_[A-Z0-9_]+)\\b|\\.(physical_)?keycode\\b")
	var raw_hits: Array[String] = []
	for path in _files("res://scripts", ".gd").filter(func(p: String) -> bool: return not p.ends_with("autoload/controls.gd")):  # key remapping owns key events
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			if not line.strip_edges().begins_with("#") and raw.search(line):
				raw_hits.append("%s:%d" % [path.trim_prefix("res://"), n])
	_check(raw_hits.is_empty(), "no script tests raw key codes or mouse buttons (%s)" % ", ".join(raw_hits))
	var wardrobe := InputEventKey.new()
	wardrobe.keycode = KEY_P
	wardrobe.pressed = true
	_check(wardrobe.is_action_pressed("toggle_wardrobe"), "P is the wardrobe")
	var left := InputEventKey.new()
	left.physical_keycode = KEY_A
	left.pressed = true
	_check(left.is_action_pressed("move_left"), "A (by position) moves left")

	# --- BD-03 version. ---
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	var semver := RegEx.create_from_string("^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)(-[0-9A-Za-z.-]+)?(\\+[0-9A-Za-z.-]+)?$")
	_check(semver.search(version) != null, "the version is SemVer (%s)" % version)
	change_scene_to_file(MENU)
	await process_frame
	await process_frame
	var label := current_scene.get_node_or_null("Version") as Label
	_check(label != null and label.text.begins_with("v" + version), "the main menu shows the version (%s)" % (label.text if label else "none"))

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)


func _files(dir: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(d), ext))
	return out


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
