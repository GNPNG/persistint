extends Node
## WorldState — single source of truth for quest flags, world variables, and outfit.
## NPC barks and dialogue conditions all read from here; dialogue mutations write here.

## The save (GC-07) is {"schema": SCHEMA, "flags": {...}}. It is written to <save>.tmp and renamed
## over the save, so a crash mid-write leaves the old save whole; the previous save is copied to
## <save>.bak first. A save that cannot be read (empty, cut short, not JSON, or from a newer
## schema) is moved aside to <save>.corrupt or <save>.newer, never overwritten, and the game loads
## the backup instead, or starts fresh when that fails too; load_report says which, and the main
## menu tells the player. A bare flags dictionary (saves before the schema) loads as schema 0.

signal flag_changed(key: String, value: Variant)
## Emitted after each successful write; the "Saved" indicator listens.
signal saved

const SCHEMA := 1
## Seconds the "Saved" indicator stays up, and the least time between two showings.
const SAVED_SHOW_SECONDS := 1.2
const SAVED_MIN_INTERVAL := 4.0

## A var so headless tests can point it at a temp file instead of the player's real save.
var SAVE_PATH := "user://save.json"
## A headless test run (godot -s tests/<name>.gd) uses this save, emptied at start, so no test
## reads or writes the player's save (QA-04, sops/09).
const TEST_SAVE_PATH := "user://test_run_save.json"

var flags: Dictionary = {}
## Outcome of the last load_save(): "" (loaded, or no save yet), "recovered" (the save was
## unreadable, the backup loaded), "fresh" (neither could be read), "newer" (the save is from a
## newer schema; the backup loaded if it could, otherwise fresh), "imported" (a save file was loaded
## from Settings, GC-13).
var load_report := ""

var _saved_label: Label
var _saved_at := -INF


func _ready() -> void:
	if running_tests():
		SAVE_PATH = TEST_SAVE_PATH
		for suffix in ["", ".tmp", ".bak", ".corrupt", ".newer"]:
			if FileAccess.file_exists(SAVE_PATH + suffix):
				DirAccess.remove_absolute(_abs(SAVE_PATH + suffix))
	load_save()
	_add_saved_indicator()
	saved.connect(_show_saved)


## True when the main loop is a script under tests/ (godot -s tests/<name>.gd).
static func running_tests() -> bool:
	var args := OS.get_cmdline_args()
	for i in args.size() - 1:
		if args[i] in ["-s", "--script"] and "tests/" in args[i + 1].replace("\\", "/"):
			return true
	return false


func get_flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)


func set_flag(key: String, value: Variant) -> void:
	flags[key] = value
	flag_changed.emit(key, value)
	save()


func has_flag(key: String) -> bool:
	return flags.has(key) and bool(flags[key])


## True only if every key in conditions matches the current flag state.
func matches(conditions: Dictionary) -> bool:
	for key in conditions:
		if get_flag(key) != conditions[key]:
			return false
	return true


func reset() -> void:
	flags = {}
	save()


