extends SceneTree
## Character pipeline Node regressions are release gates; missing tools fail.
func _init() -> void:
	var root := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var directory := root.path_join("tools/doll")
	var tests: Array[String] = []
	for file: String in DirAccess.get_files_at(directory):
		if file.begins_with("test_") and file.ends_with(".mjs"):
			tests.append(file)
	tests.sort()
	var failures := 0
	if tests.is_empty():
		print("FAIL: no tools/doll/test_*.mjs found")
		failures += 1
	for test: String in tests:
		var output: Array = []
		var code := OS.execute("node", [directory.path_join(test)], output, true)
		print("== %s" % test)
		print("\n".join(output))
		if code != 0:
			print("FAIL: %s (exit %d)" % [test, code])
			failures += 1
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
