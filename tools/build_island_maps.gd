extends SceneTree
## Builds the island tileset and the village/temple map scenes.
## Run, from the repo root, after any art change:
##   python3 -I tools/gen_island_tiles.py && python3 -I tools/gen_temple_props.py && python3 -I tools/gen_village_props.py
##   godot --headless --path project --import
##   cd project && godot --headless --path . -s ../tools/build_island_maps.gd
##   (the canon props come from python3 -I tools/cut_island_props.py, the greenery from
##   python3 -I tools/gen_island_deco.py)
## Paper look (bd gsd): tools/bake_paper.sh greenery props (and the import) before this; _prop and
## _mirror then draw each baked prop from its bordered sheet over its soft shadow (PaperBake).
## Layouts live here as code (cell = 32 world px); the scenes are the output. Re-run after edits.
## Resolution: the art files are drawn at 4x their size on the map (tiles 128 px per 32 px cell,
## generated props ART_SCALE = 0.25) and canon cuts keep the sheet's own resolution, scaled to the
## display height in data/island_props.json. Textures are imported with mipmaps and the project
## default canvas filter is Linear Mipmap, so everything is downsampled smoothly.
## Tile names and atlas cells come from assets/tiles/island_tiles.json (written by the tile
## generator); the village gets dual-grid edge overlays (Shallows, Shore, PathEdge, PavingEdge,
## GrassEdge), drawn in that order so each border runs up to the next instead of stopping short.

const CELL := 32
## Tile names and atlas cells come from the tile generator (tools/gen_island_tiles.py).
const INDEX_PATH := "res://assets/tiles/island_tiles.json"
const TILESET_PATH := "res://assets/tiles/island_tileset.tres"
const PROPS_DIR := "res://assets/canon/"
## Canon cuts: name -> display height in world px (tools/cut_island_props.py reads the same file).
const CUTS_PATH := "res://data/island_props.json"
## Generated art (tools/gen_*.py) is drawn at 4 file px per world px.
const ART_SCALE := 0.25
## Cut by tools/cut_canon_sprites.sh / tools/gen_island_deco.py, not listed in island_props.json:
## display heights in world px.
const OTHER_HEIGHTS := {"deco_tree_a": 52.0, "deco_tree_b": 52.0, "deco_tree_c": 52.0, "deco_flowers": 22.0}

var _ts: TileSet
var _walk: Array = []
var _solid: Array = []
var _cells: Dictionary = {}  # tile name -> Vector2i atlas cell (walkable, solid, or animation frame 0)
var _blocked_cells: Dictionary = {}  # walkable tile name -> Vector2i atlas cell of its blocked copy
var _edge_rows: Dictionary = {}  # overlay set name -> Vector2i atlas cell of its mask 0
var _grid: Dictionary = {}  # Vector2i -> tile name
var _blocked: Dictionary = {}  # Vector2i -> true (walkable art that props stand on)
var _size := Vector2i.ZERO
var _root: Node2D
var _rng := RandomNumberGenerator.new()
var _n := 0
var _tile_px := 32  # atlas pixels per cell (from the tile index)
var _heights: Dictionary = {}  # canon cut name -> display height
var _art_heights: Dictionary = {}  # prop Sprite2D -> height of its art on the map, world px


func _process(_delta: float) -> bool:
	# First frame, so the autoloads the map scripts refer to exist.
	_rng.seed = 11
	var cuts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CUTS_PATH))
	for n: String in cuts["props"]:
		_heights[n] = float(cuts["props"][n]["height"])
	_heights.merge(OTHER_HEIGHTS)
	_build_tileset()
	_build_village()
	_build_temple()
	quit()
	return true


# ---------- tileset ----------

