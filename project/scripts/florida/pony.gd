extends "res://scripts/florida/clickable.gd"
## Pony — one of the stable ponies (data/ponies.json, herd in WorldState fl_ponies). Drawn as a
## PonyDoll from its genes and grooming; clicking it opens the stable panel: brush, groom,
## ride, or pick a friend to have a foal with. Every choice gets a happy pony.

const PANEL_SCRIPT := preload("res://scripts/florida/stable_panel.gd")

@export var pony_id := ""

@onready var doll: PonyDoll = $Doll
@onready var bubble: Label = $BarkBubble

var _panel: CanvasLayer


func _ready() -> void:
	super()
	bubble.hide()
	refresh()


func refresh() -> void:
	doll.set_outfit(Ponies.parts(pony_id))
	doll.scale = Vector2.ONE * (0.65 if Ponies.is_foal(pony_id, GameClock.day) else 1.0)
	visible = Ponies.riding() != pony_id


func interact() -> void:
	if _panel and is_instance_valid(_panel):
		return
	say(Ponies.line("hello"))
	_panel = PANEL_SCRIPT.new()
	_panel.pony_id = pony_id
	_panel.spoke.connect(say)
	add_child(_panel)


## The pony's bubble (name: line), spoken through Voice like the other Florida critters.
func say(text: String) -> void:
	if text == "" or not is_inside_tree():
		return
	bubble.text = "%s: %s" % [Ponies.display_name(pony_id), text]
	bubble.show()
	Voice.speak(text, float(Ponies.data().get("pitch", 1.0)), "pony")
	get_tree().create_timer(3.0).timeout.connect(bubble.hide)
	var tw := create_tween()
	tw.tween_property(doll, "position:y", -8.0, 0.15)
	tw.tween_property(doll, "position:y", 0.0, 0.15)
