extends Node2D
## Paper look test scene (persistint-game-1dx, gsd, 2xr): the same subjects three times, side by
## side on island grass, so the Paper Mario edge and drop shadow can be judged on a real screen.
##
##   A  as shipped: the art exactly as the game draws it today (one draw per sprite).
##   B  engine-side: a flat white copy of the sprite drawn under it in eight directions (the border)
##      plus one black translucent copy offset down-right (a hard shadow). No shader taps, no blur,
##      but 10 draws per subject instead of 1.
##   C  baked: tools/gen_paper_edges.py wrote the border into a sibling sheet and the soft shadow
##      into another; two draws per subject, the shadow's offset and strength set in the engine.
##
## Open with ?scene=paper_look on the web build or `godot --path project -- --scene=paper_look`.
## Tap any subject to pixelate it for a moment (the gsd tap effect); the border stays crisp.

const BAKE_DIR := "res://assets/test/paper_look/"
const PAPER_FLAT := "res://shaders/paper_flat.gdshader"
const PIXELATE := "res://shaders/pixelate.gdshader"
const TILESET := "res://assets/tiles/island_tileset.tres"
const COLUMN_W := 108.0
const LEFT := 10.0  # first column's x: keeps the leftmost tree inside the 320 px view
const COLUMNS := ["A", "B", "C"]
const PAPERS := {"white": Color("fffdf7"), "cream": Color("fff0d2")}
const RIG_FEET := 50.0 / 52.0
const OUTLINE_DIRS := [
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071), Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071),
]
## name, kind, source sheet(s), shown height, feet line, where it stands in a column (feet).
const SUBJECTS := [
	{"name": "tree_a", "kind": "still", "src": ["res://assets/canon/deco_tree_a.png"], "h": 52.0, "feet": 1.0, "at": Vector2(20, 58)},
	{"name": "tree_b", "kind": "still", "src": ["res://assets/canon/deco_tree_b.png"], "h": 52.0, "feet": 1.0, "at": Vector2(86, 54)},
	{"name": "flowers", "kind": "still", "src": ["res://assets/canon/deco_flowers.png"], "h": 22.0, "feet": 1.0, "at": Vector2(54, 74)},
	{"name": "fence_a", "kind": "still", "src": ["res://assets/canon/prop_fence_a.png"], "h": 34.0, "feet": 1.0, "at": Vector2(24, 98)},
	{"name": "sign_a", "kind": "still", "src": ["res://assets/canon/prop_sign_a.png"], "h": 48.0, "feet": 1.0, "at": Vector2(88, 96)},
	{"name": "npc_mother", "kind": "rig", "src": ["res://assets/characters/npc_mother_rig.png"], "h": 52.0, "feet": RIG_FEET, "at": Vector2(22, 128)},
	{"name": "player", "kind": "rig", "src": ["res://assets/characters/player/body_base_rig.png", "res://assets/characters/player/dress_white_rig.png", "res://assets/characters/player/hair_braids_rig.png"], "h": 48.0, "feet": 1.0, "at": Vector2(54, 130)},
	{"name": "npc_initiate", "kind": "rig", "src": ["res://assets/characters/npc_initiate_rig.png"], "h": 52.0, "feet": RIG_FEET, "at": Vector2(86, 126)},
]

var edge_px := 2
var paper := "white"
var shadow_offset := 3.0
var shadow_alpha := 0.3
var shadow_soft := true
var filter_linear := false
var walking := false

var columns: Dictionary = {}  # "A" -> Node2D
var subjects: Array[Dictionary] = []  # per built subject: column, name, root, sprites, outline, shadow, bake
var camera: Camera2D
var stats: Label
var _stats_clock := 0.0
var _flat: Shader
var _pixel: Shader