func _build_tileset() -> void:
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	_walk = index["walk"]
	_solid = index["solid"] + index["anim"]  # water animates and is solid
	_tile_px = int(index["cell_px"])
	for n: String in index["edges"]:
		var e: Array = index["edges"][n]
		_edge_rows[n] = Vector2i(int(e[0]), int(e[1]))
	for n: String in index["tiles"]:
		var c: Array = index["tiles"][n]
		_cells[n] = Vector2i(int(c[0]), int(c[1]))
	for n: String in index["blocked"]:
		var c: Array = index["blocked"][n]
		_blocked_cells[n] = Vector2i(int(c[0]), int(c[1]))
	_ts = TileSet.new()
	_ts.tile_size = Vector2i(_tile_px, _tile_px)
	_ts.add_physics_layer()
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/tiles/island_tiles.png")
	src.texture_region_size = Vector2i(_tile_px, _tile_px)
	src.use_texture_padding = true
	_ts.add_source(src, 0)
	var h := _tile_px / 2.0
	var full := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	# Walkable cells; their blocked copies and the solid-only cells get a full collision square.
	for n: String in _walk:
		src.create_tile(_cells[n])
	var solid_cells: Array = _blocked_cells.values()
	for n: String in index["solid"]:
		solid_cells.append(_cells[n])
	for c: Vector2i in solid_cells:
		src.create_tile(c)
		var td := src.get_tile_data(c, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, full)
	# Animated tiles: frame 0 is the tile, the next frames sit to its right in the same row.
	for n: String in index["anim"]:
		var c: Vector2i = _cells[n]
		src.create_tile(c)
		src.set_tile_animation_columns(c, int(index["anim_frames"]))
		src.set_tile_animation_frames_count(c, int(index["anim_frames"]))
		for f in int(index["anim_frames"]):
			src.set_tile_animation_frame_duration(c, f, 0.35)
		var td := src.get_tile_data(c, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, full)
	# Edge overlays (no collision): masks 1-14 of each set.
	for n: String in _edge_rows:
		for m in range(1, 15):
			src.create_tile(_edge_rows[n] + Vector2i(m, 0))
	ResourceSaver.save(_ts, TILESET_PATH)
	_ts = load(TILESET_PATH)


# ---------- grid helpers ----------

func _begin(root_name: String, w: int, h: int, fill: String) -> void:
	_grid.clear()
	_blocked.clear()
	_size = Vector2i(w, h)
	_n = 0
	_root = Node2D.new()
	_root.name = root_name
	_root.y_sort_enabled = true
	_root.set_script(load("res://scripts/map.gd"))
	_root.set("map_size", Vector2(w * CELL, h * CELL))
	for x in w:
		for y in h:
			_grid[Vector2i(x, y)] = fill


func _fill(x0: int, y0: int, x1: int, y1: int, tile: String) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			_grid[Vector2i(x, y)] = tile


func _piece(x0: int, y0: int, piece: String, w: int, h: int) -> void:
	## A multi-cell piece from the tile sheet (cells named <piece>_<col>_<row>).
	for x in w:
		for y in h:
			_grid[Vector2i(x0 + x, y0 + y)] = "%s_%d_%d" % [piece, x, y]


func _rug(x0: int, y0: int, y1: int, ends := true) -> void:
	## Two-cell-wide runner from row y0 to y1, with fringed ends.
	var a := y0
	var b := y1
	if ends:
		_piece(x0, y0, "rug_top", 2, 1)
		_piece(x0, y1, "rug_bot", 2, 1)
		a += 1
		b -= 1
	for y in range(a, b + 1):
		for x in 2:
			_grid[Vector2i(x0 + x, y)] = "rug_%d_%d" % [x, (y - a) % 2]


