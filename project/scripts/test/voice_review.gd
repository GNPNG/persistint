extends Control
## Voice review (beads persistint-game-rxu; the author, 2026-10-24: "a separate build where it's a
## game, but it's all only just the character standing there and like I click them or whatever and
## they make their like phrases and I'll give you like a score"). Every voiced character stands in a
## row; tap one and it says its next line through Voice (its own clip, its normal bus, the usual
## bubble over its head); rate the line and the voice 1 to 10, add a note, and Save hands back a
## JSON file that tools/ingest_voice_ratings.py merges into dev/voice-ratings/ to decide which
## characters need better source material for re-cloning.
## Opens from the normal export with ?scene=voice_review (DevScene); nothing runs per frame here.

const SheetRig := preload("res://scripts/ruins/sheet_rig.gd")

const MANIFEST := "res://audio/voice/manifest.json"
const CAST_PATH := "res://data/cast.json"
const SAVE_PATH := "user://voice_ratings.json"
const BUBBLE := "res://scenes/ui/bark_bubble.tscn"
## Clones speak their original's quotes keyed by cast id (tools/export_voice_lines.py) and play
## through the Clones bus (scripts/ruins/zombie_child.gd).
const CLONE_IDS := ["epstein", "bill_clinton", "hillary_clinton", "bill_gates"]
## Cruise-show hosts are generic stand-in figures with a nameplate (scripts/minigames/stage_figure.gd).
const STAGE_ART := {"chelsea": "host_emcee", "tyra": "host_runway", "oprah": "host_talk", "silverman": "host_comic"}
const STAND_IN := "res://assets/ui/stage/host_emcee.png"
const CARD_SIZE := Vector2(74, 98)
const FEET_Y := 64.0

## {speaker, id, name, bus, art: {kind, path}, lines: [{text, key, clip, has_clip}]} per voiced character.
var roster: Array = []
## clip key -> {speaker, clip, text, rating, note}
var ratings: Dictionary = {}
## speaker -> 1..10
var overall: Dictionary = {}
## Tests turn this off so they never touch the player's saved ratings.
var persist := true

var _next: Dictionary = {}  # speaker -> index of the next line to say
var _selected := ""
var _current_key := ""
var _cards: Dictionary = {}  # speaker -> Button
var _bubbles: Dictionary = {}  # speaker -> BarkBubble
var _badges: Dictionary = {}  # speaker -> Label (overall rating)
var _line_label: Label
var _clip_label: Label
var _note: LineEdit
var _status: Label
var _json_box: TextEdit
var _line_group := ButtonGroup.new()
var _voice_group := ButtonGroup.new()
var _line_buttons: Array = []
var _voice_buttons: Array = []
var _row: HBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	roster = build_roster()
	if persist:
		_load_local()
	_build_ui()


# ---------------------------------------------------------------- roster

## Every speaker in the clip manifest with its lines, in manifest order, the ones with clips first.
static func build_roster() -> Array:
	var cast: Dictionary = _json(CAST_PATH)
	var by_name := {}
	for id: String in cast:
		if not id.begins_with("_") and cast[id] is Dictionary:
			by_name[str(cast[id].get("name", ""))] = id
	var order: Array = []
	var entries := {}
	for e: Variant in _json_array(MANIFEST):
		if not e is Dictionary:
			continue
		var speaker := str(e.get("speaker", ""))
		if not entries.has(speaker):
			var id: String = speaker if cast.has(speaker) else str(by_name.get(speaker, ""))
			if id == "":
				# Villagers named on their map node rather than in cast.json (Father, Daughter).
				var guess := speaker.to_lower().replace(" ", "_")
				if art_for(guess)["kind"] != "stand_in":
					id = guess
			var is_clone := id in CLONE_IDS
			var name := speaker
			if cast.has(id):
				name = str(cast[id].get("name", speaker))
			entries[speaker] = {"speaker": speaker, "id": id, "name": name + (" (clone)" if is_clone else ""),
				"bus": "Clones" if is_clone else "Voice", "art": art_for(id), "lines": []}
			order.append(speaker)
		var clip := str(e.get("clip", ""))
		var baked := "res://audio/voice/clones/%s.wav" % str(e.get("key", ""))
		entries[speaker]["lines"].append({"text": str(e.get("text", "")), "key": str(e.get("key", "")), "clip": clip,
			"has_clip": ResourceLoader.exists(clip) or ResourceLoader.exists(baked)})
	var out: Array = []
	for i in order.size():
		entries[order[i]]["order"] = i
		out.append(entries[order[i]])
	# The ones with clips first, manifest order within each group.
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca := clips_of(a) > 0
		var cb := clips_of(b) > 0
		return a["order"] < b["order"] if ca == cb else ca)
	return out


