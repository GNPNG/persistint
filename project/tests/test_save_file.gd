extends SceneTree
## Headless check of web save persistence and save files (GC-13, sops/09): when user:// does not
## persist, the main menu and the settings screen say so; Export save produces the save as a file
## (on a desktop, a file in the user data folder; the browser download is checked by hand); Import
## save loads a file in place of the current flags, keeps the previous save as the backup and goes
## back to the main menu, which says it loaded; a damaged, foreign or newer file changes nothing
## and says why.
## Run: godot --headless --path project -s tests/test_save_file.gd
## WorldState saves to a temp file for the run; the player's real save is never touched.

const TEMP_SAVE := "user://test_save_file_save.json"
const MENU := "res://scenes/ui/main_menu.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	var settings_node: Node = root.get_node("/root/AudioSettings")
	var real_save: String = ws.SAVE_PATH
	var real_flags: Dictionary = ws.flags.duplicate(true)
	ws.SAVE_PATH = TEMP_SAVE
	_clean(ws)

	# --- The persistence warning. ---
	_check(ws.persistence_warning_text() == "", "no warning when the browser keeps saves (desktop)")
	ws.pretend_not_persistent = true
	var warning: String = ws.persistence_warning_text()
	_check(warning != "" and "Export save" in warning, "a warning that names Export save when saves are not kept")
	_check(warning in await _menu_notice(), "the main menu shows the warning")
	settings_node.open()
	var screen: Node = settings_node._overlay
	_check(screen.save_status() == warning, "the settings screen shows the warning")
	ws.pretend_not_persistent = false
	settings_node.close()
	settings_node.open()
	_check(screen.save_status() == "", "no warning on the settings screen when saves are kept")
	_check(screen.find_child("ExportButton", true, false) is Button and screen.find_child("ImportButton", true, false) is Button, "the settings screen has Export save and Import save")

	# --- Export. ---
	ws.flags = {"_location": {"scene": "res://scenes/maps/village.tscn", "spawn": "spawn_default"}, "comic_done": true}
	ws.save()
	var parsed: Variant = JSON.parse_string(ws.export_text())
	_check(parsed is Dictionary and int(parsed.get("schema", -1)) == ws.SCHEMA and parsed.get("flags", {}).get("comic_done") == true, "the export is the save with its schema")
	_check(ws.export_file_name().begins_with("persistint-save-") and ws.export_file_name().ends_with(".json"), "the export file is named persistint-save-<date>.json")
	screen.export_save()
	var exported: String = "user://" + ws.export_file_name()
	_check(FileAccess.file_exists(exported) and FileAccess.get_file_as_string(exported) == ws.export_text(), "Export save writes the file (desktop)")
	_check(ProjectSettings.globalize_path(exported) in screen.save_status(), "the status line says where it went")
	var file_text: String = FileAccess.get_file_as_string(exported)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(exported))

	# --- Import: damaged, foreign and newer files change nothing. ---
	var before: String = FileAccess.get_file_as_string(TEMP_SAVE)
	for bad: String in ["", "{\"schema\": 1, \"fla", "<html>not a save</html>", "[1, 2, 3]"]:
		var msg: String = ws.import_text(bad)
		_check(msg != "" and FileAccess.get_file_as_string(TEMP_SAVE) == before and ws.flags.get("comic_done") == true, "a bad file (%s) is refused and changes nothing" % bad.left(12))
	_check("newer" in ws.import_text(JSON.stringify({"schema": ws.SCHEMA + 1, "flags": {}})), "a newer save file is refused with its reason")
	screen.import_from_text("not json")
	_check(screen.save_status() != "" and settings_node.is_open(), "the settings screen shows why a file was refused")

	# --- Import: a good file replaces the flags, the old save becomes the backup, back to the menu. ---
	ws.flags = {"other": 1}
	ws.save()
	var current: String = FileAccess.get_file_as_string(TEMP_SAVE)
	change_scene_to_file(MENU)
	await process_frame
	await process_frame
	screen.import_from_text(file_text)
	await process_frame
	await process_frame
	_check(ws.flags.get("comic_done") == true and not ws.flags.has("other"), "a good file replaces the flags")
	_check(FileAccess.get_file_as_string(ws.backup_path()) == current, "the save before the import is kept as the backup")
	_check(ws.load_report == "imported" and not settings_node.is_open(), "the import closes the settings screen")
	_check(current_scene != null and current_scene.scene_file_path == MENU, "the import goes back to the main menu")
	var notice := current_scene.get_node_or_null("SaveNotice") as Label
	_check(notice != null and notice.text == ws.load_report_text(), "the main menu says the save loaded")
	_check(current_scene.get_node("%BeginButton").visible, "Continue shows for the imported save")
	_check(ws.import_text(JSON.stringify({"a": 1})) == "" and ws.flags.get("a") == 1, "a save file from before the schema imports too")

	_clean(ws)
	ws.SAVE_PATH = real_save
	ws.flags = real_flags
	ws.load_report = ""
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)


## The main menu's save notice text ("" when there is none).
func _menu_notice() -> String:
	var menu: Node = load(MENU).instantiate()
	root.add_child(menu)
	await process_frame
	var label := menu.get_node_or_null("SaveNotice") as Label
	var text := label.text if label else ""
	menu.queue_free()
	await process_frame
	return text


func _clean(ws: Node) -> void:
	for suffix in ["", ".tmp", ".bak", ".corrupt", ".newer"]:
		var p: String = ws.SAVE_PATH + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	ws.flags = {}
	ws.load_report = ""


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
