extends Node2D
## RuinsDecor — a ruins room's look, read from data/ruins.json ("rooms"): the floor and wall
## tiles (assets/ruins/ruins_tiles.png through ruins_tileset.tres, painted over the whole map),
## the props as sprites (assets/ruins/<kind>.png from tools/gen_ruins_art.py, or a canon cut
## in assets/canon), a title card on entering, ambient lines that cycle slowly, and a prop's
## note when the pointer rests on it.
## Props standing on the floor sort by their feet with the player and the clones (the room
## root and this node are y-sorted); "wall" props hang on the wall band behind everyone and
## "floor" props are painted flat on the floor. Standing and wall props get the paper look when
## their art is baked (bd gsd; tools/bake_paper.sh ruins, PaperBake): the bordered sheet over a
## soft shadow; floor props stay flat.

const ForbiddenKnowledge := preload("res://scripts/ruins/forbidden_knowledge.gd")
const TILESET := preload("res://assets/ruins/ruins_tileset.tres")
const VIGNETTE := preload("res://assets/ruins/vignette.png")
const AMBIENT_SECONDS := 7.0
const TITLE_SECONDS := 3.5
## Generated ruins art (tools/gen_ruins_art.py, gen_clone_children.py) is drawn at this many
## texels per world pixel and shown at 1/TEXELS, smoothly filtered (mipmaps, linear).
const TEXELS := 8.0
const TILE := 32
## World height of a canon cut (source resolution, assets/canon) when the room data gives none.
const CANON_HEIGHT := {"prop_seal_o": 36.0, "prop_scroll": 18.0, "prop_calendar": 20.0, "prop_tag_x": 20.0}
## Atlas columns and rows in ruins_tiles.png (see tools/gen_ruins_art.py tiles()).
const FLOORS := ["deck", "grate", "plate", "concrete", "lab", "carpet"]
const WALLS := ["hull", "service", "core", "bunker", "lab", "archive"]
const ANIMATED := {"ruins_tank": 4, "ruins_tank_duck": 4}  # kind -> frames in its sheet row

@export var room_id := ""

var tiles: TileMapLayer
var props: Array[Node2D] = []
var _lines: Array = []
var _next := 0
var _ambient: Label
var _hint: Label
var _hint_prop: Node2D


func _ready() -> void:
	var r := room()
	y_sort_enabled = true
	_paint_tiles(r)
	for prop: Dictionary in r.get("props", []):
		_add_prop(prop)
	_build_screen(r)


func room() -> Dictionary:
	return ForbiddenKnowledge.data().get("rooms", {}).get(room_id, {})


## The texture a prop or pickup id names: generated ruins art first, then a canon cut.
static func texture_for(kind: String) -> Texture2D:
	for dir: String in ["res://assets/ruins/", "res://assets/canon/"]:
		if ResourceLoader.exists(dir + kind + ".png"):
			return load(dir + kind + ".png")
	return null


## The world height `tex` (one frame `frame_h` texels tall) is shown at: generated ruins art at
## 1/TEXELS; a canon cut (kept at the sheet's resolution) at `world_h` px, or its CANON_HEIGHT.
static func world_height(tex: Texture2D, world_h := 0.0, frame_h := 0.0) -> float:
	var h := frame_h if frame_h > 0.0 else float(tex.get_height())
	if tex.resource_path.begins_with("res://assets/ruins/"):
		return h / TEXELS
	if world_h <= 0.0:
		world_h = CANON_HEIGHT.get(tex.resource_path.get_file().get_basename(), 32.0)
	return world_h



## The wall band fills the rows above the walkable floor (the Nav polygon's top edge).
func wall_rows() -> int:
	var nav := get_parent().get_node_or_null("Nav") as NavigationRegion2D if get_parent() else null
	if nav == null or nav.navigation_polygon == null or nav.navigation_polygon.get_outline_count() == 0:
		return 7
	var top := INF
	for v: Vector2 in nav.navigation_polygon.get_outline(0):
		top = minf(top, v.y)
	return maxi(3, int(top / TILE))


