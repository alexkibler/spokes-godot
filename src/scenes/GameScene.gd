extends Node2D

# Orchestrator for the riding experience

@onready var hud_power_label: Label = $HUD/MarginContainer/VBoxContainer/HBoxContainer/Stats/PowerValue
@onready var hud_speed_label: Label = $HUD/MarginContainer/VBoxContainer/HBoxContainer/Stats/SpeedValue
@onready var hud_dist_label: Label = $HUD/MarginContainer/VBoxContainer/HBoxContainer/Stats/DistValue
@onready var hud_grade_label: Label = $HUD/MarginContainer/VBoxContainer/HBoxContainer/Stats/GradeValue
@onready var progress_bar: ProgressBar = $HUD/MarginContainer/VBoxContainer/ProgressBar
@onready var environment: Node2D = $Environment
@onready var player_cyclist: Node2D = $Environment/PlayerCyclist
@onready var parallax: ParallaxBackground = $ParallaxBackground
@onready var elevation_line: Line2D = $HUD/MarginContainer/VBoxContainer/ElevationContainer/ElevationLine
@onready var player_marker: ColorRect = $HUD/MarginContainer/VBoxContainer/ElevationContainer/PlayerMarker
@onready var draft_badge: PanelContainer = %DraftBadge
@onready var race_gap_panel: VBoxContainer = %RaceGapPanel

var wheel_rotation: float = 0.0
var distance_m: float = 0.0
var velocity_ms: float = 0.0
var latest_power: float = 0.0
var current_grade: float = 0.0
var player_draft_factor: float = 0.0

var ghosts: Array = [] # List of Dictionaries { "distance_m", "velocity_ms", "power_w", "node" }
var ghost_scene = preload("res://src/scenes/CyclistVisuals.tscn")

var physics_config: Dictionary = {}
var run_modifiers: Dictionary = {}

var course: Dictionary = {}
var is_complete: bool = false

var fit_writer: FitWriter
var last_record_ms: int = 0
var ride_start_time: int = 0

func _ready() -> void:
	ride_start_time = Time.get_ticks_msec()
	fit_writer = FitWriter.new(Time.get_unix_time_from_system() * 1000)
	last_record_ms = ride_start_time
	
	# Initialize physics from settings
	var weight_kg = SettingsManager.weight_kg
	var mass_kg = weight_kg + 8.0
	var base_cd_a = 0.416 * pow(weight_kg / 114.3, 0.66)
	
	physics_config = CyclistPhysics.get_default_config()
	physics_config["massKg"] = mass_kg
	physics_config["cdA"] = base_cd_a
	
	# Initialize Course from Active Edge
	if RunManager.is_active_run:
		var ae = RunManager.get_active_edge()
		if not ae.is_empty():
			course = ae["profile"]
			var surface = CourseProfile.get_surface_at_distance(course, 0.0)
			var crr_mult = CourseProfile.get_crr_for_surface(surface) / CourseProfile.get_crr_for_surface("asphalt")
			physics_config["crr"] = physics_config["crr"] * crr_mult
			_apply_biome_theming(ae)
		run_modifiers = RunManager.run_data["modifiers"]
	else:
		course = CourseProfile.generate_course_profile(5.0, 0.05)
		run_modifiers = { "powerMult": 1.0, "dragReduction": 0.0, "weightMult": 1.0, "crrMult": 1.0 }

	TrainerService.data_received.connect(_on_trainer_data)
	TrainerService.connect_trainer()
	
	# Setup UI
	progress_bar.max_value = course.get("totalDistanceM", 1000.0)
	progress_bar.value = 0.0
	_build_elevation_graph()
	
	# Spawn Ghosts
	_spawn_ghosts()

func _spawn_ghosts() -> void:
	# Spawn 3 ghosts with slightly different powers
	var base_power = 200.0
	if RunManager.is_active_run:
		base_power = RunManager.run_data.get("ftpW", 200.0)
		
	var offsets = [0.95, 1.05, 1.15]
	var labels = ["ROOKIE", "PRO", "ELITE"]
	
	for i in range(3):
		var g_node = ghost_scene.instantiate()
		environment.add_child(g_node)
		
		# Style the ghost
		var rider = g_node.get_node("Rider")
		rider.color = Color.from_hsv(0.6 + i * 0.1, 0.5, 0.8)
		
		var ghost_state = {
			"label": labels[i],
			"distance_m": 10.0 + i * 5.0,
			"velocity_ms": 0.0,
			"power_w": base_power * offsets[i],
			"node": g_node,
			"wheel_rotation": 0.0
		}
		ghosts.append(ghost_state)

