extends Node2D
## Conquest review slice (scenes/test/conquest.tscn; opened with ?scene=conquest on the web or
## `-- --scene=conquest` on desktop, see DevScene). Not in the player build (export_presets.cfg
## excludes scenes/test/ and scripts/test/). The rules live in conquest_sim.gd; this script shows
## them on the village island and takes the player's orders.
##
## Controls: click one of our leaders (or press 1/2/3, or her panel) to select her, then click a
## settlement, a rival band, an animal or open ground. Orders to a leader far from the first one
## go by letter (the scroll icon) and take longer the farther she is. Arrows/WASD or a right-drag
## pan; the wheel or +/- zooms; Space centres on the selected leader.
## The island art is the village map's own tiles and props, lifted out of village.tscn without
## running it (no player, no NPCs, no map.gd, no WorldState).

const Sim := preload("res://scripts/test/conquest/conquest_sim.gd")
const SETUP_PATH := "res://scripts/test/conquest/conquest.json"
const LAYOUT_PATH := "res://data/island_layout.json"
const VILLAGE := "res://scenes/maps/village.tscn"
const RIG := "res://assets/characters/%s_rig.png"
const LIVESTOCK_FRAMES := "res://assets/florida/crab.tres"
const SEAL_TEX := preload("res://assets/canon/prop_seal_o.png")
const LETTER_TEX := preload("res://assets/canon/prop_scroll.png")
const MARK_TEX := preload("res://assets/canon/deco_sparkle.png")
const MAP_SIZE := Vector2(1280, 1216)
const LEADER_H := 52.0
const FOLLOWER_H := 40.0
const FEET := 50.0 / 52.0
const SHOWN_FOLLOWERS := 9
const ZOOMS := [0.5, 0.75, 1.0]  # 0.5 shows the island's full width
const PAN_SPEED := 420.0
const SIDE_COLORS := {0: Color(1.0, 0.55, 0.72), 1: Color(0.55, 0.68, 1.0), -1: Color(0.92, 0.9, 0.82)}

var sim: Object
var setup: Dictionary = {}
var selected := -1  # leader id, or -1

var _world: Node2D
var _cam: Camera2D
var _zoom_i := 0
var _leader_views: Dictionary = {}  # leader id -> {body, label, followers}
var _settlement_views: Dictionary = {}  # settlement id -> {seal, label}
var _beast_views: Dictionary = {}  # beast id -> AnimatedSprite2D
var _letters: Array = []  # Sprite2D pool
var _mark: Sprite2D
var _world_labels: Array = []  # Labels kept at screen size whatever the zoom
var _top: Label
var _log: Label
var _panels: Array = []  # per player leader: {panel, name, stats, buttons}
var _end: PanelContainer
var _drag := false


func _ready() -> void:
	setup = JSON.parse_string(FileAccess.get_file_as_string(SETUP_PATH))
	for l: Dictionary in setup.get("leaders", []):
		if l.has("name_cast"):
			l["name"] = Cast.full(str(l["name_cast"]))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	sim = Sim.new(int(Time.get_ticks_usec()))
	sim.set_walk_mask(layout["mask"], 32.0)
	sim.load_setup(setup)
	_world = Node2D.new()
	_world.name = "World"
	_world.y_sort_enabled = true
	add_child(_world)
	_lift_island()
	_build_entities()
	_cam = Camera2D.new()
	_cam.name = "Camera"
	_cam.limit_left = 0
	_cam.limit_top = 0
	_cam.limit_right = int(MAP_SIZE.x)
	_cam.limit_bottom = int(MAP_SIZE.y)
	add_child(_cam)
	_cam.make_current()
	_set_zoom(_zoom_i)
	_build_ui()
	select_leader(0)
	_center_on(sim.leaders[0].pos)


## --- Building ---

## The village's ground tiles and props, without the scene's people, doors or script.
func _lift_island() -> void:
	var village: Node = (load(VILLAGE) as PackedScene).instantiate()
	for child: Node in village.get_children():
		if child is TileMapLayer or (child is Sprite2D and child.get_script() == null):
			village.remove_child(child)
			child.owner = null
			_world.add_child(child)
	village.free()