func _map_size() -> Vector2:
	var size: Variant = get_parent().get("map_size") if get_parent() else null
	return size if size is Vector2 and size != Vector2.ZERO else Vector2(960, 540)


func _paint_tiles(r: Dictionary) -> void:
	tiles = TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = TILESET
	tiles.z_index = -10
	tiles.scale = Vector2.ONE / TEXELS  # 256-texel atlas cells, 32 world px each
	add_child(tiles)
	var cols := int(ceil(_map_size().x / TILE))
	var rows := int(ceil(_map_size().y / TILE))
	var wall_rows := wall_rows()
	var floor_col := maxi(0, FLOORS.find(r.get("floor", "concrete")))
	var wall_col := maxi(0, WALLS.find(r.get("wall", "bunker")))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(room_id)
	for y in rows:
		for x in cols:
			var cell: Vector2i
			if y == 0:
				cell = Vector2i(wall_col, 2)  # cap
			elif y < wall_rows - 2:
				cell = Vector2i(wall_col, 3)  # panels
			elif y == wall_rows - 2:
				cell = Vector2i(wall_col, 4)  # accent stripe
			elif y == wall_rows - 1:
				cell = Vector2i(wall_col, 5)  # skirting
			elif y == rows - 1:
				cell = Vector2i(6, 1)  # the floor's front lip
			else:
				cell = Vector2i(floor_col, 1 if rng.randf() < 0.08 else 0)
			tiles.set_cell(Vector2i(x, y), 0, cell)
	# the skirting's soft shadow along the first floor row
	var shade := TileMapLayer.new()
	shade.name = "WallShadow"
	shade.tile_set = TILESET
	shade.z_index = -9
	shade.scale = Vector2.ONE / TEXELS
	add_child(shade)
	for x in cols:
		shade.set_cell(Vector2i(x, wall_rows), 0, Vector2i(6, 2))


func _add_prop(prop: Dictionary) -> void:
	var kind: String = prop.get("kind", "")
	var tex := texture_for(kind)
	if tex == null:
		push_warning("ruins prop %s has no texture" % kind)
		return
	var place: String = prop.get("place", "")
	var holder := Node2D.new()
	holder.name = kind
	var feet := Vector2(prop["x"], prop["y"])
	holder.position = feet
	holder.set_meta("text", prop.get("text", ""))
	if place == "wall":
		holder.z_index = -8
	elif place == "floor":
		holder.z_index = -7
	var frames: int = ANIMATED.get(kind, 1)
	var cell := Vector2(tex.get_width() / float(frames), tex.get_height())
	var node: Node2D
	if frames > 1:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = sheet_frames(tex, frames, 6.0)
		anim.play("default")
		anim.frame = randi() % frames
		node = anim
	else:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		node = sprite
	SpriteFit.fit(node, world_height(tex, float(prop.get("h", 0.0))))
	var s := node.scale.x
	holder.add_child(node)
	holder.set_meta("rect", Rect2(feet - Vector2(cell.x * s / 2.0, cell.y * s), cell * s))
	holder.set_meta("place", place)
	if place != "floor":  # floor props are painted flat on the floor: no paper edge, no shadow
		_paper(node, tex, frames)
	add_child(holder)
	props.append(holder)


## The paper look (bd gsd; tools/bake_paper.sh ruins) for a prop already fitted to its source art:
## a still one through PaperBake.dress; an animated one (a tank) plays the bordered sheet's frames,
## at the same size and place (offset x k, scale / k), over its baked shadow, which follows its
## frame. Art with no bake stays as it is.
func _paper(node: Node2D, tex: Texture2D, frames: int) -> void:
	if node is Sprite2D:
		PaperBake.dress(node as Sprite2D)
		return
	var anim := node as AnimatedSprite2D
	var bake := PaperBake.name_of(tex.resource_path)
	var edge := PaperBake.sheet(bake, PaperBake.EDGE)
	if anim == null or edge == "":
		return
	var k := PaperBake.resample(bake)
	var at := anim.frame
	anim.sprite_frames = sheet_frames(load(edge) as Texture2D, frames, 6.0)
	anim.play("default")
	anim.frame = at
	anim.offset *= k
	anim.scale /= k
	var shadow_path := PaperBake.sheet(bake, PaperBake.SHADOW)
	if shadow_path == "":
		return
	var sh := AnimatedSprite2D.new()
	sh.name = "PaperShadow"
	sh.sprite_frames = sheet_frames(load(shadow_path) as Texture2D, frames, 6.0)
	sh.offset = anim.offset
	sh.show_behind_parent = true
	PaperBake.style_shadow(sh, anim.scale)
	anim.add_child(sh)
	sh.frame = anim.frame
	anim.frame_changed.connect(func() -> void: sh.frame = anim.frame)