func _block(x0: int, y0: int, x1: int, y1: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			_blocked[Vector2i(x, y)] = true


func _scatter_grass() -> void:
	for c: Vector2i in _grid:
		if _grid[c] == "grass_a":
			var r := _rng.randf()
			if r < 0.18:
				_grid[c] = "grass_b"
			elif r < 0.25:
				_grid[c] = "grass_flower"


func _add(node: Node, node_name: String, parent: Node = null) -> Node:
	node.name = node_name
	(parent if parent else _root).add_child(node)
	node.owner = _root
	return node


func _tile_layer() -> void:
	var layer := TileMapLayer.new()
	layer.tile_set = _ts
	layer.scale = Vector2.ONE * CELL / _tile_px  # 128 px atlas cells on the 32 px grid
	layer.z_index = -10
	for c: Vector2i in _grid:
		var t: String = _grid[c]
		assert(_cells.has(t), "no tile named " + t)
		var cell: Vector2i = _cells[t]
		if _blocked.has(c) and _blocked_cells.has(t):
			cell = _blocked_cells[t]
		layer.set_cell(c, 0, cell)
	_add(layer, "Ground")
	layer.y_sort_enabled = false


func _edge_layer(layer_name: String, set_name: String, inside: Callable, skip: Callable, need := Callable()) -> void:
	## Dual-grid overlay: cell (i, j) sits half a cell up-left, its corners are the centres of
	## ground cells (i-1, j-1), (i, j-1), (i-1, j), (i, j); its mask says which are inside.
	## Cells touching a cell that skip() rejects stay empty, and so do cells with no corner
	## that need() accepts (when given).
	var layer := TileMapLayer.new()
	layer.tile_set = _ts
	layer.scale = Vector2.ONE * CELL / _tile_px
	layer.z_index = -9
	layer.position = Vector2(-CELL / 2.0, -CELL / 2.0)
	var first: Vector2i = _edge_rows[set_name]
	for j in _size.y + 1:
		for i in _size.x + 1:
			var mask := 0
			var bad := false
			var wanted := not need.is_valid()
			var k := 0
			for c: Vector2i in [Vector2i(i - 1, j - 1), Vector2i(i, j - 1), Vector2i(i - 1, j), Vector2i(i, j)]:
				var cc := c.clamp(Vector2i.ZERO, _size - Vector2i.ONE)
				var t: String = _grid[cc]
				if skip.call(t):
					bad = true
				if inside.call(t):
					mask |= 1 << k
				if not wanted and need.call(t):
					wanted = true
				k += 1
			if wanted and not bad and mask != 0 and mask != 15:
				layer.set_cell(Vector2i(i, j), 0, first + Vector2i(mask, 0))
	_add(layer, layer_name)
	layer.y_sort_enabled = false


func _bake_nav() -> void:
	var data := NavigationMeshSourceGeometryData2D.new()
	var w := _size.x * CELL
	var h := _size.y * CELL
	data.add_traversable_outline(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]))
	for y in _size.y:
		var x := 0
		while x < _size.x:
			var c := Vector2i(x, y)
			if _blocked.has(c) or _solid.has(_grid[c]):
				var x2 := x
				while x2 + 1 < _size.x and (_blocked.has(Vector2i(x2 + 1, y)) or _solid.has(_grid[Vector2i(x2 + 1, y)])):
					x2 += 1
				data.add_obstruction_outline(PackedVector2Array([
					Vector2(x * CELL, y * CELL), Vector2((x2 + 1) * CELL, y * CELL),
					Vector2((x2 + 1) * CELL, (y + 1) * CELL), Vector2(x * CELL, (y + 1) * CELL)]))
				x = x2 + 1
			else:
				x += 1
	var poly := NavigationPolygon.new()
	poly.agent_radius = 8.0
	NavigationServer2D.bake_from_source_geometry_data(poly, data)
	var region := NavigationRegion2D.new()
	region.navigation_polygon = poly
	_add(region, "Nav")


func _prop(tex: String, base: Vector2, node_name: String, flip := false, scale := Vector2.ONE) -> Sprite2D:
	## A sprite standing at base (its bottom edge on base, so it y-sorts by its foot).
	## scale multiplies the art's own display scale (_art_scale).
	var s := Sprite2D.new()
	var path := tex if tex.begins_with("res://") else PROPS_DIR + tex + ".png"
	var t: Texture2D = load(path)
	s.position = base
	s.flip_h = flip
	var world := scale * _art_scale(tex, t)
	var shadow := _paper(s, path, t, world, Vector2(0, -t.get_height() / 2.0))
	_add(s, node_name)
	if shadow:
		_add(shadow, "PaperShadow", s)
	_art_heights[s] = t.get_height() * world.y
	return s


func _paper(s: Sprite2D, src: String, t: Texture2D, world: Vector2, offset: Vector2) -> Sprite2D:
	## Paper look (bd gsd): art that tools/bake_paper.sh baked (PaperBake, assets/paper/) is drawn
	## from its bordered sheet at the same size and place (the sheet is resampled by k and padded
	## evenly, so the centre stays: offset x k, scale / k), over a soft shadow drawn behind it.
	## Returns the shadow sprite to add under s, or null; unbaked art is set up as before.
	var bake := PaperBake.name_of(src)
	var edge := PaperBake.sheet(bake, PaperBake.EDGE)
	if edge == "":
		s.texture = t
		s.offset = offset
		s.scale = world
		return null
	var k := PaperBake.resample(bake)
	s.texture = load(edge)
	s.offset = offset * k
	s.scale = world / k
	var shadow_path := PaperBake.sheet(bake, PaperBake.SHADOW)
	if shadow_path == "":
		return null
	var sh := Sprite2D.new()
	sh.texture = load(shadow_path)
	sh.offset = s.offset
	sh.flip_h = s.flip_h
	sh.show_behind_parent = true
	PaperBake.style_shadow(sh, s.scale)
	return sh


func _art_scale(tex: String, t: Texture2D) -> float:
	## World px per file px: canon cuts are scaled to their display height, generated art is 4x.
	var n := tex.get_file().get_basename()
	if _heights.has(n):
		return _heights[n] / t.get_height()
	return ART_SCALE


func _sheet_frames(png: String, frame: Vector2i, count: int, fps: float) -> SpriteFrames:
	## SpriteFrames ("idle", looping) for a one-row generated sheet, saved beside it as .tres.
	var path := png.get_basename() + ".tres"
	var sf := SpriteFrames.new()
	sf.rename_animation("default", "idle")
	sf.set_animation_speed("idle", fps)
	var sheet: Texture2D = load(png)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * frame.x, 0, frame.x, frame.y)
		sf.add_frame("idle", at)
	ResourceSaver.save(sf, path)
	return load(path)


