class_name Cyclist
extends Node2D

## Cyclist
## The root entity for a cyclist (player or ghost).
## Coordinates components to handle physics, state, and visuals.

@export var stats: CyclistStats
@export var is_player: bool = false
@export var label: String = "Cyclist"

# Components
@onready var power_receiver: PowerReceiverComponent = $PowerReceiver
@onready var drafting: DraftingComponent = $Drafting
@onready var fatigue: FatigueComponent = $Fatigue
@onready var visuals: CyclistVisuals = $Visuals

# Physics State
var velocity_ms: float = 0.0
var distance_m: float = 0.0
var cadence: float = 90.0 # Default cadence
var current_grade: float = 0.0
var current_surface: String = "asphalt"

# Public Accessors
var effective_power: float = 0.0
var draft_factor: float = 0.0

func _ready() -> void:
	if not stats:
		stats = CyclistStats.new()

	drafting.stats = stats

	# Only the player should listen to hardware power by default.
	# Ghosts will have their power set manually via PowerReceiver.
	if not is_player:
		# Disconnect signal if it was auto-connected by PowerReceiver (it connects in _ready)
		# Actually, PowerReceiver connects to SignalBus. We might want to disable that for ghosts.
		# For now, let's assume we can override it or use a separate component for ghosts later.
		# But since PowerReceiver listens to a GLOBAL signal, all instances will hear it.
		# FIX: We should probably make PowerReceiver have an 'active' flag or just not use it for ghosts if they don't need real hardware input.
		# For this refactor, let's just let it be, but we will manually set power for ghosts which overrides the listener in `_physics_process` if we wanted to.
		# However, PowerReceiver.set_power_manual emits the signal.
		# A cleaner way is to disconnect the signal in PowerReceiver if not needed, but PowerReceiver doesn't know about 'is_player'.
		# Let's disconnect it here if it's not the player.
		SignalBus.trainer_power_updated.disconnect(power_receiver._on_power_updated)

func process_cyclist(delta: float, course: CourseProfile, nearby_entities: Array, run_modifiers: Dictionary = {}) -> void:
	# 1. Gather Inputs
	var raw_power = power_receiver.get_power()

	# 2. Update Components
	drafting.update_drafting(distance_m, nearby_entities)
	draft_factor = drafting.get_draft_factor()

	fatigue.process_fatigue(delta, draft_factor)
	var fatigue_mult = fatigue.get_power_multiplier()

	# 3. Calculate Physics Modifiers
	var physics_modifiers = run_modifiers.duplicate()
	physics_modifiers["dragReduction"] = min(0.99, physics_modifiers.get("dragReduction", 0.0) + draft_factor)

	# Apply Fatigue Multiplier to effective power calculation
	# Note: In the original GameScene, fatigue multiplier was applied to 'effective_power'.
	effective_power = raw_power * fatigue_mult

	# 4. Update Physics
	current_grade = course.get_grade_at_distance(distance_m)
	current_surface = course.get_surface_at_distance(distance_m)

	# Adjust Crr based on surface
	var base_crr = 0.0041 # Default fallback
	if stats: base_crr = stats.crr # Or store base separately
	# Re-calculating Crr every frame might be overkill but follows previous logic
	# Actually, stats.crr is mutated in GameScene. We should probably avoid mutating shared resources if possible.
	# But here we have a unique stats instance per cyclist usually.
	var crr_mult = CourseProfile.get_crr_for_surface(current_surface) / CourseProfile.get_crr_for_surface("asphalt")
	# We can't easily mutate stats.crr cleanly without backing it up.
	# For now, we rely on CyclistPhysics taking 'modifiers' or we just mutate it.
	# CyclistPhysics uses stats.crr. Let's mutate it but resetting it might be needed?
	# Better: CyclistPhysics doesn't take a Crr modifier in the dictionary?
	# Checking CyclistPhysics.gd:
	# var crr: float = stats.crr
	# It doesn't look like it takes a Crr modifier in the dictionary.
	# So we must mutate stats.crr temporarily.
	var original_crr = stats.crr
	stats.crr = stats.crr * crr_mult * run_modifiers.get("crrMult", 1.0)

	var acceleration = CyclistPhysics.calculate_acceleration(
		effective_power,
		velocity_ms,
		stats,
		current_grade,
		physics_modifiers
	)

	# Restore Crr
	stats.crr = original_crr

	velocity_ms += acceleration * delta
	velocity_ms = max(0.0, velocity_ms)
	distance_m += velocity_ms * delta

	# 5. Update Visuals
	if visuals:
		visuals.update_animation(delta, velocity_ms, cadence)
		# Position/Rotation handling is usually done by the parent scene (GameScene) relative to the track/camera,
		# but strictly the visual's internal animation (pedaling) is handled here.
		# The root Node2D transform (position along track) is updated by GameScene based on distance_m.

func set_color(color: Color) -> void:
	if visuals:
		visuals.set_color(color)
