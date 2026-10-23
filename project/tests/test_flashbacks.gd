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
const COMIC := "res://scenes/minigames/next_top_comic.tscn"

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
	_check(list[0]["id"] == "landing", "The Landing comes first (story order is its prologue treatment for now)")
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

	# Next Top Comic has a set: Silverman's setups are her own lines, the punchlines are signs.
	var comic_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/next_top_comic.json"))
	var said: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/quotes/silverman.json"))["quotes"].map(func(q: Dictionary) -> String: return q["text"])
	var signs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/empowerment_lines.json"))["lines"].map(func(q: Dictionary) -> String: return q["text"])
	var setups: Array = comic_data.get("setups", [])
	_check(setups.size() >= 3, "Next Top Comic ships a set (%d setups)" % setups.size())
	_check(setups.all(func(x: Dictionary) -> bool: return said.has(x["setup"])), "every setup is one of Silverman's own lines")
	var signs_ok := true
	for x: Dictionary in setups:
		var pls: Array = x["punchlines"]
		signs_ok = signs_ok and pls.size() >= 2 and pls.size() <= 8 and pls.all(func(pl: String) -> bool: return signs.has(pl))
	_check(signs_ok, "every punchline is a verbatim sign, 2-8 per setup")
	var set_game: Control = load(COMIC).instantiate()
	set_game.autostart = false
	root.add_child(set_game)
	await process_frame
	set_game.begin_set()
	var beats := 0
	while not set_game.set_done() and beats < 100:
		_check(set_game.current_setup() != "" and set_game.has_punchline(0), "setup %d has a line and a punchline" % beats)
		set_game.pick(0)
		set_game.next_setup()
		beats += 1
	_check(beats == setups.size() and set_game.picks.size() == beats, "the set plays every setup through")
	set_game.free()

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
	ws.set_flag("hottest_prep_outfit", {"hair": "island"})
	var marker := {"outfit_hair": "marker"}
	ws.set_flag("chapter_archive_island", marker.duplicate())
	var entry: Dictionary = fb.enter("landing", WRECK)
	_check(entry.get("scene") == LANDING, "Landing enters its mini-game")
	_check(chapters.current() == "cruise", "flashback plays in the cruise chapter")
	_check(not ws.flags.has("outfit_hair") and not ws.flags.has("player_name"), "island character cleared")
	_check(ws.get_flag("flashback_archive", {}).get("outfit_hair") == "hair_rose", "island character archived")
	_check(not ws.flags.has("hottest_prep_outfit") and ws.get_flag("flashback_archive", {}).has("hottest_prep_outfit"),
		"episode-owned character flags archived too")
	_check(ws.has_flag("questioned_ritual"), "story flags stay")
	_check(ws.get_flag("_location", {}).get("scene") == fb.CARD_SCENE, "Continue resumes at the intro card first")
	_check(ws.get_flag("chapter_archive_island") == marker, "the island chapter-end archive is untouched by entering")
	_check(fb.enter("landing", WRECK).is_empty(), "no flashback inside a flashback")

	var card: Control = load(fb.CARD_SCENE).instantiate()
	card.seconds = 600.0
	root.add_child(card)
	await process_frame
	_check(card.find_child("Heading", true, false).text == fb.card("landing")["heading"] and card.entry.get("scene") == LANDING,
		"intro card shows the Landing and goes on to it")
	card.go_on()
	_check(ws.get_flag("_location", {}).get("scene") == LANDING, "after the card, Continue resumes inside the flashback")
	card.queue_free()
	var landing: Control = await _scene_now(LANDING)
	_check(landing != null, "the card goes on to the Landing")

	# Return: the episode's last mini-game goes back where the flashback started.
	if landing:
		_check(landing.return_target().get("scene") == WRECK, "Landing returns to where the flashback started")
	# The other episodes' last mini-games (the show after the chains; the comic set) route the same way.
	for path: String in ["res://scenes/minigames/hottest_of_the_hot.tscn", COMIC]:
		var g: Control = load(path).instantiate()
		_check(g.return_target().get("scene") == WRECK, "%s returns to where the flashback started" % path.get_file())
		g.free()
	_check(load("res://data/hottest_chains.json").data.get("show_scene", "").ends_with("hottest_of_the_hot.tscn"),
		"Hottest of the HOT chains lead into the show")
	ws.set_flag("outfit_hair", "hair_cruise")
	ws.set_flag("hottest_prep_outfit", {"hair": "cruise"})
	if landing:
		landing.go_back()  # the real OK path
	var wreck: Node = await _scene_now(WRECK)
	_check(wreck != null, "Landing's OK goes back to the origin")
	_check(chapters.current() == "island", "chapter restored")
	_check(ws.get_flag("outfit_hair") == "hair_rose" and ws.get_flag("player_name") == "island self", "island character restored")
	_check(ws.get_flag("hottest_prep_outfit") == {"hair": "island"}, "the passenger's makeover doesn't leak onto the island character")
	_check(fb.active().is_empty() and not ws.flags.has("flashback_archive"), "flashback cleared")
	_check(fb.seen("landing"), "flashback marked remembered")
	_check(ws.get_flag("chapter_archive_island") == marker, "the island chapter-end archive is untouched by leaving")
	_check(ws.get_flag("_location", {}).get("scene") == WRECK, "Continue resumes at the origin")

	# The journal starts a flashback from where the player stands.
	if wreck:
		var player: Node2D = get_first_node_in_group("player")
		var far: Node2D = wreck.find_child("spawn_from_corridor", true, false)
		if player and far:
			player.global_position = far.global_position
		_check(fb.nearest_spawn(wreck) == "spawn_from_corridor", "the origin is the spawn nearest the player")
		var j: CanvasLayer = load("res://scripts/ui/journal.gd").new()
		wreck.add_child(j)
		await process_frame
		j.play("landing")
		_check(fb.active().get("id") == "landing", "journal play starts the flashback")
		_check(fb.active().get("origin", {}) == {"scene": WRECK, "spawn": "spawn_from_corridor"}, "journal play records where the player stood")
		_check(ws.get_flag("_location", {}).get("scene") == fb.CARD_SCENE, "journal play goes to the intro card")
		var opened: Control = await _scene_now(fb.CARD_SCENE)
		_check(opened != null and opened.id == "landing", "the intro card opens for the Landing")
		if opened:
			opened.seconds = 600.0
			opened._left = true

	# The comic's real exit (dialogue ended) also leaves the flashback.
	fb.leave(VILLAGE)
	for piece_id: String in fb.flashback("next_top_comic")["requires"]:
		fk.recover(piece_id)
	_check(not fb.enter("next_top_comic", VILLAGE).is_empty(), "Next Top Comic enters once its pieces are found")
	_check(not ws.flags.has("outfit_hair"), "comic flashback has a fresh character")
	var comic: Control = load(COMIC).instantiate()
	comic.autostart = false
	root.add_child(comic)
	await process_frame
	comic._on_dialogue_ended(null)
	_check(fb.active().is_empty() and ws.get_flag("outfit_hair") == "hair_rose", "the end of the set leaves the flashback and restores the character")
	_check(chapters.current() == "island" and ws.get_flag("_location", {}).get("scene") == VILLAGE, "the set goes back where it started")
	comic.queue_free()
	await _scene_now(VILLAGE)

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


## Waits for a deferred scene change to `path` and returns the new current scene (or null).
func _scene_now(path: String) -> Node:
	for i in 10:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			return current_scene
	return null


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
	print(("PASS " if ok else "FAIL ") + what)
