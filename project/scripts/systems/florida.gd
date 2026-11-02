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


## The name an item shows by: a plant's, a recipe's or a found item's "label" in the data
## (ids never show; bd ke5). An id with no label anywhere falls back to its words.
static func label(item: String) -> String:
	for group: String in ["plants", "recipes", "items"]:
		var entry: Dictionary = data().get(group, {}).get(item, {})
		if entry.has("label"):
			return entry["label"]
	return item.capitalize()


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


# --- gifts -------------------------------------------------------------------
# The made things nobody wears are gifts for the critters and the ponies ("gifts" in the data).
# Each friend (a critter's cast id nickname, a pony's cast id) keeps its own hearts in fl_hearts.

static func gifts() -> Dictionary:
	return data().get("gifts", {})


## The giftable recipe ids, in the data's order.
static func gift_items() -> Array:
	return gifts().get("items", [])


## The giftable things the player has at least one of.
static func giftable_in_inventory() -> Array:
	return gift_items().filter(func(item: String) -> bool: return count(item) > 0)


static func hearts(who: String) -> int:
	return int(_ws().get_flag("fl_hearts", {}).get(who, 0))


static func max_hearts() -> int:
	return int(gifts().get("max_hearts", 5))


## A kind's favourites, lines, effects and unlock (dolphin, crab, gull, mermaid or pony).
static func gift_kind(kind: String) -> Dictionary:
	return gifts().get("kinds", {}).get(kind, {})


## "loved" for one of the kind's favourites, else "liked": every gift is welcome.
static func reaction_for(kind: String, item: String) -> String:
	return "loved" if item in gift_kind(kind).get("loved", []) else "liked"


## Gives one `item` to `who` (of `kind`). Returns {} when it can't be given (not a gift, none in
## the inventory, an unknown kind); else {reaction, line, effect, hearts, gained, unlocked}. Only
## the first hearts_per_day gifts of a day earn hearts (capped at max_hearts); `unlocked` is true
## for exactly the gift that brings the friend up to the kind's unlock.
static func give(who: String, kind: String, item: String, today: int) -> Dictionary:
	var info := gift_kind(kind)
	if who == "" or info.is_empty() or not (item in gift_items()) or count(item) < 1:
		return {}
	add_item(item, -1)
	var before := hearts(who)
	var reaction := reaction_for(kind, item)
	var gained := 0
	# fl_gift_day {who: {day, n}}: how many heart-earning gifts the friend had on its last gift day
	var days: Dictionary = _ws().get_flag("fl_gift_day", {}).duplicate(true)
	var last: Dictionary = days.get(who, {})
	var earned := int(last.get("n", 0)) if int(last.get("day", -1)) == today else 0
	if earned < int(gifts().get("hearts_per_day", 1)):
		days[who] = {"day": today, "n": earned + 1}
		_ws().set_flag("fl_gift_day", days)
		gained = mini(int(gifts().get("hearts", {}).get(reaction, 1)), max_hearts() - before)
	if gained > 0:
		var all: Dictionary = _ws().get_flag("fl_hearts", {}).duplicate()
		all[who] = before + gained
		_ws().set_flag("fl_hearts", all)
	var need := int(unlock_for(kind).get("hearts", 0))
	var effects: Dictionary = info.get("effect", {})
	return {
		"reaction": reaction,
		"line": gift_line(kind, "max" if before >= max_hearts() else reaction).replace("{item}", label(item)),
		"effect": effects.get("loved" if before >= max_hearts() else reaction, "hop"),
		"hearts": before + gained,
		"gained": gained,
		"unlocked": need > 0 and before < need and before + gained >= need,
	}


## The float text for a give() result: the unlock's, else the hearts earned, else "" (no float).
static func gift_float(result: Dictionary) -> String:
	var floats: Dictionary = gifts().get("floats", {})
	var gained := int(result.get("gained", 0))
	if result.get("unlocked", false):
		return floats.get("unlocked", "")
	if gained <= 0:
		return ""
	var text: String = floats.get("heart" if gained == 1 else "hearts", "")
	return text.replace("{n}", str(gained))


## One of the kind's gift lines ("loved", "liked" or "max"), "" if it has none.
static func gift_line(kind: String, key: String) -> String:
	var lines: Array = gift_kind(kind).get("lines", {}).get(key, [])
	return lines.pick_random() if not lines.is_empty() else ""


## The kind's unlock: {id, hearts, label, effect, lines, ...}.
static func unlock_for(kind: String) -> Dictionary:
	return gift_kind(kind).get("unlock", {})


static func has_unlock(who: String, kind: String) -> bool:
	var unlock := unlock_for(kind)
	return not unlock.is_empty() and hearts(who) >= int(unlock.get("hearts", 0))


## One of the unlock's lines under `key` ("lines", or "lines_off" / "lines_none").
static func unlock_line(kind: String, key := "lines") -> String:
	var lines: Array = unlock_for(kind).get(key, [])
	return lines.pick_random() if not lines.is_empty() else ""


## The gull's unlock: a good-friend gull brings one shell a day. True when it brought one now.
static func gull_shell(who: String, today: int) -> bool:
	if not has_unlock(who, "gull"):
		return false
	var days: Dictionary = _ws().get_flag("fl_gull_shell_day", {}).duplicate()
	if int(days.get(who, -1)) == today:
		return false
	days[who] = today
	_ws().set_flag("fl_gull_shell_day", days)
	add_item("shell")
	return true


## The crab walking beside the player ("" for none; the crab's unlock).
static func following() -> String:
	return _ws().get_flag("fl_following", "")


static func set_following(who: String) -> void:
	_ws().set_flag("fl_following", who)


## WorldState looked up at run time, so this script also compiles in headless SceneTree tests.
static func _ws() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/WorldState")
