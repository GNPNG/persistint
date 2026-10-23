extends Node
## WorldState — single source of truth for quest flags, world variables, and outfit.
## NPC barks and dialogue conditions all read from here; dialogue mutations write here.

signal flag_changed(key: String, value: Variant)

## A var so headless tests can point it at a temp file instead of the player's real save.
var SAVE_PATH := "user://save.json"

var flags: Dictionary = {}


func _ready() -> void:
	load_save()


func get_flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)


func set_flag(key: String, value: Variant) -> void:
	flags[key] = value
	flag_changed.emit(key, value)
	save()


func has_flag(key: String) -> bool:
	return flags.has(key) and bool(flags[key])


## True only if every key in conditions matches the current flag state.
func matches(conditions: Dictionary) -> bool:
	for key in conditions:
		if get_flag(key) != conditions[key]:
			return false
	return true


func reset() -> void:
	flags = {}
	save()


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(flags))


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			flags = parsed
