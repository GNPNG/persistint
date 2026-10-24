extends "res://scripts/florida/clickable.gd"
## GardenPlot — one patch of soil. Empty: plants the seed in the bag. Growing: waters it.
## Ready: picks it. Plants grow with the days (GameClock). Art: assets/florida/plot_empty,
## plot_growing and plot_ready_<plant> (tools/gen_florida_art.py).

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
	var p := Florida.plot(plot_id)
	if s == "ready" and not p.is_empty():
		s = "ready_%s" % p["plant"]
	var path := "res://assets/florida/plot_%s.png" % s
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
		# Florida art is drawn at 4x (tools/florida_draw.D); the soil stands on the origin.
		SpriteFit.fit(sprite, sprite.texture.get_height() / 4.0)


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