static func clips_of(entry: Dictionary) -> int:
	var n := 0
	for l: Dictionary in entry["lines"]:
		if l["has_clip"]:
			n += 1
	return n


## The art a cast id is shown with, first match wins: the clone sheet, a caste rig, a Florida
## sheet or still, a cruise-show stand-in; anyone else gets the generic stand-in figure (dev/STYLE.md
## 7.5: real people are named, never drawn as themselves), marked so the gap shows.
static func art_for(id: String) -> Dictionary:
	if id in CLONE_IDS and ResourceLoader.exists("res://assets/ruins/clone_%s.png" % id):
		return {"kind": "clone", "path": "res://assets/ruins/clone_%s.png" % id}
	if ResourceLoader.exists("res://assets/characters/npc_%s_rig.png" % id):
		return {"kind": "rig", "path": "res://assets/characters/npc_%s_rig.png" % id}
	for dir in ["canon", "florida", "placeholder"]:
		if ResourceLoader.exists("res://assets/%s/npc_%s.tres" % [dir, id]):
			return {"kind": "sheet", "path": "res://assets/%s/npc_%s.tres" % [dir, id]}
		if ResourceLoader.exists("res://assets/%s/npc_%s.png" % [dir, id]):
			return {"kind": "still", "path": "res://assets/%s/npc_%s.png" % [dir, id]}
	if STAGE_ART.has(id) and ResourceLoader.exists("res://assets/ui/stage/%s.png" % STAGE_ART[id]):
		return {"kind": "stage", "path": "res://assets/ui/stage/%s.png" % STAGE_ART[id]}
	return {"kind": "stand_in", "path": STAND_IN}


