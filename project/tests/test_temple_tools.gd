extends SceneTree
## Run both temple art-tool regressions in the standard suite (bd l462).
## Uses the paper-doll wrapper's interpreter order. Missing Pillow, NumPy or
## ImageMagick fails unless PERSISTINT_SKIP_ART_TESTS=1; real test failures never skip.
const SKIP_VAR := "PERSISTINT_SKIP_ART_TESTS"
const ORDER := "ART_PYTHON if set, else ~/.local/share/persistint/art-venv, else the repo's .venv, else python3 on PATH"
const ART_VENV := ".local/share/persistint/art-venv"
const REPO_VENV := ".venv"
const VENV_PYTHONS: Array[String] = ["bin/python3", "bin/python", "Scripts/python.exe"]
const TESTS: Array[String] = ["test_temple_strips.py", "test_temple_tiles.py"]


func _init() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var python := ""
	var tried: Array[String] = []
	for py: String in _pythons(root_dir):
		var probe: Array = []
		var code := OS.execute(py, ["-I", "-B", "-c", "import PIL, numpy"], probe, true)
		if code == 0:
			python = py
			break
		tried.append("%s (dependency probe exit %d)" % [py, code])
	if python == "":
		_unavailable("no Python with Pillow and NumPy; looked for %s; tried %s" % [ORDER, ", ".join(PackedStringArray(tried))])
		return
	var magick: Array = []
	if OS.execute("magick", ["-version"], magick, true) != 0:
		_unavailable("ImageMagick's magick executable is unavailable on PATH")
		return
	print("python: %s" % python)
	var failures := 0
	for test: String in TESTS:
		var out: Array = []
		var code := OS.execute(python, ["-I", "-B", root_dir.path_join("tools").path_join(test)], out, true)
		print("== %s" % test)
		print("\n".join(out))
		if code != 0:
			failures += 1
			print("FAIL: %s (exit %d)" % [test, code])
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)


func _unavailable(why: String) -> void:
	if OS.get_environment(SKIP_VAR) == "1":
		print("SKIP: %s (%s=1); temple art tools not checked" % [why, SKIP_VAR])
		print("RESULT: PASS (0 failures)")
		quit(0)
		return
	print("FAIL: %s" % why)
	print("Install Pillow and NumPy in an art Python, and ImageMagick on PATH; set ART_PYTHON if needed.")
	print("RESULT: FAIL (1 failures)")
	quit(1)


## The interpreters to try, in ORDER: ART_PYTHON alone when it is set; else the python of each venv
## that exists (the art venv in the home folder, then the repo's), then python3 on PATH.
func _pythons(root_dir: String) -> Array[String]:
	var found: Array[String] = []
	var art := OS.get_environment("ART_PYTHON")
	if art != "":
		found.append(art)
		return found
	var home := OS.get_environment("HOME")
	if home == "":
		home = OS.get_environment("USERPROFILE")
	var venvs: Array[String] = [root_dir.path_join(REPO_VENV)]
	if home != "":
		venvs.push_front(home.path_join(ART_VENV))
	for venv: String in venvs:
		for rel: String in VENV_PYTHONS:
			if FileAccess.file_exists(venv.path_join(rel)):
				found.append(venv.path_join(rel))
				break
	found.append("python3")
	return found
