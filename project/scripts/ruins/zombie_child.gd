extends "res://scripts/florida/clickable.gd"
## ZombieChild — a failed clone child from the bunker's clone hall (data/ruins.json,
## "clone_children"). Shambles around its patch of floor, groans now and then, barks when
## clicked or bumped. The player never fights it; now and then a polar bear cub from the
## batch that took eats one (CloneLab), and the tanks restock the batch later.
## Every batch of an original shares one sprite; the designation reads the original's name
## through Cast ("Epstein clone, batch 7"). The spoken part of a bark is one of the original's
## own verified lines from data/quotes/<file>.json when that file exists; otherwise the groan itself.
## A bark's bracketed sounds ("[Uuunnngh.]") show in the bubble without the brackets and play as
## generated vocalizations before the words (Voice); everything a clone says goes through the
## audio bus in data ("Clones": pitched up and distorted, a kid clone of the original). With
## another clone near, a clone prefers its original's lines marked about_others in the quote
## file (author 2026-10-24: the Hillary clone calling the other clones a basket of deplorables).
## Now and then it dances (data "dance": the floss or the dab, SheetRig.CLONE_DANCES), which is
## what the polar bear cubs pounce on (CloneLab.on_dance).
## Rig: assets/ruins/clone_<original>.png (tools/gen_clone_children.py), front/side/back idle and
## walk, the floss and the dab, through SheetRig; the node's origin sits 16 px above its feet like the player's.

const ForbiddenKnowledge := preload("res://scripts/ruins/forbidden_knowledge.gd")
const SheetRig := preload("res://scripts/ruins/sheet_rig.gd")
const PUFF := "res://assets/ruins/gore_puff.png"  # tools/gen_clone_children.py

@export var original := "epstein"  # cast id of the person the batch was meant to reproduce
@export var batch := 1
@export var wander := Rect2(0, 0, 100, 60)  # global rect it shambles inside

@onready var bubble: Label = $BarkBubble
@onready var sprite: AnimatedSprite2D = $Sprite2D

## Emitted when a dance starts (CloneLab listens through on_dance).
signal dance_started(zombie: Node2D)

var dancing := false  # mid-floss or mid-dab
var _talking := false
var _facing := "down"
var _shamble_tw: Tween


func _ready() -> void:
	super()
	add_to_group("zombie_clones")
	var path := "res://assets/ruins/clone_%s.png" % original
	if ResourceLoader.exists(path):
		sprite.sprite_frames = SheetRig.frames(load(path), SheetRig.CLONE)
		sprite.play("idle_down")
		sprite.frame = randi() % 2
		SheetRig.fit(sprite, SheetRig.CLONE)
	bubble.hide()
	area_entered.connect(_on_bumped)
	body_entered.connect(_on_bumped)
	if DisplayServer.get_name() != "headless":
		_shamble()
		_groan_later()
		_dance_later()


static func data() -> Dictionary:
	return ForbiddenKnowledge.data().get("clone_children", {})


## The audio bus a clone speaks through ("Clones" unless data says otherwise).
static func bus() -> String:
	return String(data().get("bus", "Clones"))


## "Epstein clone, batch 7" — the batch designation, the name read through Cast.
func designation() -> String:
	return String(data().get("designation", "%s clone, batch %d")) % [Cast.short(original), batch]


## One of the original's own lines (data/quotes/<file>.json), or "" if there is none. With
## another clone within data "others_radius", one of the lines about other people
## (about_others in the quote file) when the original has any.
func quote() -> String:
	var pool := quote_pool(original, others_near())
	return "" if pool.is_empty() else String(pool.pick_random())


## True when another clone child stands within data "others_radius" px.
func others_near() -> bool:
	var radius := float(data().get("others_radius", 96.0))
	if not is_inside_tree():
		return false
	for z: Node in get_tree().get_nodes_in_group("zombie_clones"):
		if z != self and z is Node2D and (z as Node2D).global_position.distance_to(global_position) <= radius:
			return true
	return false


## Every line a clone of `orig` may speak: the quotes in its data/quotes/<file>.json marked
## verified=true (checked verbatim against a primary source; tests/test_quotes_vv.gd) and not
## marked excluded_from_game. With `about_others`, only the lines marked about_others, when there
## are any (else the whole pool).
static func quote_pool(orig: String, about_others := false) -> Array:
	var file: String = data().get("originals", {}).get(orig, {}).get("quotes", "")
	var path := "res://data/quotes/%s.json" % file
	if file == "" or not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var pool: Array = []
	var others: Array = []
	for q: Variant in (parsed.get("quotes", []) if parsed is Dictionary else []):
		if q is Dictionary and q.get("verified", false) == true and not q.get("excluded_from_game", false) \
				and String(q.get("text", "")) != "":
			pool.append(String(q["text"]))
			if q.get("about_others", false) == true:
				others.append(String(q["text"]))
	return others if about_others and not others.is_empty() else pool


