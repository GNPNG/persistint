extends RefCounted
## ForbiddenKnowledge — the recovered-pieces list (DESIGN.md "Forbidden Knowledge").
## WorldState "forbidden_knowledge" is an Array of piece ids, in recovery order; later
## systems (cruise flashback unlocks) read it with has()/all(). Pieces are defined in
## data/ruins.json ("knowledge"); title/text and room dressing are filled from the sources.

const DATA_PATH := "res://data/ruins.json"
const FLAG := "forbidden_knowledge"


static func _ws() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/WorldState")


static func data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


## Every piece defined in the data file, keyed by id.
static func pieces() -> Dictionary:
	var out := {}
	for piece: Dictionary in data().get("knowledge", []):
		out[piece["id"]] = piece
	return out


static func all() -> Array:
	return _ws().get_flag(FLAG, []).duplicate()


static func has(piece_id: String) -> bool:
	return _ws().get_flag(FLAG, []).has(piece_id)


## Returns true if the piece was newly recovered.
static func recover(piece_id: String) -> bool:
	if has(piece_id) or not pieces().has(piece_id):
		return false
	var list := all()
	list.append(piece_id)
	_ws().set_flag(FLAG, list)
	return true
