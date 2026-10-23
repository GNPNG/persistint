extends Node
## Cast — character names from data/cast.json, the only place names are spelled.
## Dialogue uses {{Cast.full("initiate")}} / {{Cast.short("initiate")}}; NPCs look up by npc_id.

const CAST_PATH := "res://data/cast.json"

var _cast: Dictionary = {}


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAST_PATH))
	if parsed is Dictionary:
		_cast = parsed


func full(id: String) -> String:
	return _cast.get(id, {}).get("name", id)


func short(id: String) -> String:
	return _cast.get(id, {}).get("short", full(id))