func _anim_prop(frames: SpriteFrames, base: Vector2, foot: float, node_name: String, start := 0) -> AnimatedSprite2D:
	## An animated prop standing at base; foot is the frame's foot line below its centre, in
	## world px (the generated sheet is ART_SCALE: 4 file px per world px).
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames
	a.animation = "idle"
	a.autoplay = "idle"
	a.frame = start % frames.get_frame_count("idle")
	a.scale = Vector2.ONE * ART_SCALE
	a.offset = Vector2(0, -foot / ART_SCALE)
	a.position = base
	_add(a, node_name)
	return a


func _shadow(base: Vector2, scale := Vector2.ONE) -> void:
	## Soft contact shadow on the floor under a furnishing.
	var sh := _prop("res://assets/temple/temple_shadow.png", base + Vector2(0, 3), "Shadow_%d" % _n, false, scale)
	sh.z_index = -5
	_n += 1


func _marker(node_name: String, pos: Vector2) -> void:
	var m := Marker2D.new()
	m.position = pos
	_add(m, node_name)


func _inst(path: String, node_name: String, pos: Vector2, props := {}) -> Node2D:
	var n: Node2D = load(path).instantiate()
	n.position = pos
	for k: String in props:
		n.set(k, props[k])
	_add(n, node_name)
	return n


func _character(path: String, node_name: String, pos: Vector2, props := {}) -> Node2D:
	# Characters stand with their origin on their feet (no z_index of their own), so the
	# y-sorted map orders them with the props by where they stand; pos is the feet.
	return _inst(path, node_name, pos, props)


func _door(node_name: String, pos: Vector2, props := {}) -> Node2D:
	return _inst("res://scenes/maps/door.tscn", node_name, pos, props)


func _fence_cells(x0: int, y0: int, x1: int, y1: int, gap_x := -1, gap_y0 := -1, gap_y1 := -1) -> void:
	## Fence the rectangle outline (cells); an optional gap on the east side for a gate.
	var k := 0
	for x in range(x0, x1 + 1, 2):
		for y in [y0, y1]:
			_block(x, y, mini(x + 1, x1), y)
			_prop("prop_fence_a" if (k + y) % 2 == 0 else "prop_fence_b", Vector2(x * CELL + CELL, y * CELL + CELL), "Fence_%d" % _n, false, Vector2(1.14, 1.0))
			_n += 1
		k += 1
	for y in range(y0 + 1, y1):
		for x in [x0, x1]:
			if x == gap_x and y >= gap_y0 and y <= gap_y1:
				continue
			_block(x, y, x, y)
			_prop("prop_fence_a" if y % 2 == 0 else "prop_fence_b", Vector2(x * CELL + CELL / 2.0, y * CELL + CELL), "Fence_%d" % _n, false, Vector2(0.56, 0.95))
			_n += 1


func _save(path: String) -> void:
	_tile_layer()
	_bake_nav()
	var scene := PackedScene.new()
	var err := scene.pack(_root)
	assert(err == OK)
	err = ResourceSaver.save(scene, path)
	print("saved ", path, " err=", err, " nodes=", _root.get_child_count())
	_root.free()


# ---------- village (40 x 38 cells) ----------
## Traced from OpenStreetMap data for Little Saint James (ODbL, (c) OpenStreetMap contributors;
## see art/reference/little_st_james/SOURCES.md): the coastline, the real path network, and the
## positions of the temple, helipad, pier, pools, tennis court, ruins and buildings, projected by
## tools/project_osm_island.py at 24 m per cell, north up. The caste areas, NPCs and exits are
## mapped onto those places; sprites are the game's own.

func _land(x0: int, y0: int, x1: int, y1: int, tile: String) -> void:
	## Paint only cells that are already island (not sea or foam).
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var t: String = _grid.get(Vector2i(x, y), "water")
			if t != "water" and t != "foam":
				_grid[Vector2i(x, y)] = tile


func _is_land(x: int, y: int) -> bool:
	var t: String = _grid.get(Vector2i(x, y), "water")
	return t != "water" and t != "foam"


func _px(x: float, y: float) -> Vector2:
	return Vector2(x * CELL, y * CELL)