## Writes the flags: temp file, read back, copy the current save to the backup, rename over.
func save() -> void:
	var text := JSON.stringify({"schema": SCHEMA, "flags": flags})
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("save: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_string(tmp) != text:
		push_warning("save: %s did not read back; the save is unchanged" % tmp)
		DirAccess.remove_absolute(_abs(tmp))
		return
	if FileAccess.file_exists(SAVE_PATH):
		var err := DirAccess.copy_absolute(_abs(SAVE_PATH), _abs(backup_path()))
		if err != OK:
			push_warning("save: backup failed (%s)" % error_string(err))
	var moved := DirAccess.rename_absolute(_abs(tmp), _abs(SAVE_PATH))
	if moved != OK:
		push_warning("save: rename over %s failed (%s)" % [SAVE_PATH, error_string(moved)])
		DirAccess.remove_absolute(_abs(tmp))
		return
	saved.emit()


func backup_path() -> String:
	return SAVE_PATH + ".bak"


func load_save() -> void:
	load_report = ""
	if not FileAccess.file_exists(SAVE_PATH) and not FileAccess.file_exists(backup_path()):
		return  # first run
	var main := _read(SAVE_PATH)
	if main["state"] == "ok":
		flags = main["flags"]
		return
	# The save is missing, unreadable or newer: keep it aside and fall back to the backup.
	if FileAccess.file_exists(SAVE_PATH):
		var aside := SAVE_PATH + (".newer" if main["state"] == "newer" else ".corrupt")
		DirAccess.rename_absolute(_abs(SAVE_PATH), _abs(aside))
	var bak := _read(backup_path())
	if bak["state"] == "ok":
		flags = bak["flags"]
		load_report = "newer" if main["state"] == "newer" else "recovered"
		DirAccess.copy_absolute(_abs(backup_path()), _abs(SAVE_PATH))  # the backup stays as it is
	else:
		flags = {}
		load_report = "newer" if main["state"] == "newer" else "fresh"


## What the main menu tells the player after load_save(); "" when there is nothing to say.
func load_report_text() -> String:
	match load_report:
		"recovered":
			return "Your last save could not be read, so the game picked up from the save before it."
		"fresh":
			return "Your save could not be read and there was no backup to use, so this is a new game. The old file is kept."
		"newer":
			return "Your save comes from a newer version of the game. It is kept unchanged; this version uses %s." % (
				"the save before it" if not flags.is_empty() else "a new game")
		"imported":
			return "Save loaded from the file. Your previous save is kept as the backup."
	return ""


## --- Web save persistence and save files (GC-13) ---
## In a browser user:// lives in IndexedDB, which a private window, blocked site data or an embed
## without third-party cookies does not keep; the player is told, and can keep the save as a file.

## Tests set this to see the warning on a desktop, where user:// always persists.
var pretend_not_persistent := false


func userfs_persistent() -> bool:
	return OS.is_userfs_persistent() and not pretend_not_persistent


## What the main menu and the settings screen say when saves will not survive the tab.
func persistence_warning_text() -> String:
	if userfs_persistent():
		return ""
	return "This browser is not keeping saves (a private window, or site storage turned off), so progress ends when the page closes. Settings > Export save keeps it as a file."


## The save as a file's text, the same shape as the save itself.
func export_text() -> String:
	return JSON.stringify({"schema": SCHEMA, "flags": flags}, "\t")


func export_file_name() -> String:
	return "persistint-save-%s.json" % Time.get_date_string_from_system()


## Loads a save file's text in place of the current flags and saves it (so the current save goes
## to the backup first). Returns "" when it worked, otherwise a message for the player; a file that
## cannot be read changes nothing.
func import_text(text: String) -> String:
	var got := _parse(text)
	match got["state"]:
		"ok":
			flags = got["flags"]
			save()
			load_report = "imported"
			return ""
		"newer":
			return "That save file comes from a newer version of the game, so this version can't load it."
	return "That file isn't a PERSISTINT save, or it is damaged. Nothing was changed."


## {"state": "ok" | "missing" | "bad" | "newer", "flags": Dictionary}
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"state": "missing", "flags": {}}
	return _parse(FileAccess.get_file_as_string(path))


func _parse(text: String) -> Dictionary:
	var json := JSON.new()  # an instance, so a bad save is reported here, not as an engine error
	if json.parse(text) != OK:
		return {"state": "bad", "flags": {}}
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return {"state": "bad", "flags": {}}
	if not parsed.has("schema"):
		return {"state": "ok", "flags": parsed}  # schema 0: the bare flags dictionary
	var schema: Variant = parsed["schema"]
	if not (schema is float or schema is int) or not parsed.get("flags") is Dictionary:
		return {"state": "bad", "flags": {}}
	if int(schema) > SCHEMA:
		return {"state": "newer", "flags": {}}
	return {"state": "ok", "flags": parsed["flags"]}


func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)


## A small "Saved" note at the bottom left that fades, at most once every SAVED_MIN_INTERVAL s
## (flags change often), so the player can tell the game saved.
func _add_saved_indicator() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SavedLayer"
	layer.layer = 99
	add_child(layer)
	_saved_label = Label.new()
	_saved_label.name = "Saved"
	_saved_label.text = "Saved"
	_saved_label.add_theme_font_size_override("font_size", 8)
	_saved_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_saved_label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.15, 0.9))
	_saved_label.add_theme_constant_override("outline_size", 3)
	_saved_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_saved_label.position += Vector2(8, -16)
	_saved_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_saved_label.modulate.a = 0.0
	layer.add_child(_saved_label)


func _show_saved() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _saved_at < SAVED_MIN_INTERVAL or not is_inside_tree():
		return
	_saved_at = now
	_saved_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(SAVED_SHOW_SECONDS)
	tween.tween_property(_saved_label, "modulate:a", 0.0, 0.4)


## True while the "Saved" note is showing (for checks).
func saved_showing() -> bool:
	return _saved_label != null and _saved_label.modulate.a > 0.0
