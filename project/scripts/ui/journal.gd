extends CanvasLayer
## Journal — the player's Forbidden Knowledge: every tactic named in a Name It beat, with the
## lines where it was found; every piece recovered in the ruins; and the cruise flashbacks the
## pieces unlock (data/flashbacks.json). An unlocked flashback can be played from here; a
## locked one lists the pieces still missing. J toggles it (map.gd).

const ForbiddenKnowledge := preload("res://scripts/ruins/forbidden_knowledge.gd")
const Flashbacks := preload("res://scripts/chapters/flashbacks.gd")


func _ready() -> void:
	layer = 15
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_label(box, "Journal — Forbidden Knowledge")

	_label(box, "Named")
	var journal: Dictionary = WorldState.get_flag("journal", {})
	if journal.is_empty():
		_label(box, "    (nothing named yet)")
	for tactic: String in journal:
		_label(box, "%s\n    %s" % [tactic, "\n    ".join(journal[tactic].map(func(q: String) -> String: return "\"%s\"" % q))])

	_label(box, "Recovered")
	var found := recovered()
	if found.is_empty():
		_label(box, "    (nothing recovered yet)")
	for title: String in found:
		_label(box, "    " + title)

	_label(box, "Before the Wreck")
	for e: Dictionary in entries():
		if e["unlocked"]:
			_label(box, "%s%s\n    %s" % [e["title"], "  (remembered)" if e["seen"] else "", e["why"]])
			var play_button := Button.new()
			play_button.name = "Play_%s" % e["id"]
			play_button.text = "Remember: %s" % e["title"]
			play_button.pressed.connect(play.bind(e["id"]))
			box.add_child(play_button)
		else:
			_label(box, "%s  (locked)\n    Missing: %s" % [e["title"], ", ".join(e["missing"])])


## Titles of the recovered pieces, in recovery order.
func recovered() -> Array:
	var pieces := ForbiddenKnowledge.pieces()
	return ForbiddenKnowledge.all().filter(func(id: String) -> bool: return pieces.has(id)).map(
		func(id: String) -> String: return ForbiddenKnowledge.fill(pieces[id].get("title", id)))


## One entry per flashback, in story order: {id, title, why, unlocked, seen, missing}.
## `missing` names each missing piece and the ruins room it lies in.
func entries() -> Array:
	var pieces := ForbiddenKnowledge.pieces()
	var rooms: Dictionary = ForbiddenKnowledge.data().get("rooms", {})
	var out := []
	for f: Dictionary in Flashbacks.all():
		var id: String = f["id"]
		var missing := []
		for piece_id: String in Flashbacks.missing(id):
			var piece: Dictionary = pieces.get(piece_id, {})
			var room: String = rooms.get(piece.get("room", ""), {}).get("title", "")
			var title := ForbiddenKnowledge.fill(piece.get("title", piece_id))
			missing.append(title if room == "" else "%s (%s)" % [title, room])
		out.append({
			"id": id,
			"title": f.get("title", id),
			"why": f.get("why", ""),
			"unlocked": Flashbacks.is_unlocked(id),
			"seen": Flashbacks.seen(id),
			"missing": missing,
		})
	return out


## Plays an unlocked flashback: the character is swapped out, then its intro card.
func play(id: String) -> void:
	var here := get_tree().current_scene
	var origin := here.scene_file_path if here else ""
	if Flashbacks.enter(id, origin, Flashbacks.nearest_spawn(here)).is_empty():
		return
	get_tree().call_deferred("change_scene_to_file", Flashbacks.CARD_SCENE)


func _label(box: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(360, 0)
	box.add_child(label)
