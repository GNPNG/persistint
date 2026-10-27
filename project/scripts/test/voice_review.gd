extends Control
## Voice review (beads persistint-game-rxu, rebuilt as a character picker on 2026-10-27). Every
## character that speaks a line anywhere in the game stands in a row along the bottom, Toca Boca
## style; the selected one stands large in the middle in its game art. Tap it (or Enter / pad A)
## and it says its next line: the bubble over its head, its clip through Voice when one exists,
## "line 3 of 17 · clip / no clip". Left and right (arrow keys, d-pad, the < > buttons, a swipe
## across the middle, or a tap on a card) move along the row.
## Per character: Voice good / Voice sucks. Per line: thumbs up / thumbs down (or up / down keys).
## Neither deletes or changes anything; it is feedback. Verdicts are kept in
## user://voice_review.json as they are given, and Export review hands the file back (a download
## in the browser, user:// on a desktop).
##
## The roster is built from the game's own line sources with the speaker string each one hands to
## Voice.speak (which is what a clip is keyed on), not from the clip manifest alone, so a character
## with lines and no clips shows up marked "no voice yet":
##   dialogue/*.dialogue, data/barks.json (villagers), data/emcee.json, data/hottest_of_the_hot.json,
##   data/landing.json (first mate), data/interview.json (Oprah: intro and questions),
##   data/florida.json critters (one voice per kind: crab, gull, dolphin, mermaid),
##   data/ponies.json (one voice for every pony), data/ruins.json polar bear cubs,
##   the clones' verified quotes (data/quotes via ZombieChild.quote_pool),
##   data/title_letters.json (the title letters and their chime-ins),
##   and anything else in audio/voice/manifest.json (Margaret Atwood's lines).
## Opens from the normal export with ?scene=voice_review (DevScene); nothing runs per frame here.

const SheetRig := preload("res://scripts/ruins/sheet_rig.gd")
const ZombieChild := preload("res://scripts/ruins/zombie_child.gd")
const TextDownload := preload("res://scripts/util/text_download.gd")
const VoiceScript := preload("res://scripts/autoload/voice.gd")

const MANIFEST := "res://audio/voice/manifest.json"
const CAST_PATH := "res://data/cast.json"
const BUBBLE := "res://scenes/ui/bark_bubble.tscn"
const CLONE_IDS := ["epstein", "bill_clinton", "hillary_clinton", "bill_gates"]
const CUB_ID := "polar_bear_clone"
const CRITTER_TITLES := {"crab": "Crabs", "gull": "Gulls", "dolphin": "Dolphins", "mermaid": "Mermaids"}
## Cruise-show hosts are generic stand-in figures with a nameplate (scripts/minigames/stage_figure.gd).
const STAGE_ART := {"chelsea": "host_emcee", "tyra": "host_runway", "oprah": "host_talk", "silverman": "host_comic"}
const STAND_IN := "res://assets/ui/stage/host_emcee.png"

const BIG_H := 120.0  # the centre character's height on screen (px)
const BIG_W := 240.0  # and at most this wide (the crab, the dolphin)
const CARD_H := 40.0  # a card's character height
const CARD_SIZE := Vector2(64, 84)
const STAGE_FEET := Vector2(196, 238)
const BUBBLE_SCALE := 2.4
const SWIPE := 40.0

## {speaker, id, name, short, sub, bus, art: {kind, path}, lines: [{text, key, has_clip, source}]} per character.
var roster: Array = []
## Saved verdicts: {"characters": {speaker: {verdict, at, name}}, "lines": {key: {thumb, at, speaker, text}}}.
var review: Dictionary = {"characters": {}, "lines": {}}
## Tests turn this off, or point save_path at a test file, so they never touch the author's review.
var persist := true
var save_path := "user://voice_review.json"

var current := 0  # index into roster
var _cursor: Dictionary = {}  # speaker -> index of the line shown
var _cards: Array = []  # Button per roster entry
var _card_marks: Array = []  # Label per roster entry (verdict)
var _row: HBoxContainer
var _scroll: ScrollContainer
var _stage: Node2D
var _big: Node2D
var _bubble: Label
var _name: Label
var _sub: Label
var _clips: Label
var _line_info: Label
var _line_text: Label
var _counts: Label
var _status: Label
var _good: CheckBox
var _sucks: CheckBox
var _up: Button
var _down: Button
var _json_box: TextEdit
var _press_at := Vector2.ZERO
var _pressing := false