## SpriteFrames over one row of a sheet: `frames` equal cells, looping at `fps`.
static func sheet_frames(tex: Texture2D, frames: int, fps: float) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", true)
	var w := tex.get_width() / frames
	for i in frames:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * w, 0, w, tex.get_height())
		sf.add_frame("default", at)
	return sf


func _build_screen(r: Dictionary) -> void:
	# The vignette: its own CanvasLayer, added before the map's HUD so the HUD draws over it.
	var shade := CanvasLayer.new()
	shade.name = "Gloom"
	shade.layer = 0  # over the room, under the HUD and the room text, which sit at 1
	add_child(shade)
	var vignette := TextureRect.new()
	vignette.name = "Vignette"
	vignette.texture = VIGNETTE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(vignette)
	var screen := CanvasLayer.new()
	screen.name = "RoomText"
	add_child(screen)
	# Title card: shown on entering, then fades. Text sits on screen, not in the room: the
	# camera shows only a slice of the room.
	var title := Label.new()
	title.name = "Title"
	title.text = r.get("title", "")
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.offset_top = 22
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card(title, 13, 0.92)
	screen.add_child(title)
	if DisplayServer.get_name() != "headless":
		var fade := title.create_tween()
		fade.tween_interval(TITLE_SECONDS)
		fade.tween_property(title, "modulate:a", 0.0, 1.2)
	_lines = r.get("ambient", [])
	_ambient = Label.new()
	_ambient.name = "Ambient"
	_ambient.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_ambient.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ambient.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ambient.custom_minimum_size = Vector2(440, 0)
	_ambient.offset_bottom = -8
	_ambient.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ambient.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card(_ambient, 9, 0.78)
	screen.add_child(_ambient)
	_hint = Label.new()
	_hint.name = "Hint"
	_card(_hint, 8, 0.9)
	_hint.hide()
	screen.add_child(_hint)
	if not _lines.is_empty():
		var timer := Timer.new()
		timer.wait_time = AMBIENT_SECONDS
		timer.timeout.connect(_show_next)
		add_child(timer)
		timer.start()
		_show_next()


func _show_next() -> void:
	_ambient.text = _lines[_next % _lines.size()]
	_next += 1


## Resting the pointer on a prop shows its note in a small card above the pointer.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion) or _hint == null:
		return
	var at := get_global_mouse_position()
	var found: Node2D = null
	for p: Node2D in props:
		if String(p.get_meta("text", "")) != "" and (p.get_meta("rect") as Rect2).has_point(at):
			if found == null or p.position.y > found.position.y:  # the nearest one in front
				found = p
	if found != _hint_prop:
		_hint_prop = found
		_hint.visible = found != null
		if found:
			_hint.text = found.get_meta("text")
			_hint.reset_size()
	if found:
		var pos: Vector2 = get_viewport().get_canvas_transform() * at
		var view := get_viewport().get_visible_rect().size
		_hint.position = Vector2(clampf(pos.x - _hint.size.x / 2.0, 4, view.x - _hint.size.x - 4), maxf(4, pos.y - _hint.size.y - 10))


## On-screen text on a soft rounded card (STYLE.md: ruins captions #f2e6f2 on #331f40).
func _card(label: Label, size: int, alpha: float) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("#f2e6f2"))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Color("#331f40"), alpha)
	box.border_color = Color(Color("#c9b3f0"), 0.55)
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 3
	box.content_margin_bottom = 4
	label.add_theme_stylebox_override("normal", box)
