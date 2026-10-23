extends "res://scripts/florida/clickable.gd"
## ShellPickup — a seashell on the sand; the beach has more tomorrow.


func _ready() -> void:
	super()
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
