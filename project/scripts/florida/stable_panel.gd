extends CanvasLayer
## StablePanel — the grooming panel for one pony (the paper-doll makeover, on a pony): a big
## PonyDoll preview, Brush, mane style and accessory pickers, Ride, and one "Foal with ..."
## button per grown-up friend (in a short scrolling list, so a big herd still fits the 360 px
## view). Every choice is a good one; nothing is scored. Sizes come from themes/default.tres.

signal spoke(text: String)

## How many "Foal with ..." buttons show before the list scrolls.
const FOAL_ROWS := 3
## The pony in the panel is shown this tall (world px of the panel, before the UI scale).
const PREVIEW_HEIGHT := 114.0

var pony_id := ""

var _box: VBoxContainer
var _doll: PonyDoll


func _ready() -> void:
	layer = 15
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(panel)
	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	panel.add_child(hbox)
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(150, 130)
	hbox.add_child(preview)
	_doll = PonyDoll.new()
	_doll.name = "Preview"
	# The doll stands on its hooves (origin at the feet): PREVIEW_HEIGHT tall, centred in the box.
	var k := PREVIEW_HEIGHT / PonyDoll.FRAME_HEIGHT
	_doll.position = Vector2(75, 65 + PREVIEW_HEIGHT / 2.0)
	_doll.scale = Vector2(k, k)
	preview.add_child(_doll)
	_box = VBoxContainer.new()
	_box.name = "Buttons"
	hbox.add_child(_box)
	_build()


func _build() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_doll.set_outfit(Ponies.parts(pony_id))
	var today: int = GameClock.day
	var title := Label.new()
	title.text = "%s%s" % [Ponies.display_name(pony_id), " (foal)" if Ponies.is_foal(pony_id, today) else ""]
	_box.add_child(title)
	var looks := Label.new()
	looks.text = Ponies.describe(pony_id)
	_box.add_child(looks)
	var parents: Array = Ponies.pony(pony_id).get("parents", [])
	if parents.size() == 2:
		var fam := Label.new()
		fam.text = "Foal of %s and %s" % [Ponies.display_name(parents[0]), Ponies.display_name(parents[1])]
		_box.add_child(fam)

	_button("Brush", _brush)
	for slot: String in ["mane_style", "accessory"]:
		var now: String = Ponies.pony(pony_id)["groom"].get(slot, "none")
		var label: String = Ponies.data()["groom_labels"].get(now, now)
		_button("%s: %s  >" % ["Mane" if slot == "mane_style" else "Wear", label], _groom.bind(slot))
	if Ponies.riding() == pony_id:
		_button("Hop down", _dismount)
	elif Ponies.is_foal(pony_id, today):
		_button("Ride", _ride)
	else:
		_button("Ride", _ride, false)
		var friends: Array = Ponies.ids().filter(func(other: String) -> bool: return Ponies.can_breed(pony_id, other, today))
		if not friends.is_empty():
			var scroll := ScrollContainer.new()
			scroll.name = "Foals"
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			var list := VBoxContainer.new()
			list.name = "List"
			list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(list)
			_box.add_child(scroll)
			for other: String in friends:
				_button("Foal with %s" % Ponies.display_name(other), _foal.bind(other), false, list)
			var row := maxf(list.get_child(0).get_combined_minimum_size().y, 13.0)
			var sep := float(list.get_theme_constant("separation"))
			var rows := mini(friends.size(), FOAL_ROWS)
			scroll.custom_minimum_size = Vector2(0, rows * row + (rows - 1) * sep)
	_button("Close", queue_free, false)


func _button(text: String, action: Callable, rebuild := true, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(_press.bind(action, rebuild))
	(parent if parent else _box).add_child(b)
	return b


func _press(action: Callable, rebuild: bool) -> void:
	action.call()
	if rebuild and not is_queued_for_deletion():
		_build.call_deferred()


func _brush() -> void:
	Ponies.brush(pony_id)
	spoke.emit(Ponies.line("brush"))


func _groom(slot: String) -> void:
	Ponies.cycle(pony_id, slot)
	spoke.emit(Ponies.line("groom"))


func _ride() -> void:
	if not Ponies.mount(pony_id, GameClock.day):
		spoke.emit(Ponies.line("foal_ride"))
		return
	spoke.emit(Ponies.line("ride"))
	queue_free()


func _dismount() -> void:
	Ponies.dismount()
	spoke.emit(Ponies.line("dismount"))


func _foal(other: String) -> void:
	var foal := Ponies.breed(pony_id, other, GameClock.day)
	if foal == "":
		spoke.emit(Ponies.line("full"))
		return
	spoke.emit("%s %s is here!" % [Ponies.line("foal"), Ponies.display_name(foal)])
	queue_free()
