extends Control
## Chapter end — the full-screen time-jump card between chapters (data/chapters.json).
## Shows the ending chapter's end_card, makes the jump (new `chapter`, fresh player character),
## then a click, key or the timer goes on to the next chapter's entry scene.

const Chapters := preload("res://scripts/chapters/chapters.gd")
const FALLBACK := "res://scenes/ui/main_menu.tscn"

var autostart := true
var seconds := 9.0
var from := ""
var card: Dictionary = {}
var entry: Dictionary = {}
var _left := false


func _ready() -> void:
	from = Chapters.current()
	card = Chapters.chapter(from).get("end_card", {})
	_build_ui()
	if autostart:
		entry = Chapters.jump(from)
		get_tree().create_timer(seconds).timeout.connect(go_on)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = card.get("heading", "")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 16)
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
	if _left:
		return
	_left = true
	if entry.is_empty():
		get_tree().call_deferred("change_scene_to_file", FALLBACK)
	else:
		SceneRouter.goto_map(entry["scene"], entry["spawn"])