## The sprite for an art entry, its feet on the node's origin (SpriteFit), or null without art.
static func make_sprite(art: Dictionary) -> Node2D:
	var path: String = art.get("path", "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	match art["kind"]:
		"clone":
			var s := AnimatedSprite2D.new()
			s.sprite_frames = SheetRig.frames(load(path), SheetRig.CLONE)
			s.play("idle_down")
			SheetRig.fit(s, SheetRig.CLONE)
			return s
		"rig":
			var s := AnimatedSprite2D.new()
			s.sprite_frames = RigSheet.frames(path)
			s.play("idle_down")
			SpriteFit.fit(s, 52.0, 50.0 / 52.0)
			return s
		"sheet":
			var s := AnimatedSprite2D.new()
			s.sprite_frames = load(path)
			s.play("idle_front")
			SpriteFit.fit_sheet(s)
			return s
		"stage", "stand_in":
			var s := AnimatedSprite2D.new()
			s.sprite_frames = StageFigure._frames(load(path))
			s.play("idle")
			SpriteFit.fit(s, 48.0)
			return s
		_:
			var s := Sprite2D.new()
			s.texture = load(path)
			SpriteFit.fit(s, 48.0)
			return s


# ---------------------------------------------------------------- ui

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("fff6e6")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	var build := BuildInfo.id()
	title.text = "Voice review" + (" · build " + build if build != "" else "")
	title.position = Vector2(8, 4)
	add_child(title)
	var hint := Label.new()
	hint.theme_type_variation = &"HintLabel"
	hint.text = "tap a character for its next line · rate the line and the voice 1 to 10 · Save ratings when you're done"
	hint.position = Vector2(8, 18)
	add_child(hint)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_scroll.offset_top = 30
	_scroll.offset_bottom = 30 + CARD_SIZE.y + 10
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 4)
	_scroll.add_child(_row)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(4, 0)
	_row.add_child(pad)
	for entry: Dictionary in roster:
		_row.add_child(_make_card(entry))

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -(360 - (30 + CARD_SIZE.y + 14))
	panel.offset_left = 4
	panel.offset_right = -4
	panel.offset_bottom = -4
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)

	_line_label = Label.new()
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.custom_minimum_size = Vector2(0, 30)
	_line_label.text = "Pick a character in the row above."
	box.add_child(_line_label)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	box.add_child(controls)
	var replay := Button.new()
	replay.text = "Replay"
	replay.pressed.connect(func() -> void: _say(_selected, _current_index(), false))
	controls.add_child(replay)
	var next := Button.new()
	next.text = "Next line"
	next.pressed.connect(func() -> void: _say(_selected, _next.get(_selected, 0), true))
	controls.add_child(next)
	_clip_label = Label.new()
	_clip_label.theme_type_variation = &"HintLabel"
	_clip_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	controls.add_child(_clip_label)

	_line_buttons = _rating_row(box, "this line", _line_group, _on_line_rated)
	_voice_buttons = _rating_row(box, "this voice", _voice_group, _on_voice_rated)

	var note_row := HBoxContainer.new()
	note_row.add_theme_constant_override("separation", 6)
	box.add_child(note_row)
	_note = LineEdit.new()
	_note.placeholder_text = "note about this line (optional)"
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.text_changed.connect(_on_note_changed)
	note_row.add_child(_note)

	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 6)
	box.add_child(save_row)
	var save := Button.new()
	save.text = "Save ratings"
	save.pressed.connect(save_ratings)
	save_row.add_child(save)
	var show := Button.new()
	show.text = "Show JSON"
	show.pressed.connect(func() -> void:
		_json_box.text = export_json()
		_json_box.visible = not _json_box.visible)
	save_row.add_child(show)
	_status = Label.new()
	_status.theme_type_variation = &"HintLabel"
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status.text = _summary()
	save_row.add_child(_status)

	# The JSON in a box that can be selected and copied by hand when a download can't start
	# (some phone browsers).
	_json_box = TextEdit.new()
	_json_box.visible = false
	_json_box.editable = false
	_json_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_json_box.offset_top = 30
	_json_box.offset_bottom = -30
	_json_box.offset_left = 20
	_json_box.offset_right = -20
	add_child(_json_box)


func _make_card(entry: Dictionary) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.custom_minimum_size = CARD_SIZE
	card.clip_contents = true
	card.tooltip_text = "%s · %d of %d lines have clips" % [entry["name"], clips_of(entry), entry["lines"].size()]
	card.pressed.connect(func() -> void: _say(entry["speaker"], _next.get(entry["speaker"], 0), true))
	var stage := Node2D.new()
	stage.name = "Stage"
	stage.position = Vector2(CARD_SIZE.x / 2.0, FEET_Y)
	card.add_child(stage)
	var sprite := make_sprite(entry["art"])
	if sprite:
		sprite.name = "Sprite"
		stage.add_child(sprite)
		if clips_of(entry) == 0:
			sprite.modulate = Color(1, 1, 1, 0.45)
	var bubble: Label = load(BUBBLE).instantiate()
	var h := 48.0
	if sprite and SpriteFit.frame_size(sprite).y > 0.0:
		h = SpriteFit.frame_size(sprite).y * sprite.scale.y
	bubble.bottom = -h - 2.0
	bubble.max_width = 60.0
	stage.add_child(bubble)
	_bubbles[entry["speaker"]] = bubble
	var name := Label.new()
	name.theme_type_variation = &"CardLabel"
	name.text = entry["name"]
	name.clip_text = true
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.position = Vector2(2, FEET_Y + 4)
	name.size = Vector2(CARD_SIZE.x - 4, 12)
	card.add_child(name)
	var count := Label.new()
	count.theme_type_variation = &"HintLabel"
	count.text = _count_text(entry)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.position = Vector2(2, FEET_Y + 16)
	count.size = Vector2(CARD_SIZE.x - 4, 10)
	card.add_child(count)
	var badge := Label.new()
	badge.theme_type_variation = &"HintLabel"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(4, 2)
	badge.size = Vector2(CARD_SIZE.x - 8, 10)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(badge)
	_badges[entry["speaker"]] = badge
	_refresh_badge(entry["speaker"])
	_cards[entry["speaker"]] = card
	return card


