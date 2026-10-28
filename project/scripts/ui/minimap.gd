extends PanelContainer
## The map card (bd ctw, author 2026-10-24: "one of those little overhead maps where it shows
## waypoints on it ... if you had a little cute version of that"): the map sticker or M
## (toggle_map) opens it in the top left, under the clock tag. It shows the whole area in
## miniature, drawn by a second camera over the area's own world (a SubViewport sharing its
## World2D, so it is the real map, small, without the HUD); over it every way out (each door,
## group "doors") is a heart pin named with where it leads, the player is a plum dot, and a white
## frame marks what the screen shows now, which grows when the view zooms out one level. Tapping
## or clicking a pin walks the player to that door, as clicking the door itself would. Pointer and
## touch only: no focus, so a gamepad never lands on it (QA-13). map.gd makes and frees it.

## The miniature fits in this many viewport px and keeps the area's shape.
const MAX_SIZE := Vector2(180.0, 108.0)
## The miniature's own px per viewport px, so it stays sharp in the 1280x720 window.
const RENDER_SCALE := 2
## How near a tap must land to a pin to take it (viewport px).
const PIN_REACH := 10.0
## A pin's heart, centre to its widest side (viewport px).
const HEART := 4.5
const PLUM := Color("#593859")
const PIN_PINK := Color("#ff8cbf")
const PIN_LOCKED := Color("#c9b3d6")
const FRAME := Color(1.0, 1.0, 1.0, 0.9)

## The map this card shows (map.gd sets it before adding the card); else the current scene.
var map: Node
## The world rect shown: the map's size, or a screen-sized patch around the player without one.
var area := Rect2()
## The miniature's size in viewport px.
var mini_size := Vector2.ZERO

var _scale := 1.0  # viewport px per world px
var _view: SubViewport
var _cam: Camera2D
var _pins: Control
var _doors: Array[Node2D] = []
var _labels: Array[Label] = []
var _t := 0.0


func _ready() -> void:
	name = "Minimap"
	theme_type_variation = &"HudPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP  # a tap on the card is not a walk to the ground under it
	focus_mode = Control.FOCUS_NONE
	position = Vector2(6, 27)
	var clock := get_parent().get_node_or_null("Clock") as Control
	if clock:  # just under the clock tag, whatever the text size makes it
		position = Vector2(clock.position.x, clock.position.y + clock.size.y + 3.0)
	if map == null:
		map = get_tree().current_scene
	var map_size := Vector2.ZERO
	if map != null and "map_size" in map:
		map_size = map.map_size
	if map_size.x > 0.0 and map_size.y > 0.0:
		area = Rect2(Vector2.ZERO, map_size)
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		var c := player.global_position if player else Vector2.ZERO
		area = Rect2(c - Vector2(480.0, 270.0), Vector2(960.0, 540.0))
	_scale = minf(MAX_SIZE.x / area.size.x, MAX_SIZE.y / area.size.y)
	mini_size = (area.size * _scale).round()

	var holder := Control.new()
	holder.name = "Miniature"
	holder.custom_minimum_size = mini_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_view = SubViewport.new()
	_view.name = "View"
	_view.size = Vector2i(mini_size * RENDER_SCALE)
	_view.world_2d = get_viewport().world_2d
	_view.disable_3d = true
	_view.gui_disable_input = true
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	holder.add_child(_view)
	_cam = Camera2D.new()
	_cam.name = "Camera"
	_cam.position = area.get_center()
	_cam.zoom = Vector2.ONE * _scale * RENDER_SCALE
	_view.add_child(_cam)
	_cam.make_current()
	var ground := TextureRect.new()
	ground.name = "Ground"
	ground.texture = _view.get_texture()
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.stretch_mode = TextureRect.STRETCH_SCALE
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ground)
	_pins = Control.new()
	_pins.name = "Pins"
	_pins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pins.mouse_filter = Control.MOUSE_FILTER_STOP
	_pins.focus_mode = Control.FOCUS_NONE
	_pins.draw.connect(_draw_pins)
	_pins.gui_input.connect(_on_pins_input)
	holder.add_child(_pins)
	_add_doors()


