extends SceneTree
## Builds the island tileset and the village/temple map scenes.
## Run: cd project && godot --headless --path . -s ../tools/build_island_maps.gd
## Layouts live here as code (cell = 32 px); the scenes are the output. Re-run after edits.

const CELL := 32
const WALK := ["grass_a", "grass_b", "grass_flower", "path", "sand", "soil", "sprouts", "plaza", "floor", "floor_alt", "rug"]
const SOLID := ["water", "foam", "wall", "wall_cap", "hedge", "rock", "stripe", "gold_cap"]
const TILESET_PATH := "res://assets/tiles/island_tileset.tres"
const PROPS_DIR := "res://assets/canon/"

var _ts: TileSet
var _grid: Dictionary = {}  # Vector2i -> tile name
var _blocked: Dictionary = {}  # Vector2i -> true (walkable art that props stand on)
var _size := Vector2i.ZERO
var _root: Node2D
var _rng := RandomNumberGenerator.new()
var _n := 0


func _process(_delta: float) -> bool:
	# First frame, so the autoloads the map scripts refer to exist.
	_rng.seed = 11
	_build_tileset()
	_build_village()
	_build_temple()
	quit()
	return true


# ---------- tileset ----------

func _build_tileset() -> void:
	_ts = TileSet.new()
	_ts.tile_size = Vector2i(CELL, CELL)
	_ts.add_physics_layer()
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/tiles/island_tiles.png")
	src.texture_region_size = Vector2i(CELL, CELL)
	_ts.add_source(src, 0)
	var full := PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)])
	for x in WALK.size() + SOLID.size():
		for y in 2:
			if y == 0 and x >= WALK.size():
				continue
			src.create_tile(Vector2i(x, y))
			if y == 1:
				var td := src.get_tile_data(Vector2i(x, y), 0)
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, full)
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
	layer.z_index = -10
	for c: Vector2i in _grid:
		var t: String = _grid[c]
		if SOLID.has(t):
			layer.set_cell(c, 0, Vector2i(WALK.size() + SOLID.find(t), 1))
		else:
			layer.set_cell(c, 0, Vector2i(WALK.find(t), 1 if _blocked.has(c) else 0))
	_add(layer, "Ground")
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
			if _blocked.has(c) or SOLID.has(_grid[c]):
				var x2 := x
				while x2 + 1 < _size.x and (_blocked.has(Vector2i(x2 + 1, y)) or SOLID.has(_grid[Vector2i(x2 + 1, y)])):
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
	var s := Sprite2D.new()
	var t: Texture2D = load(PROPS_DIR + tex + ".png")
	s.texture = t
	s.offset = Vector2(0, -t.get_height() / 2.0)
	s.position = base
	s.flip_h = flip
	s.scale = scale
	_add(s, node_name)
	return s


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
	var n := _inst(path, node_name, pos, props)
	n.z_index = 0  # y-sorted with props instead of floating above them
	return n


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
	_land(22, 5, 23, 9, "rug")
	_land(26, 7, 26, 8, "water")
	_block(21, 3, 24, 4)
	_prop("prop_bunker", _px(22.6, 5.0), "MainHouse", false, Vector2(0.95, 0.95))
	# Guest villas (Initiates' quarter), beside the main compound.
	_land(20, 11, 25, 15, "floor_alt")
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
	_land(int(pools[1][0]) - 1, int(pools[1][1]) - 1, int(pools[1][0]), int(pools[1][1]), "water")
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
	_fill(tx - 1, ty - 2, tx, ty - 2, "gold_cap")
	_fill(tx - 2, ty - 1, tx + 1, ty - 1, "gold_cap")
	_fill(tx - 3, ty, tx + 2, ty + 1, "stripe")
	_fill(tx - 1, ty, tx, ty + 1, "floor")  # doorway
	_prop("prop_icon_queen_mother", _px(tx - 2, ty + 2.0), "Icon_1")
	_prop("prop_icon_queen_mother", _px(tx + 2, ty + 2.0), "Icon_2")
	_prop("prop_seal_o", _px(tx, ty - 1.0 + 0.9), "Seal_Gate")
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

	# Spawns (names unchanged) and exits.
	_marker("spawn_default", _px(19.5, 12.5))
	_marker("spawn_from_temple", _px(tx, ty + 2.6))
	_marker("spawn_from_ruins", _px(rx + 0.5, 24.6))
	_character("res://scenes/player/player.tscn", "Player", _px(19.5, 12.5))
	_character("res://scenes/npc/npc.tscn", "Initiate", _px(22.5, 12.6), {
		"npc_id": "initiate", "caste": "initiate", "sprite_texture": "npc_initiate",
		"dialogue_path": "res://dialogue/offering.dialogue", "voice_pitch": 1.25})
	_character("res://scenes/npc/npc.tscn", "Drone", _px(9.5, 15.5), {
		"npc_id": "drone", "caste": "drone", "sprite_texture": "npc_drone", "voice_pitch": 0.7})
	_character("res://scenes/npc/npc.tscn", "Barren", _px(17.5, 18.0), {
		"npc_id": "barren", "caste": "barren", "sprite_texture": "npc_barren", "voice_pitch": 0.9})
	_door("TempleDoor", _px(tx, ty + 1.5), {
		"target_scene": "res://scenes/maps/temple.tscn", "target_spawn": "spawn_from_village"})
	_mirror(_px(19.5, 11.0))

	# ---- Exit points for other areas (wired at merge). Locked until then. ----
	var ruins := _door("Exit_Ruins", _px(rx + 0.5, 24.3), {"locked": true})
	ruins.set_meta("wire_to", "Ruins of Utopia entry scene, spawn from_island")
	var cruise := _door("Exit_Cruise", _px(pr[0] - 2.5, pr[1] + 0.5), {"locked": true})
	cruise.set_meta("wire_to", "Cruise flashback world (unlocked by Forbidden Knowledge)")
	var tropical := _door("Exit_Tropical", _px(35.6, 23.5), {"locked": true})
	tropical.set_meta("wire_to", "Tropical Florida Keys entry scene")
	_save("res://scenes/maps/village.tscn")


