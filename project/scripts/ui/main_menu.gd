extends Control
## Main menu — New Game (fresh flags); Continue only when there is a save to continue.
## Help & Support opens the support page on the site in the system browser. Settings opens the
## volume sliders (AudioSettings). At the bottom, the copyright lines and Credits & Licences, which
## opens the credits screen (scenes/ui/credits.tscn, data/credits.json) over the menu.

const FIRST_MAP := "res://scenes/maps/village.tscn"
const SUPPORT_URL := "https://persistint.dataglut.org/support.html"


func _ready() -> void:
	%BeginButton.pressed.connect(_on_begin)
	%NewButton.pressed.connect(_on_new_game)
	%SupportButton.pressed.connect(_on_support)
	%SettingsButton.pressed.connect(AudioSettings.open)
	%CreditsButton.pressed.connect($Credits.open)
	%BeginButton.visible = WorldState.get_flag("_location") is Dictionary
	_add_version_label()
	_add_save_notice()
	move_child($Credits, -1)  # over the version label too


## A Fullscreen button under the others (touch-first: no key needed); F toggles it too. On the
## web the browser only allows fullscreen from a tap or key press, which both of these are.
func _add_fullscreen_button() -> void:
	var b := Button.new()
	b.name = "FullscreenButton"
	b.text = "Fullscreen"
	b.pressed.connect(toggle_fullscreen)
	$Center/VBox.add_child(b)
	$Center/VBox.move_child(b, $Center/VBox/SupportButton.get_index() + 1)


static func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


static func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		toggle_fullscreen()


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


## When the save could not be read at start (WorldState.load_report, GC-07), or the browser is not
## keeping saves (GC-13), say so at the top of the menu instead of quietly starting over.
func _add_save_notice() -> void:
	var lines := [WorldState.load_report_text(), WorldState.persistence_warning_text()].filter(
		func(s: String) -> bool: return s != "")
	var text := "\n".join(lines)
	if text == "":
		return
	var label := Label.new()
	label.name = "SaveNotice"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0.35, 0.05, 0.1, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_left = 40
	label.offset_right = -40
	label.offset_top = 6
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
