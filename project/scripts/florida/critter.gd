extends "res://scripts/florida/clickable.gd"
## Critter — dolphin, crab, gull or aquarium mermaid. Drifts around its patch; clicking it
## triggers a surprise that depends on what the paper doll is wearing (data/florida.json).
## Every outfit gets a delighted reaction. Nobody is judged.
## With a gift in the inventory (or once it is a good friend) clicking opens its gift panel:
## Say hi, one Give button per gift, and the kind's unlock (Florida "gifts"; every gift is welcome).

@export var kind := "crab"
@export var wander := Rect2(0, 0, 100, 60)  # global rect it drifts inside
@export var nickname := ""  # cast id, one of the kind's "names" in florida.json
## Rigged sheet: res://assets/florida/<sprite_frames or kind>.tres (idle, walk; faces right).
@export var sprite_frames := ""

## Heart art for the gift panel (ui_heart_full / ui_heart_empty in assets/florida); until it
## exists the panel shows the hearts as text only.
const HEART_ART := "res://assets/florida/ui_heart_%s.png"
## A following crab takes a step toward the player this often (s), and stops this far beside them.
const FOLLOW_STEP := 0.6
const FOLLOW_GAP := 22.0
## Every open gift panel is in this group: opening one closes the others (one panel at a time).
const PANEL_GROUP := "florida_gift_panel"
## A line stays in the bubble this long (s); a new line restarts the wait.
const BUBBLE_TIME := 3.0

@onready var bubble: Label = $BarkBubble
@onready var sprite: AnimatedSprite2D = $Sprite

var _busy := false
var _panel: CanvasLayer
var _move: Tween
var _bubble_timer: SceneTreeTimer


func _ready() -> void:
	super()
	# Following lasts one visit: a crab met again on a new visit is back on its own patch.
	if nickname != "" and Florida.following() == nickname:
		Florida.set_following("")
	var path := "res://assets/florida/%s.tres" % (sprite_frames if sprite_frames != "" else kind)
	if ResourceLoader.exists(path):
		sprite.sprite_frames = load(path)
		sprite.play("idle")
		sprite.frame = randi() % sprite.sprite_frames.get_frame_count("idle")
		SpriteFit.fit_sheet(sprite)  # feet (or a swimmer's belly line) on the origin
		bubble.bottom = -SpriteFit.frame_size(sprite).y * sprite.scale.y - 4.0
		PaperBake.dress_frames(sprite)  # the paper look (tools/bake_paper.sh florida_cast)
	bubble.hide()
	if DisplayServer.get_name() != "headless":
		_drift()


func _drift() -> void:
	if not is_inside_tree():
		return
	if _is_following():
		_follow()
		return
	var target := wander.position + Vector2(randf() * wander.size.x, randf() * wander.size.y)
	var tw := create_tween()
	_move = tw
	tw.tween_interval(randf_range(0.5, 3.0))
	tw.tween_callback(func() -> void:
		sprite.flip_h = target.x < global_position.x
		_anim("walk"))
	tw.tween_property(self, "global_position", target, randf_range(2.0, 5.0)).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: _anim("idle"))
	tw.tween_callback(_drift)


## A crab walking with the player: a step toward a spot beside them every FOLLOW_STEP seconds,
## back to drifting once it is told to stay.
func _follow() -> void:
	if not is_inside_tree():
		return
	if not _is_following():
		_anim("idle")
		_drift()
		return
	var tw := create_tween()
	_move = tw
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var spot := global_position
	if player:
		var side := 1.0 if global_position.x >= player.global_position.x else -1.0
		spot = _walkable(player.global_position + Vector2(FOLLOW_GAP * side, 4.0))
	if global_position.distance_to(spot) > 4.0:
		sprite.flip_h = spot.x < global_position.x
		_anim("walk")
		tw.tween_property(self, "global_position", spot, FOLLOW_STEP)
	else:
		_anim("idle")
		tw.tween_interval(FOLLOW_STEP)
	tw.tween_callback(_follow)


func _is_following() -> bool:
	return nickname != "" and Florida.following() == nickname


## The closest point to `spot` on the map's walkable ground (the player's navigation), so a
## following crab doesn't step into the sea or a prop; `spot` itself on a map without one.
func _walkable(spot: Vector2) -> Vector2:
	var map := get_world_2d().navigation_map
	if NavigationServer2D.map_get_regions(map).is_empty():
		return spot
	return NavigationServer2D.map_get_closest_point(map, spot)


## A crab walking with the player is always near her, so the interact key passes it over for
## anything else in range (player.gd interact_nearest); it is still a click or a lone E away.
func is_companion() -> bool:
	return _is_following()


## Stops the current drift or follow step and starts moving the new way (not in headless runs,
## where critters stand still).
func _restart_moving() -> void:
	if _move and _move.is_valid():
		_move.kill()
	_anim("idle")
	if DisplayServer.get_name() != "headless":
		_drift()


func _anim(name: String) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(name):
		sprite.play(name)


func interact() -> void:
	if _panel and is_instance_valid(_panel):
		return
	if Florida.giftable_in_inventory().is_empty() and not Florida.has_unlock(_who(), kind):
		surprise()
		return
	for other in get_tree().get_nodes_in_group(PANEL_GROUP):
		other.queue_free()
	_panel = CanvasLayer.new()
	_panel.name = "GiftPanel"
	_panel.layer = 15
	_panel.add_to_group(PANEL_GROUP)
	add_child(_panel)
	_build_panel()


