extends SceneTree
## Title-screen preview — loads the main menu, jumps its animated backdrop to a few moments of
## the day and of the title theme, waits a few frames and saves each as a PNG. Needs a display
## (not --headless), like tools/screenshot_scenes.gd:
##   godot --path project -s tools/preview_title.gd -- <out_dir>
## Moments (day fraction, seconds into the track): sunrise with the O just begun, noon with half
## the O, sunset with the O complete, midnight with the drips halfway, and the fade at the end;
## then a letter of the wordmark tapped (hearts and its line), and tapped on past the giggles.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const MOMENTS := [
	["sunrise_o_begun", 0.02, 0.06],
	["noon_half_o", 0.25, 0.4],
	["sunset_o_done", 0.5, 0.8],
	["midnight_drips", 0.76, 0.9],
	["dawn_fade", 0.95, 0.995],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "user://title_preview"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	change_scene_to_file(MAIN_MENU)
	await process_frame
	await process_frame
	var bd: Node = current_scene.get_node("Backdrop")
	var length: float = bd.track_length()
	for m: Array in MOMENTS:
		bd.set_time(float(m[2]) * length, float(m[1]))
		for i in 8:
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [out_dir, m[0]]
		img.save_png(path)
		print("saved ", path, " ", img.get_size())
	var wm: Node = current_scene.get_node("Wordmark")
	bd.set_time(0.3 * length, 0.3)
	wm.tap(2)
	for i in 5:
		await process_frame
	_shoot(out_dir, "letter_tapped")
	for i in 8:
		wm.tap(i % 10)
		if wm.sulk_left > 0.0:
			wm._process(wm.sulk_left + 0.01)
	wm.tap(3)
	for i in 5:
		await process_frame
	_shoot(out_dir, "letter_tapped_on")
	quit()


func _shoot(out_dir: String, name_: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name_]
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
