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
