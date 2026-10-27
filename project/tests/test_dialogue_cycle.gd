extends SceneTree
## A dialogue resource that has shown a line can be freed (bd wso). Dialogue Manager 3.10.4's
## get_line set `resource` on the line's own dictionary in resource.lines, so every resource that
## had shown a line held itself and was never freed: "2 resources still in use at exit" after each
## dialogue and interview shot of the shot walk. The vendored copy takes upstream's fix (the line's
## data is copied before `resource` is set on it; THIRD_PARTY.md). Checked on a resource made from
## text: after its first line no entry of its lines holds a resource, and once nothing outside holds
## it, it is freed.
## Run: godot --headless --path project -s tests/test_dialogue_cycle.gd

const TEXT := "~ start\nNarrator: The first line.\nNarrator: The second line.\n=> END\n"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var dm: Node = root.get_node("/root/DialogueManager")
	var res: Resource = dm.create_resource_from_text(TEXT)
	var line = await dm.get_next_dialogue_line(res, "start")
	_check(line != null and line.text == "The first line.",
		"the dialogue gives its first line (got %s)" % (line.text if line else "null"))
	var holding := 0
	for data: Variant in (res.get("lines") as Dictionary).values():
		if data is Dictionary and (data as Dictionary).has("resource"):
			holding += 1
	_check(holding == 0, "no line of the resource holds the resource (%d do)" % holding)

	var ref: WeakRef = weakref(res)
	line = null
	res = null
	await _frames(3)  # got_dialogue is emitted deferred, with the line
	_check(ref.get_ref() == null, "the resource is freed once nothing outside holds it")

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