func _count_text(entry: Dictionary) -> String:
	var n: int = entry["lines"].size()
	var c := clips_of(entry)
	if c == 0:
		return "no clips yet · %d lines" % n
	var tag := "" if entry["art"]["kind"] != "stand_in" else " · stand-in"
	return "%d/%d clips%s" % [c, n, tag]


func _rating_row(box: VBoxContainer, what: String, group: ButtonGroup, handler: Callable) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	box.add_child(row)
	var label := Label.new()
	label.text = what + ":"
	label.custom_minimum_size = Vector2(52, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var buttons: Array = []
	for i in range(1, 11):
		var b := Button.new()
		b.text = str(i)
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(22, 16)
		b.pressed.connect(handler.bind(i))
		row.add_child(b)
		buttons.append(b)
	return buttons


# ---------------------------------------------------------------- playing

func _entry(speaker: String) -> Dictionary:
	for e: Dictionary in roster:
		if e["speaker"] == speaker:
			return e
	return {}


func _current_index() -> int:
	var e := _entry(_selected)
	if e.is_empty():
		return 0
	for i in e["lines"].size():
		if e["lines"][i]["key"] == _current_key:
			return i
	return 0


## Says line `index` of `speaker` (bubble, clip through its bus) and makes it the line being rated.
## `advance` moves that speaker's "next line" on by one.
func _say(speaker: String, index: int, advance: bool) -> void:
	var e := _entry(speaker)
	if e.is_empty() or e["lines"].is_empty():
		return
	index = wrapi(index, 0, e["lines"].size())
	var line: Dictionary = e["lines"][index]
	if _selected != speaker:
		for s: String in _bubbles:
			_bubbles[s].hide()
	_selected = speaker
	_current_key = line["key"]
	if advance:
		_next[speaker] = (index + 1) % e["lines"].size()
	for s: String in _cards:
		_cards[s].button_pressed = s == speaker
	_ensure_visible(_cards[speaker])
	var voice: Node = get_node_or_null("/root/Voice")
	if voice:
		voice.speak(line["text"], 1.0, speaker, e["bus"])
		_bubbles[speaker].say(voice.display_text(line["text"]))
	else:
		_bubbles[speaker].say(line["text"])
	_line_label.text = "%s: %s" % [e["name"], line["text"]]
	_clip_label.text = "line %d of %d · %s" % [index + 1, e["lines"].size(), "clip" if line["has_clip"] else "no clip yet (bubble only)"]
	_show_rating(_line_buttons, int(ratings.get(_current_key, {}).get("rating", 0)))
	_show_rating(_voice_buttons, int(overall.get(speaker, 0)))
	_note.text = str(ratings.get(_current_key, {}).get("note", ""))


func _ensure_visible(card: Control) -> void:
	if _scroll == null:
		return
	var left := card.position.x
	var right := left + card.size.x
	if left < _scroll.scroll_horizontal:
		_scroll.scroll_horizontal = int(left) - 4
	elif right > _scroll.scroll_horizontal + _scroll.size.x:
		_scroll.scroll_horizontal = int(right - _scroll.size.x) + 4


func _show_rating(buttons: Array, value: int) -> void:
	for i in buttons.size():
		buttons[i].set_pressed_no_signal(i + 1 == value)


# ---------------------------------------------------------------- ratings

## The current line's rating; the character and the text are remembered with it.
func rate_line(rating: int) -> void:
	if _current_key == "":
		return
	var e := _entry(_selected)
	var line: Dictionary = e["lines"][_current_index()]
	var rec: Dictionary = ratings.get(_current_key, {"speaker": _selected, "clip": _current_key, "text": line["text"], "note": ""})
	rec["rating"] = clampi(rating, 1, 10)
	ratings[_current_key] = rec
	_after_change()


## The selected character's voice as a whole.
func rate_character(rating: int) -> void:
	if _selected == "":
		return
	overall[_selected] = clampi(rating, 1, 10)
	_refresh_badge(_selected)
	_after_change()


func set_note(note: String) -> void:
	if _current_key == "":
		return
	var rec: Dictionary = ratings.get(_current_key, {"speaker": _selected, "clip": _current_key, "text": _entry(_selected)["lines"][_current_index()]["text"], "rating": 0})
	rec["note"] = note.strip_edges()
	ratings[_current_key] = rec
	_after_change()


func _on_line_rated(rating: int) -> void:
	rate_line(rating)


func _on_voice_rated(rating: int) -> void:
	rate_character(rating)


func _on_note_changed(text: String) -> void:
	set_note(text)


func _after_change() -> void:
	if persist:
		_save_local()
	if _status:
		_status.text = _summary()


func _summary() -> String:
	var rated := 0
	for k: String in ratings:
		if int(ratings[k].get("rating", 0)) > 0:
			rated += 1
	return "%d lines and %d voices rated" % [rated, overall.size()]


func _refresh_badge(speaker: String) -> void:
	var badge: Label = _badges.get(speaker)
	if badge:
		badge.text = ("voice %d/10" % int(overall[speaker])) if overall.has(speaker) else ""


## Everything rated so far as the JSON tools/ingest_voice_ratings.py reads.
func export_json() -> String:
	var list: Array = []
	for k: String in ratings:
		var r: Dictionary = ratings[k]
		if int(r.get("rating", 0)) > 0 or str(r.get("note", "")) != "":
			list.append({"speaker": r["speaker"], "clip": k, "text": r.get("text", ""), "rating": int(r.get("rating", 0)), "note": r.get("note", "")})
	return JSON.stringify({"build": BuildInfo.id(), "date": Time.get_datetime_string_from_system(true, true),
		"ratings": list, "character_overall": overall.duplicate()}, "  ")


## Hands the ratings back: in the browser a download (and the clipboard), on a desktop a file in
## the user data folder (and the clipboard). The status line says where it went.
func save_ratings() -> void:
	var text := export_json()
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	var file_name := "voice_ratings_%s.json" % stamp
	if OS.has_feature("web"):
		var js := "(function(){var s=%s;var b=new Blob([s],{type:'application/json'});var u=URL.createObjectURL(b);var a=document.createElement('a');a.href=u;a.download=%s;document.body.appendChild(a);a.click();a.remove();setTimeout(function(){URL.revokeObjectURL(u)},2000);if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(s).catch(function(){});}return 'ok';})()" % [JSON.stringify(text), JSON.stringify(file_name)]
		var result = JavaScriptBridge.eval(js, true)
		_status.text = ("downloaded %s (also on the clipboard)" % file_name) if str(result) == "ok" else "download didn't start: use Show JSON and copy it"
	else:
		var path := "user://" + file_name
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(text)
			f.close()
			DisplayServer.clipboard_set(text)
			_status.text = "saved %s (also on the clipboard)" % ProjectSettings.globalize_path(path)
		else:
			_status.text = "could not write %s" % path


func _save_local() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"ratings": ratings, "overall": overall}))
		f.close()


func _load_local() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		ratings = data.get("ratings", {}) if data.get("ratings") is Dictionary else {}
		overall = data.get("overall", {}) if data.get("overall") is Dictionary else {}
		for s: String in overall:
			overall[s] = int(overall[s])


static func _json(path: String) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return v if v is Dictionary else {}


static func _json_array(path: String) -> Array:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return v if v is Array else []
