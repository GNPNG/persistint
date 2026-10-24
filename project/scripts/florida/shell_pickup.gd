extends "res://scripts/florida/clickable.gd"
## ShellPickup — a seashell on the sand; the beach has more tomorrow.
## Its look is one of the canon shells cut from the tide scroll (assets/florida/shell_<look>.png).

@export_enum("scallop", "spiral", "conch") var look := "scallop"
## Shown this many world px tall; the canon cut keeps the sheet's resolution.
const HEIGHT := 11.0


func _ready() -> void:
	super()
	$Sprite2D.texture = load("res://assets/florida/shell_%s.png" % look)
	SpriteFit.fit($Sprite2D, HEIGHT)
	GameClock.day_changed.connect(func(_d: int) -> void: show())
	if WorldState.get_flag("fl_shell_%s" % name, 0) == GameClock.day:
		hide()


func interact() -> void:
	if not visible:
		return
	Florida.add_item("shell")
	WorldState.set_flag("fl_shell_%s" % name, GameClock.day)
	float_text("+1 shell")
	hide()
