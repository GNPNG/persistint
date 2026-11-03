extends SceneTree
## Re-running the asset tools leaves landed renders alone (bd up1u): tools/test_landed_renders.py
## must pass (tools/landed_renders.py's keep(); tools/sync_rendered_assets.py in a scratch git repo
## keeps a game copy keyed after its drop and copies newer drops; the four stand-in generators ask
## keep() before they write). Standard library and git only, so python3 on PATH, as
## tools/run_tests.sh has it.
## Run: godot --headless --path project -s tests/test_landed_renders.gd


func _init() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var out: Array = []
	var code := OS.execute("python3", ["-I", "-B", root_dir.path_join("tools/test_landed_renders.py")], out, true)
	print("\n".join(out))
	if code != 0 and code != 1:
		print("FAIL: python3 tools/test_landed_renders.py did not run (exit %d; is python3 on PATH?)" % code)
		print("RESULT: FAIL (1 failures)")
		quit(1)
		return
	if code != 0:
		print("FAIL: python3 tools/test_landed_renders.py (exit %d)" % code)
	quit(code)