func _ready() -> void:
	roster = build_roster()
	if persist:
		load_review()
	_build_ui()
	select(0, false)


# ---------------------------------------------------------------- roster

## Every speaking character, grouped by the speaker string its lines go to Voice.speak with, its
## lines in source order. The ones with at least one clip come first; the order within each group
## follows the sources.
static func build_roster() -> Array:
	var cast: Dictionary = _json(CAST_PATH)
	var name_of := func(id: String) -> String:
		return str(cast[id].get("name", id)) if cast.get(id) is Dictionary else id
	var short_of := func(id: String) -> String:
		return str(cast[id].get("short", name_of.call(id))) if cast.get(id) is Dictionary else id
	var found: Array = []  # [speaker, text, source]
	var add := func(speaker: String, text: String, source: String) -> void:
		if speaker != "" and VoiceScript.display_text(text) != "" and not "{{" in speaker + text:
			found.append([speaker, text.strip_edges(), source])

	# Dialogue (Dialogue Manager speaks each line with its character's resolved name).
	var line_re := RegEx.create_from_string("^\\s*(\\{\\{Cast\\.full\\(\"\\w+\"\\)\\}\\}|[A-Z][^:{]*):\\s*(.+)$")
	var cast_re := RegEx.create_from_string("\\{\\{Cast\\.(full|short)\\(\"(\\w+)\"\\)\\}\\}")
	var resolve := func(s: String) -> String:
		var out := s
		for m: RegExMatch in cast_re.search_all(s):
			var id := m.get_string(2)
			out = out.replace(m.get_string(0), name_of.call(id) if m.get_string(1) == "full" else short_of.call(id))
		return out
	var files := Array(DirAccess.get_files_at("res://dialogue"))
	files.sort()
	for f: String in files:
		if not f.ends_with(".dialogue"):
			continue
		for raw: String in FileAccess.get_file_as_string("res://dialogue/" + f).split("\n"):
			var m := line_re.search(raw)
			if m:
				add.call(resolve.call(m.get_string(1).strip_edges()), resolve.call(m.get_string(2)), "dialogue " + f.get_basename())
	# Villager barks (npc.gd: display_name, Cast.full(npc_id) by default).
	var barks: Dictionary = _json("res://data/barks.json")
	for id: String in barks:
		if barks[id] is Array:
			for e: Variant in barks[id]:
				if e is Dictionary:
					add.call(name_of.call(id), str(e.get("text", "")), "barks")
	# Cruise shows.
	var emcee: Dictionary = _json("res://data/emcee.json")
	for intro: Variant in emcee.get("intros", {}).values():
		for t: Variant in intro:
			add.call(name_of.call(str(emcee.get("emcee", ""))), str(t), "cruise show emcee")
	var hot: Dictionary = _json("res://data/hottest_of_the_hot.json")
	for t: Variant in hot.get("verdicts", []):
		add.call(name_of.call(str(hot.get("host", ""))), str(t), "Hottest of the HOT")
	var landing: Dictionary = _json("res://data/landing.json")
	for c: Variant in landing.get("commands", []):
		if c is Dictionary:
			add.call(str(landing.get("first_mate", "")), str(c.get("text", "")), "The Landing")
	# The interview: interview.gd speaks as data.host, the cast id.
	var interview: Dictionary = _json("res://data/interview.json")
	var host := str(interview.get("host", ""))
	for t: Variant in interview.get("intro", []):
		add.call(host, str(t), "interview")
	for q: Variant in interview.get("questions", []):
		if q is Dictionary:
			add.call(host, str(q.get("prompt", "")), "interview")
	# Florida critters: critter.gd speaks as its kind; every named critter of a kind shares it.
	var critters: Dictionary = _json("res://data/florida.json").get("critters", {})
	for kind: String in critters:
		for s: Variant in critters[kind].get("surprises", []):
			for t: Variant in (s.get("lines", []) if s is Dictionary else []):
				add.call(kind, str(t), "Florida")
	# Ponies: pony.gd speaks every pony's line as "pony".
	var pony_lines: Dictionary = _json("res://data/ponies.json").get("lines", {})
	for k: String in pony_lines:
		for t: Variant in pony_lines[k]:
			add.call("pony", str(t), "Florida stable")
	# The clone hall: each clone speaks its original's verified quotes as the cast id; the cubs
	# speak their little bear sounds as polar_bear_clone.
	for id: String in CLONE_IDS:
		for t: String in ZombieChild.quote_pool(id):
			add.call(id, t, "clone hall")
	var cubs: Dictionary = ZombieChild.data().get("cubs", {})
	for list in ["barks", "bump_barks", "nom", "nap"]:
		for t: Variant in cubs.get(list, []):
			add.call(str(cubs.get("cast", CUB_ID)), str(t), "clone hall")
	# The title screen's letters and chime-ins (title_letters.gd: speaker ids from data).
	var title: Dictionary = _json("res://data/title_letters.json")
	var speakers: Dictionary = title.get("speakers", {})
	for tier: Variant in title.get("tiers", []):
		for t: Variant in (tier.get("lines", []) if tier is Dictionary else []):
			add.call(str(speakers.get("letters", "letters")), str(t), "title screen")
	for c: Variant in title.get("chime_ins", []):
		if c is Dictionary:
			var role := str(c.get("speaker", "reason"))
			add.call(str(speakers.get(role, role)), str(c.get("line", "")), "title screen")
	# Anything else the clip manifest lists (Margaret Atwood's sourced lines).
	for e: Variant in _json_array(MANIFEST):
		if e is Dictionary:
			add.call(str(e.get("speaker", "")), str(e.get("text", "")), "clip manifest")

	var order: Array = []
	var entries := {}
	var seen := {}
	for f: Array in found:
		var speaker: String = f[0]
		var text: String = f[1]
		var key := VoiceScript.line_key(speaker, text)
		if seen.has(key):
			continue
		seen[key] = true
		if not entries.has(speaker):
			entries[speaker] = _make_entry(speaker, cast, critters)
			order.append(speaker)
		var bus: String = entries[speaker]["bus"]
		var clip := VoiceScript.clone_variant(VoiceScript.clip_path(speaker, text), bus)
		entries[speaker]["lines"].append({"text": text, "key": key, "has_clip": ResourceLoader.exists(clip), "source": f[2]})
	var out: Array = []
	for i in order.size():
		var e: Dictionary = entries[order[i]]
		e["order"] = i
		var sources := {}
		for l: Dictionary in e["lines"]:
			sources[l["source"]] = true
		var where := ", ".join(PackedStringArray(sources.keys()))
		e["sub"] = (str(e["sub"]) + " · " + where) if str(e["sub"]) != "" else where
		out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca := clips_of(a) > 0
		var cb := clips_of(b) > 0
		return a["order"] < b["order"] if ca == cb else ca)
	return out


