extends Node
## Playtest — the author's playtest mode (bd dhn2). Off until the three hearts at the bottom of
## the settings screen are tapped in their order (settings.gd); on, Settings shows a Playtest row:
## Voice review, Export playtest, Playtest off. Kept in user://settings.cfg [playtest] enabled,
## beside the audio levels and the text size, so it stays on across reloads.
## Export playtest hands back one file for tools/ingest_voice_ratings.mjs: {"kind", "exported_at",
## "version", "build", "voice_review"} with the voice review's saved verdicts in voice_review.

signal changed(on: bool)

const SECTION := "playtest"
const KEY := "enabled"
const KIND := "persistint-playtest"
## By path, like TextDownload: no autoload leans on the class cache (headless tests).
const BuildInfoScript := preload("res://scripts/util/build_info.gd")

## Vars so headless tests can point them at temp files instead of the player's real settings and
## the author's review (the voice review keeps its verdicts at its own save_path, the same file).
var SETTINGS_PATH := "user://settings.cfg"
var REVIEW_PATH := "user://voice_review.json"

var _on := false


func _ready() -> void:
	if WorldState.running_tests():  # QA-04: the test settings file Music emptied at start
		SETTINGS_PATH = WorldState.TEST_SETTINGS_PATH
	load_settings()


func enabled() -> bool:
	return _on


## Turns playtest mode on or off and saves it.
func set_enabled(on: bool) -> void:
	_on = on
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep the audio levels and the text size in the same file
	cfg.set_value(SECTION, KEY, on)
	cfg.save(SETTINGS_PATH)
	changed.emit(on)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	_on = cfg.load(SETTINGS_PATH) == OK and bool(cfg.get_value(SECTION, KEY, false))


## The playtest export's text: which game it came from, and the voice review's verdicts as the
## review saved them ({} when there are none yet, or the file can't be read).
func export_text() -> String:
	var review: Variant = JSON.parse_string(FileAccess.get_file_as_string(REVIEW_PATH)) if FileAccess.file_exists(REVIEW_PATH) else null
	return JSON.stringify({"kind": KIND, "exported_at": Time.get_datetime_string_from_system(true) + "Z",
		"version": str(ProjectSettings.get_setting("application/config/version", "")), "build": BuildInfoScript.id(),
		"voice_review": review if review is Dictionary else {}}, "\t")


func export_file_name() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "persistint-playtest-%04d%02d%02d-%02d%02d.json" % [t["year"], t["month"], t["day"], t["hour"], t["minute"]]
