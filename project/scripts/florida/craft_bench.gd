extends "res://scripts/florida/clickable.gd"
## CraftBench — make things from what you grew and found; crafted accessories can be worn
## on the paper doll straight away.

var _ui: CanvasLayer


func interact() -> void:
	if _ui and is_instance_valid(_ui):
		return
	_ui = CanvasLayer.new()
	_ui.layer = 15
	add_child(_ui)
	_build()


func _build() -> void:
	for c in _ui.get_children():
		c.queue_free()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ui.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var have := Label.new()
	var parts: Array[String] = []
	for item: String in Florida.inventory():
		if int(Florida.inventory()[item]) > 0:
			parts.append("%s x%d" % [_label(item), Florida.inventory()[item]])
	have.text = ", ".join(parts) if not parts.is_empty() else "(nothing yet)"
	box.add_child(have)
	for id: String in Florida.data()["recipes"]:
		var recipe: Dictionary = Florida.data()["recipes"][id]
		var row := HBoxContainer.new()
		var make := Button.new()
		var needs: Array[String] = []
		for item: String in recipe["needs"]:
			needs.append("%d %s" % [recipe["needs"][item], _label(item)])
		make.text = "%s  (%s)" % [recipe["label"], ", ".join(needs)]
		make.disabled = not Florida.can_craft(id)
		make.pressed.connect(func() -> void: Florida.craft(id); _build())
		row.add_child(make)
		if Florida.count(id) > 0 and recipe.has("wear"):
			var wear := Button.new()
			wear.text = "Wear (%d)" % Florida.count(id)
			wear.pressed.connect(func() -> void: Florida.wear(id))
			row.add_child(wear)
		box.add_child(row)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(_ui.queue_free)
	box.add_child(close)


func _label(item: String) -> String:
	var plants: Dictionary = Florida.data()["plants"]
	if plants.has(item):
		return plants[item]["label"]
	return item.capitalize().replace("_", " ")
