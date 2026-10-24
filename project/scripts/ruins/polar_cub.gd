extends "res://scripts/florida/clickable.gd"
## PolarCub — the polar bear clone batch that took (data/ruins.json, "clone_children" ->
## "cubs"): fluffy, round, identical, not zombies. Toddles around its patch, makes little
## bear sounds, and now and then pounces on a nearby zombie clone (CloneLab.pounce), then
## naps with a pink muzzle until it wakes up clean.
## Rig: assets/ruins/clone_polar_bear.png (tools/gen_clone_children.py) through SheetRig:
## front/side/back idle and walk, smeared, chomp and nap; origin 16 px above the feet.

const ForbiddenKnowledge := preload("res://scripts/ruins/forbidden_knowledge.gd")
const SheetRig := preload("res://scripts/ruins/sheet_rig.gd")
const SHEET := "res://assets/ruins/clone_polar_bear.png"

@export var batch := 1
@export var wander := Rect2(0, 0, 100, 60)  # global rect it toddles inside

@onready var bubble: Label = $BarkBubble
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var sfx: AudioStreamPlayer2D = $Sfx

var napping := false
var busy := false
var _talking := false
var _walk: Tween
var _facing := "down"
var _state := ""  # "", "_smeared" or "_nap"


func _ready() -> void:
	super()
	add_to_group("polar_cubs")
	sprite.sprite_frames = SheetRig.frames(load(SHEET), SheetRig.CUB)
	set_frame("")
	sprite.frame = randi() % 2
	SheetRig.fit(sprite, SheetRig.CUB)
	bubble.hide()
	area_entered.connect(_on_bumped)
	body_entered.connect(_on_bumped)
	if DisplayServer.get_name() != "headless":
		_toddle()


static func data() -> Dictionary:
	return ForbiddenKnowledge.data().get("clone_children", {}).get("cubs", {})


## "Polar bear clone, batch 1" — the name read through Cast.
func designation() -> String:
	return String(data().get("designation", "%s, batch %d")) % [Cast.full(data().get("cast", "polar_bear_clone")), batch]


## "" (clean), "_smeared" (pink muzzle) or "_nap" (asleep, still pink).
func set_frame(suffix: String) -> void:
	_state = suffix
	sprite.flip_h = sprite.flip_h and suffix == ""
	sprite.play({"": "idle_" + _facing, "_smeared": "smeared", "_nap": "nap"}.get(suffix, "idle_down"))


## The animation playing now ("idle_down", "walk_side", "smeared", "chomp", "nap", ...).
func current_animation() -> String:
	return String(sprite.animation)



func pick_target() -> Vector2:
	return wander.position + Vector2(randf() * wander.size.x, randf() * wander.size.y)


func can_pounce() -> bool:
	return not napping and not busy


func _toddle() -> void:
	if not is_inside_tree():
		return
	if busy or napping:
		get_tree().create_timer(1.0).timeout.connect(_toddle)
		return
	var target := pick_target()
	_walk = create_tween()
	_walk.tween_interval(randf_range(0.8, 3.0))
	_walk.tween_callback(func() -> void:
		var delta := target - global_position
		_facing = SheetRig.facing(delta)
		sprite.flip_h = _facing == "side" and delta.x < 0
		sprite.play("walk_" + _facing))
	_walk.tween_property(self, "global_position", target, randf_range(2.5, 5.0)).set_trans(Tween.TRANS_SINE)
	_walk.tween_callback(func() -> void: set_frame(_state))
	_walk.tween_callback(_toddle)


func stop_walking() -> void:
	if _walk and _walk.is_valid():
		_walk.kill()


func interact() -> void:
	say(data().get("barks", []).pick_random() if not data().get("barks", []).is_empty() else "")


func _on_bumped(other: Node) -> void:
	if other == self or napping or not (other.is_in_group("player") or other.has_method("pick_target")):
		return
	var lines: Array = data().get("bump_barks", [])
	if not lines.is_empty():
		say(lines.pick_random())


## Shows and speaks a little bear sound; returns it ("" if already talking).
func say(text: String) -> String:
	if text == "" or _talking:
		return ""
	_talking = true
	bubble.say("%s\n%s" % [designation(), text])
	Voice.speak(text, float(data().get("pitch", 1.5)), data().get("cast", "polar_bear_clone"))
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		bubble.hide()
		_talking = false)
	return text


func play_sfx(sfx_name: String) -> void:
	var path := "res://audio/sfx/%s.wav" % sfx_name
	if sfx_name == "" or not ResourceLoader.exists(path):
		return
	sfx.stream = load(path)
	sfx.play()


## Naps for the given seconds with a pink muzzle, then wakes up clean.
func nap(seconds: float, snore := "") -> void:
	napping = true
	busy = false
	set_frame("_nap")
	_talking = false
	var lines: Array = data().get("nap", [])
	say(lines.pick_random() if not lines.is_empty() else "")
	play_sfx(snore)
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		napping = false
		set_frame(""))