static func _make_entry(speaker: String, cast: Dictionary, critters: Dictionary) -> Dictionary:
	var by_name := {}
	for cid: String in cast:
		if cast[cid] is Dictionary:
			by_name[str(cast[cid].get("name", ""))] = cid
	var id: String = speaker if cast.get(speaker) is Dictionary else str(by_name.get(speaker, speaker.to_lower().replace(" ", "_")))
	var name := speaker
	var short := ""
	var sub := ""
	if critters.has(speaker):
		name = CRITTER_TITLES.get(speaker, speaker.capitalize())
		var names := PackedStringArray()
		for cid: Variant in critters[speaker].get("names", []):
			names.append(str(cast[str(cid)].get("name", cid)) if cast.get(str(cid)) is Dictionary else str(cid))
		sub = ", ".join(names)
	elif speaker == "pony":
		name = "Ponies"
		sub = "every pony shares one voice"
	elif cast.get(id) is Dictionary:
		name = str(cast[id].get("name", speaker))
		short = str(cast[id].get("short", name))
		if id in CLONE_IDS:
			name += " clone"
			short += " clone"
		elif id == CUB_ID:
			name = "Polar bear cubs"
			short = "Cubs"
	elif speaker == speaker.to_lower():
		name = speaker.capitalize()
	var clone_bus: bool = id in CLONE_IDS or id == CUB_ID
	return {"speaker": speaker, "id": id, "name": name, "short": short if short != "" else name, "sub": sub, "bus": "Clones" if clone_bus else "Voice",
		"art": art_for(id), "lines": []}


