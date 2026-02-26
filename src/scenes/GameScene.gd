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
var raw_trainer_speed_ms: float = 0.0
var latest_power: float = 0.0
var current_grade: float = 0.0
var current_surface: String = "asphalt"
var player_draft_factor: float = 0.0

var ghosts: Array = [] # List of Dictionaries { "distance_m", "velocity_ms", "power_w", "node" }
var ghost_scene = preload("res://src/scenes/CyclistVisuals.tscn")

var base_physics: Dictionary = {}
var physics_config: Dictionary = {}
var run_modifiers: Dictionary = {}

var course: Dictionary = {}
var is_complete: bool = false

# Surge / Recovery state
var surge_timer: float = 0.0
var recovery_timer: float = 0.0
const SURGE_DURATION: float = 5.0
const SURGE_POWER_MULT: float = 1.25
const RECOVERY_DURATION: float = 4.0
const RECOVERY_POWER_MULT: float = 0.85

var fit_writer: FitWriter
var last_record_ms: int = 0
var ride_start_time: int = 0

var is_dev_build: bool = false

func _ready() -> void:
	ride_start_time = Time.get_ticks_msec()
	fit_writer = FitWriter.new(Time.get_unix_time_from_system() * 1000)
	last_record_ms = ride_start_time
	
	# Initialize physics from settings
	var weight_kg = SettingsManager.weight_kg
	var mass_kg = weight_kg + 8.0
	var cd_a = 0.416 * pow(weight_kg / 114.3, 0.66)
	var crr = 0.0041
	
	base_physics = CyclistPhysics.get_default_config()
	base_physics["massKg"] = mass_kg
	base_physics["cdA"] = cd_a
	base_physics["crr"] = crr
	
	physics_config = base_physics.duplicate()
	
	# Initialize Course from Active Edge
	if RunManager.is_active_run:
		var ae = RunManager.get_active_edge()
		if not ae.is_empty():
			course = ae["profile"]
			current_surface = CourseProfile.get_surface_at_distance(course, 0.0)
			_update_physics_for_surface_and_grade(0.0, current_surface)
			_apply_biome_theming(ae)
		run_modifiers = RunManager.run_data["modifiers"]
	else:
		course = CourseProfile.generate_course_profile(5.0, 0.05)
		run_modifiers = { "powerMult": 1.0, "dragReduction": 0.0, "weightMult": 1.0, "crrMult": 1.0 }
		current_surface = "asphalt"
		_update_physics_for_surface_and_grade(0.0, current_surface)

	TrainerService.data_received.connect(_on_trainer_data)
	TrainerService.connect_trainer()
	
	# Setup UI
	progress_bar.max_value = course.get("totalDistanceM", 1000.0)
	progress_bar.value = 0.0
	_build_elevation_graph()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()
	
	# Spawn Ghosts
	_spawn_ghosts()

	# Dev-only speed control
	var hostname = JavaScriptBridge.eval("window.location.hostname")
	if typeof(hostname) == TYPE_STRING and hostname.begins_with("spokesdev"):
		is_dev_build = true
		_create_speed_control()

