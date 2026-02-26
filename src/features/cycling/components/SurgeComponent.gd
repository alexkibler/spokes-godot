class_name SurgeComponent
extends CyclistComponent

## SurgeComponent
## Manages the Surge/Recovery state machine logic.
## Determines power multipliers based on effort and drafting opportunities.

signal state_changed(state: String) # "surge", "recovery", "normal"

@export var surge_duration: float = 5.0
@export var recovery_duration: float = 4.0
@export var surge_multiplier: float = 1.25
@export var recovery_multiplier: float = 0.85

var surge_timer: float = 0.0
var recovery_timer: float = 0.0

## Processes the state machine. Should be called every physics frame.
## 'draft_factor' is used to trigger surges (when > 0.01).
func process_surge(delta: float, draft_factor: float) -> void:
	var previous_state: String = get_state()

	if surge_timer > 0:
		surge_timer -= delta
		if surge_timer <= 0:
			recovery_timer = recovery_duration
	elif recovery_timer > 0:
		recovery_timer -= delta
	elif draft_factor > 0.01:
		surge_timer = surge_duration

	var new_state: String = get_state()
	if new_state != previous_state:
		state_changed.emit(new_state)

## Returns the current power multiplier based on the state.
func get_power_multiplier() -> float:
	if surge_timer > 0:
		return surge_multiplier
	elif recovery_timer > 0:
		return recovery_multiplier
	return 1.0

func get_state() -> String:
	if surge_timer > 0:
		return "surge"
	elif recovery_timer > 0:
		return "recovery"
	return "normal"

func get_time_remaining() -> float:
	if surge_timer > 0:
		return surge_timer
	elif recovery_timer > 0:
		return recovery_timer
	return 0.0
