class_name Cyclist
extends Node2D

## Cyclist
## The root entity for a cyclist (player or ghost).
## Coordinates components to handle physics, state, and visuals.

@export var stats: CyclistStats
@export var is_player: bool = false
@export var label: String = "Cyclist"

# Components
@onready var hardware_receiver: HardwareReceiverComponent = $HardwareReceiver
@onready var drafting: DraftingComponent = $Drafting
@onready var surge: SurgeComponent = $Surge
@onready var visuals: CyclistVisuals = $Visuals

# Physics State
var velocity_ms: float = 0.0
var distance_m: float = 0.0
# var cadence: float = 90.0 # Replaced by hardware_receiver.get_cadence()
var current_grade: float = 0.0
var current_surface: String = "asphalt"

# Public Accessors
var effective_power: float = 0.0
var draft_factor: float = 0.0

func _ready() -> void:
	if not stats:
		stats = CyclistStats.new()

	drafting.stats = stats
	hardware_receiver.is_player = is_player

## Setup the cyclist with specific properties.
func setup(p_is_player: bool, p_stats: CyclistStats, p_label: String = "Cyclist", p_color: Color = Color.WHITE, p_start_distance: float = 0.0, p_base_power: float = 200.0) -> void:
	is_player = p_is_player
	stats = p_stats
	label = p_label
	distance_m = p_start_distance
	
	if hardware_receiver:
		hardware_receiver.is_player = is_player
		if not is_player:
			hardware_receiver.set_power_manual(p_base_power)
			# Disconnect hardware signals for AI
			if SignalBus.trainer_power_updated.is_connected(hardware_receiver._on_power_updated):
				SignalBus.trainer_power_updated.disconnect(hardware_receiver._on_power_updated)
			if SignalBus.trainer_cadence_updated.is_connected(hardware_receiver._on_cadence_updated):
				SignalBus.trainer_cadence_updated.disconnect(hardware_receiver._on_cadence_updated)
	
	if drafting:
		drafting.stats = stats
	
	set_color(p_color)

func process_cyclist(delta: float, course: CourseProfile, nearby_entities: Array[Cyclist], run_modifiers: Dictionary = {}) -> void:
	# 1. Gather Inputs
	var raw_power: float = hardware_receiver.get_power()

	# 2. Update Components
	drafting.update_drafting(distance_m, nearby_entities)
	draft_factor = drafting.get_draft_factor()

	surge.process_surge(delta, draft_factor)
	var surge_mult: float = surge.get_power_multiplier()

	# 3. Calculate Physics Modifiers
	var physics_modifiers: Dictionary = run_modifiers.duplicate()
	physics_modifiers["dragReduction"] = min(0.99, physics_modifiers.get("dragReduction", 0.0) + draft_factor)
	
	# Centralize Power Scaling: Combine surge and run modifiers
	physics_modifiers["powerMult"] = physics_modifiers.get("powerMult", 1.0) * surge_mult
	effective_power = raw_power * physics_modifiers["powerMult"] # Store for HUD/UI

	# 4. Update Physics
	current_grade = course.get_grade_at_distance(distance_m)
	current_surface = course.get_surface_at_distance(distance_m)

	# Adjust Crr based on surface via modifiers (Stateless)
	var surface_crr_mult: float = CourseProfile.get_crr_for_surface(current_surface) / CourseProfile.get_crr_for_surface("asphalt")
	physics_modifiers["crrMult"] = physics_modifiers.get("crrMult", 1.0) * surface_crr_mult

	var acceleration: float = CyclistPhysics.calculate_acceleration(
		raw_power,
		velocity_ms,
		stats,
		current_grade,
		physics_modifiers
	)

	velocity_ms += acceleration * delta
	velocity_ms = max(0.0, velocity_ms)
	distance_m += velocity_ms * delta

	# 5. Update Visuals
	if visuals:
		visuals.update_animation(delta, velocity_ms, hardware_receiver.get_cadence())
		# Position/Rotation handling is usually done by the parent scene (GameScene) relative to the track/camera,
		# but strictly the visual's internal animation (pedaling) is handled here.
		# The root Node2D transform (position along track) is updated by GameScene based on distance_m.

func set_color(color: Color) -> void:
	if visuals:
		visuals.set_color(color)
