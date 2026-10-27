extends "res://scripts/florida/clickable.gd"
## SeedBag — never runs out; each visit switches which seed the plots will plant, and says
## which one it is now.


func interact() -> void:
	float_text("Now planting: %s" % Florida.label(Florida.cycle_seed()))
