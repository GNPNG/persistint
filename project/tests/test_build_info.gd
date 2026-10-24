extends SceneTree
## BuildInfo.id(): "" without res://build.json; the id from it when tools/deploy_site.sh wrote it.
## Run: godot --headless --path project -s tests/test_build_info.gd

func _init() -> void:
	var fails := 0
	var had := FileAccess.file_exists(BuildInfo.PATH)
	var saved := FileAccess.get_file_as_string(BuildInfo.PATH) if had else ""
	if not had and BuildInfo.id() != "":
		fails += 1; print("FAIL: id without build.json should be empty")
	var f := FileAccess.open(BuildInfo.PATH, FileAccess.WRITE)
	f.store_string('{"build": "abc1234"}\n'); f.close()
	if BuildInfo.id() != "abc1234":
		fails += 1; print("FAIL: id = '%s'" % BuildInfo.id())
	if had:
		f = FileAccess.open(BuildInfo.PATH, FileAccess.WRITE); f.store_string(saved); f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BuildInfo.PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
