extends SceneTree
## The paper-doll tools' checks (bd lg5w.1): tools/test_paperdoll_tools.py must pass (cut_paperdoll.py
## on small synthetic sheets: the canon frame, the wardrobe sheets' parts placed by their reference
## doll, --sheet; the slots the cutter, gen_player_rig.py, outfits.json and PaperDoll agree on).
## They need the art tools' Python, one with numpy, scipy and Pillow (tools/requirements-art.txt)
## (bd gd37): ART_PYTHON when it is set (only that one), else the repo's .venv, else python3 on
## PATH, the first that has them. The log names the one that ran. When none has them the test
## FAILS; PERSISTINT_SKIP_ART_TESTS=1 makes that a SKIP (README, "Running the tests").
## Run: godot --headless --path project -s tests/test_paperdoll_tools.gd

const SKIP_VAR := "PERSISTINT_SKIP_ART_TESTS"
const VENV_PYTHONS: Array[String] = [".venv/bin/python3", ".venv/bin/python", ".venv/Scripts/python.exe"]


func _init() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var script := root_dir.path_join("tools/test_paperdoll_tools.py")
	var tried: Array[String] = []
	for py: String in _pythons(root_dir):
		var out: Array = []
		var code := OS.execute(py, ["-I", "-B", script], out, true)
		if code == 0 or code == 1:
			print("\n".join(out))
			print("python: %s" % py)
			if code != 0:
				print("FAIL: %s -I -B tools/test_paperdoll_tools.py (exit %d)" % [py, code])
			print("RESULT: %s (%d failures)" % ["PASS" if code == 0 else "FAIL", code])
			quit(code)
			return
		# Exit 2: the script found no numpy, scipy or Pillow; anything else: it did not run.
		tried.append("%s (%s)" % [py, "no numpy, scipy or Pillow" if code == 2 else "did not run, exit %d" % code])
	var why := "no Python with numpy, scipy and Pillow for the paper-doll tools; tried %s" % ", ".join(tried)
	if OS.get_environment(SKIP_VAR) == "1":
		print("SKIP: %s (%s=1); the paper-doll tools not checked" % [why, SKIP_VAR])
		print("RESULT: PASS (0 failures)")
		quit(0)
		return
	print("FAIL: %s" % why)
	print("      Set ART_PYTHON to the art venv's python, or make the repo's .venv:")
	print("      python3 -m venv .venv && .venv/bin/pip install -r tools/requirements-art.txt")
	print("      (%s=1 skips these checks instead)" % SKIP_VAR)
	print("RESULT: FAIL (1 failures)")
	quit(1)


## The interpreters to try, in order: ART_PYTHON alone when it is set, else the repo's .venv (when
## there is one) and python3 on PATH.
func _pythons(root_dir: String) -> Array[String]:
	var found: Array[String] = []
	var art := OS.get_environment("ART_PYTHON")
	if art != "":
		found.append(art)
		return found
	for rel: String in VENV_PYTHONS:
		if FileAccess.file_exists(root_dir.path_join(rel)):
			found.append(root_dir.path_join(rel))
			break
	found.append("python3")
	return found