static func clips_of(entry: Dictionary) -> int:
	var n := 0
	for l: Dictionary in entry["lines"]:
		if l["has_clip"]:
			n += 1
	return n


## The art a character is shown with, first match wins: a clone sheet, the cub sheet, a pony, a
## Florida critter rig, a caste rig, a canon/Florida sheet or still, a cruise-show stand-in; anyone
## else gets the generic stand-in figure (dev/STYLE.md 7.5: real people are named, never drawn as
## themselves), marked so the gap shows.
static func art_for(id: String) -> Dictionary:
	if id in CLONE_IDS and ResourceLoader.exists("res://assets/ruins/clone_%s.png" % id):
		return {"kind": "clone", "path": "res://assets/ruins/clone_%s.png" % id}
	if id == CUB_ID and ResourceLoader.exists("res://assets/ruins/clone_polar_bear.png"):
		return {"kind": "cub", "path": "res://assets/ruins/clone_polar_bear.png"}
	if id == "pony":
		return {"kind": "pony", "path": "res://data/ponies.json"}
	if ResourceLoader.exists("res://assets/florida/%s.tres" % id):
		return {"kind": "sheet", "path": "res://assets/florida/%s.tres" % id}
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


## The character in its art, feet on the returned node's origin, `height` px tall (narrower when
## that would make it wider than `max_w`); the art itself is its child "Sprite".
static func make_figure(art: Dictionary, height: float, max_w := INF) -> Node2D:
	var holder := Node2D.new()
	var sprite := _make_sprite(art)
	if sprite == null:
		return holder
	sprite.name = "Sprite"
	holder.add_child(sprite)
	var size: Vector2 = Vector2(64, PonyDoll.FRAME_HEIGHT) if sprite is PonyDoll else SpriteFit.frame_size(sprite) * sprite.scale
	if size.y > 0.0:
		holder.scale = Vector2.ONE * minf(height / size.y, max_w / maxf(size.x, 1.0))
	return holder


