extends "res://scripts/florida/clickable.gd"
## SeedBag — never runs out; each visit switches which seed the plots will plant, and says
## which one it is now.


func _ready() -> void:
	super()
	PaperBake.dress($Sprite2D as Sprite2D)  # the paper look (tools/bake_paper.sh florida)


func interact() -> void:
	float_text("Now planting: %s" % Florida.label(Florida.cycle_seed()))
