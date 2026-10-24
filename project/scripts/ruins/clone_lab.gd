extends Node2D
## CloneLab — the clone hall's ambient food chain (data/ruins.json, "clone_children" ->
## "pounce"). At random intervals a polar bear cub near a zombie clone pounces: a cartoon
## chomp with kawaii gore (pastel splatter, hearts, sparkles, a bouncing bone and chunk, a
## heart-outlined puddle that fades) and the data's sfx in order; the zombie is gone, the cub
## naps with a pink muzzle, and the eaten clone's batch restocks from a tank a while later.
## WorldState "clones_eaten" counts eaten clones per batch ("epstein_batch_7": 2).
## The player never fights; this only happens around them.

const ForbiddenKnowledge := preload("res://scripts/ruins/forbidden_knowledge.gd")
const ZombieScene := preload("res://scenes/ruins/zombie_child.tscn")
const RuinsDecor := preload("res://scripts/ruins/ruins_decor.gd")
const FLAG := "clones_eaten"
const SFX_GAP := 0.35  # seconds between the pounce's sound effects
const GORE_SCALE := 0.1875  # gore_*.png are drawn at eight texels per world pixel (gen_clone_children.py)

var gore: Node2D


func _ready() -> void:
	gore = Node2D.new()
	gore.name = "Gore"
	gore.z_index = 2  # flying bits over everyone; the puddle goes under (below)
	RuinsDecor.smooth(gore)
	add_child(gore)
	if DisplayServer.get_name() != "headless":
		_schedule()


static func settings() -> Dictionary:
	return ForbiddenKnowledge.data().get("clone_children", {}).get("pounce", {})


static func eaten_count(key := "") -> int:
	var ws := (Engine.get_main_loop() as SceneTree).root.get_node("/root/WorldState")
	var counts: Dictionary = ws.get_flag(FLAG, {})
	if key != "":
		return int(counts.get(key, 0))
	var total := 0
	for k: String in counts:
		total += int(counts[k])
	return total


func zombies() -> Array:
	return get_parent().get_children().filter(func(n: Node) -> bool: return n.is_in_group("zombie_clones"))


func cubs() -> Array:
	return get_parent().get_children().filter(func(n: Node) -> bool: return n.is_in_group("polar_cubs"))


func _schedule() -> void:
	var s := settings()
	get_tree().create_timer(randf_range(float(s.get("interval_min", 15.0)), float(s.get("interval_max", 30.0)))).timeout.connect(func() -> void:
		if is_inside_tree():
			try_pounce()
			_schedule())


## Pounces with the first free cub that has a zombie within the radius; true if one did.
func try_pounce() -> bool:
	var radius := float(settings().get("radius", 150.0))
	for cub: Node2D in cubs():
		if not cub.can_pounce():
			continue
		var best: Node2D = null
		for z: Node2D in zombies():
			if z.global_position.distance_to(cub.global_position) <= radius \
					and (best == null or z.global_position.distance_to(cub.global_position) < best.global_position.distance_to(cub.global_position)):
				best = z
		if best:
			pounce(cub, best)
			return true
	return false


## The cub eats the zombie. Returns the batch key counted in WorldState.
func pounce(cub: Node2D, zombie: Node2D) -> String:
	var s := settings()
	var spot := zombie.global_position
	var key := "%s_batch_%d" % [zombie.original, zombie.batch]
	var ws := get_node("/root/WorldState")
	var counts: Dictionary = ws.get_flag(FLAG, {}).duplicate()
	counts[key] = int(counts.get(key, 0)) + 1
	ws.set_flag(FLAG, counts)
	var respawn := {"original": zombie.original, "batch": zombie.batch, "wander": zombie.wander}

	cub.busy = true
	cub.stop_walking()
	var hop := cub.create_tween()
	hop.tween_property(cub, "global_position", spot, 0.3).set_trans(Tween.TRANS_QUAD)
	var ground: float = cub.sprite.position.y
	var size: Vector2 = cub.sprite.scale
	hop.parallel().tween_property(cub.sprite, "position:y", ground - 18.0, 0.15).set_ease(Tween.EASE_OUT)
	hop.tween_property(cub.sprite, "position:y", ground, 0.15).set_ease(Tween.EASE_IN)
	for i in 2:  # chomp, chomp: a squash and the chomp frames
		hop.tween_property(cub.sprite, "scale", size * Vector2(1.13, 0.87), 0.1)
		hop.tween_property(cub.sprite, "scale", size, 0.1)
	hop.tween_callback(func() -> void:
		if cub.napping == false:
			cub.set_frame("_smeared"))
	zombie.get_eaten()
	splatter(spot)
	cub.set_frame("_smeared")
	cub.sprite.play("chomp")
	var noms: Array = cub.data().get("nom", [])
	cub.say(noms.pick_random() if not noms.is_empty() else "")

	var sounds: Array = s.get("sfx", [])
	for i in sounds.size():
		if i == 0:
			cub.play_sfx(sounds[0])
		else:
			get_tree().create_timer(SFX_GAP * i).timeout.connect(func() -> void:
				if is_instance_valid(cub):
					cub.play_sfx(sounds[i]))
	get_tree().create_timer(SFX_GAP * sounds.size() + 0.3).timeout.connect(func() -> void:
		if is_instance_valid(cub):
			cub.nap(float(s.get("nap_seconds", 6.0)), s.get("nap_sfx", "")))
	get_tree().create_timer(float(s.get("restock_seconds", 25.0))).timeout.connect(func() -> void:
		if is_inside_tree():
			restock(respawn))
	return key


