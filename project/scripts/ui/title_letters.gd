extends Node2D
class_name TitleLetters
## The PERSISTINT wordmark as ten sticker letters that jiggle to the title theme and answer
## taps (bd persistint-game-3m3, the author's addition). Each letter bobs on the beat (the
## track's BPM from data/title_letters.json, the beat phase from the backdrop's track position,
## which follows Music); a tap or click on a letter makes it jiggle harder, pops hearts out of
## it and has it speak a line in a bubble. Taps add to a counter that decays with time; the
## counter picks the line's tier (giggles at first, then the letters asking you to play the
## game), some tiers make the letters sulk and ignore taps for a moment, and past thresholds
## other voices chime in (the voice of reason, then the last word). A sulk comes on entering its
## tier and the letters don't forget while they sulk. Lines, speakers, tiers,
## thresholds and decay are all in data/title_letters.json; the letters' cells and places come
## from data/title_wordmark.json (tools/gen_brand_art.py). Touch-first: a finger tap is a tap.
## Taps go through _unhandled_input, so the menu's buttons (Controls) always win over letters.

const DATA := "res://data/title_letters.json"
const LAYOUT := "res://data/title_wordmark.json"
const HEART := "res://assets/ui/title/charm_heart.png"
const BUBBLE := "res://scenes/ui/bark_bubble.tscn"
const BUBBLE_WIDTH := 170.0       # the letters' lines get long; the bubble wraps past this
const ASIDE_POS := Vector2(548, 318)   # where the chime-ins speak from (bottom right, over the sea)
const HEART_SECONDS := 0.9

## Where the wordmark sits on the 640x360 menu (what the one-piece wordmark used to fill).
@export var rect := Rect2(150, 10, 340, 57)

var data: Dictionary = {}
var layout: Dictionary = {}
var letters: Array[Node2D] = []   # holders; each has a Sprite and a BarkBubble
var count := 0.0                  # taps, decaying
var sulk_left := 0.0
var spoken: Array[Dictionary] = []   # {"speaker": id, "text": line}, in order (for tests)
var _hard: Array[float] = []      # per letter, the extra jiggle left after a tap
var _tier_next: Dictionary = {}   # tier index -> which of its lines comes next
var _chimed: Dictionary = {}      # chime-in index -> fired since the counter was last below its min
var _aside: Node2D
var _aside_bubble: Label
var _time := 0.0
var _own_clock := 0.0
var _hearts := 0


func _ready() -> void:
	data = _json(DATA)
	layout = _json(LAYOUT)
	_build()


static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


# --- Data (pure; tests/test_title_anim.gd checks it) -----------------------------------------

## The tier (from `tiers`, each with "min") that covers `taps`, or {} below the first one.
static func tier_for(taps: int, tiers: Array) -> Dictionary:
	var best := {}
	for t: Dictionary in tiers:
		if taps >= int(t.get("min", 1)) and int(t.get("min", 1)) >= int(best.get("min", -1)):
			best = t
	return best


func tiers() -> Array:
	return data.get("tiers", [])


func chime_ins() -> Array:
	return data.get("chime_ins", [])


func speaker(role: String) -> String:
	return String(data.get("speakers", {}).get(role, role))


# --- Building --------------------------------------------------------------------------------

func _build() -> void:
	var sheet: Texture2D = load(String(layout.get("sheet", "res://assets/ui/title/wordmark_letters.png")))
	var k := rect.size.x / float(layout.get("width", 1600))
	var bubble_scene: PackedScene = load(BUBBLE)
	for i in (layout.get("letters", []) as Array).size():
		var l: Dictionary = layout["letters"][i]
		var cell: Array = l["cell"]
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(float(cell[0]), float(cell[1]), float(cell[2]), float(cell[3]))
		var holder := Node2D.new()
		holder.name = "Letter%d%s" % [i, String(l.get("ch", ""))]
		holder.position = rect.position + (Vector2(float(l["x"]), float(l["y"])) + Vector2(float(cell[2]), float(cell[3])) / 2.0) * k
		add_child(holder)
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = at
		sprite.scale = Vector2(k, k)
		holder.add_child(sprite)
		var bubble: Label = bubble_scene.instantiate()
		bubble.name = "BarkBubble"
		bubble.max_width = BUBBLE_WIDTH
		bubble.set_meta("hang", float(cell[3]) * k / 2.0 + 4.0)   # the letters sit at the top edge: bubbles hang below them
		holder.add_child(bubble)
		var tail: Control = bubble.get_node("Tail")
		tail.flip_v = true
		letters.append(holder)
		_hard.append(0.0)
	_aside = Node2D.new()
	_aside.name = "Aside"
	_aside.position = ASIDE_POS
	add_child(_aside)
	_aside_bubble = bubble_scene.instantiate()
	_aside_bubble.name = "BarkBubble"
	_aside_bubble.max_width = BUBBLE_WIDTH
	_aside_bubble.bottom = -4.0
	_aside.add_child(_aside_bubble)


# --- The beat --------------------------------------------------------------------------------

## Seconds into the title theme: the backdrop's (it follows Music), else a clock of our own.
func track_pos() -> float:
	var bd: Node = get_parent().get_node_or_null("Backdrop") if get_parent() else null
	if bd != null and "track_pos" in bd:
		return float(bd.track_pos)
	return _own_clock