func _apply_biome_theming(edge: Dictionary) -> void:
	var spoke_id = "plains"
	var run = RunManager.get_run()
	for n in run["nodes"]:
		if n["id"] == edge["to"]:
			spoke_id = n.get("metadata", {}).get("spokeId", "plains")
			break
	
	var color = SpokesTheme.BIOME_COLORS.get(spoke_id, Color.DARK_GREEN)
	$ParallaxBackground/HillLayer/Hills.color = color.lerp(Color.BLACK, 0.2)
	$ParallaxBackground/GroundLayer/Field.color = color.lerp(Color.BLACK, 0.4)

func _build_elevation_graph() -> void:
	elevation_line.clear_points()
	var total_dist = course.get("totalDistanceM", 1000.0)
	var container_size = Vector2(1240, 100)
	var points = 100
	
	var elev_points = []
	var min_elev = 0.0
	var max_elev = 0.0
	
	for i in range(points + 1):
		var d = (float(i) / points) * total_dist
		var e = _get_elevation_at(course, d)
		elev_points.append(e)
		min_elev = min(min_elev, e)
		max_elev = max(max_elev, e)
		
	var range_elev = max(10.0, max_elev - min_elev)
	
	for i in range(elev_points.size()):
		var x = (float(i) / points) * 1240.0 
		var y = container_size.y - ((elev_points[i] - min_elev) / range_elev) * container_size.y
		elevation_line.add_point(Vector2(x, y))

func _get_elevation_at(p_course: Dictionary, p_dist: float) -> float:
	var wrapped = fmod(p_dist, p_course["totalDistanceM"])
	var remaining = wrapped
	var elevation = 0.0
	for segment in p_course["segments"]:
		var dist = min(remaining, segment["distanceM"])
		elevation += dist * segment["grade"]
		if remaining <= segment["distanceM"]: break
		remaining -= segment["distanceM"]
	return elevation

func _physics_process(delta: float) -> void:
	if is_complete: return
	
	# 1. Update Drafting
	var best_draft = 0.0
	for g in ghosts:
		best_draft = max(best_draft, DraftingPhysics.get_draft_factor(g["distance_m"] - distance_m))
	player_draft_factor = best_draft
	
	# 2. Update Player Physics
	current_grade = CourseProfile.get_grade_at_distance(course, distance_m)
	physics_config["grade"] = current_grade
	
	var draft_mods = run_modifiers.duplicate()
	draft_mods["dragReduction"] = min(0.99, draft_mods.get("dragReduction", 0.0) + player_draft_factor)
	
	var acceleration = CyclistPhysics.calculate_acceleration(
		latest_power, 
		velocity_ms, 
		physics_config, 
		draft_mods
	)
	
	velocity_ms += acceleration * delta
	velocity_ms = max(0.0, velocity_ms)
	distance_m += velocity_ms * delta
	
	# 3. Update Ghosts
	for g in ghosts:
		var g_dist = g["distance_m"]
		var g_grade = CourseProfile.get_grade_at_distance(course, g_dist)
		var g_config = physics_config.duplicate()
		g_config["grade"] = g_grade
		
		# Ghost also drafts!
		var g_draft = DraftingPhysics.get_draft_factor(distance_m - g_dist)
		for other in ghosts:
			if other == g: continue
			g_draft = max(g_draft, DraftingPhysics.get_draft_factor(other["distance_m"] - g_dist))
			
		var g_accel = CyclistPhysics.calculate_acceleration(g["power_w"], g["velocity_ms"], g_config, {"dragReduction": g_draft})
		g["velocity_ms"] = max(0.0, g["velocity_ms"] + g_accel * delta)
		g["distance_m"] += g["velocity_ms"] * delta
	
	# 4. Record every second
	var now = Time.get_ticks_msec()
	if now - last_record_ms >= 1000:
		last_record_ms = now
		fit_writer.add_record({
			"timestampMs": Time.get_unix_time_from_system() * 1000,
			"powerW": latest_power,
			"cadenceRpm": 90,
			"speedMs": velocity_ms,
			"distanceM": distance_m
		})
	
	# 5. Check Completion
	if distance_m >= course.get("totalDistanceM", 1000000.0):
		_on_ride_complete()
	
	# 6. Update UI & Visuals
	_update_hud()
	_update_visuals(delta)
	
	if Engine.get_physics_frames() % 60 == 0:
		TrainerService.set_simulation_params(current_grade, physics_config["crr"])