func _build_entities() -> void:
	for s: Object in sim.settlements:
		var seal := Sprite2D.new()
		seal.texture = SEAL_TEX
		SpriteFit.fit(seal, 18.0)
		seal.position = s.pos
		_world.add_child(seal)
		var label := _world_label(s.pos + Vector2(0, 4))
		_settlement_views[s.id] = {"seal": seal, "label": label}
	for b: Object in sim.beasts:
		var a := AnimatedSprite2D.new()
		a.sprite_frames = load(LIVESTOCK_FRAMES)
		a.play(&"walk")
		SpriteFit.fit(a, 14.0)
		a.position = b.pos
		_world.add_child(a)
		_beast_views[b.id] = a
	for l: Object in sim.leaders:
		var body := _character(l.caste, LEADER_H)
		body.name = "Leader_%d" % l.id
		body.position = l.pos
		_world.add_child(body)
		var followers: Array = []
		for i in SHOWN_FOLLOWERS:
			var f := _character(l.follower_caste, FOLLOWER_H)
			f.position = l.pos + Vector2(randf_range(-10, 10), randf_range(4, 14))
			_world.add_child(f)
			followers.append(f)
		var label := _world_label(l.pos + Vector2(0, -LEADER_H - 12))
		_leader_views[l.id] = {"body": body, "label": label, "followers": followers}
	_mark = Sprite2D.new()
	_mark.texture = MARK_TEX
	SpriteFit.fit(_mark, 12.0)
	_mark.z_index = 10
	add_child(_mark)


func _character(caste: String, h: float) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = RigSheet.frames(RIG % caste)
	a.play(&"idle_down")
	SpriteFit.fit(a, h, FEET)
	return a


## A label over the world that keeps its screen size at any zoom.
func _world_label(at: Vector2) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"NameLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 20
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta(&"anchor", at)
	add_child(label)
	_world_labels.append(label)
	return label


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	var top := PanelContainer.new()
	top.theme_type_variation = &"HudPanel"
	top.position = Vector2(6, 5)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top)
	var col := VBoxContainer.new()
	top.add_child(col)
	_top = Label.new()
	col.add_child(_top)
	_log = Label.new()
	_log.theme_type_variation = &"HintLabel"
	col.add_child(_log)
	var row := HBoxContainer.new()
	row.name = "Panels"
	row.add_theme_constant_override("separation", 4)
	row.position = Vector2(6, 290)
	layer.add_child(row)
	var player_leaders: Array = sim.leaders.filter(func(l: Object) -> bool: return l.side == Sim.PLAYER)
	for i in player_leaders.size():
		var l: Object = player_leaders[i]
		var panel := PanelContainer.new()
		panel.name = "Panel_%d" % l.id
		panel.theme_type_variation = &"HudPanel"
		panel.custom_minimum_size = Vector2(200, 0)
		row.add_child(panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		panel.add_child(v)
		var name_btn := Button.new()
		name_btn.text = "%d  %s" % [i + 1, l.name]
		name_btn.flat = true
		name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_btn.pressed.connect(select_leader.bind(l.id))
		v.add_child(name_btn)
		var stats := Label.new()
		stats.theme_type_variation = &"HintLabel"
		v.add_child(stats)
		var h := HBoxContainer.new()
		v.add_child(h)
		var group := ButtonGroup.new()
		var buttons := {}
		for p: String in Sim.POSTURES:
			var b := Button.new()
			b.text = str(setup.get("postures", {}).get(p, {}).get("label", p.capitalize()))
			b.toggle_mode = true
			b.button_group = group
			b.button_pressed = l.posture == p
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func() -> void: sim.set_posture(l, p))
			h.add_child(b)
			buttons[p] = b
		_panels.append({"leader": l, "panel": panel, "stats": stats, "buttons": buttons, "name": name_btn})
	_end = PanelContainer.new()
	_end.theme_type_variation = &"HudPanel"
	_end.visible = false
	_end.position = Vector2(220, 140)
	layer.add_child(_end)
	var ev := VBoxContainer.new()
	ev.name = "Box"
	_end.add_child(ev)
	var end_label := Label.new()
	end_label.name = "Text"
	ev.add_child(end_label)
	var again := Button.new()
	again.text = "Again"
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	ev.add_child(again)


## --- Running ---

func _process(delta: float) -> void:
	sim.step(delta)
	_pan(delta)
	_sync_world(delta)
	_sync_ui()