## Plays the surprise for the doll's current outfit; returns the surprise entry used.
func surprise() -> Dictionary:
	var s := Florida.surprise_for(kind, Florida.current_outfit())
	if s.is_empty() or _busy:
		return s
	_busy = true
	_play(s.get("effect", "hop"))
	var lines: Array = s.get("lines", [])
	if not lines.is_empty():
		_speak(lines.pick_random())
	return s


## The critter's bubble (name: line), spoken through Voice.
func _speak(text: String) -> void:
	if text == "" or not is_inside_tree():
		return
	bubble.say("%s: %s" % [Cast.short(nickname), text] if nickname != "" else text)
	Voice.speak(text, float(Florida.data()["critters"][kind].get("pitch", 1.0)), kind)
	if _bubble_timer and _bubble_timer.timeout.is_connected(bubble.hide):
		_bubble_timer.timeout.disconnect(bubble.hide)
	_bubble_timer = get_tree().create_timer(BUBBLE_TIME)
	_bubble_timer.timeout.connect(bubble.hide)


## Plays `effect` (unless one is already playing) and says `text`.
func _react(effect: String, text: String) -> void:
	if not _busy:
		_busy = true
		_play(effect)
	_speak(text)


## Who keeps the hearts: the critter's cast id (its kind, for an unnamed one).
func _who() -> String:
	return nickname if nickname != "" else kind


# --- gift panel --------------------------------------------------------------

func _build_panel() -> void:
	if not _panel or not is_instance_valid(_panel) or _panel.is_queued_for_deletion():
		return
	for c in _panel.get_children():
		_panel.remove_child(c)
		c.queue_free()
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Buttons"
	panel.add_child(box)
	var title := Label.new()
	title.name = "Title"
	title.text = Cast.short(nickname) if nickname != "" else kind.capitalize()
	box.add_child(title)
	box.add_child(_hearts_row())
	_panel_button(box, "SayHi", "Say hi", _say_hi)
	for item: String in Florida.giftable_in_inventory():
		_panel_button(box, "Give_%s" % item, "Give %s (%d)" % [Florida.label(item), Florida.count(item)], _give.bind(item))
	if Florida.has_unlock(_who(), kind):
		var unlock := Florida.unlock_for(kind)
		var text: String = unlock.get("label_off", unlock["label"]) if _is_following() else unlock["label"]
		_panel_button(box, "Unlock", text, _unlock)
	_panel_button(box, "Close", "Close", _close)


## "Friendship: n / max", with a row of hearts in front once the heart art exists.
func _hearts_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Hearts"
	var n := Florida.hearts(_who())
	if ResourceLoader.exists(HEART_ART % "full") and ResourceLoader.exists(HEART_ART % "empty"):
		for i in Florida.max_hearts():
			var heart := TextureRect.new()
			heart.texture = load(HEART_ART % ("full" if i < n else "empty"))
			heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(heart)
	var count := Label.new()
	count.name = "Count"
	count.text = "Friendship: %d / %d" % [n, Florida.max_hearts()]
	row.add_child(count)
	return row


func _panel_button(box: VBoxContainer, id: String, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = id
	b.text = text
	b.pressed.connect(action)
	box.add_child(b)
	return b


func _say_hi() -> void:
	surprise()


func _give(item: String) -> void:
	var r := Florida.give(_who(), kind, item, GameClock.day)
	if r.is_empty():
		return
	_react(r["effect"], r["line"])
	var cheer := Florida.gift_float(r)
	if cheer != "":
		float_text(cheer)
	_build_panel.call_deferred()


## The kind's good-friend thing: a dolphin trick, a mermaid bubble trick, a crab that walks with
## you, a gull that brings a shell a day.
func _unlock() -> void:
	var unlock := Florida.unlock_for(kind)
	var effect: String = unlock.get("effect", "hop")
	match unlock.get("id", ""):
		"follow":
			if _is_following():
				Florida.set_following("")
				_react(effect, Florida.unlock_line(kind, "lines_off"))
			else:
				Florida.set_following(nickname)
				_react(effect, Florida.unlock_line(kind))
			_restart_moving()
		"shell":
			if Florida.gull_shell(_who(), GameClock.day):
				_react(effect, Florida.unlock_line(kind))
				float_text("+1 %s" % Florida.label("shell"))
			else:
				_speak(Florida.unlock_line(kind, "lines_none"))
		"trick", "bubbles":
			_react(effect, Florida.unlock_line(kind))
	_build_panel.call_deferred()


func _close() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()


func _play(effect: String) -> void:
	var tw := create_tween()
	match effect:
		"jump":
			tw.tween_property(sprite, "position:y", -34.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(sprite, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		"spin":
			tw.tween_property(sprite, "rotation", TAU, 0.7)
			tw.tween_callback(func() -> void: sprite.rotation = 0.0)
		"wiggle":
			for i in 3:
				tw.tween_property(sprite, "rotation", 0.3, 0.1)
				tw.tween_property(sprite, "rotation", -0.3, 0.1)
			tw.tween_property(sprite, "rotation", 0.0, 0.1)
		"flip":
			tw.tween_method(_flip_step, 0.0, 1.0, 0.8)
			tw.tween_callback(func() -> void: sprite.rotation = 0.0)
		_:
			tw.tween_property(sprite, "position:y", -12.0, 0.15)
			tw.tween_property(sprite, "position:y", 0.0, 0.15)
			tw.tween_property(sprite, "position:y", -8.0, 0.12)
			tw.tween_property(sprite, "position:y", 0.0, 0.12)
	tw.tween_callback(func() -> void: _busy = false)


## The dolphin's trick: a big leap with a full spin (t runs 0 to 1).
func _flip_step(t: float) -> void:
	sprite.position.y = -48.0 * sin(PI * t)
	sprite.rotation = TAU * t