func _update_physics_for_surface_and_grade(p_grade: float, p_surface: String) -> void:
	current_grade = p_grade
	current_surface = p_surface
	
	var crr_mult = CourseProfile.get_crr_for_surface(p_surface) / CourseProfile.get_crr_for_surface("asphalt")
	var effective_crr = base_physics["crr"] * crr_mult * run_modifiers.get("crrMult", 1.0)
	
	physics_config = base_physics.duplicate()
	physics_config["grade"] = p_grade
	physics_config["crr"] = effective_crr

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
		var rider_n = g_node.get_node("Rider")
		rider_n.color = Color.from_hsv(0.6 + i * 0.1, 0.5, 0.8)
		
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
	var width = $HUD/MarginContainer/VBoxContainer/ElevationContainer.size.x
	if width <= 0: width = 1240
	
	var container_size = Vector2(width, 100)
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
		var x = (float(i) / points) * width
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
	
	# 0. Autoplay Power (only if no real trainer is active)
	if RunManager.autoplay_enabled and TrainerService.is_mock_mode:
		var target_power = float(RunManager.run_data.get("ftpW", 200.0))
		latest_power = target_power
	
	# 1. Update Drafting Logic
	var best_draft = 0.0
	
	for g in ghosts:
		var gap_behind = g["distance_m"] - distance_m # Ghost is in front
		var gap_ahead = distance_m - g["distance_m"]  # Ghost is behind
		
		# Benefit from ghost in front (standard draft)
		var draft = DraftingPhysics.get_draft_factor(gap_behind)
		# Benefit from ghost behind (push)
		var push = DraftingPhysics.get_leading_draft_factor(gap_ahead)
		
		best_draft = max(best_draft, max(draft, push))
				
	player_draft_factor = best_draft
	
	# Surge State Machine
	if surge_timer > 0:
		surge_timer -= delta
		if surge_timer <= 0:
			recovery_timer = RECOVERY_DURATION
	elif recovery_timer > 0:
		recovery_timer -= delta
	elif player_draft_factor > 0.01:
		surge_timer = SURGE_DURATION
	
	# 2. Update Player Physics
	var new_grade = CourseProfile.get_grade_at_distance(course, distance_m)
	var new_surface = CourseProfile.get_surface_at_distance(course, distance_m)
	
	if new_grade != current_grade or new_surface != current_surface:
		_update_physics_for_surface_and_grade(new_grade, new_surface)
		if new_surface != current_surface:
			parallax.set_surface(new_surface)
	
	var draft_mods = run_modifiers.duplicate()
	draft_mods["dragReduction"] = min(0.99, draft_mods.get("dragReduction", 0.0) + player_draft_factor)
	
	var effective_power = latest_power
	if surge_timer > 0:
		effective_power *= SURGE_POWER_MULT
	elif recovery_timer > 0:
		effective_power *= RECOVERY_POWER_MULT
	
	if not TrainerService.is_mock_mode:
		# Directly tie in-game speed to the physical flywheel's speed (bypassing virtual inertia)
		# We apply the surge/recovery multiplier to the speed itself so it actually feels like an "attack"
		var target_speed = raw_trainer_speed_ms
		if surge_timer > 0: target_speed *= 1.15 # 15% speed boost during attack
		elif recovery_timer > 0: target_speed *= 0.90 # 10% speed penalty during recovery
		
		velocity_ms += (target_speed - velocity_ms) * delta * 5.0
	else:
		var acceleration = CyclistPhysics.calculate_acceleration(
			effective_power, 
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
		var g_surface = CourseProfile.get_surface_at_distance(course, g_dist)
		
		var g_crr_mult = CourseProfile.get_crr_for_surface(g_surface) / CourseProfile.get_crr_for_surface("asphalt")
		
		var g_config = physics_config.duplicate()
		g_config["grade"] = g_grade
		g_config["crr"] = base_physics["crr"] * g_crr_mult
		
		# Ghost also drafts the player (following)
		var g_draft = DraftingPhysics.get_draft_factor(distance_m - g_dist)
		# Ghost also gets pushed (leading player)
		g_draft = max(g_draft, DraftingPhysics.get_leading_draft_factor(g_dist - distance_m))
		
		for other in ghosts:
			if other == g: continue
			# Drafting other ghosts
			g_draft = max(g_draft, DraftingPhysics.get_draft_factor(other["distance_m"] - g_dist))
			# Getting pushed by other ghosts
			g_draft = max(g_draft, DraftingPhysics.get_leading_draft_factor(g_dist - other["distance_m"]))
			
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
	_update_hud(effective_power)
	_update_visuals(delta)
	
	if Engine.get_physics_frames() % 60 == 0:
		# Match Phaser's Trainer simulation parameters (scaling by massRatio)
		var assumed_trainer_mass = 83.0
		var mass_ratio = physics_config["massKg"] / assumed_trainer_mass
		
		var effective_grade = current_grade * mass_ratio
		var effective_crr = physics_config["crr"] * mass_ratio
		# CWA = CdA according to Phaser implementation (Rho scaling is commented out there)
		var cwa = physics_config["cdA"]
		
		TrainerService.set_simulation_params(effective_grade, effective_crr, cwa)

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
		var relative_x = (g["distance_m"] - distance_m) * 100.0
		g_node.position.x = 300.0 + relative_x
		
		g["wheel_rotation"] += g["velocity_ms"] * delta * 10.0
		_animate_cyclist(g_node, g["wheel_rotation"], g["velocity_ms"])
	
	# Update Player marker on elevation graph
	var total_dist = course.get("totalDistanceM", 1.0)
	var graph_width = $HUD/MarginContainer/VBoxContainer/ElevationContainer.size.x
	if graph_width <= 0: graph_width = 1240
	player_marker.position.x = (distance_m / total_dist) * graph_width

func _on_viewport_resized() -> void:
	var vw = get_viewport_rect().size.x
	var mirror_val = Vector2(max(1280, vw), 0)
	if parallax:
		for layer in parallax.get_children():
			if layer is ParallaxLayer:
				layer.motion_mirroring = mirror_val
				for child in layer.get_children():
					if child is Control:
						child.custom_minimum_size.x = mirror_val.x
	_build_elevation_graph()

func _animate_cyclist(node: Node2D, w_rot: float, vel: float) -> void:
	node.get_node("WheelBack").rotation = w_rot
	node.get_node("WheelFront").rotation = w_rot
	
	var bob = sin(Time.get_ticks_msec() * 0.01) * (3.0 if vel > 1.0 else 0.5)
	node.get_node("Rider").position.y = -65 + bob

func _create_speed_control() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(20, -60)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	var lbl = Label.new()
	lbl.text = "SPEED:"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(lbl)

	for speed in [1.0, 2.0, 5.0, 10.0]:
		var btn = Button.new()
		btn.text = "%gx" % speed
		btn.custom_minimum_size = Vector2(48, 32)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color.WHITE)
		var s_normal = StyleBoxFlat.new()
		s_normal.bg_color = Color(0.25, 0.25, 0.25, 1.0)
		s_normal.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", s_normal)
		var s_hover = s_normal.duplicate()
		s_hover.bg_color = Color(0.45, 0.45, 0.45, 1.0)
		btn.add_theme_stylebox_override("hover", s_hover)
		var s_pressed = s_normal.duplicate()
		s_pressed.bg_color = Color(1.0, 0.55, 0.0, 1.0)
		btn.add_theme_stylebox_override("pressed", s_pressed)
		btn.pressed.connect(func(): Engine.time_scale = speed)
		hbox.add_child(btn)

