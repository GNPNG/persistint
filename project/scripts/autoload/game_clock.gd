extends Node
## GameClock — day phases and the Calendar of Blood (28-day cycle).
## The Festival of the Fourteenth falls mid-cycle.

signal phase_changed(phase: String)
signal day_changed(day: int)

const PHASES: Array[String] = ["morning", "midday", "evening", "night"]
const SECONDS_PER_PHASE := 90.0
const DAYS_PER_CYCLE := 28
const FESTIVAL_DAY := 14
const CALENDAR_PATH := "res://data/calendar.json"

var day := 1
var phase_index := 0
var _elapsed := 0.0
## data/calendar.json: "cohort_signals" (Priestess cohort signals), "schedules" (per-NPC
## locations), "places", "schedule_hold" and "ask_around"; schedule and signal entries carry a
## "when" condition block, see matches_when().
var calendar_data: Dictionary = {}


func _ready() -> void:
	_load_calendar()
	restore()


func _load_calendar() -> void:
	var f := FileAccess.open(CALENDAR_PATH, FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			calendar_data = parsed


## Load day/phase from the WorldState save; no saved clock means Day 1 morning.
func restore() -> void:
	var saved: Variant = WorldState.get_flag("_clock")
	if saved is Dictionary:
		day = int(saved.get("day", 1))
		phase_index = int(saved.get("phase_index", 0)) % PHASES.size()
	else:
		day = 1
		phase_index = 0
	_elapsed = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= SECONDS_PER_PHASE:
		_elapsed = 0.0
		_advance_phase()


func _advance_phase() -> void:
	phase_index += 1
	if phase_index >= PHASES.size():
		phase_index = 0
		day += 1
		day_changed.emit(day)
	WorldState.set_flag("_clock", {"day": day, "phase_index": phase_index})
	phase_changed.emit(phase())


func phase() -> String:
	return PHASES[phase_index]


func cycle_day() -> int:
	return ((day - 1) % DAYS_PER_CYCLE) + 1


## Time is measured in cycles: cycle 1 is days 1-28, cycle 2 is days 29-56, ...
func cycle_number() -> int:
	return (day - 1) / DAYS_PER_CYCLE + 1


func is_festival() -> bool:
	return cycle_day() == FESTIVAL_DAY


func days_until_festival() -> int:
	return posmod(FESTIVAL_DAY - cycle_day(), DAYS_PER_CYCLE)


## Does a "when" block hold right now? Keys (all must match):
##   festival: bool, cycle_day: int, cycle_day_min / cycle_day_max: int,
##   cycle: int, cycle_min: int, phase: String, days_until_festival: int.
## Used by barks (data/barks.json), cohort signals and NPC schedules.
func matches_when(when: Dictionary) -> bool:
	for key: String in when:
		var want: Variant = when[key]
		match key:
			"festival":
				if is_festival() != bool(want):
					return false
			"cycle_day":
				if cycle_day() != int(want):
					return false
			"cycle_day_min":
				if cycle_day() < int(want):
					return false
			"cycle_day_max":
				if cycle_day() > int(want):
					return false
			"cycle":
				if cycle_number() != int(want):
					return false
			"cycle_min":
				if cycle_number() < int(want):
					return false
			"phase":
				if phase() != str(want):
					return false
			"days_until_festival":
				if days_until_festival() != int(want):
					return false
			_:
				return false
	return true


## Cohort signals in force today (entries of calendar.json "cohort_signals").
func active_cohort_signals() -> Array:
	var out: Array = []
	for entry: Dictionary in calendar_data.get("cohort_signals", []):
		if matches_when(entry.get("when", {})):
			out.append(entry)
	return out


## First schedule entry for npc_id whose "when" holds, or {} (stay at default spot).
func schedule_for(npc_id: String) -> Dictionary:
	for entry: Dictionary in calendar_data.get("schedules", {}).get(npc_id, []):
		if matches_when(entry.get("when", {})):
			return entry
	return {}


## The places table entry for a schedule location (calendar.json "places"), or {}.
func place(location: String) -> Dictionary:
	return calendar_data.get("places", {}).get(location, {})


## The scene of a places entry as a String ("" for a place with no map; the data uses null).
static func scene_of(p: Dictionary) -> String:
	var scene: Variant = p.get("scene")
	if scene is String:
		return scene
	return ""


## Where npc_id is right now per the Calendar of Blood: the location of the first schedule
## entry whose "when" holds, honouring "schedule_hold": while none of the NPC's hold flags is
## set she keeps the village (her home spot) whatever the schedule says, so the Initiate waits
## in the village until the player has answered the Offering. "" when no entry matches:
## the NPC stays where her scene placed her.
func location_for(npc_id: String) -> String:
	var hold: Dictionary = calendar_data.get("schedule_hold", {}).get(npc_id, {})
	if not hold.is_empty():
		var held := true
		for flag: String in hold.get("until_any", []):
			if WorldState.has_flag(flag):
				held = false
				break
		if held:
			return "village"
	return str(schedule_for(npc_id).get("location", ""))


## Where npc_id is and what she is doing, for hint text (an ask-around): {"location",
## "activity", "place"}; place is the calendar.json "places" entry ({} for an unmapped
## location), activity "" when the (held) location is not what the schedule says.
func whereabouts(npc_id: String) -> Dictionary:
	var location := location_for(npc_id)
	var entry := schedule_for(npc_id)
	var activity := ""
	if str(entry.get("location", "")) == location:
		activity = str(entry.get("activity", ""))
	return {"location": location, "activity": activity, "place": place(location)}


## The npc_id the ask-around "seeking" rules (calendar.json "ask_around") currently point at
## ("" for none): the first rule whose "if" holds. In an "if", true asks for the flag set and
## false for it not set (WorldState.matches would ask for a flag that is literally false, and
## offering_delivered is only ever set true); any other value must equal the flag exactly.
func sought_npc() -> String:
	for rule: Dictionary in calendar_data.get("ask_around", {}).get("seeking", []):
		var ok := true
		for flag: String in rule.get("if", {}):
			var want: Variant = rule["if"][flag]
			if want is bool:
				if WorldState.has_flag(flag) != want:
					ok = false
					break
			elif WorldState.get_flag(flag) != want:
				ok = false
				break
		if ok:
			return str(rule.get("npc", ""))
	return ""


## The ask-around hint for a sought NPC, from whereabouts(): the calendar.json "ask_around"
## template for the kind of place she is in, filled with her name (Cast), her place's "where"
## and her activity. The kind is "here" (this_scene is her map), "elsewhere" (another map has
## her), "away" (her place has no map) or "asleep" (the dormitory's away). "" when the data has
## no ask_around block, no place for her, or no template for the kind.
func ask_around_hint(npc_id: String, this_scene: String) -> String:
	var templates: Dictionary = calendar_data.get("ask_around", {}).get("templates", {})
	var w := whereabouts(npc_id)
	var place: Dictionary = w.get("place", {})
	if place.is_empty():
		return ""
	var scene := scene_of(place)
	var kind := "elsewhere"
	if scene != "" and scene == this_scene:
		kind = "here"
	elif scene == "":
		kind = "asleep" if str(w.get("location", "")) == "dormitory" else "away"
	var entry: Variant = templates.get(kind)
	var text := ""
	if entry is Dictionary:
		text = str(entry.get("text", ""))
	elif entry is String:
		text = entry
	if text == "":
		return ""
	var activity := str(w.get("activity", ""))
	if activity == "":
		text = text.replace(", {activity}", "").replace("{activity}", "").replace("  ", " ").strip_edges()
	else:
		text = text.replace("{activity}", activity)
	return text.replace("{name}", Cast.full(npc_id)).replace("{where}", str(place.get("where", "")))


func status_text() -> String:
	var festival := "  ✿ FESTIVAL ✿" if is_festival() else ""
	return "Day %d — %s (Cycle %d, day %d/%d)%s" % [day, phase().capitalize(), cycle_number(), cycle_day(), DAYS_PER_CYCLE, festival]