func _update_visuals(delta: float) -> void:
	# Parallax scrolling
	parallax.scroll_offset.x -= velocity_ms * delta * 100.0
	
	# Rotate the environment
	var target_rot = -atan(current_grade * 3.0) 
	environment.rotation = lerp_angle(environment.rotation, target_rot, delta * 2.0)
	
	# Animate Player
	wheel_rotation += velocity_ms * delta * 10.0
	_animate_cyclist(player_cyclist, wheel_rotation, velocity_ms)
	
	# Animate and Position Ghosts
	for g in ghosts:
		var g_node = g["node"]
		# Screen position: 1 meter = 100 pixels (arbitrary scaling)
		# Player is at x=300 relative to environment
		var relative_x = (g["distance_m"] - distance_m) * 100.0
		g_node.position.x = 300.0 + relative_x
		
		g["wheel_rotation"] += g["velocity_ms"] * delta * 10.0
		_animate_cyclist(g_node, g["wheel_rotation"], g["velocity_ms"])
	
	# Update Player marker on elevation graph
	var total_dist = course.get("totalDistanceM", 1.0)
	player_marker.position.x = (distance_m / total_dist) * 1240.0

func _animate_cyclist(node: Node2D, w_rot: float, vel: float) -> void:
	node.get_node("WheelBack").rotation = w_rot
	node.get_node("WheelFront").rotation = w_rot
	
	var bob = sin(Time.get_ticks_msec() * 0.01) * (3.0 if vel > 1.0 else 0.5)
	node.get_node("Rider").position.y = -65 + bob

func _on_ride_complete() -> void:
	is_complete = true
	velocity_ms = 0.0
	
	var run = RunManager.get_run()
	var current_node = null
	for n in run["nodes"]:
		if n["id"] == run["currentNodeId"]:
			current_node = n
			break
			
	var is_first_clear = RunManager.complete_active_edge()
	
	if current_node and current_node["type"] == "finish":
		get_tree().change_scene_to_file("res://src/scenes/VictoryScene.tscn")
		return

	if is_first_clear:
		var overlay = load("res://src/ui/RewardOverlay.tscn").instantiate()
		add_child(overlay)
		overlay.reward_selected.connect(func(): get_tree().change_scene_to_file("res://src/scenes/MapScene.tscn"))
	else:
		get_tree().create_timer(2.0).timeout.connect(func(): get_tree().change_scene_to_file("res://src/scenes/MapScene.tscn"))

func _on_trainer_data(data: Dictionary) -> void:
	latest_power = data.get("power", 0.0)

func _update_hud() -> void:
	if hud_power_label:
		hud_power_label.text = str(round(latest_power)) + " W"
	if hud_speed_label:
		var speed = CyclistPhysics.ms_to_kmh(velocity_ms) if SettingsManager.units == "metric" else CyclistPhysics.ms_to_mph(velocity_ms)
		var unit_suffix = " km/h" if SettingsManager.units == "metric" else " mph"
		hud_speed_label.text = "%.1f" % speed + unit_suffix
	if hud_dist_label:
		var dist = distance_m / 1000.0 if SettingsManager.units == "metric" else distance_m * 0.000621371
		var unit_suffix = " km" if SettingsManager.units == "metric" else " mi"
		hud_dist_label.text = "%.2f" % dist + unit_suffix
	if hud_grade_label:
		hud_grade_label.text = "Grade: %.1f%%" % (current_grade * 100.0)
	if progress_bar:
		progress_bar.value = distance_m
		
	# Update Draft Badge
	if player_draft_factor > 0.01:
		draft_badge.visible = true
		draft_badge.get_node("Label").text = "SLIPSTREAM -%d%% DRAG" % int(player_draft_factor * 100)
	else:
		draft_badge.visible = false
		
	# Update Race Gap Panel
	for child in race_gap_panel.get_children():
		child.queue_free()
		
	# Sort ghosts by distance
	var sorted_ghosts = ghosts.duplicate()
	sorted_ghosts.sort_custom(func(a, b): return a["distance_m"] > b["distance_m"])
	
	for g in sorted_ghosts:
		var gap = g["distance_m"] - distance_m
		var l = Label.new()
		var color_prefix = "[color=green]" if gap < 0 else "[color=red]"
		var dist_str = "%+.1f m" % gap
		l.text = g["label"] + ": " + dist_str
		l.add_theme_font_size_override("font_size", 14)
		if gap > 0: l.add_theme_color_override("font_color", Color.SALMON)
		else: l.add_theme_color_override("font_color", Color.LIGHT_GREEN)
		race_gap_panel.add_child(l)
