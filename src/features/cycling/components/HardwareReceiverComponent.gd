class_name HardwareReceiverComponent
extends Node

## HardwareReceiverComponent
## Listens for telemetry updates from hardware (via SignalBus) or other sources.
## Provides the latest power, cadence, and speed values to the parent entity.

signal power_changed(watts: float)
signal cadence_changed(rpm: float)
signal speed_changed(kmh: float)

@export var is_player: bool = false ## If true, listens to global hardware signals
@export var smoothing_factor: float = 0.5 ## 0.0 = no smoothing (instant), 1.0 = no update

var _current_power: float = 0.0
var _current_cadence: float = 0.0
var _current_speed_kmh: float = 0.0

func _ready() -> void:
	if is_player:
		if not SignalBus.trainer_power_updated.is_connected(_on_power_updated):
			SignalBus.trainer_power_updated.connect(_on_power_updated)
		if not SignalBus.trainer_cadence_updated.is_connected(_on_cadence_updated):
			SignalBus.trainer_cadence_updated.connect(_on_cadence_updated)
		if not SignalBus.trainer_speed_updated.is_connected(_on_speed_updated):
			SignalBus.trainer_speed_updated.connect(_on_speed_updated)

func _on_power_updated(watts: float) -> void:
	# Simple exponential moving average for smoothing if needed
	_current_power = lerp(watts, _current_power, smoothing_factor)
	power_changed.emit(_current_power)

func _on_cadence_updated(rpm: float) -> void:
	_current_cadence = rpm
	cadence_changed.emit(_current_cadence)

func _on_speed_updated(kmh: float) -> void:
	_current_speed_kmh = kmh
	speed_changed.emit(_current_speed_kmh)

func get_power() -> float:
	return _current_power

func get_cadence() -> float:
	return _current_cadence

func get_speed_kmh() -> float:
	return _current_speed_kmh

func set_power_manual(watts: float) -> void:
	# Useful for testing or mock mode
	_current_power = watts
	power_changed.emit(_current_power)

func set_cadence_manual(rpm: float) -> void:
	_current_cadence = rpm
	cadence_changed.emit(_current_cadence)
