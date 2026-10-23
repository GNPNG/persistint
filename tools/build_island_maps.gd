extends SceneTree
## Builds the island tileset and the village/temple map scenes.
## Run: cd project && godot --headless --path . -s ../tools/build_island_maps.gd
## Layouts live here as code (cell = 32 px); the scenes are the output. Re-run after edits.

const CELL := 32
const WALK := ["grass_a", "grass_b", "grass_flower", "path", "sand", "soil", "sprouts", "plaza", "floor", "floor_alt", "rug"]
const SOLID := ["water", "foam", "wall", "wall_cap", "hedge", "rock"]
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


# ---------- village (36 x 24 cells) ----------

func _build_village() -> void:
	_begin("Village", 36, 24, "grass_a")
	_scatter_grass()
	# Sea along the south edge, sand shore above it.
	_fill(0, 19, 35, 20, "sand")
	_fill(0, 21, 35, 21, "foam")
	_fill(0, 22, 35, 23, "water")
	# Hedge rim and the high wall of the temple precinct across the north.
	_fill(0, 0, 0, 18, "hedge")
	_fill(35, 0, 35, 18, "hedge")
	_fill(1, 0, 34, 0, "wall_cap")
	_fill(1, 1, 34, 2, "wall")
	_fill(17, 1, 18, 2, "floor")  # the gate
	# Stone plaza under the temple (Mothers and Priestesses), pink rug up the middle.
	_fill(12, 3, 23, 8, "plaza")
	_fill(17, 3, 18, 8, "rug")
	# Main paths: south spine, west to the compound, east to the Initiates' quarter.
	_fill(16, 9, 19, 19, "path")
	_fill(12, 10, 15, 11, "path")
	_fill(20, 10, 23, 11, "path")
	# Drones' compound (west): garden beds inside a fence, gate on the east side.
	_fill(3, 6, 10, 12, "soil")
	_fill(3, 6, 10, 7, "sprouts")
	_fill(3, 10, 10, 11, "sprouts")
	_fill(3, 8, 10, 9, "path")
	_fill(11, 8, 11, 9, "path")
	_fill(11, 10, 15, 11, "path")
	_fence_cells(2, 5, 11, 12, 11, 8, 9)
	_fill(11, 8, 11, 9, "path")
	# Initiates' quarter (east): pink paving and two dwellings.
	_fill(24, 5, 33, 13, "floor_alt")
	_fill(24, 10, 33, 11, "path")
	_fill(20, 10, 23, 11, "path")
	# Barren yard (south-east): bare ground to the shore, a rock pile to haul from.
	_fill(23, 15, 33, 18, "path")
	_fill(30, 15, 31, 16, "rock")
	# Piers into the sea.
	_fill(17, 21, 18, 22, "path")
	_fill(29, 21, 30, 22, "path")

	# Ship: the wreck on the south-west beach, entrance of the Ruins of Utopia.
	_fill(2, 15, 8, 19, "sand")
	_block(3, 16, 8, 19)
	_prop("prop_ship", Vector2(6 * CELL + 16, 20 * CELL), "Ship")
	# Dwellings in the Initiates' quarter (bunker-style, canon building sheet).
	_block(25, 6, 28, 8)
	_prop("prop_bunker", Vector2(27 * CELL, 9 * CELL), "Dwelling_1")
	_block(30, 6, 33, 8)
	_prop("prop_bunker", Vector2(32 * CELL, 9 * CELL), "Dwelling_2", true)
	# Gate icons and seal on the temple wall.
	_prop("prop_icon_queen_mother", Vector2(11 * CELL + 16, 3 * CELL), "Icon_1")
	_prop("prop_icon_queen_mother", Vector2(24 * CELL + 16, 3 * CELL), "Icon_2")
	_prop("prop_seal_o", Vector2(17 * CELL + 16, CELL + 10), "Seal_Gate")
	# Signs: compound gate, barren yard.
	_block(12, 7, 12, 7)
	_prop("prop_sign_a", Vector2(12 * CELL + 16, 8 * CELL), "Sign_Compound")
	_block(24, 14, 24, 14)
	_prop("prop_sign_b", Vector2(24 * CELL + 16, 15 * CELL), "Sign_Yard")
	_block(22, 16, 22, 16)
	_prop("prop_tag_x", Vector2(22 * CELL + 16, 17 * CELL), "Tag_Yard")

	# Spawns (names unchanged) and exits.
	_marker("spawn_default", Vector2(18 * CELL, 12 * CELL))
	_marker("spawn_from_temple", Vector2(18 * CELL, 4 * CELL + 8))
	_marker("spawn_from_ruins", Vector2(6 * CELL + 16, 20 * CELL + 24))
	_character("res://scenes/player/player.tscn", "Player", Vector2(18 * CELL, 12 * CELL))
	_character("res://scenes/npc/npc.tscn", "Initiate", Vector2(22 * CELL, 10 * CELL + 16), {
		"npc_id": "initiate", "caste": "initiate", "sprite_texture": "npc_initiate",
		"dialogue_path": "res://dialogue/offering.dialogue", "voice_pitch": 1.25})
	_character("res://scenes/npc/npc.tscn", "Drone", Vector2(6 * CELL, 8 * CELL + 16), {
		"npc_id": "drone", "caste": "drone", "sprite_texture": "npc_drone", "voice_pitch": 0.7})
	_character("res://scenes/npc/npc.tscn", "Barren", Vector2(29 * CELL, 17 * CELL), {
		"npc_id": "barren", "caste": "barren", "sprite_texture": "npc_barren", "voice_pitch": 0.9})
	_door("TempleDoor", Vector2(18 * CELL, 2 * CELL), {
		"target_scene": "res://scenes/maps/temple.tscn", "target_spawn": "spawn_from_village"})
	_mirror(Vector2(21 * CELL, 13 * CELL + 16))

	# ---- Exit points for other areas (wired at merge). Locked until then. ----
	var ruins := _door("Exit_Ruins", Vector2(6 * CELL + 16, 20 * CELL + 8), {"locked": true})
	ruins.set_meta("wire_to", "Ruins of Utopia entry scene, spawn from_island")
	var cruise := _door("Exit_Cruise", Vector2(18 * CELL, 22 * CELL), {"locked": true})
	cruise.set_meta("wire_to", "Cruise flashback world (unlocked by Forbidden Knowledge)")
	var tropical := _door("Exit_Tropical", Vector2(30 * CELL, 22 * CELL), {"locked": true})
	tropical.set_meta("wire_to", "Tropical Florida Keys entry scene")
	_save("res://scenes/maps/village.tscn")


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