## A random point inside the wander rect; where the next shamble goes.
func pick_target() -> Vector2:
	return wander.position + Vector2(randf() * wander.size.x, randf() * wander.size.y)


func _shamble() -> void:
	if not is_inside_tree() or dancing:
		return
	var target := pick_target()
	_shamble_tw = create_tween()
	_shamble_tw.tween_interval(randf_range(1.0, 4.0))
	_shamble_tw.tween_callback(func() -> void: _walk_towards(target))
	_shamble_tw.tween_property(self, "global_position", target, randf_range(5.0, 9.0)).set_trans(Tween.TRANS_SINE)
	_shamble_tw.tween_callback(func() -> void: sprite.play("idle_" + _facing))
	_shamble_tw.tween_callback(_shamble)


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


func _dance_later() -> void:
	var d: Dictionary = data().get("dance", {})
	get_tree().create_timer(randf_range(float(d.get("interval_min", 25.0)), float(d.get("interval_max", 60.0)))).timeout.connect(func() -> void:
		if is_inside_tree():
			dance()
			_dance_later())


## Stops mid-shamble and does `move` (the floss or the dab; a random one of SheetRig.CLONE_DANCES
## when ""), facing front, for data "dance" -> "seconds"; then shambles on. Returns the move
## done ("" when it couldn't: already dancing, or the rig has no such animation).
func dance(move := "") -> String:
	if dancing or sprite.sprite_frames == null:
		return ""
	if move == "":
		move = SheetRig.CLONE_DANCES.keys().pick_random()
	if not sprite.sprite_frames.has_animation(move):
		return ""
	dancing = true
	if _shamble_tw and _shamble_tw.is_valid():
		_shamble_tw.kill()
	_facing = "down"
	sprite.flip_h = false
	sprite.play(move)
	dance_started.emit(self)
	var lab := get_parent().get_node_or_null("CloneLab") if get_parent() else null
	if lab and lab.has_method("on_dance"):
		lab.on_dance(self)
	var seconds := float(data().get("dance", {}).get("seconds", 2.6))
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if not is_inside_tree() or not dancing:
			return
		dancing = false
		sprite.play("idle_" + _facing)
		_shamble())
	return move


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
	bubble.say("%s\n%s" % [designation(), Voice.display_text(text)] + ("\n\"%s\"" % spoken if spoken != "" else ""))
	# the bark's sounds, then the original's line (its clip is keyed on the words alone)
	var line := text if spoken == "" else ("%s %s" % [Voice.brackets_of(text), spoken]).strip_edges()
	Voice.speak(line, float(data().get("pitch", 1.0)), original, bus())
	get_tree().create_timer(3.5).timeout.connect(func() -> void:
		bubble.hide()
		_talking = false)
	return text


## Eaten by a polar bear cub (CloneLab.pounce): a kawaii puff where it stood, then gone.
func get_eaten() -> void:
	dancing = false
	remove_from_group("zombie_clones")
	set_deferred("monitoring", false)
	if ResourceLoader.exists(PUFF):
		_puff()
	queue_free()


## The puff: generated clone-dust sprites (gore_puff.png), each about 6-10 world px wide.
func _puff() -> void:
	var tex: Texture2D = load(PUFF)
	var fit := SpriteFit.scale_for(tex, 6.0 * tex.get_height() / float(tex.get_width()))
	var puff := CPUParticles2D.new()
	puff.texture = tex
	puff.one_shot = true
	puff.amount = 10
	puff.lifetime = 0.6
	puff.explosiveness = 1.0
	puff.spread = 180.0
	puff.initial_velocity_min = 20.0
	puff.initial_velocity_max = 50.0
	puff.gravity = Vector2(0, -20)
	puff.scale_amount_min = fit
	puff.scale_amount_max = fit * 1.7
	puff.color = Color(1, 1, 1, 0.9)
	get_parent().add_child(puff)
	puff.global_position = global_position - Vector2(0, 16)  # from its middle; the origin is the feet
	puff.emitting = true
	puff.finished.connect(puff.queue_free)
