extends RefCounted
## Hands a text file to the player: in the browser a download (a Blob and a temporary link), on a
## desktop a file in the user data folder. Shared by Settings' Export save and the voice review's
## Export review. Preload it by path (no class_name: headless tests run without the class cache).


## Saves `text` as `file_name`. Returns where it went: "download" in the browser, the absolute
## path on a desktop, or "" when it could not be saved.
static func save(file_name: String, text: String) -> String:
	if OS.has_feature("web"):
		var js := "(function(){var s=%s;var b=new Blob([s],{type:'application/json'});var u=URL.createObjectURL(b);var a=document.createElement('a');a.href=u;a.download=%s;document.body.appendChild(a);a.click();a.remove();setTimeout(function(){URL.revokeObjectURL(u)},2000);return 'ok';})()" % [JSON.stringify(text), JSON.stringify(file_name)]
		return "download" if str(JavaScriptBridge.eval(js, true)) == "ok" else ""
	var path := "user://" + file_name
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	f.close()
	return ProjectSettings.globalize_path(path)
