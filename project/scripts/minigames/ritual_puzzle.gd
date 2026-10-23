extends Control
## Ritual Puzzle — "Arrange the Sacred Icons": swap tiles on a 3x3 altar grid to
## match the pattern the Covenant prescribes. Completion writes puzzle_ritual_done;
## The priestess's dialogue and barks react to it.

const RETURN_MAP := "res://scenes/maps/temple.tscn"
const COLORS: Array[Color] = [
	Color("f7a8c4"),  # icon rose
	Color("a8d8f0"),  # icon sky
	Color("f9e4a8"),  # icon gold
]

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
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(24, 24)
		swatch.color = COLORS[value]
		target_grid.add_child(swatch)
	var play_grid: GridContainer = $Panel/HBox/PlaySide/PlayGrid
	for i in grid.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(48, 48)
		b.pressed.connect(_on_tile_pressed.bind(i))
		play_grid.add_child(b)
		buttons.append(b)
	$Panel/HBox/TargetSide/BackButton.pressed.connect(_leave)
	_paint()


func _paint() -> void:
	for i in grid.size():
		buttons[i].modulate = Color.WHITE if i != selected else Color(1.3, 1.3, 1.3)
		buttons[i].add_theme_color_override("font_color", Color.TRANSPARENT)
		var style := StyleBoxFlat.new()
		style.bg_color = COLORS[grid[i]]
		style.set_corner_radius_all(8)
		buttons[i].add_theme_stylebox_override("normal", style)
		buttons[i].add_theme_stylebox_override("hover", style)
		buttons[i].add_theme_stylebox_override("pressed", style)


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