func _trees() -> void:
	## Bubbly trees and flower clumps on open grass, kept clear of paths and everything built.
	var taken: Dictionary = {}
	for c: Vector2i in _grid:
		var t: String = _grid[c]
		if not t.begins_with("grass") or _blocked.has(c):
			taken[c] = true
	for y in _size.y:
		for x in _size.x:
			var c := Vector2i(x, y)
			if taken.has(c) or not _is_land(x, y):
				continue
			var r := _rng.randf()
			if r < 0.16:
				taken[c] = true
				_block(x, y, x, y)
				_prop("deco_tree_" + ["a", "b", "c"][_rng.randi() % 3], _px(x + 0.5, y + 1.0), "Tree_%d_%d" % [x, y])
			elif r < 0.26:
				_prop("deco_flowers", _px(x + 0.5, y + 0.9), "Flowers_%d_%d" % [x, y])


func _build_village() -> void:
	var L: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/island_layout.json"))
	_begin("Village", int(L["w"]), int(L["h"]), "water")
	var rows: Array = L["mask"]
	for y in rows.size():
		for x in (rows[y] as String).length():
			var ch: String = (rows[y] as String)[x]
			_grid[Vector2i(x, y)] = {"L": "grass_a", "S": "sand", "F": "foam", "w": "water"}[ch]
	_scatter_grass()
	for p: Array in L["paths"]:
		_grid[Vector2i(int(p[0]), int(p[1]))] = "path"
	var tp: Array = L["temple"]
	var hp: Array = L["helipad"]
	var ph: Array = L["pitch"]
	var pools: Array = L["pools"]

	# North tip: main house, paving and pool (Mothers and Priestesses).
	_land(21, 5, 25, 9, "plaza")
	_rug(22, 5, 9, false)
	_piece(26, 7, "pool", 2, 2)
	_block(21, 3, 24, 4)
	_prop("prop_bunker", _px(22.6, 5.0), "MainHouse", false, Vector2(0.95, 0.95))
	# Guest villas (Initiates' quarter), beside the main compound.
	_land(20, 11, 25, 15, "plaza")
	_block(21, 10, 24, 10)
	_prop("prop_bunker", _px(22.6, 11.0), "Dwelling_1", false, Vector2(0.8, 0.8))
	_block(21, 14, 24, 14)
	_prop("prop_bunker", _px(22.6, 15.0), "Dwelling_2", true, Vector2(0.8, 0.8))
	# Helipad with its two small buildings; a walkway runs down to the beach.
	_land(int(hp[0]) - 1, int(hp[1]), int(hp[0]), int(hp[1]) + 1, "plaza")
	_block(int(hp[0]) - 2, int(hp[1]), int(hp[0]) - 2, int(hp[1]))
	_prop("prop_bunker", _px(hp[0] - 1.5, hp[1] + 1.0), "HelipadHut_1", false, Vector2(0.4, 0.4))
	_block(int(hp[0]) + 1, int(hp[1]), int(hp[0]) + 1, int(hp[1]))
	_prop("prop_bunker", _px(hp[0] + 1.5, hp[1] + 1.0), "HelipadHut_2", true, Vector2(0.4, 0.4))
	_land(int(hp[0]), int(hp[1]) + 2, int(hp[0]), int(hp[1]) + 6, "path")
	# Pool house and pool at the west end; the Drones' fenced garden beside them.
	_piece(int(pools[1][0]) - 1, int(pools[1][1]) - 1, "pool", 2, 2)
	_prop("prop_bunker", _px(6.5, 17.0), "PoolHouse", false, Vector2(0.5, 0.5))
	_block(6, 16, 7, 16)
	_land(8, 14, 11, 17, "soil")
	_land(8, 14, 11, 14, "sprouts")
	_land(8, 16, 11, 16, "sprouts")
	_land(8, 15, 11, 15, "path")
	_fence_cells(7, 13, 12, 18, 12, 15, 16)
	_land(12, 15, 14, 16, "path")
	_land(13, 15, 13, 18, "path")
	_block(13, 13, 13, 13)
	_prop("prop_sign_a", _px(13.5, 14.0), "Sign_Compound")
	# Tennis court, fenced (the real pitch is disused).
	_land(int(ph[0]) - 1, int(ph[1]), int(ph[0]) + 1, int(ph[1]), "plaza")
	_fence_cells(int(ph[0]) - 2, int(ph[1]) - 1, int(ph[0]) + 2, int(ph[1]) + 1)
	# Barren yard (maintenance sheds): bare ground, rock pile, signs.
	_land(14, 16, 19, 19, "path")
	_land(15, 17, 16, 18, "rock")
	_block(14, 20, 14, 20)
	_prop("prop_sign_b", _px(14.5, 21.0), "Sign_Yard")
	_block(20, 17, 20, 17)
	_prop("prop_tag_x", _px(20.5, 18.0), "Tag_Yard")
	# Temple on the south-west hill, at the real temple's spot: terrace, striped pavilion, gold dome.
	var tx := int(tp[0])
	var ty := int(tp[1])
	_land(tx - 4, ty - 3, tx + 3, ty + 2, "plaza")
	# The pavilion stands on the terrace; the doorway cells stay open so the door can be reached.
	for x in range(tx - 2, tx + 2):
		for y in range(ty - 2, ty + 2):
			if not (x >= tx - 1 and x <= tx and y >= ty):
				_block(x, y, x, y)
	_prop("res://assets/island/temple_pavilion.png", _px(tx, ty + 1.75), "Temple").offset.y += 4 / ART_SCALE
	_prop("prop_icon_queen_mother", _px(tx - 3, ty + 2.4), "Icon_1")
	_prop("prop_icon_queen_mother", _px(tx + 3, ty + 2.4), "Icon_2")
	_block(tx - 4, ty + 1, tx - 3, ty + 1)
	_block(tx + 2, ty + 1, tx + 3, ty + 1)
	var seal := _prop("prop_seal_o", _px(tx, ty + 0.1), "Seal_Gate")
	seal.z_index = 1
	# Ship: the wreck on the south beach at the real ruins' spot, entrance of the Ruins of Utopia.
	var rx := int(L["ruins"][0]) + 2
	_block(rx - 2, 21, rx + 3, 23)
	_prop("prop_ship", _px(rx + 0.5, 24.0), "Ship")
	# Dock on the west side of the neck at the real pier, dock house beside its end.
	var pr: Array = L["piers"][0]
	_fill(int(pr[0]) - 3, int(pr[1]), int(pr[0]) + 2, int(pr[1]), "path")
	_prop("prop_bunker", _px(pr[0] - 4.0, pr[1] + 1.0), "BoatHouse", false, Vector2(0.55, 0.55))
	# East jetty for the tropical exit (the map's own; the real island has none).
	_fill(33, 23, 36, 23, "path")

	_trees()
	_hearts_and_sparkles()
	# Round the coast and the grass borders. The Shore goes first and the land overlays over
	# it, none of them skipping cells that touch the sea, so footpaths, paving and grass run
	# right up to the coast instead of stopping a cell short of it in a square notch.
	var sea := func(t: String) -> bool: return t == "water" or t == "foam"
	var none := func(_t: String) -> bool: return false
	_edge_layer("Shallows", "shallows", func(t: String) -> bool: return t != "water", none)
	_edge_layer("Shore", "shore", func(t: String) -> bool: return not sea.call(t), none)
	# Footpaths and paving get soft borders where they meet sand. Where such a border also
	# touches grass or paving, those corners count as inside too (so the border stops at
	# them instead of leaving a square notch) and the overlays drawn after it (PavingEdge,
	# GrassEdge) paint their own ground back over them. Soil, crops, rock and pools have no
	# overlay of their own, so borders touching them are left out.
	var bare := func(t: String) -> bool: return t in ["soil", "sprouts", "rock"] or t.begins_with("pool")
	var paved := func(t: String) -> bool: return t == "plaza" or t.begins_with("rug")
	_edge_layer("PathEdge", "path_edge",
		func(t: String) -> bool: return t == "path" or t.begins_with("grass") or paved.call(t), bare,
		func(t: String) -> bool: return t == "path")
	_edge_layer("PavingEdge", "paving_edge",
		func(t: String) -> bool: return paved.call(t) or t.begins_with("grass"), bare, paved)
	_edge_layer("GrassEdge", "grass_edge", func(t: String) -> bool: return t.begins_with("grass"), none)

	# Spawns (names unchanged) and exits.
	_marker("spawn_default", _px(19.5, 13.0))
	_marker("spawn_from_temple", _px(tx, ty + 3.1))
	_marker("spawn_from_ruins", _px(rx - 1.375, 24.8))  # beside the wreck door, not on it
	_marker("spawn_from_tropical", _px(34.0, 23.5))  # feet on the sand, not in the surf
	_character("res://scenes/player/player.tscn", "Player", _px(19.5, 13.0))
	_character("res://scenes/npc/npc.tscn", "Initiate", _px(20.6, 13.95), {
		"npc_id": "initiate", "caste": "initiate", "sprite_texture": "npc_initiate",
		"dialogue_path": "res://dialogue/offering.dialogue", "voice_pitch": 1.25})
	_character("res://scenes/npc/npc.tscn", "Drone", _px(9.5, 16.25), {
		"npc_id": "drone", "caste": "drone", "sprite_texture": "npc_drone", "voice_pitch": 0.7})
	_character("res://scenes/npc/npc.tscn", "Barren", _px(17.5, 18.75), {
		"npc_id": "barren", "caste": "barren", "sprite_texture": "npc_barren", "voice_pitch": 0.9})
	_door("TempleDoor", _px(tx, ty + 1.5), {
		"target_scene": "res://scenes/maps/temple.tscn", "target_spawn": "spawn_from_village",
		"exit_label": "To the Temple"})
	_mirror(_px(19.5, 11.5))

	# ---- Exit points for other areas. ----
	_door("Exit_Ruins", _px(rx + 0.5, 24.3), {
		"target_scene": "res://scenes/ruins/ruins_wreck.tscn", "target_spawn": "spawn_default",
		"exit_label": "To the Ruins of Utopia"})
	# The island chapter ends here: time-jump card, then the cruise chapter (data/chapters.json).
	_door("Exit_Cruise", _px(pr[0] - 2.5, pr[1] + 0.5), {
		"target_scene": "res://scenes/chapters/chapter_end.tscn", "exit_label": "Back to the Cruise"})
	_door("Exit_Tropical", _px(35.6, 23.5), {
		"target_scene": "res://scenes/florida/beach.tscn", "target_spawn": "spawn_default",
		"exit_label": "To the Tropical Beach"})
	_save("res://scenes/maps/village.tscn")


