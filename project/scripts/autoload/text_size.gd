extends Node
## TextSize — the player's text size (QA-06, GC-04): Normal, Large or Larger (STEPS), chosen on the
## settings screen and kept in user://settings.cfg [display] text_scale. It scales every font
## size in the project theme (themes/default.tres) and every font-size override a node carries
## (bark bubbles, door names, labels built in code), as nodes enter the tree and again on each
## change, so no screen has to know about it. Base sizes are kept, so the steps never compound.

signal changed(step: int)

const STEPS := [1.0, 1.25, 1.5]
const NAMES := ["Normal", "Large", "Larger"]
const SECTION := "display"
const KEY := "text_scale"
const GROUP := "text_sized"
const BASE := &"text_size_base"

## A var so headless tests can point it at a temp file instead of the player's real settings.
var SETTINGS_PATH := "user://settings.cfg"

var step := 0
var _theme: Theme
var _theme_base := {}  # "type/name" -> size, plus "" -> default_font_size


func _ready() -> void:
	if WorldState.running_tests():  # QA-04: the test settings file Music emptied at start
		SETTINGS_PATH = WorldState.TEST_SETTINGS_PATH
	_theme = load(ProjectSettings.get_setting("gui/theme/custom", "")) as Theme
	if _theme:
		_theme_base[""] = _theme.default_font_size
		for type in _theme.get_font_size_type_list():
			for name in _theme.get_font_size_list(type):
				_theme_base["%s/%s" % [type, name]] = _theme.get_font_size(name, type)
	get_tree().node_added.connect(_on_node_added)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		step = clampi(int(cfg.get_value(SECTION, KEY, 0)), 0, STEPS.size() - 1)
	_apply_theme()


func scale() -> float:
	return STEPS[step]


func step_name() -> String:
	return NAMES[step]


## Sets the step (0 Normal, 1 Large, 2 Larger), applies it everywhere and saves it.
func set_step(s: int) -> void:
	step = clampi(s, 0, STEPS.size() - 1)
	_apply_theme()
	for n in get_tree().get_nodes_in_group(GROUP):
		_scale_node(n)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep the audio levels in the same file
	cfg.set_value(SECTION, KEY, step)
	cfg.save(SETTINGS_PATH)
	changed.emit(step)


## The size a base font size shows at now.
func sized(base: int) -> int:
	return int(round(base * scale()))


func _apply_theme() -> void:
	if _theme == null:
		return
	_theme.default_font_size = sized(_theme_base.get("", 9))
	for key: String in _theme_base:
		if key == "":
			continue
		_theme.set_font_size(key.get_slice("/", 1), key.get_slice("/", 0), sized(_theme_base[key]))


func _on_node_added(n: Node) -> void:
	if n is Control and n.has_theme_font_size_override("font_size"):
		if not n.has_meta(BASE):  # a node that re-enters keeps its first base size
			n.set_meta(BASE, n.get_theme_font_size("font_size"))
		n.add_to_group(GROUP)
		_scale_node(n)


func _scale_node(n: Node) -> void:
	if n is Control and n.has_meta(BASE):
		n.add_theme_font_size_override("font_size", sized(int(n.get_meta(BASE))))
