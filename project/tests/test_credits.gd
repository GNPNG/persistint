extends SceneTree
## Headless check of the main menu's copyright lines and the credits and licences screen (GC-08):
## the menu shows the copyright and the book credit exactly as data/credits.json has them, its
## Credits & Licences button opens the screen and Escape closes it; the screen carries the
## engine's licence and the parts built into the engine, and every third-party notice in the
## data; Dialogue Manager's text is its LICENSE file word for word; the CPML and OpenStreetMap
## notices are there.
## Run: godot --headless --path project -s tests/test_credits.gd

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const Credits := preload("res://scripts/ui/credits.gd")

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		print("ok   ", what)
	else:
		_failures += 1
		print("FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(2)
	var data: Dictionary = Credits.load_data()
	_check(data.get("copyright") == "© 2026 Brett Whitty", "copyright line in the data")
	_check(data.get("based_on") == "Based on characters and themes from the book ‘Persistint’", "book credit in the data")
	var by_name := {}
	for e: Dictionary in data.get("third_party", []):
		by_name[e.get("name", "")] = e
	for n in ["Godot Engine", "Dialogue Manager 3.10.4", "Coqui XTTS v2", "OpenStreetMap"]:
		_check(by_name.has(n), "credits data lists %s" % n)
	_check(by_name.get("Godot Engine", {}).get("engine", false), "Godot's licence text comes from the engine")
	var dm_license := FileAccess.get_file_as_string("res://addons/dialogue_manager/LICENSE")
	_check(dm_license != "" and by_name.get("Dialogue Manager 3.10.4", {}).get("text", "") == dm_license,
		"Dialogue Manager's text is its LICENSE file word for word")
	var cpml: String = by_name.get("Coqui XTTS v2", {}).get("text", "")
	_check(cpml.begins_with("# Coqui Public Model License 1.0.0") and cpml.contains("https://coqui.ai/cpml.txt")
		and cpml.contains("## Notices"), "the CPML terms ship with the voice clips")
	var osm: String = by_name.get("OpenStreetMap", {}).get("notice", "")
	_check(osm.contains("© OpenStreetMap contributors") and osm.contains("Open Database License")
		and osm.contains("island_layout.json"), "OpenStreetMap attribution, ODbL and the derived island layout")

	var text := Credits.compose(data)
	_check(text.contains(Credits._esc(Engine.get_license_text())), "the screen carries the engine's licence text")
	var parts_ok := true
	for c: Dictionary in Engine.get_copyright_info():
		parts_ok = parts_ok and text.contains(Credits._esc(c.get("name", "")))
	_check(parts_ok, "every part built into the engine is listed (%d)" % Engine.get_copyright_info().size())
	var licences: Dictionary = Engine.get_license_info()
	var texts_ok := not licences.is_empty()
	for n: String in licences:
		texts_ok = texts_ok and text.contains(Credits._esc(licences[n]))
	_check(texts_ok, "every licence text of the engine's parts is shown (%d)" % licences.size())
	_check(text.contains(Credits._esc(dm_license)) and text.contains(Credits._esc(cpml)) and text.contains(Credits._esc(osm)),
		"the screen carries every notice in the data")
	_check(Credits._esc("[b]x[/b]") == "[lb]b]x[lb]/b]", "brackets in licence texts stay text")

	change_scene_to_file(MAIN_MENU)
	await _frames(3)
	var menu := current_scene
	var copyright: Label = menu.get_node_or_null("Colophon/Copyright")
	var based_on: Label = menu.get_node_or_null("Colophon/BasedOn")
	_check(copyright != null and copyright.text == data.get("copyright"), "the main menu shows © 2026 Brett Whitty")
	_check(based_on != null and based_on.text == data.get("based_on"), "the main menu shows the book credit")
	_check(menu.get_node_or_null("Imprint/Mark") != null, "the G|P|G mark is on the main menu")
	var screen: Control = menu.get_node_or_null("Credits")
	var button: Button = menu.get_node_or_null("%CreditsButton")
	_check(screen != null and button != null and not screen.visible, "Credits & Licences button, screen closed at first")
	if screen == null or button == null:
		_finish()
		return
	_check(screen.get_index() == menu.get_child_count() - 1, "the screen draws over everything on the menu")
	button.pressed.emit()
	await _frames(2)
	var body: RichTextLabel = screen.get_node("%Body")
	_check(screen.visible and body.get_parsed_text().contains("Permission is hereby granted"), "the button opens the screen with the licence texts")
	_check(body.get_parsed_text().contains("© OpenStreetMap contributors"), "the parsed screen text keeps the OpenStreetMap credit")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	root.push_unhandled_input(esc)
	await _frames(2)
	_check(not screen.visible, "Escape closes the screen")
	_check(not root.get_node("/root/AudioSettings").is_open(), "Escape on the menu did not open the settings screen")
	_finish()


func _finish() -> void:
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)