func _hearts_and_sparkles() -> void:
	## Hearts on the dwellings and the main house, sparkles on the temple and the ship.
	for n: String in ["MainHouse", "Dwelling_1", "Dwelling_2"]:
		var b: Sprite2D = _root.get_node(n)
		# On the roof's left shoulder, about half the building's height up.
		_prop("deco_heart", b.position + Vector2(-34, -0.517 * _art_heights[b]), "Heart_" + n)
	for n: String in ["Ship", "Seal_Gate"]:
		var b: Sprite2D = _root.get_node(n)
		_prop("deco_sparkle", b.position + Vector2(30, -_art_heights[b]), "Sparkle_" + n)


func _mirror(pos: Vector2) -> void:
	var m := Area2D.new()
	m.position = pos
	m.set_script(load("res://scripts/mirror.gd"))
	var sp := Sprite2D.new()
	var mirror := "res://assets/island/mirror.png"  # tools/gen_village_props.py
	# Foot line on the node, so it y-sorts by its feet.
	var mirror_shadow := _paper(sp, mirror, load(mirror), Vector2.ONE * ART_SCALE, Vector2(0, -17 / ART_SCALE))
	var cs := CollisionShape2D.new()
	cs.position = Vector2(0, -14)
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	cs.shape = shape
	_add(m, "Mirror")
	_add(sp, "Sprite2D", m)
	if mirror_shadow:
		_add(mirror_shadow, "PaperShadow", sp)
	_add(cs, "CollisionShape2D", m)


