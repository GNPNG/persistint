extends Area2D
## KnowledgePickup — a piece of Forbidden Knowledge lying in the ruins. Click to walk
## over and recover it (ForbiddenKnowledge.recover); gone from the map once recovered.

const ForbiddenKnowledge := preload("res://scripts/ruins/forbidden_knowledge.gd")

@export var piece_id := ""

@onready var label: Label = $Label

var _recovered := false


func _ready() -> void:
	label.hide()
	if ForbiddenKnowledge.has(piece_id):
		queue_free()
		return
	input_event.connect(_on_input_event)


func _draw() -> void:
	if _recovered:
		return
	draw_circle(Vector2.ZERO, 7.0, Color(0.95, 0.85, 0.5, 0.9))
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 24, Color(1, 1, 1, 0.6), 1.5)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.approach(self)
			get_viewport().set_input_as_handled()


func interact() -> void:
	if not ForbiddenKnowledge.recover(piece_id):
		return
	var piece: Dictionary = ForbiddenKnowledge.pieces()[piece_id]
	var title: String = ForbiddenKnowledge.fill(piece.get("title", ""))
	var text: String = ForbiddenKnowledge.fill(piece.get("text", ""))
	label.text = "Forbidden Knowledge recovered." if title == "" else "Recovered: %s" % title
	if text != "":
		label.text += "\n" + text
	label.show()
	_recovered = true
	queue_redraw()
	$CollisionShape2D.set_deferred("disabled", true)
	await get_tree().create_timer(4.0).timeout
	queue_free()
