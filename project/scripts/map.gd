extends Node2D
## Map — common behavior for every map area: place the player at the requested
## spawn marker, build the HUD (clock + calendar); P (or the hanger sticker) toggles the
## wardrobe, J (or the book sticker) the journal.

const WARDROBE_SCENE := "res://scenes/ui/wardrobe.tscn"

## Pixel size of the map; the camera stops at its edge. Zero leaves the camera free.
## Maps are y-sorted: characters and props have their origin on their feet and no z_index of
## their own, so they sort by where they stand (behind a pillar's top, in front of its base);
## ground art sits at negative z_index.
@export var map_size := Vector2.ZERO
## Paper look (bd gsd) for a hand-made map (the Florida maps): when it loads, each prop drawn by a
## Sprite2D child of the map whose art tools/bake_paper.sh baked shows its bordered sheet over a
## soft shadow (PaperBake.dress), once; nothing runs per frame. Maps built by
## tools/build_island_maps.gd have the sheets in the scene already and leave this off.
@export var paper_props := false

var _hud_label: Label
var _wardrobe: CanvasLayer
var _journal: CanvasLayer
const JOURNAL_SCRIPT := preload("res://scripts/ui/journal.gd")
const HUD_ICON := preload("res://assets/canon/prop_calendar.png")


func _ready() -> void:
	# Doors and NPCs are Area2Ds clicked through input_event, which needs picking on.
	get_viewport().physics_object_picking = true
	# Ponies stay in Florida: arriving anywhere else, the rider has already hopped down.
	if not scene_file_path.contains("/florida/") and WorldState.get_flag("fl_riding", "") != "":
		WorldState.set_flag("fl_riding", "")
	if paper_props:
		for c in get_children():
			if c is Sprite2D:
				PaperBake.dress(c as Sprite2D)
	_spawn_player()
	_limit_camera()
	_build_hud()
	GameClock.phase_changed.connect(func(_p: String) -> void: _update_hud())
	GameClock.day_changed.connect(func(_d: int) -> void: _update_hud())


func _spawn_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var marker := find_child(SceneRouter.next_spawn, true, false)
	if marker == null:
		marker = find_child("spawn_default", true, false)
	if player and marker:
		player.global_position = (marker as Node2D).global_position


func _limit_camera() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var cam: Camera2D = player.get_node_or_null("Camera2D") if player else null
	if cam and map_size != Vector2.ZERO:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(map_size.x)
		cam.limit_bottom = int(map_size.y)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	# A small cream tag (theme HudPanel) with the canon Calendar of Blood as its icon.
	var tag := PanelContainer.new()
	tag.name = "Clock"
	tag.theme_type_variation = &"HudPanel"
	tag.position = Vector2(6, 5)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tag)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	tag.add_child(row)
	var icon := TextureRect.new()
	icon.texture = HUD_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(15, 14)
	row.add_child(icon)
	_hud_label = Label.new()
	_hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_hud_label)
	# Tap stickers under the settings gear for the wardrobe and the journal, so a finger or a
	# mouse alone reaches what P and J open (bd ctw, QA-07).
	for pair: Array in [["WardrobeSticker", "hanger", 1, toggle_wardrobe], ["JournalSticker", "book", 2, toggle_journal],
			["ZoomSticker", "zoom", 3, toggle_zoom], ["HelpSticker", "help", 4, toggle_help]]:
		var s := StickerButton.new()
		s.name = pair[0]
		s.kind = pair[1]
		s.slot = pair[2]
		s.pressed.connect(pair[3])
		layer.add_child(s)
	_hud_layer = layer
	_update_hud()


func _update_hud() -> void:
	if _hud_label:
		_hud_label.text = GameClock.status_text()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_wardrobe"):
		toggle_wardrobe()
	elif event.is_action_pressed("toggle_journal"):
		toggle_journal()
	elif event.is_action_pressed("zoom_out"):
		set_zoom_level(1)
	elif event.is_action_pressed("zoom_in"):
		set_zoom_level(0)
	elif event.is_action_pressed("toggle_help"):
		toggle_help()
	elif event is InputEventMagnifyGesture:  # a trackpad pinch
		set_zoom_level(0 if event.factor > 1.0 else 1)
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		_pinch(event)


## --- Zoom (bd ctw: "at least zoom out to one level" to see what is around in crowded places) ---
## ZOOMS are the camera zooms: 0 the normal view, 1 one level out. The +/- keys, the wheel, the
## pad's shoulders, a pinch and the magnifier sticker move between them; the sticker shows which
## way it will go.
const ZOOMS := [2.0, 1.25]
const PINCH_STEP := 40.0  # px the fingers must move apart or together
var zoom_level := 0
var _touches := {}  # finger index -> position
var _pinch_start := 0.0
var _hud_layer: CanvasLayer
var _help: PanelContainer


func set_zoom_level(level: int) -> void:
	level = clampi(level, 0, ZOOMS.size() - 1)
	zoom_level = level
	var player := get_tree().get_first_node_in_group("player")
	var cam: Camera2D = player.get_node_or_null("Camera2D") if player else null
	if cam:
		var z: float = ZOOMS[level]
		create_tween().tween_property(cam, "zoom", Vector2(z, z), 0.25)
	var s := _hud_layer.get_node_or_null("ZoomSticker") if _hud_layer else null
	if s:
		s.set_icon("zoom_in" if level > 0 else "zoom_out")


func toggle_zoom() -> void:
	set_zoom_level(0 if zoom_level > 0 else 1)


func _pinch(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed:
		_touches.erase(event.index)
		return
	_touches[event.index] = event.position
	if _touches.size() != 2:
		_pinch_start = 0.0
		return
	var pts := _touches.values()
	var d: float = pts[0].distance_to(pts[1])
	if _pinch_start == 0.0:
		_pinch_start = d
	elif d - _pinch_start > PINCH_STEP:
		set_zoom_level(0)
		_pinch_start = d
	elif _pinch_start - d > PINCH_STEP:
		set_zoom_level(1)
		_pinch_start = d


## --- Help (bd ctw): the "?" sticker or F1 opens how to play with each kind of input. ---
func toggle_help() -> void:
	if _help and _help.visible:
		_help.shut()
		return
	if _help == null:
		_help = preload("res://scripts/ui/help_panel.gd").new()
		var center := CenterContainer.new()
		center.name = "HelpCenter"
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(_help)
		_hud_layer.add_child(center)
	_help.refresh()
	_help.show()


func help_open() -> bool:
	return _help != null and _help.visible


func toggle_journal() -> void:
	if _journal and is_instance_valid(_journal):
		_journal.queue_free()
		_journal = null
		return
	_journal = JOURNAL_SCRIPT.new()
	add_child(_journal)


func toggle_wardrobe() -> void:
	if _wardrobe and is_instance_valid(_wardrobe):
		_wardrobe.queue_free()
		_wardrobe = null
		return
	_wardrobe = load(WARDROBE_SCENE).instantiate()
	add_child(_wardrobe)
