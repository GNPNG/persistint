extends SceneTree
## The coordination-repository sync's checks (bd uowd): tools/test_sync_agent_channel.mjs must
## pass (tools/sync_agent_channel.mjs against a bare repository and a scratch beads workspace of
## the test's own, in a temp folder; the repository's beads are not touched). Needs node, git and
## bd on PATH, as tools/run_tests.sh has them.
## Run: godot --headless --path project -s tests/test_sync_agent_channel.gd


func _init() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var out: Array = []
	var code := OS.execute("node", [root_dir.path_join("tools/test_sync_agent_channel.mjs")], out, true)
	print("\n".join(out))
	if code != 0 and code != 1:
		print("FAIL: node tools/test_sync_agent_channel.mjs did not run (exit %d; is node on PATH?)" % code)
		print("RESULT: FAIL (1 failures)")
		quit(1)
		return
	if code != 0:
		print("FAIL: node tools/test_sync_agent_channel.mjs (exit %d)" % code)
	quit(code)
