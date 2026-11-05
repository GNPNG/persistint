extends SceneTree
# Diagnostic only: run against an existing canon output; no fitting or pixels change.
# godot --headless --path . --script tools/doll/inspect_face_overlap.gd -- OUTPUT_ROOT [ITEM]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Expected canon output root and optional item id")
		quit(2)
		return
	var root := args[0]
	var item := args[1] if args.size() > 1 else "hair_pigtails"
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("project/data/doll/rig_chibi.json")))
	var map := Image.load_from_file(root.path_join(rig.regions.file))
	var body := Image.load_from_file(root.path_join(rig.body_file))
	var hair := Image.load_from_file(root.path_join("project/assets/doll/" + item + ".png"))
	if map == null or body == null or hair == null:
		quit(2)
		return
	var size := Vector2i((body.get_width() + 1) / 2, (body.get_height() + 1) / 2)
	var source_height := body.get_height()
	for img in [map, body, hair]:
		img.convert(Image.FORMAT_RGBA8)
		img.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	var total := 0
	var hit := 0
	var forehead_capacity := 0
	var forehead_hits := 0
	var rows := {}
	var brow: int = rig.landmarks.brow_y
	for y in size.y:
		var source_y := floori((float(y) + 0.5) * source_height / size.y)
		for x in size.x:
			if roundi(map.get_pixel(x, y).r * 255) != int(rig.regions.labels.face) or body.get_pixel(x, y).a <= 0.5:
				continue
			total += 1
			if source_y < brow:
				forehead_capacity += 1
			if hair.get_pixel(x, y).a <= 0.5:
				continue
			hit += 1
			if source_y < brow:
				forehead_hits += 1
			if not rows.has(source_y):
				rows[source_y] = {"count": 0, "half_x_min": x, "half_x_max": x}
			rows[source_y].count += 1
			rows[source_y].half_x_max = x
	print(JSON.stringify({"item": item, "brow_y": brow, "sampling": "task4 Godot nearest half resolution", "face_total": total, "overlap": hit, "above_brow_region_capacity": forehead_capacity, "above_brow_overlap": forehead_hits, "at_or_below_brow_overlap": hit - forehead_hits, "rows_by_source_y": rows}))
	quit(0)
