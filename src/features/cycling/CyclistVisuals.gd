class_name CyclistVisuals
extends Node2D

## CyclistVisuals
## Pure view component. Handles animations and visual representation of the cyclist.
## Controlled by the parent Cyclist entity.

@export var wheel_frames: int = 12
@export var crank_frames: int = 12

# Internal animation state
var _wheel_rotation: float = 0.0
var _crank_rotation: float = 0.0

## Updates the animation state.
## 'velocity' affects wheel rotation speed and bobbing.
## 'cadence_rpm' affects crank rotation speed.
## 'delta' is the time step.
func update_animation(delta: float, velocity: float, cadence_rpm: float) -> void:
	# Update rotation accumulators
	_wheel_rotation += velocity * delta * 10.0
	_crank_rotation += (cadence_rpm / 60.0) * 2.0 * PI * delta

	_animate_parts(velocity)

func _animate_parts(velocity: float) -> void:
	# Frame Index for Wheels/Chain/Frame (Speed-based)
	var wheel_idx = 0
	if velocity > 0.1:
		wheel_idx = int(fmod(_wheel_rotation, 2.0 * PI) / (2.0 * PI) * wheel_frames)
		if wheel_idx < 0: wheel_idx += wheel_frames

	# Frame Index for Crank (Cadence-based)
	var crank_idx = int(fmod(_crank_rotation, 2.0 * PI) / (2.0 * PI) * crank_frames)
	if crank_idx < 0: crank_idx += crank_frames

	# Update Sprites
	for child in get_children():
		if child is Sprite2D:
			if child.name == "Crank" or child.name == "BackPedal":
				child.frame = crank_idx
			else:
				child.frame = wheel_idx

	# Bob ONLY the Rider (the person)
	var bob = 0.0
	if velocity > 0.1:
		bob = sin(Time.get_ticks_msec() * 0.01) * 3.0

	for node_name in ["Rider", "RiderPoly"]:
		if has_node(node_name):
			var rider = get_node(node_name)
			var base_y = -45.0 if rider is Sprite2D else -62.0
			rider.position.y = base_y + bob

	# Ensure Bike parts stay stationary (at their base_y)
	for node_name in ["Frame", "Crank", "Chain", "Wheels", "Handlebars", "BackPedal"]:
		if has_node(node_name):
			var child = get_node(node_name)
			if child is Sprite2D:
				child.position.y = -45.0

## Sets the color of the cyclist parts (for ghosts/teams).
func set_color(color: Color) -> void:
	if has_node("Frame"): get_node("Frame").modulate = color
	if has_node("Crank"): get_node("Crank").modulate = color

	if has_node("Rider"):
		var rider = get_node("Rider")
		if rider is Sprite2D: rider.modulate = color
		elif rider is Polygon2D: rider.color = color

	if has_node("RiderPoly"):
		get_node("RiderPoly").color = color