static func _make_sprite(art: Dictionary) -> Node2D:
	var path: String = art.get("path", "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	match art["kind"]:
		"clone", "cub":
			var s := AnimatedSprite2D.new()
			var rig: Dictionary = SheetRig.CLONE if art["kind"] == "clone" else SheetRig.CUB
			s.sprite_frames = SheetRig.frames(load(path), rig)
			s.play("idle_down")
			SheetRig.fit(s, rig)
			return s
		"pony":
			var starters: Array = Ponies.data().get("starters", [])
			var doll := PonyDoll.new()
			doll.set_outfit(Ponies.parts(starters[0]) if not starters.is_empty() else {})
			return doll
		"rig":
			var s := AnimatedSprite2D.new()
			s.sprite_frames = RigSheet.frames(path)
			s.play("idle_down")
			SpriteFit.fit(s, 52.0, 50.0 / 52.0)
			return s
		"sheet":
			var s := AnimatedSprite2D.new()
			s.sprite_frames = load(path)
			for a: String in ["idle_front", "idle_down", "idle"]:
				if s.sprite_frames.has_animation(a):
					s.play(a)
					break
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
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Top: title, counts, Export review.
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	var build := BuildInfo.id()
	title.text = "Voice review" + (" · build " + build if build != "" else "")
	title.position = Vector2(8, 2)
	add_child(title)
	_counts = Label.new()
	_counts.name = "Counts"
	_counts.theme_type_variation = &"HintLabel"
	_counts.position = Vector2(8, 18)
	_counts.size = Vector2(520, 12)
	add_child(_counts)
	var export := _button("Export review", export_review)
	export.name = "Export"
	export.position = Vector2(536, 4)
	export.size = Vector2(98, 26)
	add_child(export)
	_status = Label.new()
	_status.theme_type_variation = &"HintLabel"
	_status.position = Vector2(8, 30)
	_status.size = Vector2(620, 12)
	_status.clip_text = true
	add_child(_status)

	# Middle: the selected character, large. Tap it for its next line; swipe for the next character.
	var touch := Control.new()
	touch.name = "Stage"
	touch.position = Vector2(0, 44)
	touch.size = Vector2(392, 220)
	touch.mouse_filter = Control.MOUSE_FILTER_STOP
	touch.gui_input.connect(_on_stage_input)
	add_child(touch)
	_stage = Node2D.new()
	_stage.position = STAGE_FEET - touch.position
	touch.add_child(_stage)
	var bubble_holder := Node2D.new()
	bubble_holder.scale = Vector2.ONE * BUBBLE_SCALE
	bubble_holder.position = Vector2(0, -BIG_H - 4.0)
	_stage.add_child(bubble_holder)
	_bubble = load(BUBBLE).instantiate()
	_bubble.max_width = 140.0
	_bubble.bottom = 0.0
	bubble_holder.add_child(_bubble)
	var tap_hint := Label.new()
	tap_hint.theme_type_variation = &"HintLabel"
	tap_hint.text = "tap the character for its next line · swipe or < > for the next character"
	tap_hint.position = Vector2(8, 204)
	tap_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch.add_child(tap_hint)

	# Right: who it is, the voice verdict, the line and its thumbs.
	var panel := PanelContainer.new()
	panel.position = Vector2(396, 44)
	panel.size = Vector2(240, 220)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	_name = Label.new()
	_name.theme_type_variation = &"HeaderLabel"
	_name.clip_text = true
	box.add_child(_name)
	_sub = Label.new()
	_sub.theme_type_variation = &"HintLabel"
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_sub)
	_clips = Label.new()
	_clips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_clips)
	var verdict := HBoxContainer.new()
	box.add_child(verdict)
	var voice_group := ButtonGroup.new()
	voice_group.allow_unpress = true
	_good = CheckBox.new()
	_good.text = "Voice good"
	_sucks = CheckBox.new()
	_sucks.text = "Voice sucks"
	for c: CheckBox in [_good, _sucks]:
		c.button_group = voice_group
		c.focus_mode = Control.FOCUS_NONE
		c.custom_minimum_size = Vector2(0, 28)
		verdict.add_child(c)
	_good.pressed.connect(func() -> void: set_verdict(_speaker(), "good" if _good.button_pressed else ""))
	_sucks.pressed.connect(func() -> void: set_verdict(_speaker(), "sucks" if _sucks.button_pressed else ""))
	box.add_child(HSeparator.new())
	_line_info = Label.new()
	_line_info.theme_type_variation = &"HintLabel"
	box.add_child(_line_info)
	_line_text = Label.new()
	_line_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_line_text.custom_minimum_size = Vector2(228, 0)
	_line_text.clip_text = true
	box.add_child(_line_text)
	var thumbs := HBoxContainer.new()
	box.add_child(thumbs)
	_up = _button("Thumbs up", func() -> void: _toggle_thumb("up"))
	_down = _button("Thumbs down", func() -> void: _toggle_thumb("down"))
	for b: Button in [_up, _down]:
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 28)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		thumbs.add_child(b)
	var again := HBoxContainer.new()
	box.add_child(again)
	var replay := _button("Replay", func() -> void: say_line(int(_cursor.get(_speaker(), 0))))
	var next := _button("Next line", next_line)
	for b: Button in [replay, next]:
		b.custom_minimum_size = Vector2(0, 28)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		again.add_child(b)

	# Bottom: every character in a row, < and > at the ends.
	var prev_b := _button("<", select_prev)
	prev_b.position = Vector2(4, 268)
	prev_b.size = Vector2(30, CARD_SIZE.y + 4)
	add_child(prev_b)
	var next_b := _button(">", select_next)
	next_b.position = Vector2(606, 268)
	next_b.size = Vector2(30, CARD_SIZE.y + 4)
	add_child(next_b)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(38, 266)
	_scroll.size = Vector2(564, CARD_SIZE.y + 10)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 4)
	_scroll.add_child(_row)
	for i in roster.size():
		_row.add_child(_make_card(i))

	# The JSON to copy by hand when an export can't start.
	_json_box = TextEdit.new()
	_json_box.visible = false
	_json_box.editable = false
	_json_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_json_box.offset_top = 44
	_json_box.offset_bottom = -20
	_json_box.offset_left = 20
	_json_box.offset_right = -20
	add_child(_json_box)
	_refresh_counts()


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b


