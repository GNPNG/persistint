extends Control
## Ritual Puzzle — "Arrange the Sacred Icons": swap tiles on a 3x3 altar grid to
## match the pattern the Covenant prescribes. Completion writes puzzle_ritual_done;
## The priestess's dialogue and barks react to it.

const RETURN_MAP := "res://scenes/maps/temple.tscn"
## The three sacred icons: canon temple props (tools/cut_island_props.py) on rose, sky and gold
## altar tiles (tools/gen_ui_art.py).
const ICONS: Array[Texture2D] = [
	preload("res://assets/canon/prop_seal_o.png"),
	preload("res://assets/canon/prop_pillar_orb.png"),
	preload("res://assets/canon/prop_icon_queen_mother.png"),
]
const TILES: Array[Texture2D] = [
	preload("res://assets/ui/chrome/altar_tile_rose.png"),
	preload("res://assets/ui/chrome/altar_tile_sky.png"),
	preload("res://assets/ui/chrome/altar_tile_gold.png"),
]
const TILE_SELECTED := preload("res://assets/ui/chrome/altar_tile_selected.png")

var target: Array[int] = [0, 1, 2, 1, 2, 0, 2, 0, 1]
var grid: Array[int] = []
var selected := -1
var buttons: Array[Button] = []


func _ready() -> void:
	grid = target.duplicate()
	while grid == target:
		grid.shuffle()
	_build_ui()
	Voice.speak("arrange the icons", 0.8)


func _build_ui() -> void:
	var target_grid: GridContainer = $Panel/HBox/TargetSide/TargetGrid
	for value in target:
		var swatch := PanelContainer.new()
		swatch.custom_minimum_size = Vector2(28, 28)
		swatch.add_theme_stylebox_override("panel", _tile_style(TILES[value], 3))
		swatch.add_child(_icon(value))
		target_grid.add_child(swatch)
	var play_grid: GridContainer = $Panel/HBox/PlaySide/PlayGrid
	for i in grid.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 52)
		b.pressed.connect(_on_tile_pressed.bind(i))
		var icon := _icon(0)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)
		b.add_child(icon)
		play_grid.add_child(b)
		buttons.append(b)
	$Panel/HBox/TargetSide/BackButton.pressed.connect(_leave)
	_paint()


func _icon(value: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = ICONS[value]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _tile_style(tex: Texture2D, pad: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.set_texture_margin_all(7)
	style.set_content_margin_all(pad)
	return style


func _paint() -> void:
	for i in grid.size():
		var style := _tile_style(TILE_SELECTED if i == selected else TILES[grid[i]], 7)
		for state in ["normal", "hover", "pressed", "focus"]:
			buttons[i].add_theme_stylebox_override(state, style)
		(buttons[i].get_child(0) as TextureRect).texture = ICONS[grid[i]]


func _on_tile_pressed(i: int) -> void:
	if selected == -1:
		selected = i
	elif selected == i:
		selected = -1
	else:
		var tmp := grid[selected]
		grid[selected] = grid[i]
		grid[i] = tmp
		selected = -1
		if grid == target:
			_win()
	_paint()


func _win() -> void:
	$Panel/HBox/TargetSide/StatusLabel.text = "The icons approve. ✿"
	Voice.speak("blessed be the arrangement", 1.2)
	WorldState.set_flag("puzzle_ritual_done", true)


func _leave() -> void:
	SceneRouter.goto_map(RETURN_MAP, "spawn_from_puzzle")
