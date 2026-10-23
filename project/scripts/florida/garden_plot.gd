extends "res://scripts/florida/clickable.gd"
## GardenPlot — one patch of soil. Empty: plants the seed in the bag. Growing: waters it.
## Ready: picks it. Plants grow with the days (GameClock).

@export var plot_id := ""

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	super()
	GameClock.day_changed.connect(func(_d: int) -> void: refresh())
	refresh()


func state() -> String:
	return Florida.plot_state(plot_id, GameClock.day)


func refresh() -> void:
	var s := state()
	var path := "res://assets/placeholder/plot_%s.png" % s
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	var p := Florida.plot(plot_id)
	sprite.modulate = Color.WHITE if p.is_empty() else Color(Florida.data()["plants"][p["plant"]]["color"]).lerp(Color.WHITE, 0.5)


func interact() -> void:
	match state():
		"empty":
			if Florida.plant(plot_id, Florida.selected_seed(), GameClock.day):
				float_text(Florida.data()["plants"][Florida.selected_seed()]["label"])
		"growing":
			if Florida.water(plot_id):
				float_text("watered")
		"ready":
			var plant_id := Florida.harvest(plot_id, GameClock.day)
			if plant_id != "":
				float_text("+%d %s" % [Florida.data()["plants"][plant_id]["yield"], Florida.data()["plants"][plant_id]["label"]])
	refresh()
