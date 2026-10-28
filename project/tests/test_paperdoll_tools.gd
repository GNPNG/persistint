extends SceneTree
## The paper-doll tools' checks (bd lg5w.1): tools/test_paperdoll_tools.py must pass (cut_paperdoll.py
## on small synthetic sheets: the canon frame, the wardrobe sheets' parts placed by their reference
## doll, --sheet; the slots the cutter, gen_player_rig.py, outfits.json and PaperDoll agree on).
## Skipped with a note when numpy, scipy or Pillow is not installed (tools/requirements-art.txt).
## Run: godot --headless --path project -s tests/test_paperdoll_tools.gd

func _init() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("..")
	var out: Array = []
	var code := OS.execute("python3", ["-I", "-B", root_dir.path_join("tools/test_paperdoll_tools.py")], out, true)
	print("\n".join(out))
	if code == 2:
		print("SKIP: numpy, scipy or Pillow not installed; the paper-doll tools not checked")
		print("RESULT: PASS (0 failures)")
		quit(0)
		return
	if code != 0:
		print("FAIL: python3 -I -B tools/test_paperdoll_tools.py (exit %d)" % code)
	print("RESULT: %s (%d failures)" % ["PASS" if code == 0 else "FAIL", 0 if code == 0 else 1])
	quit(0 if code == 0 else 1)
