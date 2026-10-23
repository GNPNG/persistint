extends "res://scripts/map.gd"
## Stable — the pony stable out back of the house (DESIGN.md section 3). Every pony in the herd
## (WorldState fl_ponies) gets a stall spot from data/ponies.json; new foals trot in at once and
## the pony being ridden is out with the player.

const PONY_SCENE := preload("res://scenes/florida/pony.tscn")

@onready var ponies_root: Node2D = $Ponies


func _ready() -> void:
	super()
	refresh_ponies()
	WorldState.flag_changed.connect(_on_flag_changed)


func _on_flag_changed(key: String, _value: Variant) -> void:
	if key == "fl_ponies" or key == "fl_riding":
		refresh_ponies()


## One Pony node per pony in the herd, in stall order; existing nodes are kept and redrawn.
func refresh_ponies() -> void:
	var stalls: Array = Ponies.data().get("stalls", [])
	var i := 0
	for id: String in Ponies.ids():
		var node: Node = ponies_root.get_node_or_null(id)
		if node == null:
			node = PONY_SCENE.instantiate()
			node.name = id
			node.pony_id = id
			var spot: Array = stalls[i % stalls.size()] if not stalls.is_empty() else [480, 330]
			node.position = Vector2(float(spot[0]), float(spot[1]))
			ponies_root.add_child(node)
		else:
			node.refresh()
		i += 1


func pony_node(id: String) -> Node:
	return ponies_root.get_node_or_null(id)