func _ready() -> void:
	_flat = load(PAPER_FLAT)
	_pixel = load(PIXELATE)
	_build_ground()
	for i in COLUMNS.size():
		var col := Node2D.new()
		col.name = "Column" + COLUMNS[i]
		col.position = Vector2(LEFT + i * COLUMN_W, 0.0)
		col.y_sort_enabled = true
		add_child(col)
		columns[COLUMNS[i]] = col
		_label(col, COLUMNS[i] + ("  as shipped" if i == 0 else ("  engine (10 draws)" if i == 1 else "  baked (2 draws)")), Vector2(2, -4))
		for s in SUBJECTS:
			_build_subject(COLUMNS[i], s)
	camera = Camera2D.new()
	camera.position = Vector2(LEFT + COLUMN_W * 1.5, 72.0)
	camera.zoom = Vector2(2, 2)
	add_child(camera)
	_build_ui()
	_apply_all()


# ---------------------------------------------------------------- scene
func _build_ground() -> void:
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = load(TILESET)
	ground.scale = Vector2(0.25, 0.25)
	ground.z_index = -9
	ground.position = Vector2(-16, -32)
	for y in 7:
		for x in 11:
			var atlas := Vector2i(1 if (x + y) % 3 == 0 else 0, 0)  # grass_a / grass_b
			ground.set_cell(Vector2i(x, y), 0, atlas)
	add_child(ground)


