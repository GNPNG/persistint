extends "res://scripts/florida/clickable.gd"
## SeedBag — never runs out; each visit switches which seed the plots will plant.


func interact() -> void:
	float_text(Florida.data()["plants"][Florida.cycle_seed()]["label"])
