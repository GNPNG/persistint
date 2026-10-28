extends Node
## Review builds share the normal export: a test scene under res://scenes/test/ opens when the web
## page is loaded with ?scene=<name> (or the desktop binary runs with `-- --scene=<name>`), instead of
## the studio intro. The Web preset leaves scenes/test/ out of the player build; the playtest scenes
## under res://scenes/playtest/ (the voice review, bd dhn2) ship in it, so ?scene=voice_review works
## on the live site too. Only lower-case names resolve, only under those two folders, so a stray
## query string cannot open anything else.

const TEST_DIR := "res://scenes/test/"
const PLAYTEST_DIR := "res://scenes/playtest/"


func _ready() -> void:
	var name := requested_scene()
	if name.is_empty():
		return
	var path := path_for(name)
	if path.is_empty():
		push_warning("DevScene: no test or playtest scene named %s" % name)
		return
	get_tree().change_scene_to_file.call_deferred(path)


## The requested test scene name, or "" when none (or an unusable one) was asked for.
func requested_scene() -> String:
	var raw := ""
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("new URLSearchParams(location.search).get('scene') || ''", true)
		raw = str(v) if v != null else ""
	else:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--scene="):
				raw = a.trim_prefix("--scene=")
	return sanitize(raw)


## The scene a sanitized name opens: scenes/test/<name>.tscn, else scenes/playtest/<name>.tscn,
## else "" (none there, or no name).
static func path_for(name: String) -> String:
	if name.is_empty():
		return ""
	for dir: String in [TEST_DIR, PLAYTEST_DIR]:
		if ResourceLoader.exists(dir + name + ".tscn"):
			return dir + name + ".tscn"
	return ""


static func sanitize(raw: String) -> String:
	var s := raw.strip_edges().trim_prefix("test/").trim_suffix(".tscn")
	var re := RegEx.new()
	re.compile("^[a-z0-9_]{1,40}$")
	return s if re.search(s) != null else ""
