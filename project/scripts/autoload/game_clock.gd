extends Node
## GameClock — day phases and the Calendar of Blood (28-day cycle).
## The Festival of the Fourteenth falls mid-cycle.

signal phase_changed(phase: String)
signal day_changed(day: int)

const PHASES: Array[String] = ["morning", "midday", "evening", "night"]
const SECONDS_PER_PHASE := 90.0
const DAYS_PER_CYCLE := 28
const FESTIVAL_DAY := 14

var day := 1
var phase_index := 0
var _elapsed := 0.0


func _ready() -> void:
	restore()


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


func is_festival() -> bool:
	return cycle_day() == FESTIVAL_DAY


func status_text() -> String:
	var festival := "  ✿ FESTIVAL ✿" if is_festival() else ""
	return "Day %d — %s (Cycle %d/%d)%s" % [day, phase().capitalize(), cycle_day(), DAYS_PER_CYCLE, festival]
