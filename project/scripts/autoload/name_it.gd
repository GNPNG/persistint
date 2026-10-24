extends Node
## NameIt — the pedagogy loop (DESIGN.md "Name It"): after a manipulative beat the player
## picks the hook hidden in the compliment, then names the tactic. Named tactics go into
## the journal (WorldState "journal": tactic -> quoted hooks), the player's Forbidden Knowledge.
## Beats, prompts and tactics live in data/name_it.json.

const DATA_PATH := "res://data/name_it.json"

var data: Dictionary = {}
var _layer: CanvasLayer


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		data = parsed


func beat(beat_id: String) -> Dictionary:
	return data.get("beats", {}).get(beat_id, {})


func check_hook(beat_id: String, index: int) -> bool:
	return int(beat(beat_id).get("hook", -1)) == index


func check_tactic(beat_id: String, tactic: String) -> bool:
	return beat(beat_id).get("answer", "") == tactic


## Writes the named tactic and its hook line into the journal.
func record(beat_id: String) -> void:
	var b := beat(beat_id)
	var journal: Dictionary = WorldState.get_flag("journal", {}).duplicate(true)
	var quotes: Array = journal.get(b["answer"], [])
	var quote: String = b["lines"][int(b["hook"])]
	if not quotes.has(quote):
		quotes.append(quote)
	journal[b["answer"]] = quotes
	WorldState.set_flag("journal", journal)
	WorldState.set_flag("named_%s" % beat_id, true)


## Opens the two-step Name It panel for a beat (called from dialogue mutations).
func start(beat_id: String) -> void:
	var b := beat(beat_id)
	# A beat runs only once its author has set the hook line and the answer.
	if b.is_empty() or b.get("hook") == null or b.get("answer") == null:
		return
	if WorldState.has_flag("named_%s" % beat_id):
		return
	if _layer and is_instance_valid(_layer):
		_layer.queue_free()
	_layer = CanvasLayer.new()
	_layer.layer = 20
	get_tree().root.add_child(_layer)
	_show_hook_step(beat_id)


func _panel() -> VBoxContainer:
	for child in _layer.get_children():
		child.queue_free()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	return box


func _show_hook_step(beat_id: String, note := "") -> void:
	var box := _panel()
	_label(box, data["prompts"]["hook"] + ("\n" + note if note != "" else ""))
	var lines: Array = beat(beat_id)["lines"]
	for i in lines.size():
		_button(box, "\"%s\"" % lines[i], func() -> void:
			if check_hook(beat_id, i):
				_show_tactic_step(beat_id)
			else:
				_show_hook_step(beat_id, data["prompts"]["retry"]))


func _show_tactic_step(beat_id: String, note := "") -> void:
	var box := _panel()
	_label(box, data["prompts"]["tactic"] + ("\n" + note if note != "" else ""))
	for tactic: String in data.get("tactics", []):
		_button(box, tactic, func() -> void:
			if check_tactic(beat_id, tactic):
				record(beat_id)
				_show_done(tactic)
			else:
				_show_tactic_step(beat_id, data["prompts"]["retry"]))


func _show_done(tactic: String) -> void:
	var box := _panel()
	_label(box, "%s %s" % [data["prompts"]["added"], tactic])
	Music.event("name_it")  # the revelation sting (STYLE.md 2.2)
	Voice.speak(tactic, 1.2)
	_button(box, "OK", func() -> void: _layer.queue_free())


func _label(box: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(320, 0)
	box.add_child(label)


func _button(box: Container, text: String, on_press: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_press)
	box.add_child(button)
