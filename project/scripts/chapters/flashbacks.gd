extends RefCounted
## Flashbacks — cruise flashback episodes unlocked by Forbidden Knowledge (DESIGN.md §2).
## data/flashbacks.json maps the knowledge piece ids each episode requires to its title,
## entry scene and intro card. Playing one goes through the chapter system: the current
## player character's flags are archived and cleared (the characters aren't shared), the
## chapter becomes the cruise for the episode, and leave() restores everything afterwards.
## State lives in WorldState so quitting mid-flashback survives: `flashback_active`
## ({id, chapter, origin: {scene, spawn}}), `flashback_archive` (the archived player flags),
## `flashback_seen_<id>` once an episode has been played through.

const DATA_PATH := "res://data/flashbacks.json"
const CARD_SCENE := "res://scenes/chapters/flashback_card.tscn"
const Chapters := preload("res://scripts/chapters/chapters.gd")
const ForbiddenKnowledge := preload("res://scripts/ruins/forbidden_knowledge.gd")


static func _ws() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/WorldState")


static func data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


## Every flashback, in story order.
static func all() -> Array:
	var list: Array = data().get("flashbacks", []).duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	return list


static func flashback(id: String) -> Dictionary:
	for f: Dictionary in data().get("flashbacks", []):
		if f.get("id") == id:
			return f
	return {}


## Required piece ids not recovered yet.
static func missing(id: String) -> Array:
	var out := []
	for piece_id: String in flashback(id).get("requires", []):
		if not ForbiddenKnowledge.has(piece_id):
			out.append(piece_id)
	return out


static func is_unlocked(id: String) -> bool:
	return not flashback(id).is_empty() and missing(id).is_empty()


## Ids of every unlocked flashback, in story order.
static func unlocked() -> Array:
	return all().filter(func(f: Dictionary) -> bool: return is_unlocked(f["id"])).map(func(f: Dictionary) -> String: return f["id"])


## Flashbacks that need this piece and are unlocked now (for the pickup message).
static func opened_by(piece_id: String) -> Array:
	return all().filter(func(f: Dictionary) -> bool:
		return f.get("requires", []).has(piece_id) and is_unlocked(f["id"])).map(func(f: Dictionary) -> String: return f["id"])


static func seen(id: String) -> bool:
	return _ws().has_flag("flashback_seen_%s" % id)


## The flashback being played ({} when none).
static func active() -> Dictionary:
	var a: Variant = _ws().get_flag("flashback_active")
	return a if a is Dictionary else {}


## The intro card with {cast_id} names filled from data/cast.json.
static func card(id: String) -> Dictionary:
	var c: Dictionary = flashback(id).get("card", {}).duplicate(true)
	c["heading"] = ForbiddenKnowledge.fill(c.get("heading", ""))
	c["lines"] = c.get("lines", []).map(func(l: String) -> String: return ForbiddenKnowledge.fill(l))
	return c


## Starts flashback `id` from `origin_scene` (where to come back to). Archives and clears the
## player flags, sets the chapter, and returns the entry ({scene, spawn}); {} if locked.
static func enter(id: String, origin_scene := "", origin_spawn := "spawn_default") -> Dictionary:
	if not is_unlocked(id) or not active().is_empty():
		return {}
	var ws := _ws()
	var origin := {"scene": origin_scene, "spawn": origin_spawn}
	if origin_scene == "":
		var loc: Variant = ws.get_flag("_location")
		origin = loc if loc is Dictionary else {"scene": Chapters.return_scene(Chapters.current(), ""), "spawn": "spawn_default"}
	var archive := {}
	for key: String in ws.flags.keys():
		for prefix: String in Chapters.data().get("player_flags", []):
			if key.begins_with(prefix):
				archive[key] = ws.flags[key]
				ws.flags.erase(key)
				break
	ws.set_flag("flashback_archive", archive)
	ws.set_flag("flashback_active", {"id": id, "chapter": Chapters.current(), "origin": origin})
	ws.set_flag("chapter", data().get("chapter", "cruise"))
	var entry := {"scene": flashback(id).get("entry_scene", ""), "spawn": "spawn_default"}
	# Continue resumes inside the episode; it still comes back through leave().
	ws.set_flag("_location", entry)
	return entry


## Where an episode's last mini-game goes back to: the flashback's origin when one is
## active, otherwise `fallback`. Pure; leave() does the restoring.
static func return_target(fallback: String) -> Dictionary:
	var a := active()
	if a.is_empty():
		return {"scene": fallback, "spawn": "spawn_default"}
	return a.get("origin", {"scene": fallback, "spawn": "spawn_default"})


## Ends the active flashback: marks it seen, drops the flashback character's flags, restores
## the original character, chapter and location. Returns where to go ({scene, spawn}).
static func leave(fallback: String) -> Dictionary:
	var target := return_target(fallback)
	var a := active()
	if a.is_empty():
		return target
	var ws := _ws()
	for key: String in ws.flags.keys():
		for prefix: String in Chapters.data().get("player_flags", []):
			if key.begins_with(prefix):
				ws.flags.erase(key)
				break
	var archive: Variant = ws.get_flag("flashback_archive", {})
	if archive is Dictionary:
		for key: String in archive:
			ws.flags[key] = archive[key]
	ws.flags.erase("flashback_archive")
	ws.flags.erase("flashback_active")
	ws.set_flag("flashback_seen_%s" % a.get("id", ""), true)
	ws.set_flag("chapter", a.get("chapter", data().get("chapter", "cruise")))
	ws.set_flag("_location", target)
	return target
