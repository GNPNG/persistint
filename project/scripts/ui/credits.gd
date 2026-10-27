extends Control
## The credits and licences screen (GC-08 in sops/09-game-release-checklist.md), over the main
## menu: the copyright lines, people and tools, then every third-party notice with its licence
## text. Ours come from data/credits.json (THIRD_PARTY.md at the repo root lists the same); the
## engine's licence and the parts built into the engine come from the engine itself
## (https://docs.godotengine.org/en/stable/about/complying_with_licenses.html). The text is built
## the first time the screen opens, since the engine's licence texts are long. Done (or Escape,
## or the dimmed background) closes it.

const DATA := "res://data/credits.json"
const HEADING := "#d65a8a"

var data: Dictionary = {}


func _ready() -> void:
	%DoneButton.add_to_group(PadFocus.DEFAULT)  # where a pad starts (QA-13)
	data = load_data()
	$Dim.gui_input.connect(_on_dim_input)
	%DoneButton.pressed.connect(close)


static func load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return parsed if parsed is Dictionary else {}


func open() -> void:
	if %Body.text == "":
		%Body.text = compose(data)
	%Scroll.scroll_vertical = 0
	visible = true
	%DoneButton.grab_focus()


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


## The whole screen as BBCode. Every text from the data or the engine goes in escaped, so a
## bracket in a licence stays text.
static func compose(d: Dictionary) -> String:
	var out := PackedStringArray()
	out.append(_esc(d.get("copyright", "")))
	out.append(_esc(d.get("based_on", "")))
	out.append(_heading("People"))
	for p: Dictionary in d.get("people", []):
		out.append("%s: %s" % [_esc(p.get("role", "")), _esc(p.get("name", ""))])
	out.append(_heading("Made with"))
	for t: String in d.get("tools", []):
		out.append(_esc(t))
	out.append(_heading("Third-party notices and licences"))
	for e: Dictionary in d.get("third_party", []):
		out.append("")
		out.append("[color=%s]%s[/color]" % [HEADING, _esc(e.get("name", ""))])
		out.append("Used for: %s" % _esc(e.get("use", "")))
		out.append("Licence: %s (%s)" % [_esc(e.get("licence", "")), _esc(e.get("url", ""))])
		if e.has("notice"):
			out.append(_esc(e["notice"]))
		if e.get("engine", false):
			out.append(_esc(Engine.get_license_text()))
		elif e.has("text"):
			out.append(_esc(e["text"]))
	out.append(_heading("Third-party parts of Godot Engine"))
	for c: Dictionary in Engine.get_copyright_info():
		for part: Dictionary in c.get("parts", []):
			out.append("%s: © %s (%s)" % [_esc(c.get("name", "")), _esc(", ".join(part.get("copyright", PackedStringArray()))), _esc(part.get("license", ""))])
	out.append(_heading("Licence texts for the parts of Godot Engine"))
	var licences: Dictionary = Engine.get_license_info()
	var names: Array = licences.keys()
	names.sort()
	for n: String in names:
		out.append("")
		out.append("[color=%s]%s[/color]" % [HEADING, _esc(n)])
		out.append(_esc(licences[n]))
	return "\n".join(out)


static func _heading(text: String) -> String:
	return "\n[color=%s]%s[/color]" % [HEADING, text.to_upper()]


static func _esc(text: String) -> String:
	return text.replace("[", "[lb]")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_dim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		accept_event()
		close()
