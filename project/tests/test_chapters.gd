extends SceneTree
## Chapters: the village's Exit_Cruise ends the island chapter on the time-jump card; the jump
## sets `chapter`, archives and clears the island player character, and enters the Interview.
## Run: godot --headless --path project -s tests/test_chapters.gd
## The player's real save (user://save.json) is backed up and restored.

const VILLAGE := "res://scenes/maps/village.tscn"
const CHAPTER_END := "res://scenes/chapters/chapter_end.tscn"
const INTERVIEW := "res://scenes/minigames/interview.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	var had_save := FileAccess.file_exists(ws.SAVE_PATH)
	var backup := FileAccess.get_file_as_string(ws.SAVE_PATH) if had_save else ""
	ws.reset()
	var chapters: Script = load("res://scripts/chapters/chapters.gd")

	# The door.
	var village: Node = load(VILLAGE).instantiate()
	var exit: Node = village.get_node("Exit_Cruise")
	_check(not exit.locked and exit.target_scene == CHAPTER_END, "village Exit_Cruise is unlocked and leads to the chapter end")
	village.free()
	_check(ResourceLoader.exists(CHAPTER_END), "chapter end scene exists")

	# The data.
	var d: Dictionary = chapters.data()
	var island: Dictionary = d["chapters"]["island"]
	_check(d["first"] == "island" and island["next"] == "cruise", "island is first; its next chapter is the cruise")
	_check(d["chapters"]["cruise"]["entry_scene"] == INTERVIEW, "cruise chapter enters at the Interview")
	_check(island["end_card"]["heading"] != "" and island["end_card"]["lines"].size() > 0, "island end card has text")
	var no_years := true
	for line: String in island["end_card"]["lines"]:
		no_years = no_years and not line.to_lower().contains("year") and not line.to_lower().contains("decade")
	_check(no_years, "end card names no year count")
	_check(chapters.current() == "island", "a fresh game is in the island chapter")

	# The card and the jump.
	ws.set_flag("outfit_hair", "hair_rose")
	ws.set_flag("outfit_dress", "dress_teal")
	ws.set_flag("questioned_ritual", true)
	var card: Control = load(CHAPTER_END).instantiate()
	card.seconds = 600.0
	root.add_child(card)
	await process_frame
	_check(card.from == "island" and card.find_child("Heading", true, false).text == island["end_card"]["heading"],
		"card shows the island chapter's end card")
	var heading_size: int = (card.find_child("Heading", true, false) as Label).get_theme_font_size("font_size")
	_check(heading_size == 30, "its heading is 30 px, as STYLE.md 4.10 has it and the flashback card shows it (%d)" % heading_size)
	_check(ws.get_flag("chapter") == "cruise", "jump sets chapter to cruise")
	var archive: Variant = ws.get_flag("chapter_archive_island")
	_check(archive is Dictionary and archive.get("outfit_hair") == "hair_rose" and archive.get("outfit_dress") == "dress_teal",
		"island outfit archived under chapter_archive_island")
	_check(not ws.flags.has("outfit_hair") and not ws.flags.has("outfit_dress"), "active outfit cleared for a fresh character")
	_check(not archive.has("questioned_ritual"), "story flags are not player flags")
	_check(card.entry.get("scene") == INTERVIEW and ws.get_flag("_location", {}).get("scene") == INTERVIEW,
		"next scene is the Interview (and Continue resumes there)")
	card.free()

	# The Interview returns into the cruise, not the village, in the cruise chapter.
	var iv: Control = load(INTERVIEW).instantiate()
	iv.autostart = false
	root.add_child(iv)
	await process_frame
	_check(iv.return_scene() == "res://scenes/minigames/hottest_chains.tscn", "cruise-chapter Interview returns to the cruise")
	ws.reset()
	_check(iv.return_scene() == VILLAGE, "island-chapter Interview still returns to the village")
	iv.free()
	_check(chapters.jump("cruise").is_empty(), "the cruise has no next chapter yet")

	if had_save:
		var f := FileAccess.open(ws.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
		ws.load_save()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ws.SAVE_PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
	print(("PASS " if ok else "FAIL ") + what)