## A fresh clone of the eaten batch climbs out of a tank.
func restock(info: Dictionary) -> Node2D:
	var tanks: Array = settings().get("tanks", [[300, 320]])
	var t: Array = tanks.pick_random()
	var z: Node2D = ZombieScene.instantiate()
	z.original = info["original"]
	z.batch = info["batch"]
	z.wander = info["wander"]
	z.position = Vector2(t[0], t[1])
	get_parent().add_child(z)
	z.scale = Vector2(0.2, 0.2)
	z.create_tween().tween_property(z, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return z


## Kawaii gore at a spot: splatter, hearts, sparkles, bouncing bits and a fading puddle.
func splatter(spot: Vector2) -> void:
	var puddle := Sprite2D.new()
	puddle.texture = _tex("gore_puddle")
	puddle.scale = Vector2(GORE_SCALE, GORE_SCALE)
	puddle.name = "Puddle"
	puddle.z_index = -8  # on the floor, under the characters
	gore.add_child(puddle)
	puddle.global_position = spot + Vector2(0, 14)
	var fade := puddle.create_tween()
	fade.tween_interval(float(settings().get("puddle_seconds", 8.0)))
	fade.tween_property(puddle, "modulate:a", 0.0, 1.5)
	fade.tween_callback(puddle.queue_free)

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.62, 0.75))
	ramp.set_color(1, Color(0.9, 0.25, 0.38))
	_burst(spot, null, 24, Color.WHITE, ramp, 2.5)
	_burst(spot, _tex("deco_heart"), 6, Color.WHITE, null, 0.7)
	_burst(spot, _tex("deco_sparkle"), 6, Color.WHITE, null, 0.7)

	for bit: String in ["gore_bone", "gore_chunk"]:
		var b := Sprite2D.new()
		b.texture = _tex(bit)
		b.scale = Vector2(GORE_SCALE, GORE_SCALE)
		gore.add_child(b)
		b.global_position = spot
		var dx := randf_range(-40.0, 40.0)
		var tw := b.create_tween()
		tw.tween_property(b, "position", b.position + Vector2(dx * 0.5, -30), 0.25).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "position", b.position + Vector2(dx, 14), 0.3).set_ease(Tween.EASE_IN)
		tw.tween_property(b, "position", b.position + Vector2(dx * 1.2, 6), 0.15).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "position", b.position + Vector2(dx * 1.3, 14), 0.15).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(b, "rotation", randf_range(-6.0, 6.0), 0.75)
		tw.tween_interval(1.5)
		tw.tween_property(b, "modulate:a", 0.0, 0.8)
		tw.tween_callback(b.queue_free)


func _burst(spot: Vector2, texture: Texture2D, amount: int, color: Color, ramp: Gradient, size: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 80.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 130.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = size
	p.scale_amount_max = size * 1.6
	p.color = color
	if ramp:
		p.color_initial_ramp = ramp
	if texture:
		p.texture = texture
	gore.add_child(p)
	p.global_position = spot
	p.emitting = true
	p.finished.connect(p.queue_free)


func _tex(name_: String) -> Texture2D:
	var path := "res://assets/ruins/%s.png" % name_
	return load(path) if ResourceLoader.exists(path) else null
