extends "res://scripts/florida/clickable.gd"
## Critter — dolphin, crab, gull or aquarium mermaid. Drifts around its patch; clicking it
## triggers a surprise that depends on what the paper doll is wearing (data/florida.json).
## Every outfit gets a delighted reaction. Nobody is judged.

@export var kind := "crab"
@export var wander := Rect2(0, 0, 100, 60)  # global rect it drifts inside
@export var sprite_texture := ""

@onready var bubble: Label = $BarkBubble
@onready var sprite: Sprite2D = $Sprite2D

var _busy := false


func _ready() -> void:
	super()
	var path := "res://assets/placeholder/%s.png" % (sprite_texture if sprite_texture != "" else kind)
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	bubble.hide()
	if DisplayServer.get_name() != "headless":
		_drift()


func _drift() -> void:
	if not is_inside_tree():
		return
	var target := wander.position + Vector2(randf() * wander.size.x, randf() * wander.size.y)
	var tw := create_tween()
	tw.tween_interval(randf_range(0.5, 3.0))
	tw.tween_callback(func() -> void: sprite.flip_h = target.x > global_position.x)
	tw.tween_property(self, "global_position", target, randf_range(2.0, 5.0)).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_drift)


func interact() -> void:
	surprise()


## Plays the surprise for the doll's current outfit; returns the surprise entry used.
func surprise() -> Dictionary:
	var s := Florida.surprise_for(kind, Florida.current_outfit())
	if s.is_empty() or _busy:
		return s
	_busy = true
	_play(s.get("effect", "hop"))
	var lines: Array = s.get("lines", [])
	if not lines.is_empty():
		var text: String = lines.pick_random()
		bubble.text = text
		bubble.show()
		Voice.speak(text, float(Florida.data()["critters"][kind].get("pitch", 1.0)), kind)
		get_tree().create_timer(3.0).timeout.connect(bubble.hide)
	return s


func _play(effect: String) -> void:
	var tw := create_tween()
	match effect:
		"jump":
			tw.tween_property(sprite, "position:y", -34.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(sprite, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		"spin":
			tw.tween_property(sprite, "rotation", TAU, 0.7)
			tw.tween_callback(func() -> void: sprite.rotation = 0.0)
		"wiggle":
			for i in 3:
				tw.tween_property(sprite, "rotation", 0.3, 0.1)
				tw.tween_property(sprite, "rotation", -0.3, 0.1)
			tw.tween_property(sprite, "rotation", 0.0, 0.1)
		_:
			tw.tween_property(sprite, "position:y", -12.0, 0.15)
			tw.tween_property(sprite, "position:y", 0.0, 0.15)
			tw.tween_property(sprite, "position:y", -8.0, 0.12)
			tw.tween_property(sprite, "position:y", 0.0, 0.12)
	tw.tween_callback(func() -> void: _busy = false)
