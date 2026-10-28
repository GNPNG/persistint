extends SceneTree
## Paper-doll slots (bd lg5w.1): PaperDoll has eight, in stack order (body, shoes, bottom, top,
## dress, hair, hat, accessory), and a part's slot is its prefix (acc_ is the accessory). outfits.json
## registers every slot but the body, each option worn in its own slot, its art in the tree. The
## doll draws one layer per slot. The wardrobe has a row per slot, in PaperDoll.PICK_ORDER, and shows
## the ones with something to choose (hair, dress and accessory before any wardrobe sheet lands; a
## new slot's row appears when it gets a part), its panel growing to fit; a hat and a bow are worn
## together. The player in the village has a rig layer and a paper ring per slot in that order and
## draws a worn hat and bow both. Florida reads every slot. The makeover offers a button only for a
## slot with a choice, in the wardrobe's row order, then Walk: on the tree's outfits.json and on
## options set without and with top and hat parts, so the checks hold whether or not sheets landed.
## Run: godot --headless --path project -s tests/test_paperdoll_slots.gd

const SLOTS := ["body", "shoes", "bottom", "top", "dress", "hair", "hat", "accessory"]
const WARDROBE := "res://scenes/ui/wardrobe.tscn"
const VILLAGE := "res://scenes/maps/village.tscn"
const HOTTEST := "res://scenes/minigames/hottest_of_the_hot.tscn"
## Parts that exist (with rigs) standing in for a hat in the tests: no hat_ art is cut yet.
const STAND_IN_HAT := "hair_crown"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _joined(a: Array) -> String:
	return ", ".join(PackedStringArray(a))


## The makeover's buttons, in order, on `opts` (set before it enters the tree; empty: it reads
## outfits.json itself), from a reset WorldState (no prepared outfit).
func _makeover_buttons(ws: Node, opts: Dictionary) -> Array:
	ws.reset()
	var hot: Node = load(HOTTEST).instantiate()
	hot.options = opts
	root.add_child(hot)
	await process_frame
	var buttons: Array = hot.find_children("*", "Button", true, false).map(func(b: Node) -> String: return (b as Button).text)
	hot.queue_free()
	await process_frame
	return buttons


