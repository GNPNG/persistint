class_name Ponies
extends RefCounted
## Ponies — rules of the Florida pony stable (DESIGN.md section 3): groom (the paper-doll
## makeover on a pony), ride (mounted click-to-move, faster), foals (coat and mane traits mix,
## genetics played straight and joyful). The herd lives in WorldState flag fl_ponies, the pony
## being ridden in fl_riding, so everything saves with the game. Nothing is scored and nothing
## can be done wrong.

const DATA_PATH := "res://data/ponies.json"
const ART := "res://assets/placeholder/pony_%s.png"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
	return _data


# --- the herd ----------------------------------------------------------------

## Every pony by id (its cast id). The starters arrive the first time anyone looks.
static func herd() -> Dictionary:
	var h: Dictionary = _ws().get_flag("fl_ponies", {})
	if h.is_empty():
		for s: Dictionary in data().get("starters", []):
			h[s["cast"]] = {"genes": s["genes"].duplicate(true), "groom": s["groom"].duplicate(), "parents": [], "born_day": 0}
		_ws().set_flag("fl_ponies", h)
	return h


static func ids() -> Array:
	return herd().keys()


static func pony(id: String) -> Dictionary:
	return herd().get(id, {})


static func _store(id: String, value: Dictionary) -> void:
	var h := herd().duplicate(true)
	h[id] = value
	_ws().set_flag("fl_ponies", h)


static func display_name(id: String) -> String:
	return _cast().short(id) if _cast() else id


## Foals are little for a couple of days, then grown-ups who can be ridden and have foals.
static func is_foal(id: String, today: int) -> bool:
	var p := pony(id)
	return not p.get("parents", []).is_empty() and today - int(p.get("born_day", 0)) < int(data().get("foal_grow_days", 2))


# --- genetics ----------------------------------------------------------------

## The allele you see: the strongest of the pair in the gene's dominance list.
static func phenotype(id_or_pony: Variant, gene: String) -> String:
	var p: Dictionary = pony(id_or_pony) if id_or_pony is String else id_or_pony
	var pair: Array = p.get("genes", {}).get(gene, [])
	var order: Array = data()["genes"][gene]["dominance"]
	var best := ""
	for allele: String in pair:
		if best == "" or order.find(allele) < order.find(best):
			best = allele
	return best


## "honey coat, rose mane, dappled" — how the stable talks about a pony.
static func describe(id: String) -> String:
	var genes: Dictionary = data()["genes"]
	var coat: String = genes["coat"]["alleles"][phenotype(id, "coat")]["label"]
	var mane: String = genes["mane"]["alleles"][phenotype(id, "mane")]["label"]
	var text := "%s coat, %s mane" % [coat, mane]
	if phenotype(id, "spots") == "dappled":
		text += ", dappled"
	return text


## One allele per gene from each parent, picked by rng. Pure: returns the foal's genes.
static func cross(a: Dictionary, b: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var genes := {}
	for gene: String in data()["genes"]:
		var pa: Array = a["genes"][gene]
		var pb: Array = b["genes"][gene]
		genes[gene] = [pa[rng.randi_range(0, pa.size() - 1)], pb[rng.randi_range(0, pb.size() - 1)]]
	return genes


static func next_foal_name() -> String:
	for name_id: String in data().get("foal_names", []):
		if not herd().has(name_id):
			return name_id
	return ""


static func can_breed(a: String, b: String, today: int) -> bool:
	return a != b and herd().has(a) and herd().has(b) and not is_foal(a, today) and not is_foal(b, today)


## Two grown-up ponies have a foal, who joins the stable at once. Returns the foal's id, or ""
## when every stall is full (the stable is simply full of happy ponies).
static func breed(a: String, b: String, today: int, rng: RandomNumberGenerator = null) -> String:
	if not can_breed(a, b, today):
		return ""
	var foal_id := next_foal_name()
	if foal_id == "":
		return ""
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var groom := {"mane_style": pony(a)["groom"].get("mane_style", "flowing"), "accessory": "none"}
	_store(foal_id, {"genes": cross(pony(a), pony(b), rng), "groom": groom, "parents": [a, b], "born_day": today})
	return foal_id


# --- grooming ----------------------------------------------------------------

## The pony as paper-doll parts {slot: part_id} for PonyDoll, in PonyDoll.LAYERS order.
static func parts(id_or_pony: Variant) -> Dictionary:
	var p: Dictionary = pony(id_or_pony) if id_or_pony is String else id_or_pony
	if p.is_empty():
		return {}
	var g: Dictionary = p.get("groom", {})
	var acc: String = g.get("accessory", "none")
	return {
		"body": "body_%s" % phenotype(p, "coat"),
		"spots": "spots" if phenotype(p, "spots") == "dappled" else "none",
		"mane": "mane_%s_%s" % [g.get("mane_style", "flowing"), phenotype(p, "mane")],
		"accessory": "none" if acc == "none" else "acc_%s" % acc,
		"sparkle": "sparkle" if g.get("brushed", false) else "none",
	}


static func groom(id: String, slot: String, choice: String) -> bool:
	if not herd().has(id) or not data()["groom"].has(slot) or choice not in data()["groom"][slot]:
		return false
	var p := pony(id).duplicate(true)
	p["groom"][slot] = choice
	_store(id, p)
	return true


## Next option for a groom slot (wraps around), applied to the pony.
static func cycle(id: String, slot: String) -> String:
	var options: Array = data()["groom"][slot]
	var now: String = pony(id).get("groom", {}).get(slot, options[0])
	var next: String = options[(options.find(now) + 1) % options.size()]
	groom(id, slot, next)
	return next


static func brush(id: String) -> bool:
	if not herd().has(id):
		return false
	var p := pony(id).duplicate(true)
	p["groom"]["brushed"] = true
	_store(id, p)
	return true


# --- riding ------------------------------------------------------------------

static func riding() -> String:
	var id: String = _ws().get_flag("fl_riding", "")
	return id if id != "" and herd().has(id) else ""


static func mount(id: String, today: int) -> bool:
	if not herd().has(id) or is_foal(id, today):
		return false
	_ws().set_flag("fl_riding", id)
	return true


static func dismount() -> void:
	if _ws().get_flag("fl_riding", "") != "":
		_ws().set_flag("fl_riding", "")


static func speed_multiplier() -> float:
	return float(data().get("ride_speed_multiplier", 1.0)) if riding() != "" else 1.0


static func line(kind: String) -> String:
	var lines: Array = data().get("lines", {}).get(kind, [])
	return lines.pick_random() if not lines.is_empty() else ""


## Autoloads looked up at run time, so this script also compiles in headless SceneTree tests.
static func _ws() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/WorldState")


static func _cast() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/Cast")
