class_name BuildInfo
## The build id (short commit) that tools/deploy_site.sh writes to res://build.json
## ({"build": "<id>"}) before each export; "" in an editor or test run without the file.

const PATH := "res://build.json"


static func id() -> String:
	if not FileAccess.file_exists(PATH):
		return ""
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return str(data.get("build", "")) if data is Dictionary else ""
