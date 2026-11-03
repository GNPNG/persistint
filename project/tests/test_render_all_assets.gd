extends SceneTree
## The render queue's checks (bd e8e8): tools/test_render_all_assets.py must pass (each prompt's
## aspect comes from its front matter, else the ratio its prompt text states, else its Notes, else
## 16:9; temple_twinkle is 1:1). Standard library only, so python3 on PATH, as tools/run_tests.sh
## has it.
## Run: godot --headless --path project -s tests/test_render_all_assets.gd


func _init() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var out: Array = []
	var code := OS.execute("python3", ["-I", "-B", root_dir.path_join("tools/test_render_all_assets.py")], out, true)
	print("\n".join(out))
	if code != 0 and code != 1:
		print("FAIL: python3 tools/test_render_all_assets.py did not run (exit %d; is python3 on PATH?)" % code)
		print("RESULT: FAIL (1 failures)")
		quit(1)
		return
	if code != 0:
		print("FAIL: python3 tools/test_render_all_assets.py (exit %d)" % code)
	quit(code)
