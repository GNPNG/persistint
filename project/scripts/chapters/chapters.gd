extends RefCounted
## Chapters — data/chapters.json lookups and the time jump between chapters.
## The characters aren't shared: jumping archives the current chapter's player flags and
## clears them, so the next chapter starts with a fresh player character.

const DATA_PATH := "res://data/chapters.json"


static func data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


## The chapter the player is in (WorldState `chapter`; the first chapter when unset).
static func current() -> String:
	return String(WorldState.get_flag("chapter", data().get("first", "island")))


static func chapter(id: String) -> Dictionary:
	return data().get("chapters", {}).get(id, {})


## Where a chapter's own scenes return to (e.g. the Interview inside the cruise chapter).
static func return_scene(id: String, fallback: String) -> String:
	return String(chapter(id).get("return_scene", fallback))


## Ends chapter `from` and starts its next one. Archives and clears the player flags,
## sets `chapter`, and returns the next chapter's entry ({scene, spawn}); {} if there is none.
static func jump(from: String) -> Dictionary:
	var next_id: String = chapter(from).get("next", "")
	var next := chapter(next_id)
	if next.is_empty():
		return {}
	var archive := {}
	for key: String in WorldState.flags.keys():
		for prefix: String in data().get("player_flags", []):
			if key.begins_with(prefix):
				archive[key] = WorldState.flags[key]
				WorldState.flags.erase(key)
				break
	WorldState.set_flag("chapter_archive_%s" % from, archive)
	var entry := {"scene": next.get("entry_scene", ""), "spawn": next.get("entry_spawn", "spawn_default")}
	# Continue resumes in the new chapter, not on the map the last one ended on.
	WorldState.set_flag("_location", entry)
	WorldState.set_flag("chapter", next_id)
	return entry