func _add_doors() -> void:
	for n in get_tree().get_nodes_in_group("doors"):
		var door := n as Node2D
		if door == null or not door.is_visible_in_tree() or (map != null and not map.is_ancestor_of(door)):
			continue
		_doors.append(door)
		var l := Label.new()
		l.text = door.destination_name() if door.has_method("destination_name") else ""
		l.add_theme_color_override("font_color", PLUM)
		l.add_theme_color_override("font_outline_color", Color.WHITE)
		l.add_theme_constant_override("outline_size", 3)
		l.add_theme_font_size_override("font_size", 7)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pins.add_child(l)
		_labels.append(l)
		var s := l.get_minimum_size()
		l.size = s
		var p := mini_point(door.global_position)
		var at := Vector2(p.x - s.x / 2.0, p.y - HEART - s.y - 1.0)  # over its pin
		if at.y < 0.0:
			at.y = p.y + HEART + 2.0  # no room over it: under it
		at.x = clampf(at.x, 0.0, maxf(0.0, mini_size.x - s.x))
		at.y = clampf(at.y, 0.0, maxf(0.0, mini_size.y - s.y))
		l.position = at


## Where a world position sits on the miniature, in its own px from its top-left corner (a door
## or player past the area's edge sits on the edge).
func mini_point(world: Vector2) -> Vector2:
	return ((world - area.position) * _scale).clamp(Vector2.ZERO, mini_size)


## The doors shown as pins, in the order they were found.
func waypoints() -> Array[Node2D]:
	return _doors


## The names on the pins, in the same order.
func waypoint_names() -> PackedStringArray:
	var out := PackedStringArray()
	for l in _labels:
		out.append(l.text)
	return out


## What the screen shows now, on the miniature and inside it; empty when there is no camera.
func view_frame() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null or cam.zoom.x <= 0.0:
		return Rect2()
	var half := get_viewport().get_visible_rect().size / cam.zoom / 2.0
	var shown := Rect2(cam.get_screen_center_position() - half, half * 2.0)
	var r := Rect2((shown.position - area.position) * _scale, shown.size * _scale)
	return r.intersection(Rect2(Vector2.ZERO, mini_size))


## A tap or click on the miniature at `at` (its own px): the nearest pin within PIN_REACH sends the
## player walking to that door (they go through it on arrival). Returns the door, or null.
func tap(at: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := PIN_REACH
	for door in _doors:
		if not is_instance_valid(door):
			continue
		var d := at.distance_to(mini_point(door.global_position))
		if d <= best_d:
			best = door
			best_d = d
	var player := get_tree().get_first_node_in_group("player")
	if best != null and player != null and player.has_method("approach"):
		player.approach(best)
	return best


func _on_pins_input(event: InputEvent) -> void:
	if event.is_action_pressed("click") or (event is InputEventScreenTouch and event.pressed):
		_pins.accept_event()
		tap(event.position)


func _process(delta: float) -> void:
	_t += delta
	_pins.queue_redraw()


func _draw_pins() -> void:
	var f := view_frame()
	if f.has_area():
		_pins.draw_rect(f, FRAME, false, 1.0)
	for door in _doors:
		if is_instance_valid(door):
			_draw_heart(mini_point(door.global_position), PIN_LOCKED if door.get("locked") == true else PIN_PINK)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var p := mini_point(player.global_position)
		var r := 2.6 + 0.5 * sin(_t * TAU / 1.6)  # a slow, small pulse
		_pins.draw_circle(p, r + 1.2, Color.WHITE)
		_pins.draw_circle(p, r, PLUM)


func _draw_heart(at: Vector2, fill: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var t := TAU * float(i) / 24.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(at + Vector2(x, y + 2.0) * (HEART / 16.0))
	_pins.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	_pins.draw_polyline(pts, PLUM, 1.0, true)
