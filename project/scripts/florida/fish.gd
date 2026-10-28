extends AnimatedSprite2D
## Fish — one of the aquarium tank's fish (assets/florida/fish.tres, tools/gen_florida_art.py).
## Swims slowly back and forth across its stretch of the tank, and every so often stops to
## wave a fin at whoever is watching.

@export_enum("coral", "mango", "lilac") var colour := "coral"
@export var swim_range := 80.0

var _home := Vector2.ZERO


func _ready() -> void:
	_home = position
	play("swim_%s" % colour)
	SpriteFit.fit_sheet(self, 0.5)  # a swimmer: centred on its spot
	frame = randi() % 3
	PaperBake.dress_frames(self)  # the paper look (tools/bake_paper.sh florida_cast)
	if DisplayServer.get_name() != "headless":
		_swim()


func _swim() -> void:
	if not is_inside_tree():
		return
	var target := _home + Vector2(randf_range(-swim_range, swim_range), randf_range(-10.0, 10.0))
	var tw := create_tween()
	tw.tween_callback(func() -> void:
		flip_h = target.x < position.x
		play("swim_%s" % colour))
	tw.tween_property(self, "position", target, randf_range(3.0, 6.0)).set_trans(Tween.TRANS_SINE)
	if randf() < 0.4:
		tw.tween_callback(func() -> void: play("wave_%s" % colour))
		tw.tween_interval(2.0)
	tw.tween_callback(_swim)
