extends SceneTree
## Text size (QA-06, GC-04): the settings screen's Text row sets Normal, Large or Larger; the theme
## font sizes and every font-size override (a door's name, a label built in code) scale with it,
## back and forth without compounding; the choice is saved; the settings screen still fits on
## screen at Larger, on the main menu and as the pause menu.
## Run: godot --headless --path project -s tests/test_text_size.gd
## The test run uses the test settings file (QA-04).

const MENU := "res://scenes/ui/main_menu.tscn"
const VILLAGE := "res://scenes/maps/village.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ts: Node = root.get_node("/root/TextSize")
	var settings: Node = root.get_node("/root/AudioSettings")
	var theme: Theme = load(ProjectSettings.get_setting("gui/theme/custom"))
	_check(ts.step == 0 and theme.default_font_size == 9, "a fresh start is Normal (theme text 9)")
	var hint0 := theme.get_font_size("font_size", "HintLabel")

	# --- Larger: the theme and overrides scale. ---
	change_scene_to_file(VILLAGE)
	await process_frame
	await process_frame
	var door_label := current_scene.get_node("TempleDoor/Label") as Label
	var door0 := door_label.get_theme_font_size("font_size")
	ts.set_step(2)
	await process_frame
	_check(theme.default_font_size == 14 and theme.get_font_size("font_size", "HintLabel") == int(round(hint0 * 1.5)), "Larger scales the theme (9 -> %d, hint %d -> %d)" % [theme.default_font_size, hint0, theme.get_font_size("font_size", "HintLabel")])
	_check(door_label.get_theme_font_size("font_size") == int(round(door0 * 1.5)), "a door's name scales (%d -> %d)" % [door0, door_label.get_theme_font_size("font_size")])
	var built := Label.new()
	built.add_theme_font_size_override("font_size", 8)
	current_scene.add_child(built)
	_check(built.get_theme_font_size("font_size") == 12, "a label built later comes in scaled (8 -> %d)" % built.get_theme_font_size("font_size"))

	# --- The settings screen fits at Larger, as the pause menu and on the main menu. ---
	settings.open()
	await process_frame
	await process_frame
	var panel: Control = settings._overlay.get_node("Center/Panel")
	_check(root.get_visible_rect().encloses(panel.get_global_rect()), "the pause menu fits on screen at Larger (%s)" % panel.get_global_rect())
	var row: Node = settings._overlay.find_child("Text", true, false)
	_check(row != null and row.get_node("Slider").value == 2, "the Text row shows Larger")
	settings.close()
	change_scene_to_file(MENU)
	await process_frame
	await process_frame
	settings.open()
	await process_frame
	await process_frame
	_check(root.get_visible_rect().encloses(panel.get_global_rect()), "Settings fits on screen at Larger on the main menu (%s)" % panel.get_global_rect())
	var menu_panel: Control = current_scene.get_node("Center/Panel")
	_check(root.get_visible_rect().encloses(menu_panel.get_global_rect()), "the main menu fits at Larger (%s)" % menu_panel.get_global_rect())
	settings.close()

	# --- Saved, and back to Normal without compounding. ---
	var cfg := ConfigFile.new()
	_check(cfg.load(ts.SETTINGS_PATH) == OK and int(cfg.get_value("display", "text_scale", -1)) == 2, "the choice is saved")
	ts.set_step(1)
	ts.set_step(2)
	ts.set_step(0)
	await process_frame
	_check(theme.default_font_size == 9 and theme.get_font_size("font_size", "HintLabel") == hint0, "back to Normal restores the theme sizes exactly")
	var later := Label.new()
	later.add_theme_font_size_override("font_size", 8)
	current_scene.add_child(later)
	ts.set_step(2)
	ts.set_step(0)
	_check(later.get_theme_font_size("font_size") == 8, "and a label's own size, after Larger and back")

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
