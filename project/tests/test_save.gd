extends SceneTree
## Headless check of the save (GC-07, sops/09): a save carries its schema version; a write goes
## through <save>.tmp and leaves none behind; the previous save is kept in <save>.bak; a save from
## before the schema loads with its flags; a truncated, empty or non-JSON save is moved aside and
## the backup loads ("recovered") without the backup being overwritten; with no usable backup the
## game starts fresh ("fresh") and keeps the bad file; a newer-schema save is kept unchanged
## ("newer"); the main menu shows the notice; each write emits saved and shows the "Saved" note.
## Run: godot --headless --path project -s tests/test_save.gd
## WorldState saves to a temp file for the run; the player's real save is never touched.

const TEMP_SAVE := "user://test_save_save.json"
const MENU := "res://scenes/ui/main_menu.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	var real_save: String = ws.SAVE_PATH
	var real_flags: Dictionary = ws.flags.duplicate(true)
	ws.SAVE_PATH = TEMP_SAVE
	_clean(ws)

	# --- Writing: schema, temp file gone, backup of the previous save. ---
	var heard := [0]
	ws.saved.connect(func() -> void: heard[0] += 1)
	ws.flags = {"a": 1}
	ws.save()
	var first := FileAccess.get_file_as_string(TEMP_SAVE)
	var parsed: Variant = JSON.parse_string(first)
	_check(parsed is Dictionary and int(parsed.get("schema", -1)) == ws.SCHEMA and _same(parsed.get("flags"), {"a": 1}), "the save carries its schema version and the flags")
	_check(not FileAccess.file_exists(TEMP_SAVE + ".tmp"), "no temp file is left after a save")
	_check(not FileAccess.file_exists(ws.backup_path()), "the first save has no backup yet")
	_check(heard[0] == 1, "a write emits saved")
	_check(ws.saved_showing(), "the Saved note shows after a write")
	ws.set_flag("b", 2)
	_check(FileAccess.get_file_as_string(ws.backup_path()) == first, "the backup holds the previous save")
	_check(_same(JSON.parse_string(FileAccess.get_file_as_string(TEMP_SAVE)).get("flags"), {"a": 1, "b": 2}), "the save holds the new flags")
	var good := FileAccess.get_file_as_string(TEMP_SAVE)

	# --- Loading a save from before the schema (a bare flags dictionary). ---
	_write(TEMP_SAVE, JSON.stringify({"_location": {"scene": "x"}, "comic_done": true}))
	ws.load_save()
	_check(ws.flags.get("comic_done") == true and ws.flags.get("_location") is Dictionary and ws.load_report == "", "a save from before the schema loads its flags, nothing to report")

	# --- A save cut short: moved aside, the backup loads, the backup is not overwritten. ---
	_write(TEMP_SAVE, good)
	ws.set_flag("c", 3)  # backup = good ({a, b}), save = {a, b, c}
	var bak_before := FileAccess.get_file_as_string(ws.backup_path())
	var whole := FileAccess.get_file_as_string(TEMP_SAVE)
	_write(TEMP_SAVE, whole.substr(0, whole.length() / 2))
	ws.load_save()
	_check(ws.load_report == "recovered" and _same(ws.flags, {"a": 1, "b": 2}), "a truncated save falls back to the backup and reports it")
	_check(FileAccess.file_exists(TEMP_SAVE + ".corrupt"), "the truncated save is kept aside as .corrupt")
	_check(FileAccess.get_file_as_string(ws.backup_path()) == bak_before, "recovery leaves the backup as it was")
	_check(ws.load_report_text() != "", "there is a message for the player")
	_check(await _menu_notice() == ws.load_report_text(), "the main menu shows the message")

	# --- An empty save and a broken backup: a fresh game, the bad file kept. ---
	_write(TEMP_SAVE, "")
	_write(ws.backup_path(), "{\"schema\": 1, \"fla")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE + ".corrupt"))
	ws.load_save()
	_check(ws.load_report == "fresh" and ws.flags.is_empty(), "an empty save with a broken backup starts fresh and reports it")
	_check(FileAccess.file_exists(TEMP_SAVE + ".corrupt"), "the empty save is kept aside")
	_check(not "{" in ws.load_report_text() and ws.load_report_text() != "", "the fresh-start message is plain words")

	# --- A save from a newer version: kept unchanged, reported. ---
	_clean(ws)
	var newer := JSON.stringify({"schema": ws.SCHEMA + 1, "flags": {"z": 9}})
	_write(TEMP_SAVE, newer)
	ws.load_save()
	_check(ws.load_report == "newer" and ws.flags.is_empty(), "a newer-schema save is reported and not loaded")
	_check(FileAccess.get_file_as_string(TEMP_SAVE + ".newer") == newer, "the newer save is kept byte for byte")
	ws.set_flag("d", 4)
	_check(FileAccess.get_file_as_string(TEMP_SAVE + ".newer") == newer, "playing on does not touch the newer save")

	# --- Not JSON at all, no backup. ---
	_clean(ws)
	_write(TEMP_SAVE, "not json")
	ws.load_save()
	_check(ws.load_report == "fresh", "a save that is not JSON, with no backup, starts fresh and reports it")

	# --- First run: no files, nothing to report. ---
	_clean(ws)
	ws.load_save()
	_check(ws.load_report == "" and ws.flags.is_empty() and ws.load_report_text() == "", "first run: no save, nothing to report")
	_check(await _menu_notice() == "", "the main menu shows no notice when the save loaded")

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


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


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


## Same keys and equal values (JSON reads numbers back as floats, so 1 and 1.0 count as equal).
func _same(got: Variant, want: Dictionary) -> bool:
	if not got is Dictionary or got.size() != want.size():
		return false
	for k in want:
		if not got.has(k) or got[k] != want[k]:
			return false
	return true
