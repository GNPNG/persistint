extends "res://scripts/florida/clickable.gd"
## ZombieChild — a failed clone child from the bunker's clone hall (data/ruins.json,
## "clone_children"). Shambles around its patch of floor, groans now and then, barks when
## clicked or bumped. The player never fights it; now and then a polar bear cub from the
## batch that took eats one (CloneLab), and the tanks restock the batch later.
## Every batch of an original shares one sprite; the designation reads the original's name
## through Cast ("Epstein clone, batch 7"). The spoken part of a bark is one of the original's
## own verified lines from data/quotes/<file>.json when that file exists; otherwise the groan itself.
## Rig: assets/canon/clone_<original>.png (tools/gen_clone_children.py), front/side/back idle and
## walk through SheetRig; the node's origin sits 16 px above its feet like the player's.

const ForbiddenKnowledge := preload("res://scripts/ruins/forbidden_knowledge.gd")
const SheetRig := preload("res://scripts/ruins/sheet_rig.gd")
const BUBBLE_BOTTOM := -21.0  # just over the head

@export var original := "epstein"  # cast id of the person the batch was meant to reproduce
@export var batch := 1
@export var wander := Rect2(0, 0, 100, 60)  # global rect it shambles inside

@onready var bubble: Label = $BarkBubble
@onready var sprite: AnimatedSprite2D = $Sprite2D

var _talking := false
var _facing := "down"


func _ready() -> void:
	super()
	add_to_group("zombie_clones")
	var path := "res://assets/canon/clone_%s.png" % original
	if ResourceLoader.exists(path):
		sprite.sprite_frames = SheetRig.frames(load(path), SheetRig.CLONE)
		sprite.play("idle_down")
		sprite.frame = randi() % 2
	bubble.hide()
	area_entered.connect(_on_bumped)
	body_entered.connect(_on_bumped)
	if DisplayServer.get_name() != "headless":
		_shamble()
		_groan_later()


static func data() -> Dictionary:
	return ForbiddenKnowledge.data().get("clone_children", {})


## "Epstein clone, batch 7" — the batch designation, the name read through Cast.
func designation() -> String:
	return String(data().get("designation", "%s clone, batch %d")) % [Cast.short(original), batch]


## One of the original's own lines (data/quotes/<file>.json), or "" if there is none.
func quote() -> String:
	var pool := quote_pool(original)
	return "" if pool.is_empty() else String(pool.pick_random())


## Every line a clone of `orig` may speak: the quotes in its data/quotes/<file>.json marked
## verified=true (checked verbatim against a primary source; tests/test_quotes_vv.gd) and not
## marked excluded_from_game.
static func quote_pool(orig: String) -> Array:
	var file: String = data().get("originals", {}).get(orig, {}).get("quotes", "")
	var path := "res://data/quotes/%s.json" % file
	if file == "" or not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var pool: Array = []
	for q: Variant in (parsed.get("quotes", []) if parsed is Dictionary else []):
		if q is Dictionary and q.get("verified", false) == true and not q.get("excluded_from_game", false) \
				and String(q.get("text", "")) != "":
			pool.append(String(q["text"]))
	return pool


func _process(_delta: float) -> void:
	if bubble.visible:
		SheetRig.keep_on_screen(bubble)


## A random point inside the wander rect; where the next shamble goes.
func pick_target() -> Vector2:
	return wander.position + Vector2(randf() * wander.size.x, randf() * wander.size.y)


func _shamble() -> void:
	if not is_inside_tree():
		return
	var target := pick_target()
	var tw := create_tween()
	tw.tween_interval(randf_range(1.0, 4.0))
	tw.tween_callback(func() -> void: _walk_towards(target))
	tw.tween_property(self, "global_position", target, randf_range(5.0, 9.0)).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: sprite.play("idle_" + _facing))
	tw.tween_callback(_shamble)


## Faces the way it is about to walk and starts the shamble cycle.
func _walk_towards(target: Vector2) -> void:
	var delta := target - global_position
	_facing = SheetRig.facing(delta)
	sprite.flip_h = _facing == "side" and delta.x < 0
	sprite.play("walk_" + _facing)


func _groan_later() -> void:
	get_tree().create_timer(randf_range(8.0, 20.0)).timeout.connect(func() -> void:
		if is_inside_tree():
			bark("barks")
			_groan_later())


func interact() -> void:
	bark("barks")


func _on_bumped(other: Node) -> void:
	if other == self or not (other.is_in_group("player") or other.has_method("pick_target")):
		return
	bark("bump_barks")
	var tw := create_tween()
	tw.tween_property(sprite, "position:x", 4.0 if sprite.flip_h else -4.0, 0.12)
	tw.tween_property(sprite, "position:x", 0.0, 0.2)


## Shows and speaks one line from the given list; returns it ("" if already talking).
func bark(list := "barks") -> String:
	var lines: Array = data().get(list, [])
	if lines.is_empty() or _talking:
		return ""
	_talking = true
	var text: String = lines.pick_random()
	var spoken := quote()
	SheetRig.say(bubble, "%s\n%s" % [designation(), text] + ("\n\"%s\"" % spoken if spoken != "" else ""), BUBBLE_BOTTOM)
	bubble.show()
	Voice.speak(spoken if spoken != "" else text, float(data().get("pitch", 1.0)), original)
	get_tree().create_timer(3.5).timeout.connect(func() -> void:
		bubble.hide()
		_talking = false)
	return text


## Eaten by a polar bear cub (CloneLab.pounce): a kawaii puff where it stood, then gone.
func get_eaten() -> void:
	remove_from_group("zombie_clones")
	set_deferred("monitoring", false)
	var puff := CPUParticles2D.new()
	puff.one_shot = true
	puff.amount = 10
	puff.lifetime = 0.6
	puff.explosiveness = 1.0
	puff.spread = 180.0
	puff.initial_velocity_min = 20.0
	puff.initial_velocity_max = 50.0
	puff.gravity = Vector2(0, -20)
	puff.scale_amount_min = 3.0
	puff.scale_amount_max = 6.0
	puff.color = Color(0.85, 0.95, 0.85, 0.8)
	get_parent().add_child(puff)
	puff.global_position = global_position
	puff.emitting = true
	puff.finished.connect(puff.queue_free)
	queue_free()
