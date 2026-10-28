extends Area2D
## KnowledgePickup — a piece of Forbidden Knowledge lying in the ruins. Click to walk
## over and recover it (ForbiddenKnowledge.recover); gone from the map once recovered.
## Says so when the piece completes a cruise flashback (data/flashbacks.json).
## What it says is put in its Label; in a ruins room the room's RuinsDecor shows it on screen
## over the piece (show_found), and the Label itself shows only for a pickup outside a room.
## Shows the piece's "icon" (data/ruins.json; assets/ruins/icon_*.png or a canon cut) bobbing
## over a warm glow (AnimationPlayer "bob").

const ForbiddenKnowledge := preload("res://scripts/ruins/forbidden_knowledge.gd")
const Flashbacks := preload("res://scripts/chapters/flashbacks.gd")
const RuinsDecor := preload("res://scripts/ruins/ruins_decor.gd")

## The icon is shown at most this tall (world px), centred over the glow.
const ICON_HEIGHT := 20.0
## The warm glow under it, world px across.
const GLOW_SIZE := 38.0
## How long the recovered card stays up.
const FOUND_SECONDS := 4.0

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


## The card outside a ruins room is drawn at the screen's resolution under the camera's zoom,
## one level out too (bd wso.4).
func _process(_delta: float) -> void:
	if label.visible:
		WorldText.fit(label)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("click"):
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
	var decor := _decor()
	if decor:  # the card's bottom edge where the Label's would be
		decor.show_found(label.text, global_position + Vector2(0, label.offset_bottom), FOUND_SECONDS)
	else:
		label.show()
		WorldText.fit(label)
	_recovered = true
	$Glow.hide()
	icon.hide()
	$CollisionShape2D.set_deferred("disabled", true)
	await get_tree().create_timer(FOUND_SECONDS).timeout
	queue_free()


## The room's RuinsDecor (the map's "Decor"), or null for a pickup outside a ruins room.
func _decor() -> RuinsDecor:
	var d: Node = get_parent().get_node_or_null("Decor") if get_parent() else null
	return d as RuinsDecor
