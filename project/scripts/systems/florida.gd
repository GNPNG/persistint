class_name Florida
extends RefCounted
## Florida — rules of the tropical sandbox (DESIGN.md section 3): gardening, crafting,
## critter surprises. Everything lives in WorldState flags (fl_*) so it saves with the game.
## Nothing is scored and nothing can be done wrong.

const DATA_PATH := "res://data/florida.json"
const BEACH_MAP := "res://scenes/florida/beach.tscn"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
	return _data


# --- inventory ---------------------------------------------------------------

static func inventory() -> Dictionary:
	return _ws().get_flag("fl_inventory", {})


static func count(item: String) -> int:
	return int(inventory().get(item, 0))


static func add_item(item: String, n := 1) -> void:
	var inv := inventory().duplicate()
	inv[item] = int(inv.get(item, 0)) + n
	_ws().set_flag("fl_inventory", inv)


# --- gardening ---------------------------------------------------------------

static func selected_seed() -> String:
	var seeds: Array = data().get("seeds", [])
	return _ws().get_flag("fl_seed", seeds[0] if not seeds.is_empty() else "")


static func cycle_seed() -> String:
	var seeds: Array = data().get("seeds", [])
	if seeds.is_empty():
		return ""
	var next: String = seeds[(seeds.find(selected_seed()) + 1) % seeds.size()]
	_ws().set_flag("fl_seed", next)
	return next


static func plot(plot_id: String) -> Dictionary:
	return _ws().get_flag("fl_plots", {}).get(plot_id, {})


static func _set_plot(plot_id: String, value: Dictionary) -> void:
	var plots: Dictionary = _ws().get_flag("fl_plots", {}).duplicate()
	if value.is_empty():
		plots.erase(plot_id)
	else:
		plots[plot_id] = value
	_ws().set_flag("fl_plots", plots)


## "empty", "growing" or "ready". Watering shaves a day off the growing time.
static func plot_state(plot_id: String, today: int) -> String:
	var p := plot(plot_id)
	if p.is_empty():
		return "empty"
	var grow: int = int(data()["plants"][p["plant"]]["grow_days"]) - (1 if p.get("watered", false) else 0)
	return "ready" if today - int(p["day"]) >= grow else "growing"


static func plant(plot_id: String, plant_id: String, today: int) -> bool:
	if not plot(plot_id).is_empty() or not data()["plants"].has(plant_id):
		return false
	_set_plot(plot_id, {"plant": plant_id, "day": today, "watered": false})
	return true


static func water(plot_id: String) -> bool:
	var p := plot(plot_id).duplicate()
	if p.is_empty() or p.get("watered", false):
		return false
	p["watered"] = true
	_set_plot(plot_id, p)
	return true


## Picks the plot's plants and returns what was gathered ("" when nothing is ready).
static func harvest(plot_id: String, today: int) -> String:
	if plot_state(plot_id, today) != "ready":
		return ""
	var plant_id: String = plot(plot_id)["plant"]
	add_item(plant_id, int(data()["plants"][plant_id]["yield"]))
	_set_plot(plot_id, {})
	return plant_id


# --- crafting ----------------------------------------------------------------

static func can_craft(recipe_id: String) -> bool:
	var recipe: Dictionary = data()["recipes"].get(recipe_id, {})
	if recipe.is_empty():
		return false
	for item: String in recipe["needs"]:
		if count(item) < int(recipe["needs"][item]):
			return false
	return true


static func craft(recipe_id: String) -> bool:
	if not can_craft(recipe_id):
		return false
	var recipe: Dictionary = data()["recipes"][recipe_id]
	var inv := inventory().duplicate()
	for item: String in recipe["needs"]:
		inv[item] = int(inv[item]) - int(recipe["needs"][item])
	inv[recipe_id] = int(inv.get(recipe_id, 0)) + 1
	_ws().set_flag("fl_inventory", inv)
	return true


## Put a crafted piece on the paper doll (the same outfit_* flags the wardrobe uses).
static func wear(recipe_id: String) -> bool:
	var recipe: Dictionary = data()["recipes"].get(recipe_id, {})
	if recipe.is_empty() or not recipe.has("wear") or count(recipe_id) < 1:
		return false
	_ws().set_flag("outfit_%s" % recipe["wear"]["slot"], recipe["wear"]["part"])
	return true


# --- critters ----------------------------------------------------------------

## The first surprise whose "when" matches what the doll is wearing, else the kind's default.
static func surprise_for(kind: String, outfit: Dictionary) -> Dictionary:
	for s: Dictionary in data()["critters"].get(kind, {}).get("surprises", []):
		var ok := true
		for slot: String in s.get("when", {}):
			if outfit.get(slot, "none") != s["when"][slot]:
				ok = false
		if ok:
			return s
	return {}


static func current_outfit() -> Dictionary:
	var outfit := {}
	for slot: String in PaperDoll.LAYERS:
		outfit[slot] = _ws().get_flag("outfit_%s" % slot, "none")
	return outfit


## WorldState looked up at run time, so this script also compiles in headless SceneTree tests.
static func _ws() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/WorldState")
