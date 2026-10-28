extends SceneTree
## The wardrobe landing driver's checks (bd lg5w.2): tools/test_land_wardrobe.mjs must pass
## (tools/land_wardrobe.mjs on small synthetic wardrobe sheets in a temp copy: a dry run changes
## nothing; a run registers the sheets and their parts in paperdoll_parts.json, outfits.json and the
## canon SOURCES.md, once each, and cuts them on the frame; a second run changes nothing; bad parts
## files fail and write nothing). The cut needs the art tools' Python, found as
## tests/test_paperdoll_tools.gd finds it; without one it FAILS unless PERSISTINT_SKIP_ART_TESTS=1
## (then only the cut checks are skipped). Needs node on PATH, as tools/run_tests.sh does.
## Run: godot --headless --path project -s tests/test_land_wardrobe.gd


func _init() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var out: Array = []
	var code := OS.execute("node", [root_dir.path_join("tools/test_land_wardrobe.mjs")], out, true)
	print("\n".join(out))
	if code != 0 and code != 1:
		print("FAIL: node tools/test_land_wardrobe.mjs did not run (exit %d; is node on PATH?)" % code)
		print("RESULT: FAIL (1 failures)")
		quit(1)
		return
	if code != 0:
		print("FAIL: node tools/test_land_wardrobe.mjs (exit %d)" % code)
	quit(code)
