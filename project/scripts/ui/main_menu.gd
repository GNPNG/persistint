extends Control
## Main menu — New Game (fresh flags); Continue only when there is a save to continue.

const FIRST_MAP := "res://scenes/maps/village.tscn"


func _ready() -> void:
	$Center/VBox/BeginButton.pressed.connect(_on_begin)
	$Center/VBox/NewButton.pressed.connect(_on_new_game)
	$Center/VBox/BeginButton.visible = WorldState.get_flag("_location") is Dictionary
	_add_version_label()


## Version from project.godot application/config/version (stamped from VERSION by tools/version.py).
func _add_version_label() -> void:
	var label := Label.new()
	label.name = "Version"
	label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	label.add_theme_font_size_override("font_size", 8)
	label.modulate = Color(1, 1, 1, 0.6)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	label.position -= Vector2(36, 14)
	add_child(label)


func _on_begin() -> void:
	var loc: Variant = WorldState.get_flag("_location")
	if loc is Dictionary and ResourceLoader.exists(loc.get("scene", "")):
		SceneRouter.goto_map(loc["scene"], loc.get("spawn", "spawn_default"))
	else:
		SceneRouter.goto_map(FIRST_MAP, "spawn_default")


func _on_new_game() -> void:
	WorldState.reset()
	GameClock.restore()
	SceneRouter.goto_map(FIRST_MAP, "spawn_default")