func _make_card(i: int) -> Button:
	var entry: Dictionary = roster[i]
	var card := Button.new()
	card.name = "Card%d" % i
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = CARD_SIZE
	card.clip_contents = true
	card.pressed.connect(func() -> void: select(i))
	var fig := make_figure(entry["art"], CARD_H, CARD_SIZE.x - 6.0)
	fig.name = "Figure"
	fig.position = Vector2(CARD_SIZE.x / 2.0, 50)
	if clips_of(entry) == 0:
		fig.modulate = Color(1, 1, 1, 0.45)
	card.add_child(fig)
	var name := Label.new()
	name.theme_type_variation = &"CardLabel"
	name.text = entry["short"]
	name.add_theme_font_size_override("font_size", 8)
	name.clip_text = true
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.position = Vector2(2, 52)
	name.size = Vector2(CARD_SIZE.x - 4, 12)
	card.add_child(name)
	var count := Label.new()
	count.theme_type_variation = &"HintLabel"
	var c := clips_of(entry)
	count.text = ("%d/%d clips" % [c, entry["lines"].size()]) if c > 0 else "no voice yet"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.position = Vector2(2, 66)
	count.size = Vector2(CARD_SIZE.x - 4, 10)
	card.add_child(count)
	var mark := Label.new()
	mark.theme_type_variation = &"HintLabel"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.position = Vector2(2, 1)
	mark.size = Vector2(CARD_SIZE.x - 4, 10)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(mark)
	_cards.append(card)
	_card_marks.append(mark)
	_refresh_mark(i)
	return card


# ---------------------------------------------------------------- moving and playing

func _speaker() -> String:
	return roster[current]["speaker"] if current < roster.size() else ""


func entry_of(speaker: String) -> Dictionary:
	for e: Dictionary in roster:
		if e["speaker"] == speaker:
			return e
	return {}


func index_of(speaker: String) -> int:
	for i in roster.size():
		if roster[i]["speaker"] == speaker:
			return i
	return -1


func select_next() -> void:
	select(current + 1)


func select_prev() -> void:
	select(current - 1)


## Makes character `i` (wrapping) the one in the middle. With `speak` it says the line it was on
## (its first line the first time), so arrowing along the row hears each voice at once.
func select(i: int, speak := true) -> void:
	if roster.is_empty():
		return
	current = wrapi(i, 0, roster.size())
	var e: Dictionary = roster[current]
	for k in _cards.size():
		_cards[k].set_pressed_no_signal(k == current)
	_center_card(current)
	if _big:
		_big.queue_free()
	_big = make_figure(e["art"], BIG_H, BIG_W)
	_big.name = "Big"
	if clips_of(e) == 0:
		_big.modulate = Color(1, 1, 1, 0.6)
	_stage.add_child(_big)
	_stage.move_child(_big, 0)
	_bubble.hide()
	_name.text = e["name"]
	_sub.text = e["sub"]
	var c := clips_of(e)
	var n: int = e["lines"].size()
	_clips.text = ("%d of %d lines have a clip" % [c, n]) if c > 0 else "NO VOICE YET: none of its %d lines has a clip" % n
	_good.set_pressed_no_signal(verdict_of(e["speaker"]) == "good")
	_sucks.set_pressed_no_signal(verdict_of(e["speaker"]) == "sucks")
	if speak:
		say_line(int(_cursor.get(e["speaker"], 0)))
	else:
		_show_line(int(_cursor.get(e["speaker"], -1)))


