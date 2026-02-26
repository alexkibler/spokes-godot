class_name PowerReceiverComponent
extends Node

## PowerReceiverComponent
## Listens for power updates from the hardware (via SignalBus) or other sources.
## Provides the latest power value to the parent entity.

signal power_changed(watts: float)

@export var smoothing_factor: float = 0.5 ## 0.0 = no smoothing (instant), 1.0 = no update

var _current_power: float = 0.0

func _ready() -> void:
	# Listen to the global SignalBus for trainer updates
	SignalBus.trainer_power_updated.connect(_on_power_updated)

func _on_power_updated(watts: float) -> void:
	# Simple exponential moving average for smoothing if needed
	_current_power = lerp(watts, _current_power, smoothing_factor)
	power_changed.emit(_current_power)

func get_power() -> float:
	return _current_power

func set_power_manual(watts: float) -> void:
	# Useful for testing or mock mode
	_current_power = watts
	power_changed.emit(_current_power)
