extends Area2D
## Door — proximity map transition, or a locked door with a bark.
## Also used for mini-game entrances (a mini-game is just another scene).
## Every door shows a little kawaii doormat with a bobbing arrow (assets/common/door_marker.png,
## drawn by tools/gen_door_marker.py: 160x192 frames stored at 4x, shown 48 px tall; row 0 "open" x 8,
## row 1 "locked"), names where it goes
## when hovered or when the player is close, and can be clicked: the player walks over
## and goes through, like approaching an NPC.

const NEAR_DISTANCE := 72.0
const MARKER_SHEET := "res://assets/common/door_marker.png"
const MARKER_FRAME := Vector2i(160, 192)  # file px
## A frame is shown this tall (world px; SpriteFit), smoothly filtered.
const MARKER_HEIGHT := 48.0
const MARKER_FRAMES := 8
## The mat's centre, as a fraction of the frame height (centred across), is put on the door's
## origin. The mat lies on the floor: it draws under everyone standing (z -1, above the ground).
const MARKER_MAT := 144.0 / 192.0

static var _marker_frames: SpriteFrames

@export var target_scene := ""  # res:// path
@export var target_spawn := "spawn_default"
@export var locked := false
@export var locked_bark := "It is sealed."
## Shown on hover/proximity, e.g. "Back to the Temple". Empty: named from target_scene.
@export var exit_label := ""
## Off for entrances that already have their own prop (the ritual table).
@export var show_marker := true

@onready var label: Label = $Label

var _name_label: Label
var _hovered := false
var _gone := false
var _marker: AnimatedSprite2D


func _ready() -> void:
	label.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	input_event.connect(_on_input_event)
	mouse_entered.connect(func() -> void: _hovered = true)
	mouse_exited.connect(func() -> void: _hovered = false)
	_name_label = label.duplicate() as Label
	_name_label.name = "NameLabel"
	_name_label.text = destination_name()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if show_marker:  # sit above the marker's arrow
		_name_label.offset_top -= 12.0
		_name_label.offset_bottom -= 12.0
	_name_label.hide()
	add_child(_name_label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	_name_label.z_index = 20
	if show_marker:
		_marker = AnimatedSprite2D.new()
		_marker.name = "Marker"
		_marker.sprite_frames = marker_frames()
		_marker.z_index = -1
		add_child(_marker)
		_marker.play("locked" if locked else "open")
		SpriteFit.fit(_marker, MARKER_HEIGHT, MARKER_MAT)


## The marker's animations, cut from the sheet once and shared by every door.
static func marker_frames() -> SpriteFrames:
	if _marker_frames == null:
		var sheet: Texture2D = load(MARKER_SHEET)
		_marker_frames = SpriteFrames.new()
		_marker_frames.remove_animation("default")
		for row: int in 2:
			var anim: String = ["open", "locked"][row]
			_marker_frames.add_animation(anim)
			_marker_frames.set_animation_speed(anim, 8.0)
			_marker_frames.set_animation_loop(anim, true)
			for i in (MARKER_FRAMES if row == 0 else 1):
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(Vector2(i * MARKER_FRAME.x, row * MARKER_FRAME.y), Vector2(MARKER_FRAME))
				_marker_frames.add_frame(anim, at)
	return _marker_frames


func destination_name() -> String:
	if exit_label != "":
		return exit_label
	var base := target_scene.get_file().get_basename().trim_prefix("ruins_").replace("_", " ")
	return "To the " + base.capitalize()


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var near := player != null and player.global_position.distance_to(global_position) <= NEAR_DISTANCE
	_name_label.visible = (_hovered or near) and not label.visible


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("click"):
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.approach(self)
			get_viewport().set_input_as_handled()


## Called by the player on arrival after clicking the door.
func interact() -> void:
	if locked:
		label.text = locked_bark
		label.show()
		return
	_go()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if locked:
		label.text = locked_bark
		label.show()
		return
	_go()


func _go() -> void:
	if _gone:
		return
	_gone = true
	SceneRouter.goto_map(target_scene, target_spawn)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		label.hide()
