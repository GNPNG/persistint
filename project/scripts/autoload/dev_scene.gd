extends Node
## Review builds share the normal export: a test scene under res://scenes/test/ opens when the web
## page is loaded with ?scene=<name> (or the desktop binary runs with `-- --scene=<name>`), instead of
## the studio intro. Only lower-case names resolve, only under scenes/test/, so a stray query string
## cannot open anything else.

const TEST_DIR := "res://scenes/test/"


func _ready() -> void:
	var name := requested_scene()
	if name.is_empty():
		return
	var path := TEST_DIR + name + ".tscn"
	if not ResourceLoader.exists(path):
		push_warning("DevScene: no test scene at %s" % path)
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


static func sanitize(raw: String) -> String:
	var s := raw.strip_edges().trim_prefix("test/").trim_suffix(".tscn")
	var re := RegEx.new()
	re.compile("^[a-z0-9_]{1,40}$")
	return s if re.search(s) != null else ""