func _hearts_and_sparkles() -> void:
	## Hearts on the dwellings and the main house, sparkles on the temple and the ship.
	for n: String in ["MainHouse", "Dwelling_1", "Dwelling_2"]:
		var b: Sprite2D = _root.get_node(n)
		_prop("deco_heart", b.position + Vector2(-34, -62 * b.scale.y), "Heart_" + n)
	for n: String in ["Ship", "Seal_Gate"]:
		var b: Sprite2D = _root.get_node(n)
		_prop("deco_sparkle", b.position + Vector2(30, -b.texture.get_height() * b.scale.y), "Sparkle_" + n)


func _mirror(pos: Vector2) -> void:
	var m := Area2D.new()
	m.position = pos
	m.set_script(load("res://scripts/mirror.gd"))
	var sp := Sprite2D.new()
	sp.texture = load("res://assets/placeholder/mirror.png")
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	cs.shape = shape
	_add(m, "Mirror")
	_add(sp, "Sprite2D", m)
	_add(cs, "CollisionShape2D", m)


# ---------- temple (30 x 20 cells) ----------

func _build_temple() -> void:
	_begin("Temple", 30, 20, "floor")
	for x in 30:
		for y in range(4, 19):
			if (x + y) % 2 == 1:
				_grid[Vector2i(x, y)] = "floor_alt"
	_fill(0, 0, 29, 0, "wall_cap")
	_fill(0, 1, 29, 3, "wall")
	_fill(0, 4, 0, 19, "wall")
	_fill(29, 4, 29, 19, "wall")
	_fill(0, 19, 29, 19, "wall")
	_fill(14, 19, 15, 19, "floor")  # exit
	_fill(0, 7, 0, 8, "floor")  # the sealed alcove
	_fill(13, 4, 16, 6, "plaza")  # dais
	_fill(14, 4, 15, 18, "rug")
	# Icons of the Queen Mother along the high wall, the Seal over the dais.
	for x in [3, 6, 9, 20, 23, 26]:
		_prop("prop_icon_queen_mother", Vector2(x * CELL + 16, 3 * CELL), "Icon_%d" % x)
	_prop("prop_seal_o", Vector2(15 * CELL, 2 * CELL + 18), "Seal")
	_prop("prop_calendar", Vector2(11 * CELL, 3 * CELL - 4), "Calendar_Left")
	# Colonnade.
	for x in [3, 26]:
		for y in [8, 11, 14, 17]:
			_block(x, y, x, y)
			_prop("prop_pillar_orb", Vector2(x * CELL + 16, y * CELL + CELL), "Pillar_%d_%d" % [x, y])
	# Sealed door to the Ruins, with the forbidden tag beside it.
	_prop("prop_tag_x", Vector2(2 * CELL, 7 * CELL), "Tag_Ruins")

	_marker("spawn_default", Vector2(15 * CELL, 15 * CELL))
	_marker("spawn_from_village", Vector2(15 * CELL, 17 * CELL + 8))
	_marker("spawn_from_puzzle", Vector2(25 * CELL, 12 * CELL))
	_character("res://scenes/player/player.tscn", "Player", Vector2(15 * CELL, 15 * CELL))
	_character("res://scenes/npc/npc.tscn", "Priestess", Vector2(15 * CELL, 7 * CELL + 16), {
		"npc_id": "priestess", "caste": "priestess", "sprite_texture": "npc_priestess",
		"dialogue_path": "res://dialogue/priestess.dialogue", "voice_pitch": 0.85})
	_door("ExitDoor", Vector2(15 * CELL, 19 * CELL + 16), {
		"target_scene": "res://scenes/maps/village.tscn", "target_spawn": "spawn_from_temple"})
	var table := _door("RitualTable", Vector2(25 * CELL, 9 * CELL + 16), {
		"target_scene": "res://scenes/minigames/ritual_puzzle.tscn"})
	_prop("prop_skull_altar", Vector2(25 * CELL, 9 * CELL + 24), "RitualAltar")
	var ruins := _door("RuinsDoor", Vector2(CELL / 2.0 + 8, 8 * CELL), {
		"locked": true,
		"locked_bark": "Sealed since the Before. The Covenant says there is nothing inside. The lock says otherwise."})
	ruins.set_meta("wire_to", "Ruins of Utopia dungeon entry (from the temple), spawn from_temple")
	_save("res://scenes/maps/temple.tscn")
