extends Control
## Main menu — New Game (fresh flags); Continue only when there is a save to continue.
## Help & Support opens the support page on the site in the system browser. Settings opens the
## volume sliders (AudioSettings).

const FIRST_MAP := "res://scenes/maps/village.tscn"
const SUPPORT_URL := "https://persistint.dataglut.org/support.html"


func _ready() -> void:
	%BeginButton.pressed.connect(_on_begin)
	%NewButton.pressed.connect(_on_new_game)
	%SupportButton.pressed.connect(_on_support)
	%SettingsButton.pressed.connect(AudioSettings.open)
	%BeginButton.visible = WorldState.get_flag("_location") is Dictionary
	_add_version_label()


## Version from project.godot application/config/version (stamped from VERSION by tools/version.py),
## followed by the build id (short commit) that tools/deploy_site.sh writes to res://build.json
## before it exports, so a player can tell which build the site is serving.
func _add_version_label() -> void:
	var label := Label.new()
	label.name = "Version"
	label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	var build := BuildInfo.id()
	if build != "":
		label.text += " · %s" % build
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.55, 1))
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


func _on_support() -> void:
	OS.shell_open(SUPPORT_URL)