## The tap on the middle character: its next line, wrapping after the last.
func next_line() -> void:
	var speaker := _speaker()
	say_line(int(_cursor[speaker]) + 1 if _cursor.has(speaker) else 0)


## Says line `index` (wrapping) of the selected character: the bubble, and its clip through Voice.
func say_line(index: int) -> void:
	var e: Dictionary = roster[current]
	if e["lines"].is_empty():
		return
	index = wrapi(index, 0, e["lines"].size())
	_cursor[e["speaker"]] = index
	var line: Dictionary = e["lines"][index]
	var voice: Node = get_node_or_null("/root/Voice")
	if voice:
		voice.speak(line["text"], 1.0, e["speaker"], e["bus"])
	_bubble.say(VoiceScript.display_text(line["text"]))
	_show_line(index)


func _show_line(index: int) -> void:
	var e: Dictionary = roster[current]
	var n: int = e["lines"].size()
	if index < 0 or n == 0:
		_line_info.text = "%d lines · tap the character to hear the first" % n
		_line_text.text = ""
		_up.set_pressed_no_signal(false)
		_down.set_pressed_no_signal(false)
		_up.disabled = true
		_down.disabled = true
		return
	var line: Dictionary = e["lines"][index]
	_line_info.text = "line %d of %d · %s · %s" % [index + 1, n, "clip" if line["has_clip"] else "no clip", line["source"]]
	_line_text.text = VoiceScript.display_text(line["text"])
	_up.disabled = false
	_down.disabled = false
	var t := thumb_of(line["key"])
	_up.set_pressed_no_signal(t == "up")
	_down.set_pressed_no_signal(t == "down")


## "line 3 of 17 · clip · ..." for the selected character.
func line_info() -> String:
	return _line_info.text


## The line on screen for the selected character ({} before the first tap).
func current_line() -> Dictionary:
	var e: Dictionary = roster[current]
	var at: int = _cursor.get(e["speaker"], -1)
	return e["lines"][at] if at >= 0 and at < e["lines"].size() else {}


func _center_card(i: int) -> void:
	if _scroll == null or i >= _cards.size():
		return
	var x := i * (CARD_SIZE.x + 4.0) + CARD_SIZE.x / 2.0
	_scroll.scroll_horizontal = int(maxf(0.0, x - _scroll.size.x / 2.0))


func _unhandled_input(event: InputEvent) -> void:
	if _json_box and _json_box.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			_json_box.hide()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right"):
		select_next()
	elif event.is_action_pressed("ui_left"):
		select_prev()
	elif event.is_action_pressed("ui_accept"):
		next_line()
	elif event.is_action_pressed("ui_up"):
		_toggle_thumb("up")
	elif event.is_action_pressed("ui_down"):
		_toggle_thumb("down")
	else:
		return
	get_viewport().set_input_as_handled()


## A tap on the middle says the next line; a sideways swipe moves along the row. Touch arrives as
## emulated mouse events (input_devices/pointing/emulate_mouse_from_touch, on by default).
func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_at = event.position
		elif _pressing:
			_pressing = false
			var dx: float = event.position.x - _press_at.x
			if dx <= -SWIPE:
				select_next()
			elif dx >= SWIPE:
				select_prev()
			else:
				next_line()
		accept_event()


# ---------------------------------------------------------------- verdicts

func verdict_of(speaker: String) -> String:
	return str(review["characters"].get(speaker, {}).get("verdict", ""))


func thumb_of(key: String) -> String:
	return str(review["lines"].get(key, {}).get("thumb", ""))


## "good", "sucks", or "" (unreviewed) for a character's voice. Feedback only: nothing is changed.
func set_verdict(speaker: String, verdict: String) -> void:
	var e := entry_of(speaker)
	if e.is_empty():
		return
	if verdict == "":
		review["characters"].erase(speaker)
	else:
		review["characters"][speaker] = {"verdict": verdict, "at": _now(), "name": e["name"]}
	if speaker == _speaker() and _good:
		_good.set_pressed_no_signal(verdict == "good")
		_sucks.set_pressed_no_signal(verdict == "sucks")
	_refresh_mark(index_of(speaker))
	_after_change()