## The buttons the makeover should offer on `opts`: a button per slot with a choice (more than one
## option), in `order` (the wardrobe's rows), then Walk.
func _expected_buttons(order: Array, opts: Dictionary) -> Array:
	var with_choice := order.filter(func(s: String) -> bool: return opts.get(s, []).size() > 1)
	return with_choice.map(func(s: String) -> String: return s.capitalize()) + ["Walk"]


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	ws.reset()

	# --- The slots.
	_check(_joined(PaperDoll.LAYERS) == _joined(SLOTS), "PaperDoll's slots in stack order (%s)" % _joined(PaperDoll.LAYERS))
	_check(PaperDoll.DEFAULT_OUTFIT.keys().size() == SLOTS.size() and SLOTS.all(func(s: String) -> bool: return PaperDoll.DEFAULT_OUTFIT.has(s)),
		"the default outfit names every slot")
	_check(["shoes", "bottom", "top", "hat"].all(func(s: String) -> bool: return PaperDoll.DEFAULT_OUTFIT[s] == "none"),
		"she starts with nothing in the new slots")
	var slot_of := {"hat_straw": "hat", "acc_bow": "accessory", "top_tee_heart": "top", "bottom_skirt_rose": "bottom",
		"shoes_maryjane_pink": "shoes", "dress_white": "dress", "hair_braids": "hair", "body_base": "body",
		"none": "", "robe_white": ""}
	var wrong: Array = slot_of.keys().filter(func(p: String) -> bool: return PaperDoll.slot_of(p) != slot_of[p])
	_check(wrong.is_empty(), "a part's slot is its prefix (%s)" % _joined(wrong))

	# --- outfits.json.
	var options: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/outfits.json"))
	var slots_but_body := SLOTS.filter(func(s: String) -> bool: return s != "body")
	_check(options.size() == slots_but_body.size() and slots_but_body.all(func(s: String) -> bool: return options.has(s)),
		"outfits.json registers every slot but the body (%s)" % _joined(options.keys()))
	var misplaced: Array = []
	var missing: Array = []
	for slot: String in options:
		for p: String in options[slot]:
			if p == "none":
				continue
			if PaperDoll.slot_of(p) != slot:
				misplaced.append("%s in %s" % [p, slot])
			if not ResourceLoader.exists(PaperDoll.part_path(PaperDoll.art_dir_for([p]), p)):
				missing.append(p)
	_check(misplaced.is_empty(), "every option is worn in its own slot (%s)" % _joined(misplaced))
	_check(missing.is_empty(), "every option's art is in the tree (%s)" % _joined(missing))
	_check(["shoes", "bottom", "top", "hat"].all(func(s: String) -> bool: return options.get(s, []).has("none")),
		"the new slots can be left empty")

	# --- The doll: one layer per slot, a hat and a bow together.
	var doll := PaperDoll.new()
	root.add_child(doll)
	await process_frame
	var names: Array = doll.get_children().map(func(c: Node) -> String: return String(c.name))
	_check(_joined(names) == _joined(SLOTS.map(func(s: String) -> String: return s.capitalize())),
		"the doll draws a layer per slot in stack order (%s)" % _joined(names))
	doll.set_outfit({"body": "body_base", "dress": "dress_white", "hair": "hair_short", "hat": STAND_IN_HAT, "accessory": "acc_bow"})
	_check(doll.get_node("Hat").texture != null and doll.get_node("Accessory").texture != null and doll.get_node("Hair").texture != null,
		"the doll wears a hat and a bow together, over her hair")
	doll.queue_free()

	# --- The wardrobe.
	var w: Node = load(WARDROBE).instantiate()
	root.add_child(w)
	await _frames(2)
	var rows: Node = w.get_node("Panel/HBox/VBox")
	var no_row := slots_but_body.filter(func(s: String) -> bool: return rows.get_node_or_null(s.capitalize()) == null)
	_check(no_row.is_empty(), "the wardrobe has a row per slot but the body (missing %s)" % _joined(no_row))
	var row_names: Array = rows.get_children().map(func(c: Node) -> String: return String(c.name).to_lower())
	var row_order := row_names.filter(func(s: String) -> bool: return slots_but_body.has(s))
	_check(_joined(row_order) == _joined(PaperDoll.PICK_ORDER),
		"its rows are in PaperDoll's pick order (expected %s; got %s)" % [_joined(PaperDoll.PICK_ORDER), _joined(row_order)])
	var shown := slots_but_body.filter(func(s: String) -> bool: return rows.get_node(s.capitalize()).visible)
	var with_choice := slots_but_body.filter(func(s: String) -> bool: return options.get(s, []).size() > 1)
	_check(_joined(shown) == _joined(with_choice), "it shows the rows with something to choose (%s)" % _joined(shown))
	var panel: Control = w.get_node("Panel")
	var box: Control = w.get_node("Panel/HBox")
	var h0 := panel.size.y
	_check(h0 >= 224.0 and h0 >= box.get_combined_minimum_size().y + 20.0, "the panel fits its rows (%d px)" % h0)
	w.options["hat"] = ["none", STAND_IN_HAT]
	w.options["top"] = ["none", "hair_short"]
	w.show_rows()
	await _frames(2)
	_check(rows.get_node("Hat").visible and rows.get_node("Top").visible and not rows.get_node("Shoes").visible,
		"a slot's row shows once it has a part")
	_check(panel.size.y >= box.get_combined_minimum_size().y + 20.0 and panel.size.y >= h0,
		"and the panel grows to fit the rows (%d px)" % panel.size.y)
	rows.get_node("Hat/Next").pressed.emit()
	rows.get_node("Accessory/Next").pressed.emit()
	await process_frame
	_check(ws.get_flag("outfit_hat") == STAND_IN_HAT and ws.get_flag("outfit_accessory") == "acc_bow",
		"the hat and the accessory rows set their own slots (%s, %s)" % [ws.get_flag("outfit_hat"), ws.get_flag("outfit_accessory")])
	var preview: Node = w.get_node("Panel/HBox/Preview")
	_check(preview.get_node("Hat").texture != null and preview.get_node("Accessory").texture != null and preview.get_node("Dress").texture != null,
		"the preview wears the hat and the bow together, the dress still on")
	w.queue_free()
	await process_frame

	# --- The player in the village: a layer and a ring per slot; the hat and the bow both drawn.
	change_scene_to_file(VILLAGE)
	await _frames(4)
	var player: Node = get_first_node_in_group("player")
	var at: Array = SLOTS.map(func(s: String) -> int:
		var n: Node = player.get_node_or_null(s.capitalize())
		return n.get_index() if n is AnimatedSprite2D else -1)
	var ordered := not at.has(-1)
	for i in range(1, at.size()):
		ordered = ordered and at[i] > at[i - 1]
	_check(ordered, "the player has a rig layer per slot in stack order (%s)" % _joined(at.map(func(i: int) -> String: return str(i))))
	var no_ring := SLOTS.filter(func(s: String) -> bool: return player.get_node_or_null(s.capitalize() + "Ring") == null)
	_check(no_ring.is_empty(), "and a paper ring under the art for each (missing %s)" % _joined(no_ring))
	var hat: AnimatedSprite2D = player.get_node("Hat")
	var acc: AnimatedSprite2D = player.get_node("Accessory")
	_check(hat.sprite_frames != null and acc.sprite_frames != null and player.get_node("Hair").sprite_frames != null,
		"the player wears the hat and the bow from the wardrobe together")
	_check(hat.animation == acc.animation and hat.frame == acc.frame, "the hat steps with the other layers")
	ws.set_flag("outfit_hat", "none")
	await process_frame
	_check(hat.sprite_frames == null and acc.sprite_frames != null, "taking the hat off leaves the bow")
	_check(player.get_node("Top").sprite_frames == null and player.get_node("Shoes").sprite_frames == null,
		"empty slots draw nothing")

	# --- Florida reads every slot.
	var fl: Dictionary = Florida.current_outfit()
	_check(SLOTS.all(func(s: String) -> bool: return fl.has(s)), "Florida's current outfit names every slot")

	# --- The makeover: a button per slot with a choice, in the wardrobe's row order, then Walk; on
	# the tree's outfits.json, then on its options with no top or hat parts and with one of each.
	var got: Array = await _makeover_buttons(ws, {})
	var expected := _expected_buttons(row_order, options)
	_check(_joined(got) == _joined(expected),
		"the makeover offers a button per slot with a choice in outfits.json, in the wardrobe's order (expected %s; got %s)" % [_joined(expected), _joined(got)])
	var bare := options.duplicate(true)
	for slot: String in ["top", "bottom", "shoes", "hat"]:
		bare[slot] = ["none"]
	got = await _makeover_buttons(ws, bare)
	expected = _expected_buttons(row_order, bare)
	_check(_joined(got) == _joined(expected) and not got.has("Top") and not got.has("Hat"),
		"with no top or hat parts it offers no Top or Hat button (expected %s; got %s)" % [_joined(expected), _joined(got)])
	var dressed := bare.duplicate(true)
	dressed["hat"] = ["none", STAND_IN_HAT]
	dressed["top"] = ["none", "hair_short"]
	got = await _makeover_buttons(ws, dressed)
	expected = _expected_buttons(row_order, dressed)
	_check(_joined(got) == _joined(expected) and got.has("Top") and got.has("Hat"),
		"with a top and a hat it offers their buttons, in the wardrobe's order (expected %s; got %s)" % [_joined(expected), _joined(got)])
	ws.reset()

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)
