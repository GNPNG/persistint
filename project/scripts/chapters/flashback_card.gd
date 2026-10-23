extends Control
## Flashback card — the full-screen intro card before a cruise flashback (data/flashbacks.json
## "card"), in the same register as the chapter-end time jump. Reads the active flashback
## (Flashbacks.enter has already swapped the character out); a click, key or the timer
## goes on to the episode's entry scene.

const Flashbacks := preload("res://scripts/chapters/flashbacks.gd")
const FALLBACK := "res://scenes/ui/main_menu.tscn"

var seconds := 9.0
var id := ""
var card: Dictionary = {}
var entry: Dictionary = {}
var _left := false


func _ready() -> void:
	id = String(Flashbacks.active().get("id", ""))
	card = Flashbacks.card(id) if id != "" else {}
	entry = {"scene": Flashbacks.flashback(id).get("entry_scene", ""), "spawn": "spawn_default"} if id != "" else {}
	_build_ui()
	get_tree().create_timer(seconds).timeout.connect(go_on)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = card.get("heading", "")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	box.add_child(heading)
	for line: String in card.get("lines", []):
		var l := Label.new()
		l.text = line
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.modulate = Color(1, 1, 1, 0.85)
		box.add_child(l)
	var prompt := Label.new()
	prompt.text = card.get("prompt", "")
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.modulate = Color(1, 1, 1, 0.5)
	box.add_child(prompt)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event is InputEventMouseButton or event is InputEventKey):
		go_on()


func go_on() -> void:
	if _left or not is_inside_tree():
		return
	_left = true
	if entry.is_empty() or entry["scene"] == "":
		get_tree().call_deferred("change_scene_to_file", FALLBACK)
	else:
		SceneRouter.goto_map(entry["scene"], entry["spawn"])