## "up", "down", or "" for one line (by its key). Feedback only: the line stays in the game.
func set_thumb(key: String, thumb: String) -> void:
	if thumb == "":
		review["lines"].erase(key)
	else:
		var speaker := ""
		var text := ""
		for e: Dictionary in roster:
			for l: Dictionary in e["lines"]:
				if l["key"] == key:
					speaker = e["speaker"]
					text = l["text"]
		if speaker == "":
			return
		review["lines"][key] = {"thumb": thumb, "at": _now(), "speaker": speaker, "text": text}
	var line := current_line()
	if _up and not line.is_empty() and line["key"] == key:
		_up.set_pressed_no_signal(thumb == "up")
		_down.set_pressed_no_signal(thumb == "down")
	_after_change()


## The thumb buttons and up/down keys: the same thumb again takes it back.
func _toggle_thumb(thumb: String) -> void:
	var line := current_line()
	if line.is_empty():
		return
	set_thumb(line["key"], "" if thumb_of(line["key"]) == thumb else thumb)


func _refresh_mark(i: int) -> void:
	if i < 0 or i >= _card_marks.size():
		return
	var v := verdict_of(roster[i]["speaker"])
	_card_marks[i].text = {"good": "GOOD", "sucks": "SUCKS"}.get(v, "")


## {good, sucks, unreviewed, up, down} over the current roster.
func counts() -> Dictionary:
	var c := {"good": 0, "sucks": 0, "unreviewed": 0, "up": 0, "down": 0}
	for e: Dictionary in roster:
		var v := verdict_of(e["speaker"])
		c[v if c.has(v) else "unreviewed"] += 1
	for k: String in review["lines"]:
		var t := str(review["lines"][k].get("thumb", ""))
		if t == "up" or t == "down":
			c[t] += 1
	return c


func counts_text() -> String:
	return _counts.text if _counts else ""


func _refresh_counts() -> void:
	if _counts == null:
		return
	var c := counts()
	var voiced := 0
	for e: Dictionary in roster:
		if clips_of(e) > 0:
			voiced += 1
	_counts.text = "%d characters (%d with clips, %d no voice yet) · voices: %d good, %d suck, %d unreviewed · lines: %d up, %d down" % [
		roster.size(), voiced, roster.size() - voiced, c["good"], c["sucks"], c["unreviewed"], c["up"], c["down"]]


func _after_change() -> void:
	if persist:
		save_review()
	_refresh_counts()


static func _now() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


func save_review() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(review, "  "))
		f.close()


func load_review() -> void:
	review = {"characters": {}, "lines": {}}
	if not FileAccess.file_exists(save_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if data is Dictionary:
		if data.get("characters") is Dictionary:
			review["characters"] = data["characters"]
		if data.get("lines") is Dictionary:
			review["lines"] = data["lines"]


## The review as handed back: the verdicts, the counts, and every character with its clip count.
func export_json() -> String:
	var chars: Array = []
	for e: Dictionary in roster:
		chars.append({"speaker": e["speaker"], "name": e["name"], "lines": e["lines"].size(), "clips": clips_of(e),
			"verdict": verdict_of(e["speaker"])})
	return JSON.stringify({"build": BuildInfo.id(), "date": _now(), "counts": counts(), "roster": chars,
		"characters": review["characters"], "lines": review["lines"]}, "  ")


## Export review: a download in the browser, a file in user:// on a desktop. When a download can't
## start (some browsers), the JSON shows in a box to copy by hand. Returns where it went ("" if not).
func export_review() -> String:
	var text := export_json()
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	var file_name := "voice_review_%s.json" % stamp
	var where := TextDownload.save(file_name, text)
	if where == "":
		_status.text = "The export didn't start: the JSON is shown below to copy (Esc closes it)."
		_json_box.text = text
		_json_box.show()
	else:
		_status.text = ("Downloaded %s." % file_name) if where == "download" else "Saved %s." % where
	return where


static func _json(path: String) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return v if v is Dictionary else {}


static func _json_array(path: String) -> Array:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return v if v is Array else []
