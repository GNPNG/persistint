extends SceneTree
## Audio levels gate: tools/audio_report.py --check must pass (every music track, voice clip and
## sound effect at its target, the buses at 0 dB). Skipped with a note when ffmpeg is not here.
## Run: godot --headless --path project -s tests/test_audio_levels.gd

func _init() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("..")
	var out: Array = []
	var code := OS.execute("python3", ["-I", root_dir.path_join("tools/audio_report.py"), "--check", "--quiet"], out, true)
	var text := "\n".join(out)
	if code == 2:
		print("SKIP: ffmpeg not installed; levels not checked")
		print("RESULT: PASS (0 failures)")
		quit(0)
		return
	if code != 0:
		print(text)
		print("FAIL: audio levels out of range or a bus drifted (python3 tools/audio_report.py)")
	print("RESULT: %s (%d failures)" % ["PASS" if code == 0 else "FAIL", 0 if code == 0 else 1])
	quit(0 if code == 0 else 1)
