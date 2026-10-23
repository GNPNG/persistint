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
## data/calendar.json: "cohort_signals" (Priestess cohort signals) and "schedules"
## (per-NPC locations); entries carry a "when" condition block, see matches_when().
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


func status_text() -> String:
	var festival := "  ✿ FESTIVAL ✿" if is_festival() else ""
	return "Day %d — %s (Cycle %d, day %d/%d)%s" % [day, phase().capitalize(), cycle_number(), cycle_day(), DAYS_PER_CYCLE, festival]
