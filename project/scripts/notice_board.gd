extends Area2D
## NoticeBoard: the village board on the spawn plaza: click it (or E next to it) to read
## today's cohort signals again (the morning notice, scripts/ui/cohort_notice.gd) with the
## day/phase line. Its art is a drop (scripts/placeholder_prop.gd): a rendered
## prop_notice_board.png replaces the sign when it lands.


func _ready() -> void:
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("click"):
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.approach(self)
			get_viewport().set_input_as_handled()


## Called by the player on arrival after clicking the board (or with E next to it).
func interact() -> void:
	var map := _map()
	if map != null and map.has_method("show_cohort_notice"):
		map.show_cohort_notice(true)


## The map node this board stands on (the outermost parent under the scene root), or null.
func _map() -> Node:
	if not is_inside_tree():
		return null
	var map: Node = self
	while map.get_parent() != null and map.get_parent() != get_tree().root:
		map = map.get_parent()
	return map