func _sync_world(delta: float) -> void:
	for s: Object in sim.settlements:
		var v: Dictionary = _settlement_views[s.id]
		(v["seal"] as Sprite2D).modulate = SIDE_COLORS[s.owner]
		var label: Label = v["label"]
		label.text = "%s\n%d people · %d food" % [s.name, s.pop, int(s.food)]
		label.self_modulate = SIDE_COLORS[s.owner]
	for b: Object in sim.beasts:
		var a: AnimatedSprite2D = _beast_views[b.id]
		a.visible = b.alive
		a.position = b.pos
	for l: Object in sim.leaders:
		var v: Dictionary = _leader_views[l.id]
		var body: AnimatedSprite2D = v["body"]
		var label: Label = v["label"]
		var moving: bool = body.position.distance_to(l.pos) > 0.05
		_face(body, l.pos - body.position, moving)
		body.position = l.pos
		body.visible = not l.out
		label.visible = not l.out
		label.set_meta(&"anchor", l.pos + Vector2(0, -LEADER_H - 14))
		var state := " (hungry)" if l.starving() else ""
		label.text = "%s · %d%s" % [l.name, l.men, state]
		label.self_modulate = SIDE_COLORS[l.side]
		var side_dir: Vector2 = Vector2(-l.facing.y, l.facing.x)
		var followers: Array = v["followers"]
		for i in followers.size():
			var f: AnimatedSprite2D = followers[i]
			f.visible = not l.out and i < l.men
			if not f.visible:
				continue
			var slot: Vector2 = l.pos - l.facing * (16.0 + (i / 3) * 11.0) + side_dir * ((i % 3) - 1) * 13.0
			var step := f.position.move_toward(slot, (sim.speed + 20.0) * delta)
			_face(f, step - f.position, step.distance_to(f.position) > 0.05)
			f.position = step
	# Letters on the way: from the first leader towards the one they are for.
	var couriers: Array = sim.couriers
	while _letters.size() < couriers.size():
		var s := Sprite2D.new()
		s.texture = LETTER_TEX
		SpriteFit.fit(s, 12.0)
		s.z_index = 15
		add_child(s)
		_letters.append(s)
	for i in _letters.size():
		var s: Sprite2D = _letters[i]
		s.visible = i < couriers.size()
		if s.visible:
			var c: Object = couriers[i]
			var to: Vector2 = sim.leaders[c.leader_id].pos + Vector2(0, -LEADER_H)
			s.position = (c.from + Vector2(0, -LEADER_H)).lerp(to, clampf(c.t / c.duration, 0.0, 1.0))
	_mark.visible = selected >= 0 and not sim.leaders[selected].out
	if _mark.visible:
		_mark.position = sim.leaders[selected].pos + Vector2(0, -LEADER_H - 30.0 / _cam.zoom.x)
	var inv := Vector2.ONE / _cam.zoom
	for label: Label in _world_labels:
		label.scale = inv
		var at: Vector2 = label.get_meta(&"anchor")
		label.position = at - Vector2(label.size.x * inv.x / 2.0, 0)


func _face(a: AnimatedSprite2D, d: Vector2, moving: bool) -> void:
	var dir := "down"
	if moving and d.length() > 0.0:
		if absf(d.x) > absf(d.y):
			dir = "left"
			a.flip_h = d.x > 0.0
		else:
			dir = "down" if d.y > 0.0 else "up"
			a.flip_h = false
	else:
		var cur := String(a.animation)
		dir = cur.get_slice("_", 1) if cur.contains("_") else "down"
	var anim := StringName(("walk_" if moving else "idle_") + dir)
	if a.animation != anim:
		a.play(anim)


func _sync_ui() -> void:
	var lean := "  · lean days, bands eat double" if sim.is_lean() else ""
	_top.text = "Day %d of %d%s   ·   %s hold %d%% of the people   ·   %s %d%%" % [
		sim.day(), sim.days_per_cycle, lean, sim.side_names[Sim.PLAYER], roundi(sim.share(Sim.PLAYER) * 100),
		sim.side_names[Sim.RIVAL], roundi(sim.share(Sim.RIVAL) * 100)]
	var tail: Array = sim.events.slice(maxi(sim.events.size() - 2, 0))
	_log.text = "\n".join(tail) if not tail.is_empty() else "Select a leader (1/2/3), then click a settlement, a band, an animal or the ground."
	for p: Dictionary in _panels:
		var l: Object = p["leader"]
		var stats: Label = p["stats"]
		if l.out:
			stats.text = "out of the game"
		else:
			var doing := "idle"
			if l.starving():
				doing = "starving, not listening"
			elif not l.order.is_empty():
				doing = "on the way"
			elif sim.couriers.any(func(c: Object) -> bool: return c.leader_id == l.id):
				doing = "a letter is coming"
			stats.text = "%d followers · %d food · %s" % [l.men, int(l.food), doing]
		(p["panel"] as Control).modulate = Color(1, 1, 1, 1) if selected == l.id else Color(1, 1, 1, 0.8)
		for posture: String in p["buttons"]:
			var b: Button = p["buttons"][posture]
			b.disabled = l.out
			if l.posture == posture and not b.button_pressed:
				b.set_pressed_no_signal(true)
	if sim.outcome != "" and not _end.visible:
		_end.visible = true
		(_end.get_node("Box/Text") as Label).text = (
				"%s hold most of the island's people. The island contributes." % sim.side_names[Sim.PLAYER]
				if sim.outcome == "won" else "%s are out of the running." % sim.side_names[Sim.PLAYER])


