class_name Cyclist
extends Node2D

## Cyclist
## The root entity for a cyclist (player or ghost).
## Coordinates components to handle physics, state, and visuals.

@export var stats: CyclistStats
@export var is_player: bool = false
@export var label: String = "Cyclist"

# Components
@onready var hardware_receiver: Node = $HardwareReceiver
@onready var drafting: Node = $Drafting
@onready var surge: Node = $Surge
@onready var visuals: Node2D = $Visuals

# Physics State
var velocity_ms: float = 0.0
var distance_m: float = 0.0
# var cadence: float = 90.0 # Replaced by hardware_receiver.get_cadence()
var current_grade: float = 0.0
var current_surface: Resource = preload("res://src/features/map/surfaces/asphalt.tres")

# Public Accessors
var effective_power: float = 0.0
var draft_factor: float = 0.0

func _ready() -> void:
	if not stats:
		stats = CyclistStats.new()

	for child in get_children():
		if child.has_method("initialize"):
			child.initialize(self)
	
	if is_player:
		SignalBus.inventory_changed.connect(refresh_visuals)

## Setup the cyclist with specific properties.
func setup(p_is_player: bool, p_stats: CyclistStats, p_label: String = "Cyclist", p_color: Color = Color.WHITE, p_start_distance: float = 0.0, p_base_power: float = 200.0) -> void:
	is_player = p_is_player
	stats = p_stats
	label = p_label
	distance_m = p_start_distance
	
	for child in get_children():
		if child.has_method("initialize"):
			child.initialize(self)
			
	if not is_player and hardware_receiver:
		(hardware_receiver as HardwareReceiverComponent).set_power_manual(p_base_power)
	
	if is_player:
		refresh_visuals()
		# For player, p_color might be used as a base or ignored if items exist
	else:
		set_color(p_color)

func refresh_visuals() -> void:
	if not visuals or not (visuals is CyclistVisuals): return
	
	var v: CyclistVisuals = visuals as CyclistVisuals
	
	# 1. Reset all parts to default (White / Original Color)
	var parts: Array[String] = ["BackPedal", "Wheels", "Chain", "Frame", "Crank", "Handlebars", "Rider"]
	for p: String in parts:
		v.set_part_visuals(p, Color.WHITE)
	
	# Reset Rider specific color (the skin/kit default)
	v.set_part_visuals("Rider", Color(0.35, 0.23, 0.1))

	# 2. Apply equipped item visuals
	if is_player and RunManager.is_active_run:
		var equipped: Dictionary = RunManager.run_data.get("equipped", {})
		for slot: String in equipped:
			var item_id: String = equipped[slot]
			var item_def: Dictionary = ContentRegistry.get_item(item_id)
			if item_def.has("visuals"):
				var vis: Dictionary = item_def["visuals"]
				var color: Color = vis.get("color", Color.WHITE)
				var texture_path: String = vis.get("texture", "")
				var texture: Texture2D = null
				if texture_path != "":
					texture = load(texture_path) as Texture2D
				
				# 'slot' in our items now matches 'part_name' in CyclistVisuals
				v.set_part_visuals(slot, color, texture)

func process_cyclist(delta: float, course: CourseProfile, nearby_entities: Array[Cyclist], run_modifiers: Dictionary = {}) -> void:
	# 1. Gather Inputs
	var raw_power: float = (hardware_receiver as HardwareReceiverComponent).get_power() if hardware_receiver else 0.0

	# 2. Update Components
	if drafting:
		(drafting as DraftingComponent).update_drafting(distance_m, nearby_entities)
		draft_factor = (drafting as DraftingComponent).get_draft_factor()

	if surge:
		(surge as SurgeComponent).process_surge(delta, draft_factor)
		var surge_mult: float = (surge as SurgeComponent).get_power_multiplier()

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
		var surface_crr_mult: float = current_surface.get("crr") / 0.005
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

func _process(delta: float) -> void:
	# 5. Update Visuals
	if visuals and hardware_receiver:
		(visuals as CyclistVisuals).update_animation(delta, velocity_ms, (hardware_receiver as HardwareReceiverComponent).get_cadence())
		# Position/Rotation handling is usually done by the parent scene (GameScene) relative to the track/camera,
		# but strictly the visual's internal animation (pedaling) is handled here.
		# The root Node2D transform (position along track) is updated by GameScene based on distance_m.

func set_color(color: Color) -> void:
	if visuals:
		(visuals as CyclistVisuals).set_color(color)
