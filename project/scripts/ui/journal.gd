extends CanvasLayer
## Journal — the player's Forbidden Knowledge: every tactic named in a Name It beat,
## with the lines where it was found. J toggles it (map.gd).


func _ready() -> void:
	layer = 15
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "Journal — Forbidden Knowledge"
	box.add_child(title)
	var journal: Dictionary = WorldState.get_flag("journal", {})
	if journal.is_empty():
		var empty := Label.new()
		empty.text = "(nothing named yet)"
		box.add_child(empty)
	for tactic: String in journal:
		var entry := Label.new()
		entry.custom_minimum_size = Vector2(320, 0)
		entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.text = "%s\n    %s" % [tactic, "\n    ".join(journal[tactic].map(func(q: String) -> String: return "\"%s\"" % q))]
		box.add_child(entry)