## --- Input ---

func select_leader(id: int) -> void:
	if id >= 0 and id < sim.leaders.size() and sim.leaders[id].side == Sim.PLAYER and not sim.leaders[id].out:
		selected = id


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3:
				var ours: Array = sim.leaders.filter(func(l: Object) -> bool: return l.side == Sim.PLAYER)
				var i: int = event.keycode - KEY_1
				if i < ours.size():
					select_leader(ours[i].id)
			KEY_SPACE:
				if selected >= 0:
					_center_on(sim.leaders[selected].pos)
			KEY_EQUAL, KEY_KP_ADD:
				_set_zoom(_zoom_i + 1)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_set_zoom(_zoom_i - 1)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_set_zoom(_zoom_i + 1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_set_zoom(_zoom_i - 1)
		elif mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_drag = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			click_world(get_global_mouse_position())
	elif event is InputEventMouseMotion and _drag:
		_cam.position -= (event as InputEventMouseMotion).relative / _cam.zoom
		_clamp_cam()


## A click on the island at world position p: select one of ours, or order the selected leader.
func click_world(p: Vector2) -> void:
	for l: Object in sim.leaders:
		if l.side == Sim.PLAYER and not l.out and _hit(l.pos + Vector2(0, -LEADER_H / 2.0), p, 22.0):
			select_leader(l.id)
			return
	if selected < 0 or sim.outcome != "":
		return
	var me: Object = sim.leaders[selected]
	var order := {}
	for l: Object in sim.leaders:
		if l.side != Sim.PLAYER and not l.out and _hit(l.pos + Vector2(0, -LEADER_H / 2.0), p, 24.0):
			order = {"kind": "leader", "id": l.id}
	if order.is_empty():
		for b: Object in sim.beasts:
			if b.alive and _hit(b.pos, p, 14.0):
				order = {"kind": "beast", "id": b.id}
	if order.is_empty():
		for s: Object in sim.settlements:
			if _hit(s.pos, p, 34.0):
				order = {"kind": "settlement", "id": s.id}
	if order.is_empty():
		if not sim.walkable(p):
			return
		order = {"kind": "move", "pos": p}
	sim.issue_order(me, order)


func _hit(at: Vector2, p: Vector2, r: float) -> bool:
	return at.distance_to(p) <= r / minf(_cam.zoom.x, 1.0) * 0.6 + r * 0.4


func _pan(delta: float) -> void:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		d.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		d.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		d.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		d.y += 1
	if d != Vector2.ZERO:
		_cam.position += d.normalized() * PAN_SPEED * delta / _cam.zoom.x
		_clamp_cam()


func _set_zoom(i: int) -> void:
	_zoom_i = clampi(i, 0, ZOOMS.size() - 1)
	_cam.zoom = Vector2.ONE * float(ZOOMS[_zoom_i])
	_clamp_cam()


func _center_on(p: Vector2) -> void:
	_cam.position = p
	_clamp_cam()


## Keeps the camera's centre where the view stays on the map (limits alone let the centre drift).
func _clamp_cam() -> void:
	var half := get_viewport_rect().size / _cam.zoom / 2.0
	_cam.position.x = clampf(_cam.position.x, minf(half.x, MAP_SIZE.x / 2.0), maxf(MAP_SIZE.x - half.x, MAP_SIZE.x / 2.0))
	_cam.position.y = clampf(_cam.position.y, minf(half.y, MAP_SIZE.y / 2.0), maxf(MAP_SIZE.y - half.y, MAP_SIZE.y / 2.0))