func _on_ride_complete() -> void:
	is_complete = true
	velocity_ms = 0.0
	Engine.time_scale = 1.0
	
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
	if data.has("speed_kmh"):
		raw_trainer_speed_ms = data["speed_kmh"] / 3.6
	
	if data.has("cadence"):
		var cadence_node = hud_power_label.get_parent().get_parent().find_child("CadenceValue", true, false)
		if cadence_node:
			cadence_node.text = str(round(data["cadence"])) + " RPM"

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var pause_menu = load("res://src/ui/PauseOverlay.tscn").instantiate()
		add_child(pause_menu)
		get_viewport().set_input_as_handled()

func _update_hud(p_effective_power: float) -> void:
	if hud_power_label:
		hud_power_label.text = str(round(p_effective_power)) + " W"
	if hud_speed_label:
		var speed = Units.ms_to_kmh(velocity_ms) if SettingsManager.units == "metric" else Units.ms_to_mph(velocity_ms)
		var unit_suffix = " km/h" if SettingsManager.units == "metric" else " mph"
		hud_speed_label.text = Units.format_fixed(speed, 1) + unit_suffix
	if hud_dist_label:
		var dist = Units.m_to_km(distance_m) if SettingsManager.units == "metric" else Units.m_to_mi(distance_m)
		var unit_suffix = " km" if SettingsManager.units == "metric" else " mi"
		hud_dist_label.text = Units.format_fixed(dist, 2) + unit_suffix
	if hud_grade_label:
		hud_grade_label.text = "Grade: " + Units.format_fixed(current_grade * 100.0, 1) + "%"
	if progress_bar:
		progress_bar.value = distance_m
		
	# Update Draft/Surge Badge
	if surge_timer > 0:
		draft_badge.visible = true
		draft_badge.get_node("Label").text = "ATTACK! +25% POWER"
		draft_badge.modulate = Color.ORANGE_RED
	elif recovery_timer > 0:
		draft_badge.visible = true
		draft_badge.get_node("Label").text = "RECOVERING... -15% POWER"
		draft_badge.modulate = Color.SKY_BLUE
	elif player_draft_factor > 0.01:
		draft_badge.visible = true
		draft_badge.get_node("Label").text = "SLIPSTREAM  −%d%% DRAG" % int(player_draft_factor * 100)
		draft_badge.modulate = Color.WHITE
	else:
		draft_badge.visible = false
		
	# Update Race Gap Panel (Only every 10 frames to prevent layout churn)
	if Engine.get_physics_frames() % 10 == 0:
		for child in race_gap_panel.get_children():
			child.queue_free()
			
		# Sort ghosts by distance
		var sorted_ghosts = ghosts.duplicate()
		sorted_ghosts.sort_custom(func(a, b): return a["distance_m"] > b["distance_m"])
		
		for g in sorted_ghosts:
			var gap = g["distance_m"] - distance_m
			var l = Label.new()
			var dist_str = "%+.1f m" % gap
			l.text = g["label"] + ": " + dist_str
			l.add_theme_font_size_override("font_size", 14)
			if gap > 0: l.add_theme_color_override("font_color", Color.SALMON)
			else: l.add_theme_color_override("font_color", Color.LIGHT_GREEN)
			race_gap_panel.add_child(l)