func _label(parent: Node, text: String, at: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.z_index = 20
	l.add_theme_font_size_override("font_size", 7)
	l.add_theme_color_override("font_color", Color(0.2, 0.12, 0.2))
	l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	parent.add_child(l)
	return l


## A sprite for one source sheet: AnimatedSprite2D for a rig (8x3 grid, RigSheet), Sprite2D for a still.
func _sprite_for(kind: String, path: String) -> Node2D:
	if kind == "rig":
		var a := AnimatedSprite2D.new()
		a.sprite_frames = RigSheet.frames(path)
		a.animation = "idle_down"
		a.play()
		return a
	var s := Sprite2D.new()
	s.texture = load(path)
	return s


func _build_subject(column: String, s: Dictionary) -> void:
	var root := Node2D.new()
	root.name = s["name"]
	root.position = s["at"]
	columns[column].add_child(root)
	var entry := {"column": column, "name": s["name"], "root": root, "sprites": [], "outline": [], "shadow": null, "bake": null, "h": s["h"], "feet": s["feet"]}
	var sources: Array = s["src"]
	if column == "C":
		var side := _sidecar(s["name"])
		entry["bake"] = side
		if side.is_empty():
			_label(root, "no bake", Vector2(-12, -20))
		else:
			var shadow := _baked_sprite(s["kind"], side, "shadow_soft" if shadow_soft else "shadow_hard")
			shadow.z_index = -1
			shadow.modulate = Color(0, 0, 0, shadow_alpha)
			root.add_child(shadow)
			entry["shadow"] = shadow
			var main := _baked_sprite(s["kind"], side, "edge%d_%s" % [edge_px, paper])
			root.add_child(main)
			entry["sprites"].append(main)
	else:
		if column == "B":
			# One hard shadow from the first (body) layer, then the eight border copies of every layer.
			var shadow := _sprite_for(s["kind"], sources[0])
			shadow.z_index = -1
			shadow.material = _flat_material(Color(0, 0, 0, shadow_alpha))
			SpriteFit.fit(shadow, s["h"], s["feet"])
			root.add_child(shadow)
			entry["shadow"] = shadow
			for path in sources:
				for d in OUTLINE_DIRS:
					var o := _sprite_for(s["kind"], path)
					o.material = _flat_material(PAPERS[paper])
					SpriteFit.fit(o, s["h"], s["feet"])
					o.position = d * edge_px
					root.add_child(o)
					entry["outline"].append(o)
		for path in sources:
			var sp := _sprite_for(s["kind"], path)
			SpriteFit.fit(sp, s["h"], s["feet"])
			root.add_child(sp)
			entry["sprites"].append(sp)
	# Tap target over the frame.
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var fw: float = s["h"] * 0.7
	rect.size = Vector2(fw, s["h"])
	shape.shape = rect
	shape.position = Vector2(0, -s["h"] * 0.5)
	area.add_child(shape)
	area.input_event.connect(_on_subject_input.bind(entry))
	root.add_child(area)
	subjects.append(entry)


func _sidecar(name: String) -> Dictionary:
	var path := BAKE_DIR + name + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## A sprite showing one of a subject's baked sheets at the subject's shipped height.
func _baked_sprite(kind: String, side: Dictionary, which: String) -> Node2D:
	var path: String = BAKE_DIR + String(side["files"][which])
	var node := _sprite_for(kind, path)
	SpriteFit.fit(node, float(side["world_h_padded"]), float(side["feet"]))
	return node


func _flat_material(tint: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _flat
	m.set_shader_parameter("tint", tint)
	return m


# ---------------------------------------------------------------- live settings
func _apply_all() -> void:
	var filter := CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if filter_linear else CanvasItem.TEXTURE_FILTER_NEAREST
	for e in subjects:
		var off := Vector2(shadow_offset, shadow_offset * 0.6)
		if e["column"] == "B":
			for o in e["outline"]:
				o.position = o.position.normalized() * edge_px if o.position != Vector2.ZERO else Vector2.ZERO
				o.material.set_shader_parameter("tint", PAPERS[paper])
			if e["shadow"]:
				e["shadow"].position = off
				e["shadow"].material.set_shader_parameter("tint", Color(0, 0, 0, shadow_alpha))
		elif e["column"] == "C" and not e["bake"].is_empty():
			var side: Dictionary = e["bake"]
			var main: Node2D = e["sprites"][0]
			_retexture(main, BAKE_DIR + String(side["files"]["edge%d_%s" % [edge_px, paper]]))
			var sh: Node2D = e["shadow"]
			_retexture(sh, BAKE_DIR + String(side["files"]["shadow_soft" if shadow_soft else "shadow_hard"]))
			sh.position = off
			sh.modulate = Color(0, 0, 0, shadow_alpha)
		for n in _all_sprites(e):
			n.texture_filter = filter
			if n is AnimatedSprite2D:
				var anim := "walk_down" if walking else "idle_down"
				if n.animation != anim:
					n.play(anim)
	for i in COLUMNS.size():
		columns[COLUMNS[i]].position.x = LEFT + i * COLUMN_W


func _retexture(node: Node2D, path: String) -> void:
	if node is AnimatedSprite2D:
		var a := node as AnimatedSprite2D
		if a.sprite_frames != RigSheet.frames(path):
			var anim: StringName = a.animation
			var frame: int = a.frame
			a.sprite_frames = RigSheet.frames(path)
			a.play(anim)
			a.frame = frame
	elif node is Sprite2D:
		(node as Sprite2D).texture = load(path)


func _all_sprites(e: Dictionary) -> Array:
	var out: Array = []
	out.append_array(e["sprites"])
	out.append_array(e["outline"])
	if e["shadow"]:
		out.append(e["shadow"])
	return out


func _process(delta: float) -> void:
	# Border and shadow copies follow the main sprite's frame.
	for e in subjects:
		if e["column"] != "B":
			continue
		var main := e["sprites"][0] as AnimatedSprite2D
		if main:
			for o in _all_sprites(e):
				var copy := o as AnimatedSprite2D
				if copy and copy != main and copy.sprite_frames == main.sprite_frames:
					copy.animation = main.animation
					copy.frame = main.frame
	_stats_clock += delta
	if _stats_clock >= 0.5 and stats:
		_stats_clock = 0.0
		stats.text = "FPS %d   draw calls %d   objects %d   zoom %.1f   %s" % [
			Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			camera.zoom.x, "linear+mipmaps" if filter_linear else "nearest (as shipped)"]


# ---------------------------------------------------------------- tap to pixelate (gsd / 2xr)
func _on_subject_input(_viewport: Node, event: InputEvent, _idx: int, e: Dictionary) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not tap:
		return
	get_viewport().set_input_as_handled()
	pixelate(e)


## Shifts the subject's art to coarse pixels and back over half a second; borders stay as they are.
func pixelate(e: Dictionary) -> void:
	var mats: Array[ShaderMaterial] = []
	var scales: Array[float] = []
	for n in e["sprites"]:
		var m := ShaderMaterial.new()
		m.shader = _pixel
		n.material = m
		mats.append(m)
		scales.append(n.scale.x)
	var tw := create_tween()
	tw.tween_method(func(block_world: float):
		for i in mats.size():
			mats[i].set_shader_parameter("block", block_world / maxf(scales[i], 0.0001)), 0.0, 5.0, 0.22)
	tw.tween_method(func(block_world: float):
		for i in mats.size():
			mats[i].set_shader_parameter("block", block_world / maxf(scales[i], 0.0001)), 5.0, 0.0, 0.3)
	tw.tween_callback(func():
		for n in e["sprites"]:
			n.material = null)


# ---------------------------------------------------------------- controls
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	stats = Label.new()
	stats.position = Vector2(6, 4)
	stats.add_theme_font_size_override("font_size", 9)
	stats.add_theme_color_override("font_color", Color(0.15, 0.1, 0.15))
	stats.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	stats.add_theme_constant_override("outline_size", 3)
	layer.add_child(stats)
	var panel := PanelContainer.new()
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.anchor_right = 1.0
	panel.offset_top = -58
	panel.offset_bottom = 0
	layer.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	panel.add_child(rows)
	var r1 := HBoxContainer.new()
	var r2 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 4)
	r2.add_theme_constant_override("separation", 4)
	rows.add_child(r1)
	rows.add_child(r2)
	# Row 1: edge width, paper colour, shadow softness, filter, walk.
	_text(r1, "edge")
	var edge_group := ButtonGroup.new()
	for w in [1, 2, 3]:
		var b := _button(r1, str(w), true, edge_group)
		b.button_pressed = w == edge_px
		b.pressed.connect(func(): edge_px = w; _apply_all())
	_text(r1, " paper")
	var paper_group := ButtonGroup.new()
	for p in ["white", "cream"]:
		var b := _button(r1, p, true, paper_group)
		b.button_pressed = p == paper
		b.pressed.connect(func(): paper = p; _apply_all())
	_text(r1, " shadow")
	var soft_group := ButtonGroup.new()
	for k in ["soft", "hard"]:
		var b := _button(r1, k, true, soft_group)
		b.button_pressed = (k == "soft") == shadow_soft
		b.pressed.connect(func(): shadow_soft = k == "soft"; _apply_all())
	_text(r1, " filter")
	var filt_group := ButtonGroup.new()
	for k in ["nearest", "linear"]:
		var b := _button(r1, k, true, filt_group)
		b.button_pressed = (k == "linear") == filter_linear
		b.pressed.connect(func(): filter_linear = k == "linear"; _apply_all())
	var walk := _button(r1, "walk", true)
	walk.toggled.connect(func(on: bool): walking = on; _apply_all())
	# Row 2: shadow offset and strength, columns, zoom.
	_text(r2, "offset")
	var off := _slider(r2, 0.0, 8.0, 0.5, shadow_offset)
	off.value_changed.connect(func(v: float): shadow_offset = v; _apply_all())
	_text(r2, " strength")
	var alpha := _slider(r2, 0.0, 0.7, 0.05, shadow_alpha)
	alpha.value_changed.connect(func(v: float): shadow_alpha = v; _apply_all())
	_text(r2, " show")
	for c in COLUMNS:
		var b := _button(r2, c, true)
		b.button_pressed = true
		b.toggled.connect(func(on: bool): columns[c].visible = on)
	_text(r2, " zoom")
	var zin := _button(r2, "+", false)
	zin.pressed.connect(func(): camera.zoom = Vector2.ONE * minf(camera.zoom.x + 0.5, 5.0))
	var zout := _button(r2, "-", false)
	zout.pressed.connect(func(): camera.zoom = Vector2.ONE * maxf(camera.zoom.x - 0.5, 1.0))
	var menu := _button(r2, "menu", false)
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))


func _text(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 9)
	parent.add_child(l)


func _button(parent: Control, text: String, toggle: bool, group: ButtonGroup = null) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	if group:
		b.button_group = group
	b.custom_minimum_size = Vector2(26, 24)
	b.add_theme_font_size_override("font_size", 9)
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b


func _slider(parent: Control, lo: float, hi: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(70, 24)
	s.focus_mode = Control.FOCUS_NONE
	parent.add_child(s)
	return s
