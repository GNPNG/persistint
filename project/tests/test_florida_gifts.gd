extends SceneTree
## Headless check of the Florida gifts: the made things nobody wears are the gifts, every kind
## (dolphin, crab, gull, mermaid, pony) has its lines and an unlock, a gift uses one up and earns
## 2 hearts for a favourite and 1 for anything else, only once a day per friend, up to the max
## (then the 'max' lines), the unlock comes exactly once, hearts are per friend, the gull's shell
## comes once a day, the crab's follow flag round-trips, it all survives save/load, and the
## critter's gift panel and the stable panel's Give and Nuzzle buttons work. Also: hearts_per_day
## is read, the float texts come from the data, one gift panel opens at a time, a quick second
## line keeps its bubble, a following crab is let go on a new visit, and the E key passes over it.
## Run: godot --headless --path project -s tests/test_florida_gifts.gd
## WorldState saves to a temp file for the run; the player's real save is never touched.

const TEMP_SAVE := "user://test_florida_gifts_save.json"
const KINDS := ["dolphin", "crab", "gull", "mermaid", "pony"]

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	var clock: Node = root.get_node("/root/GameClock")
	var real_save: String = ws.SAVE_PATH
	ws.SAVE_PATH = TEMP_SAVE
	ws.reset()
	var today: int = clock.day

	# The data: the gifts are exactly the recipes nobody wears; every kind is complete
	var unworn: Array = []
	for id: String in Florida.data()["recipes"]:
		if not Florida.data()["recipes"][id].has("wear"):
			unworn.append(id)
	_check(Florida.gift_items() == unworn and unworn.size() == 5, "the gifts are the five recipes without a 'wear' (%s)" % ", ".join(unworn))
	for item: String in Florida.gift_items():
		_check(Florida.label(item) != item.capitalize(), "%s has a label" % item)
	_check(Florida.gifts().has("_draft") and Florida.gifts().has("_note"), "the gifts block is marked as draft and explained")
	for kind: String in KINDS:
		var info := Florida.gift_kind(kind)
		_check(not info.is_empty(), "%s takes gifts" % kind)
		var loved: Array = info.get("loved", [])
		_check(not loved.is_empty() and loved.all(func(i: String) -> bool: return i in Florida.gift_items()), "%s loves one or two of the gifts" % kind)
		for key: String in ["loved", "liked", "max"]:
			_check(Florida.gift_line(kind, key) != "", "%s has %s lines" % [kind, key])
		var unlock := Florida.unlock_for(kind)
		_check(unlock.get("id", "") != "" and unlock.get("label", "") != "" and Florida.unlock_line(kind) != "", "%s has an unlock" % kind)
	_check(Florida.unlock_line("crab", "lines_off") != "" and Florida.unlock_for("crab").has("label_off"), "the crab can be told to stay")
	_check(Florida.unlock_line("gull", "lines_none") != "", "the gull has a nothing-yet line")

	# Giving: nothing in the inventory, nothing to give; a gift uses one up
	var sunny := "dolphin_sunny"
	_check(Florida.give(sunny, "dolphin", "mango_smoothie", today).is_empty(), "no gift without one in the inventory")
	_check(Florida.give(sunny, "dolphin", "flower_crown", today).is_empty(), "a worn piece is not a gift")
	Florida.add_item("flower_crown")
	_check(Florida.give(sunny, "dolphin", "flower_crown", today).is_empty() and Florida.count("flower_crown") == 1, "...even with one in the inventory")
	for item: String in Florida.gift_items():
		Florida.add_item(item, 10)
	_check(Florida.give(sunny, "shark", "mango_smoothie", today).is_empty(), "only the kinds in the data")
	var r := Florida.give(sunny, "dolphin", "mango_smoothie", today)
	_check(not r.is_empty() and Florida.count("mango_smoothie") == 9, "a gift uses one up")
	_check(r.get("reaction") == "loved" and r.get("gained") == 2 and Florida.hearts(sunny) == 2, "a favourite earns 2 hearts")
	_check(String(r.get("line", "")) != "" and not String(r["line"]).contains("{item}"), "the reaction line fills in the gift (%s)" % r.get("line"))
	_check(r.get("effect") == "flip" and r.get("unlocked") == false, "the dolphin flips for it; no unlock yet")
	var again := Florida.give(sunny, "dolphin", "mango_smoothie", today)
	_check(again.get("gained") == 0 and Florida.hearts(sunny) == 2 and String(again.get("line", "")) != "", "a second gift the same day: no hearts, still a happy line")
	_check(Florida.count("mango_smoothie") == 8, "...and still taken")
	var liked := Florida.give(sunny, "dolphin", "key_lime_pie", today + 1)
	_check(liked.get("reaction") == "liked" and liked.get("gained") == 1 and Florida.hearts(sunny) == 3, "any other gift earns 1 heart")
	_check(liked.get("unlocked") == true and Florida.has_unlock(sunny, "dolphin"), "3 hearts: the dolphin's trick unlocks")
	var more := Florida.give(sunny, "dolphin", "shell_wind_chime", today + 2)
	_check(more.get("hearts") == 5 and more.get("unlocked") == false, "the unlock comes only once")
	var maxed := Florida.give(sunny, "dolphin", "shell_wind_chime", today + 3)
	_check(maxed.get("gained") == 0 and Florida.hearts(sunny) == Florida.max_hearts(), "hearts stop at the max")
	_check(maxed.get("line") in Florida.gift_kind("dolphin")["lines"]["max"], "a best friend says a 'max' line")
	_check(Florida.gift_float(r) == "+2 hearts" and Florida.gift_float(liked) == Florida.gifts()["floats"]["unlocked"], "the float texts come from the data")
	_check(Florida.gift_float(again) == "" and Florida.gift_float({"gained": 1}) == "+1 heart", "...no float without hearts; one heart")

	# hearts_per_day is read: at 2, two gifts a day earn hearts
	var per_day: int = Florida.gifts()["hearts_per_day"]
	Florida.gifts()["hearts_per_day"] = 2
	var coral := "mermaid_test_coral"
	var g1 := int(Florida.give(coral, "mermaid", "key_lime_pie", today).get("gained"))
	var g2 := int(Florida.give(coral, "mermaid", "key_lime_pie", today).get("gained"))
	var g3 := int(Florida.give(coral, "mermaid", "key_lime_pie", today).get("gained"))
	var g4 := int(Florida.give(coral, "mermaid", "key_lime_pie", today + 1).get("gained"))
	_check([g1, g2, g3, g4] == [1, 1, 0, 1], "hearts_per_day 2: two heart-earning gifts a day (%s)" % [[g1, g2, g3, g4]])
	Florida.gifts()["hearts_per_day"] = per_day
	var hearts_all: Dictionary = ws.get_flag("fl_hearts").duplicate()
	hearts_all.erase(coral)
	ws.set_flag("fl_hearts", hearts_all)
	for item: String in Florida.gift_items():
		Florida.add_item(item, 10 - Florida.count(item))

	# Hearts are per friend
	var sidestep := "crab_sidestep"
	var clementine := "crab_clementine"
	_check(not Florida.has_unlock(sidestep, "crab"), "no unlock before the hearts")
	Florida.give(sidestep, "crab", "sea_grape_jelly", today)
	var cr := Florida.give(sidestep, "crab", "guava_pastry", today + 1)
	_check(Florida.hearts(sidestep) == 3 and cr.get("unlocked") == true and Florida.has_unlock(sidestep, "crab"), "Sidestep: 2 + 1 hearts, walks with you")
	_check(Florida.hearts(clementine) == 0 and not Florida.has_unlock(clementine, "crab"), "Clementine has her own hearts")

	# The gull brings one shell a day
	var biscuit := "gull_biscuit"
	_check(not Florida.gull_shell(biscuit, today), "no shell from a gull that isn't a good friend yet")
	Florida.give(biscuit, "gull", "key_lime_pie", today)
	Florida.give(biscuit, "gull", "guava_pastry", today + 1)
	var shells := Florida.count("shell")
	_check(Florida.gull_shell(biscuit, today + 1) and Florida.count("shell") == shells + 1, "a good-friend gull brings a shell")
	_check(not Florida.gull_shell(biscuit, today + 1) and Florida.count("shell") == shells + 1, "...one a day")
	_check(Florida.gull_shell(biscuit, today + 2) and Florida.count("shell") == shells + 2, "...and another the next day")

	# The crab's follow flag
	_check(Florida.following() == "", "nobody follows at first")
	Florida.set_following(sidestep)
	_check(Florida.following() == sidestep, "set_following / following round-trip")

	# Save/load
	var hearts_before: Dictionary = ws.get_flag("fl_hearts").duplicate(true)
	ws.flags = {}
	ws.load_save()
	_check(Florida.hearts(sunny) == 5 and Florida.hearts(sidestep) == 3 and Florida.hearts(biscuit) == 4, "hearts survive save/load")
	_check(ws.get_flag("fl_hearts").size() == hearts_before.size(), "...for every friend")
	_check(Florida.following() == sidestep and not Florida.gull_shell(biscuit, today + 2), "the follow and the gull's day survive save/load")
	_check(Florida.give(sidestep, "crab", "sea_grape_jelly", today + 1).get("gained") == 0 and Florida.hearts(sidestep) == 3, "the gift day survives save/load")
	Florida.set_following("")

	# The critter's gift panel: no gifts and no unlock, a surprise as before
	var inv: Dictionary = ws.get_flag("fl_inventory").duplicate()
	ws.set_flag("fl_inventory", {})
	var pearl: Area2D = load("res://scenes/florida/critter.tscn").instantiate()
	pearl.kind = "dolphin"
	pearl.nickname = "dolphin_pearl"
	root.add_child(pearl)
	await process_frame
	pearl.interact()
	await process_frame
	_check(pearl.get_node_or_null("GiftPanel") == null, "nothing to give and no unlock: a click is a surprise, as before")
	ws.set_flag("fl_inventory", inv)

	# ...with a gift: the panel, a Give button per gift, Say hi and Close
	pearl.interact()
	await process_frame
	var panel: Node = pearl.get_node_or_null("GiftPanel")
	_check(panel is CanvasLayer and panel.layer == 15, "a gift in the inventory: clicking opens the gift panel")
	var box: Node = panel.get_node_or_null("Panel/Buttons") if panel else null
	_check(box != null and box.get_node_or_null("SayHi") is Button and box.get_node_or_null("Close") is Button, "the panel has Say hi and Close")
	for item: String in Florida.giftable_in_inventory():
		_check(box != null and box.get_node_or_null("Give_%s" % item) is Button, "a Give button for %s" % item)
	_check(box != null and box.get_node_or_null("Unlock") == null, "no unlock button before the hearts")
	_check(box != null and String(box.get_node("Hearts/Count").text).contains("0 / %d" % Florida.max_hearts()), "the panel shows the friendship")
	var view_h := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var panel_h: float = panel.get_node("Panel").get_combined_minimum_size().y if panel else 0.0
	_check(panel_h <= view_h, "the gift panel fits the view (%d <= %d px)" % [panel_h, view_h])
	var smoothies := Florida.count("mango_smoothie")
	var give_button: Button = box.get_node_or_null("Give_mango_smoothie") if box else null
	if give_button:
		give_button.pressed.emit()
	await process_frame
	await process_frame
	_check(Florida.hearts("dolphin_pearl") == 2 and Florida.count("mango_smoothie") == smoothies - 1, "pressing Give gives it: Pearl has 2 hearts")
	box = pearl.get_node_or_null("GiftPanel/Panel/Buttons")
	_check(box != null and String(box.get_node("Hearts/Count").text).contains("2 / "), "the panel rebuilds with the new hearts")
	_check(box != null and String(box.get_node("Give_mango_smoothie").text).contains("(%d)" % (smoothies - 1)), "...and the new count")
	Florida.give("dolphin_pearl", "dolphin", "key_lime_pie", today + 1)
	if box:
		box.get_node("Close").pressed.emit()
	await process_frame
	_check(pearl.get_node_or_null("GiftPanel") == null, "Close closes the panel")

	# ...and with the unlock but nothing to give, the panel still opens for it
	ws.set_flag("fl_inventory", {})
	pearl.interact()
	await process_frame
	var trick: Node = pearl.get_node_or_null("GiftPanel/Panel/Buttons/Unlock")
	_check(trick is Button and trick.text == Florida.unlock_for("dolphin")["label"], "a good friend with nothing to give: the trick button")
	_check(pearl.get_node_or_null("GiftPanel/Panel/Buttons/Give_mango_smoothie") == null, "...and no Give buttons")
	if trick:
		trick.pressed.emit()
	await process_frame
	var trick_lines: Array = Florida.unlock_for("dolphin")["lines"]
	_check(trick_lines.any(func(t: String) -> bool: return String(pearl.bubble.text).ends_with(t)), "the trick says a trick line (%s)" % pearl.bubble.text)
	pearl.queue_free()
	await process_frame

	# The crab walks with you and stays when asked; the gull brings a shell from the panel
	var crab: Area2D = load("res://scenes/florida/critter.tscn").instantiate()
	crab.kind = "crab"
	crab.nickname = sidestep
	root.add_child(crab)
	await process_frame
	crab.interact()
	await process_frame
	var walk: Node = crab.get_node_or_null("GiftPanel/Panel/Buttons/Unlock")
	_check(walk is Button and walk.text == Florida.unlock_for("crab")["label"], "Sidestep: Walk with me")
	if walk:
		walk.pressed.emit()
	await process_frame
	await process_frame
	_check(Florida.following() == sidestep, "...and Sidestep follows")
	var stay: Node = crab.get_node_or_null("GiftPanel/Panel/Buttons/Unlock")
	_check(stay is Button and stay.text == Florida.unlock_for("crab")["label_off"], "...then Stay here")
	if stay:
		stay.pressed.emit()
	await process_frame
	_check(Florida.following() == "", "...and Sidestep stays")
	crab.queue_free()
	await process_frame

	var gull: Area2D = load("res://scenes/florida/critter.tscn").instantiate()
	gull.kind = "gull"
	gull.nickname = biscuit
	root.add_child(gull)
	await process_frame
	gull.interact()
	await process_frame
	var found: Node = gull.get_node_or_null("GiftPanel/Panel/Buttons/Unlock")
	_check(found is Button, "Biscuit: Found anything?")
	clock.day = today + 5
	shells = Florida.count("shell")
	if found:
		found.pressed.emit()
	await process_frame
	await process_frame
	_check(Florida.count("shell") == shells + 1, "the gull's button brings a shell")
	found = gull.get_node_or_null("GiftPanel/Panel/Buttons/Unlock")
	if found:
		found.pressed.emit()
	await process_frame
	_check(Florida.count("shell") == shells + 1, "...one a day")
	clock.day = today
	gull.queue_free()
	await process_frame

	# The stable panel: Give buttons for the pony, then Nuzzle
	ws.set_flag("fl_inventory", inv)
	var pony_id: String = Ponies.ids()[0]
	var stable_panel: CanvasLayer = load("res://scripts/florida/stable_panel.gd").new()
	stable_panel.pony_id = pony_id
	var said: Array = []
	stable_panel.spoke.connect(func(text: String) -> void: said.append(text))
	var cheers: Array = []
	stable_panel.cheered.connect(func(text: String) -> void: cheers.append(text))
	root.add_child(stable_panel)
	await process_frame
	var pony_give: Node = stable_panel.get_node_or_null("Panel/HBox/Side/Friends/Gifts/List/Give_guava_pastry")
	_check(pony_give is Button, "the stable panel has a Give button per gift")
	_check(stable_panel.get_node_or_null("Panel/HBox/Side/Friends/Nuzzle") == null, "no Nuzzle before the hearts")
	var stable_h: float = stable_panel.get_node("Panel").get_combined_minimum_size().y
	_check(stable_h <= view_h, "the stable panel with gifts fits the view (%d <= %d px)" % [stable_h, view_h])
	if pony_give:
		pony_give.pressed.emit()
	await process_frame
	await process_frame
	_check(Florida.hearts(pony_id) == 2 and said.size() == 1 and said[0] != "", "Give: the pony loves it and says so")
	_check(cheers == ["+2 hearts"], "...with a hearts float (%s)" % [cheers])
	var pony_more: Node = stable_panel.get_node_or_null("Panel/HBox/Side/Friends/Gifts/List/Give_mango_smoothie")
	clock.day = today + 1
	if pony_more:
		pony_more.pressed.emit()
	await process_frame
	await process_frame
	clock.day = today
	_check(cheers.size() == 2 and cheers[1] == Florida.gifts()["floats"]["unlocked"], "3 hearts: the unlock's float for the pony too")
	said.clear()
	stable_panel._build()
	var nuzzle: Node = stable_panel.get_node_or_null("Panel/HBox/Side/Friends/Nuzzle")
	_check(nuzzle is Button, "3 hearts: a Nuzzle button")
	if nuzzle:
		nuzzle.pressed.emit()
	_check(said.size() == 1 and said[0] in Florida.unlock_for("pony")["lines"], "Nuzzle: a nuzzle line")
	_check(String(stable_panel.get_node("Panel/HBox/Side/Friends/Friendship").text).contains("3 / "), "the stable panel shows the friendship")
	stable_panel.queue_free()
	await process_frame

	# One gift panel at a time; a following crab is let go on a new visit; E passes over it
	var map := Node2D.new()
	map.name = "Map"
	root.add_child(map)
	current_scene = map
	Florida.set_following(sidestep)
	var walker: Area2D = load("res://scenes/florida/critter.tscn").instantiate()
	walker.kind = "crab"
	walker.nickname = sidestep
	map.add_child(walker)
	await process_frame
	_check(Florida.following() == "", "a crab met again on a new visit is back on its own patch (fl_following cleared)")
	var player: Node2D = load("res://scenes/player/player.tscn").instantiate()
	map.add_child(player)
	var pal: Area2D = load("res://scenes/florida/critter.tscn").instantiate()
	pal.kind = "dolphin"
	pal.nickname = sunny
	map.add_child(pal)
	await process_frame
	player.global_position = Vector2(200, 200)
	walker.global_position = player.global_position + Vector2(20, 4)
	pal.global_position = player.global_position + Vector2(-44, 0)
	walker.interact()
	await process_frame
	_check(walker.get_node_or_null("GiftPanel") != null, "the crab's gift panel opens")
	pal.interact()
	await process_frame
	_check(walker.get_node_or_null("GiftPanel") == null and pal.get_node_or_null("GiftPanel") != null, "opening Sunny's panel closes Sidestep's: one at a time")
	pal._close()
	var walk_with: Node = null
	walker.interact()
	await process_frame
	walk_with = walker.get_node_or_null("GiftPanel/Panel/Buttons/Unlock")
	if walk_with:
		walk_with.pressed.emit()
	await process_frame
	walker._close()
	await process_frame
	_check(Florida.following() == sidestep and walker.is_companion() and not pal.is_companion(), "Sidestep walks with you: a companion")
	var picked: Node = player.interact_nearest()
	_check(picked == pal, "E passes over the companion crab for Sunny, farther off (%s)" % [picked.name if picked else "nothing"])
	pal.global_position = player.global_position + Vector2(400, 0)
	picked = player.interact_nearest()
	_check(picked == walker, "...and picks the crab when nothing else is near (%s)" % [picked.name if picked else "nothing"])
	player.set("_interact_target", null)
	player.nav.target_position = player.global_position
	Florida.set_following("")

	# A quick second line keeps its bubble the full time
	walker._speak("one")
	await create_timer(2.0).timeout
	walker._speak("two")
	await create_timer(1.5).timeout
	_check(walker.bubble.visible and String(walker.bubble.text).ends_with("two"), "a line said 2 s after another is not hidden by the first one's timer")
	current_scene = null
	map.queue_free()
	await process_frame

	for suffix in ["", ".bak"]:  # the save keeps a backup of the previous write (GC-07)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE + suffix))
	ws.SAVE_PATH = real_save
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
