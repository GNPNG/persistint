extends Area2D
## KnowledgePickup — a piece of Forbidden Knowledge lying in the ruins. Click to walk
## over and recover it (ForbiddenKnowledge.recover); gone from the map once recovered.
## Says so when the piece completes a cruise flashback (data/flashbacks.json).
## Shows the piece's "icon" (data/ruins.json; assets/ruins/icon_*.png or a canon cut) bobbing
## over a warm glow (AnimationPlayer "bob").

const ForbiddenKnowledge := preload("res://scripts/ruins/forbidden_knowledge.gd")
const Flashbacks := preload("res://scripts/chapters/flashbacks.gd")
const RuinsDecor := preload("res://scripts/ruins/ruins_decor.gd")

## The icon is shown at most this tall (world px), centred over the glow.
const ICON_HEIGHT := 20.0
## The warm glow under it, world px across.
const GLOW_SIZE := 38.0

@export var piece_id := ""

@onready var label: Label = $Label
@onready var icon: Sprite2D = $Icon

var _recovered := false


func _ready() -> void:
	label.hide()
	SpriteFit.fit($Glow, GLOW_SIZE, 0.5)
	var tex := RuinsDecor.texture_for(String(ForbiddenKnowledge.pieces().get(piece_id, {}).get("icon", "icon_paper")))
	if tex:
		icon.texture = tex
		SpriteFit.fit(icon, minf(ICON_HEIGHT, RuinsDecor.world_height(tex)), 0.5)
	if ForbiddenKnowledge.has(piece_id):
		queue_free()
		return
	input_event.connect(_on_input_event)


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
	for id: String in Flashbacks.opened_by(piece_id):
		label.text += "\nA memory of the cruise opens: %s (J: Journal)" % Flashbacks.flashback(id).get("title", id)
	label.show()
	_recovered = true
	$Glow.hide()
	icon.hide()
	$CollisionShape2D.set_deferred("disabled", true)
	await get_tree().create_timer(4.0).timeout
	queue_free()