# ---------- temple (30 x 20 cells) ----------

func _build_temple() -> void:
	_begin("Temple", 30, 20, "floor")
	# Cream and blush marble checkerboard, one slab per cell (blush where x + y is odd);
	# now and then a cream slab catches the light. The row under the north wall is shaded.
	for x in 30:
		for y in range(4, 19):
			var blush := (x + y) % 2 == 1
			if y == 4:
				_grid[Vector2i(x, y)] = "floor_nb" if blush else "floor_n"
			elif blush:
				_grid[Vector2i(x, y)] = "floor_b"
			elif _rng.randf() < 0.12:
				_grid[Vector2i(x, y)] = "floor_alt"
	# High north wall (cap, face, wainscot), wall tops round the other three sides.
	_fill(0, 0, 29, 0, "wall_cap")
	_fill(0, 1, 29, 2, "wall")
	_fill(0, 3, 29, 3, "wall_base")
	_fill(0, 4, 0, 18, "wall_l")
	_fill(29, 4, 29, 18, "wall_r")
	_fill(0, 19, 29, 19, "wall_s")
	_grid[Vector2i(0, 19)] = "wall_sl"
	_grid[Vector2i(29, 19)] = "wall_sr"
	_piece(14, 19, "door_s", 2, 1)  # exit
	_piece(0, 7, "stairs_w", 1, 2)  # the sealed alcove, steps down to the Ruins
	_piece(13, 4, "dais", 4, 3)
	_rug(14, 7, 18)
	# Icons of the Queen Mother along the high wall, the Seal over the dais.
	for x in [3, 6, 9, 20, 23, 26]:
		_prop("prop_icon_queen_mother", Vector2(x * CELL + 16, 3 * CELL), "Icon_%d" % x)
	_prop("prop_seal_o", Vector2(15 * CELL, 2 * CELL + 18), "Seal")
	_prop("prop_calendar", Vector2(12 * CELL + 8, 3 * CELL - 4), "Calendar_Left")
	# Colonnade.
	for x in [3, 26]:
		for y in [8, 11, 14, 17]:
			_block(x, y, x, y)
			_prop("res://assets/temple/temple_plinth.png", Vector2(x * CELL + 16, y * CELL + CELL + 5), "Plinth_%d_%d" % [x, y]).z_index = -5
			_prop("prop_pillar_orb", Vector2(x * CELL + 16, y * CELL + CELL - 2), "Pillar_%d_%d" % [x, y])
	# Sealed door to the Ruins, with the forbidden tag beside it.
	_prop("prop_tag_x", Vector2(16, 7 * CELL + 2), "Tag_Ruins").z_index = 1

	# Candle stands flanking the dais, urns of flowers in the corners and by the door,
	# sparkles twinkling round the Seal, the dais and the icons.
	var candles := _sheet_frames("res://assets/temple/temple_candles.png", Vector2i(96, 176), 4, 6.0)
	for x in [12, 17]:
		_block(x, 6, x, 6)
		_shadow(Vector2(x * CELL + 16, 7 * CELL - 4))
		_anim_prop(candles, Vector2(x * CELL + 16, 7 * CELL - 4), 20, "Candles_%d" % x, x)
	for c: Vector2i in [Vector2i(1, 4), Vector2i(28, 4), Vector2i(12, 18), Vector2i(17, 18)]:
		_block(c.x, c.y, c.x, c.y)
		_shadow(Vector2(c.x * CELL + 16, c.y * CELL + 30))
		_prop("res://assets/temple/temple_urn.png", Vector2(c.x * CELL + 16, c.y * CELL + 30), "Urn_%d_%d" % [c.x, c.y]).offset.y += 2 / ART_SCALE
	# Kneeling cushions in rows either side of the runner, facing the dais.
	for x in [6, 8, 10, 19, 21, 23]:
		for y in [10, 12, 14, 16]:
			_block(x, y, x, y)
			_prop("res://assets/temple/temple_cushion.png", Vector2(x * CELL + 16, y * CELL + 26), "Cushion_%d_%d" % [x, y])
	var twinkle := _sheet_frames("res://assets/temple/temple_twinkle.png", Vector2i(48, 48), 6, 7.0)
	var spots := [Vector2(452, 52), Vector2(512, 70), Vector2(418, 150), Vector2(546, 136),
		Vector2(150, 40), Vector2(262, 70), Vector2(694, 46), Vector2(806, 72), Vector2(902, 40)]
	for i in spots.size():
		var tw := _anim_prop(twinkle, spots[i], 0, "Twinkle_%d" % i, i * 2)
		tw.z_index = 3

	_marker("spawn_default", Vector2(15 * CELL, 15 * CELL + 16))
	_marker("spawn_from_village", Vector2(15 * CELL, 17 * CELL + 24))
	_marker("spawn_from_ruins", Vector2(2 * CELL + 8, 8 * CELL + 16))
	_marker("spawn_from_puzzle", Vector2(25 * CELL, 12 * CELL + 16))
	_character("res://scenes/player/player.tscn", "Player", Vector2(15 * CELL, 15 * CELL + 16))
	_character("res://scenes/npc/npc.tscn", "Priestess", Vector2(15 * CELL, 7 * CELL + 40), {
		"npc_id": "priestess", "caste": "priestess", "sprite_texture": "npc_priestess",
		"dialogue_path": "res://dialogue/priestess.dialogue", "voice_pitch": 0.85})
	_door("ExitDoor", Vector2(15 * CELL, 19 * CELL + 16), {
		"target_scene": "res://scenes/maps/village.tscn", "target_spawn": "spawn_from_temple",
		"exit_label": "Back to the Village"})
	var table := _door("RitualTable", Vector2(25 * CELL, 9 * CELL + 16), {
		"target_scene": "res://scenes/minigames/ritual_puzzle.tscn", "exit_label": "The Ritual Table",
		"show_marker": false})
	_shadow(Vector2(25 * CELL, 9 * CELL + 22), Vector2(1.6, 1.4))
	_prop("prop_skull_altar", Vector2(25 * CELL, 9 * CELL + 24), "RitualAltar")
	_door("RuinsDoor", Vector2(CELL / 2.0 + 8, 8 * CELL), {
		"target_scene": "res://scenes/ruins/ruins_wreck.tscn", "target_spawn": "spawn_default",
		"exit_label": "Into the Ruins of Utopia"})
	_save("res://scenes/maps/temple.tscn")
