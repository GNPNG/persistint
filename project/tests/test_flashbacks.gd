extends SceneTree
## Cruise flashbacks: each is locked until its Forbidden Knowledge pieces are recovered, opens on
## pickup, enters its cruise mini-game through the chapter system with a fresh character, comes
## back to where it was started with the island character restored, and the journal lists it all.
## Run: godot --headless --path project -s tests/test_flashbacks.gd
## The player's real save (user://save.json) is backed up and restored.

const LANDING := "res://scenes/minigames/landing.tscn"
const WRECK := "res://scenes/ruins/ruins_wreck.tscn"
const VILLAGE := "res://scenes/maps/village.tscn"
const PICKUP := "res://scenes/ruins/knowledge_pickup.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	var had_save := FileAccess.file_exists(ws.SAVE_PATH)
	var backup := FileAccess.get_file_as_string(ws.SAVE_PATH) if had_save else ""
	ws.reset()
	var fb: Script = load("res://scripts/chapters/flashbacks.gd")
	var fk: Script = load("res://scripts/ruins/forbidden_knowledge.gd")
	var chapters: Script = load("res://scripts/chapters/chapters.gd")

	# The data.
	var list: Array = fb.all()
	_check(list.size() >= 3, "flashbacks defined (%d)" % list.size())
	_check(list[0]["id"] == "landing" and list[0].get("prologue") == true, "The Landing comes first and is prologue-capable")
	var pieces: Dictionary = fk.pieces()
	var banned := ["layer", "idyll", "guardrail", "gilead", "handmaid", "animalese"]
	for f: Dictionary in list:
		var id: String = f["id"]
		_check(ResourceLoader.exists(f["entry_scene"]), "%s entry scene exists" % id)
		_check(not f["requires"].is_empty() and f["requires"].all(func(p: String) -> bool: return pieces.has(p)),
			"%s requires known Forbidden Knowledge pieces" % id)
		var card: Dictionary = fb.card(id)
		var text: String = (card["heading"] + " " + " ".join(card["lines"]) + " " + f.get("why", "")).to_lower()
		_check(card["heading"] != "" and card["lines"].size() > 0 and card.get("prompt", "") != "", "%s has an intro card" % id)
		_check(not text.contains("{"), "%s card names are filled from the cast" % id)
		_check(banned.all(func(w: String) -> bool: return not text.contains(w)), "%s card avoids banned words" % id)
	_check(" ".join(fb.card("landing")["lines"]).contains(root.get_node("/root/Cast").full("kate")), "Landing card names the captain via Cast")
	_check(not list.any(func(f: Dictionary) -> bool: return f["entry_scene"].ends_with("interview.tscn")),
		"the Interview stays the cruise chapter's own entry")

	# Locked until the pieces are found.
	_check(fb.unlocked().is_empty(), "a fresh game has every flashback locked")
	_check(list.all(func(f: Dictionary) -> bool: return fb.missing(f["id"]) == f["requires"]), "each lists all its pieces as missing")
	var needs: Array = fb.flashback("landing")["requires"]
	for i in needs.size() - 1:
		fk.recover(needs[i])
	_check(not fb.is_unlocked("landing"), "Landing still locked with a piece missing")
	_check(fb.missing("landing") == [needs[-1]], "Landing names the one piece still missing")
	_check(fb.enter("landing", WRECK).is_empty(), "a locked flashback cannot be entered")

	# Unlock on pickup.
	var pickup: Node = load(PICKUP).instantiate()
	pickup.piece_id = needs[-1]
	root.add_child(pickup)
	await process_frame
	pickup.interact()
	_check(fk.has(needs[-1]), "pickup recovers the piece")
	_check(fb.is_unlocked("landing") and fb.unlocked() == ["landing"], "pickup unlocks the Landing (and only it)")
	_check(pickup.get_node("Label").text.contains(fb.flashback("landing")["title"]), "pickup says the flashback opened")
	pickup.queue_free()

	# The journal lists found pieces and both states.
	var journal: CanvasLayer = load("res://scripts/ui/journal.gd").new()
	root.add_child(journal)
	await process_frame
	var rec: Array = journal.recovered()
	_check(rec.size() == needs.size() and rec.has(fk.fill(pieces[needs[-1]]["title"])), "journal lists recovered pieces")
	var entries: Array = journal.entries()
	_check(entries.size() == list.size() and entries[0]["id"] == "landing" and entries[0]["unlocked"], "journal shows the Landing unlocked")
	var locked: Dictionary = entries[1]
	var first_missing: Dictionary = pieces[fb.flashback(locked["id"])["requires"][0]]
	_check(not locked["unlocked"] and locked["missing"].size() == fb.flashback(locked["id"])["requires"].size()
		and locked["missing"][0].contains(fk.fill(first_missing["title"])), "journal shows what a locked flashback is missing")
	_check(journal.find_child("Play_landing", true, false) is Button, "journal can play the unlocked Landing")
	_check(journal.find_child("Play_%s" % locked["id"], true, false) == null, "journal cannot play a locked one")
	journal.free()

	# Enter: the island character doesn't carry over.
	ws.set_flag("outfit_hair", "hair_rose")
	ws.set_flag("player_name", "island self")
	ws.set_flag("questioned_ritual", true)
	var entry: Dictionary = fb.enter("landing", WRECK)
	_check(entry.get("scene") == LANDING, "Landing enters its mini-game")
	_check(chapters.current() == "cruise", "flashback plays in the cruise chapter")
	_check(not ws.flags.has("outfit_hair") and not ws.flags.has("player_name"), "island character cleared")
	_check(ws.get_flag("flashback_archive", {}).get("outfit_hair") == "hair_rose", "island character archived")
	_check(ws.has_flag("questioned_ritual"), "story flags stay")
	_check(ws.get_flag("_location", {}).get("scene") == LANDING, "Continue resumes inside the flashback")
	_check(ws.get_flag("chapter_archive_island") == null, "the island chapter-end archive is untouched")
	_check(fb.enter("landing", WRECK).is_empty(), "no flashback inside a flashback")

	var card: Control = load(fb.CARD_SCENE).instantiate()
	card.seconds = 600.0
	root.add_child(card)
	await process_frame
	_check(card.find_child("Heading", true, false).text == fb.card("landing")["heading"] and card.entry.get("scene") == LANDING,
		"intro card shows the Landing and goes on to it")
	card.free()

	# Return: the episode's last mini-game goes back where the flashback started.
	var landing: Control = load(LANDING).instantiate()
	root.add_child(landing)
	await process_frame
	_check(landing.return_target().get("scene") == WRECK, "Landing returns to where the flashback started")
	landing.free()
	# The other episodes' last mini-games (the show after the chains; the comic set) route the same way.
	for path: String in ["res://scenes/minigames/hottest_of_the_hot.tscn", "res://scenes/minigames/next_top_comic.tscn"]:
		var g: Control = load(path).instantiate()
		_check(g.return_target().get("scene") == WRECK, "%s returns to where the flashback started" % path.get_file())
		g.free()
	_check(load("res://data/hottest_chains.json").data.get("show_scene", "").ends_with("hottest_of_the_hot.tscn"),
		"Hottest of the HOT chains lead into the show")
	ws.set_flag("outfit_hair", "hair_cruise")
	var back: Dictionary = fb.leave(VILLAGE)
	_check(back.get("scene") == WRECK, "leave goes back to the origin")
	_check(chapters.current() == "island", "chapter restored")
	_check(ws.get_flag("outfit_hair") == "hair_rose" and ws.get_flag("player_name") == "island self", "island character restored")
	_check(fb.active().is_empty() and not ws.flags.has("flashback_archive"), "flashback cleared")
	_check(fb.seen("landing"), "flashback marked remembered")
	_check(ws.get_flag("_location", {}).get("scene") == WRECK, "Continue resumes at the origin")

	# Outside a flashback the mini-games keep their own return maps.
	var lg: Control = load(LANDING).instantiate()
	root.add_child(lg)
	await process_frame
	_check(lg.return_target().get("scene") == VILLAGE, "Landing outside a flashback returns to its return_map")
	lg.free()
	_check(chapters.jump("cruise").is_empty(), "the cruise still has no next chapter")

	if had_save:
		var f := FileAccess.open(ws.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
		ws.load_save()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ws.SAVE_PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
	print(("PASS " if ok else "FAIL ") + what)