## 0..1 through the current beat.
func beat_phase() -> float:
	var bpm := float(data.get("bpm", 84))
	return fposmod(track_pos() * bpm / 60.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	_own_clock += delta
	if sulk_left <= 0.0:                                     # sulking letters don't forget
		count = maxf(count - float(data.get("decay_per_second", 0.4)) * delta, 0.0)
	for i in chime_ins().size():
		if count < float(chime_ins()[i].get("min", 999)):
			_chimed.erase(i)
	sulk_left = maxf(sulk_left - delta, 0.0)
	var hard_seconds := float(data.get("hard_jiggle_seconds", 0.8))
	var phase := beat_phase()
	var sulk := clampf(sulk_left, 0.0, 1.0)
	for i in letters.size():
		_hard[i] = maxf(_hard[i] - delta / hard_seconds, 0.0)
		var sprite: Sprite2D = letters[i].get_node("Sprite")
		var ph := fposmod(phase - i * 0.07, 1.0)
		var pulse := exp(-5.0 * ph)                              # a bounce right on the beat, settling
		var boost := 1.0 + 4.0 * _hard[i]
		var base: float = sprite.scale.x / maxf(sprite.scale.x, 0.0001)   # 1
		var k := rect.size.x / float(layout.get("width", 1600))
		var s := k * (1.0 + 0.05 * pulse * boost * base)
		sprite.scale = Vector2(s * (1.0 + 0.03 * _hard[i] * sin(_time * 40.0)), s)
		sprite.rotation = 0.04 * sin(TAU * phase + i) * (0.5 + boost) * (1.0 - sulk) + sulk * (0.22 if i % 2 == 0 else -0.16)
		sprite.position = Vector2(0.0, -2.5 * pulse * boost * (1.0 - sulk) + 5.0 * sulk)


# --- Taps ------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not pressed:
		return
	var local: InputEvent = make_input_local(event)
	var i := letter_at(local.position)
	if i >= 0:
		get_viewport().set_input_as_handled()
		tap(i)


## Which letter is under `point` (in this node's coordinates), or -1.
func letter_at(point: Vector2) -> int:
	for i in letters.size():
		var sprite: Sprite2D = letters[i].get_node("Sprite")
		var in_sprite: Vector2 = (letters[i].transform * sprite.transform).affine_inverse() * point
		if sprite.get_rect().has_point(in_sprite):
			return i
	return -1


## A tap on letter `i`: harder jiggle, hearts, a line from the tier the counter lands in, a
## sulk if the tier says so, and any chime-in whose threshold the counter just crossed.
func tap(i: int) -> void:
	if i < 0 or i >= letters.size() or sulk_left > 0.0:
		return
	count += 1.0
	_hard[i] = 1.0
	var tier := tier_for(int(count), tiers())
	if tier.get("hearts", false):
		_pop_hearts(letters[i])
	var lines: Array = tier.get("lines", [])
	if not lines.is_empty():
		var idx: int = tiers().find(tier)
		var n: int = _tier_next.get(idx, 0)
		_say(letters[i], speaker("letters"), String(lines[n % lines.size()]))
		_tier_next[idx] = n + 1
	if int(count - 1.0) < int(tier.get("min", 1)):           # a sulk on entering its tier, not every tap in it
		sulk_left = float(tier.get("sulk_seconds", 0.0))
	for c in chime_ins().size():
		var chime: Dictionary = chime_ins()[c]
		if count >= float(chime.get("min", 999)) and not _chimed.get(c, false):
			_chimed[c] = true
			_say(_aside, speaker(String(chime.get("speaker", "reason"))), String(chime.get("line", "")))


func _say(who: Node2D, speaker_id: String, line: String) -> void:
	spoken.append({"speaker": speaker_id, "text": line})
	if who != _aside:                                         # the letters are one voice: one bubble at a time
		for other in letters:
			if other != who:
				other.get_node("BarkBubble").hide()
	var bubble: Label = who.get_node("BarkBubble")
	bubble.say(line)
	_hang(bubble)
	var voice := get_node_or_null("/root/Voice")
	if voice != null and voice.has_method("speak"):
		voice.speak(line, 1.0, speaker_id)
	var timer := get_tree().create_timer(maxf(1.6, 0.06 * line.length()))
	timer.timeout.connect(func() -> void:
		if is_instance_valid(bubble) and bubble.text == line:
			bubble.hide())


## A letter's bubble hangs below it (the wordmark is at the top of the screen, so a bubble over
## it would be off screen) with its tail flipped up; the chime-ins' bubble keeps the default.
func _hang(bubble: Label) -> void:
	if not bubble.has_meta("hang"):
		return
	bubble.position.y = float(bubble.get_meta("hang"))
	var tail: Control = bubble.get_node("Tail")
	tail.position.y = -tail.size.y + 1.0


func _pop_hearts(holder: Node2D) -> void:
	var tex: Texture2D = load(HEART)
	for n in int(data.get("hearts_per_tap", 3)):
		var h := Sprite2D.new()
		_hearts += 1
		h.name = "Heart%d" % _hearts
		h.texture = tex
		h.scale = Vector2(0.1, 0.1)
		h.position = Vector2(randf_range(-6.0, 6.0), -4.0)
		holder.add_child(h)
		var tw := h.create_tween().set_parallel(true)
		tw.tween_property(h, "position", h.position + Vector2(randf_range(-14.0, 14.0), -randf_range(18.0, 30.0)), HEART_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(h, "modulate:a", 0.0, HEART_SECONDS).set_delay(HEART_SECONDS * 0.4)
		tw.tween_property(h, "scale", Vector2(0.16, 0.16), HEART_SECONDS)
		tw.chain().tween_callback(h.queue_free)


## Hearts in the air right now (for tests).
func hearts_flying() -> int:
	var n := 0
	for holder in letters:
		for c in holder.get_children():
			if c.name.begins_with("Heart"):
				n += 1
	return n
