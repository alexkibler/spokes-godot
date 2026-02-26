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
@onready var ground_line: Line2D = $Environment/Ground
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
var travel_direction: float = 1.0 # 1.0 for L->R, -1.0 for R->L
var cadence: float = 90.0
var crank_rotation: float = 0.0

var ghosts: Array = [] # List of Dictionaries { "distance_m", "velocity_ms", "power_w", "node", "stats" }
var ghost_scene = preload("res://src/features/cycling/CyclistVisuals.tscn")

var player_stats: CyclistStats
var base_crr: float = 0.0041
var run_modifiers: Dictionary = { "powerMult": 1.0, "dragReduction": 0.0, "weightMult": 1.0, "crrMult": 1.0 }

var course: CourseProfile = null
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

# Elite Challenge Tracking
var challenge_power_sum: float = 0.0
var challenge_tick_count: int = 0
var challenge_peak_power: float = 0.0
var challenge_ever_stopped: bool = false
var challenge_start_time: int = 0

func _ready() -> void:
	ride_start_time = Time.get_ticks_msec()
	fit_writer = FitWriter.new(Time.get_unix_time_from_system() * 1000)
	last_record_ms = ride_start_time
	
	# Initialize stats from settings
	var weight_kg = SettingsManager.weight_kg
	player_stats = CyclistStats.new()
	player_stats.mass_kg = weight_kg + 8.0
	player_stats.cda = 0.416 * pow(weight_kg / 114.3, 0.66)
	player_stats.crr = 0.0041
	base_crr = player_stats.crr
	
	# Initialize Course from Active Edge
	if RunManager.is_active_run:
		run_modifiers = RunManager.run_data["modifiers"]
		var ae = RunManager.get_active_edge()
		if not ae.is_empty():
			course = ae["profile"]
			current_surface = course.get_surface_at_distance(0.0)
			
			# Determine direction from map coordinates
			var from_node = null
			var to_node = null
			for n in RunManager.run_data["nodes"]:
				if n["id"] == ae["actual_from"]: from_node = n
				if n["id"] == ae["actual_to"]: to_node = n
			
			if from_node and to_node:
				var dx = to_node["x"] - from_node["x"]
				var dy = to_node["y"] - from_node["y"]
				if abs(dx) > 0.1:
					travel_direction = 1.0 if dx > 0 else -1.0
				else:
					# Straight vertical: North (decreasing Y) is L->R, South (increasing Y) is R->L
					travel_direction = 1.0 if dy < 0 else -1.0
			
			_update_physics_for_surface_and_grade(0.0, current_surface)
			_apply_biome_theming(ae)
			
			var vw = get_viewport_rect().size.x
			if vw <= 0: vw = 1280
			player_cyclist.position.x = vw - 300.0 if travel_direction < 0 else 300.0
	else:
		run_modifiers = { "powerMult": 1.0, "dragReduction": 0.0, "weightMult": 1.0, "crrMult": 1.0 }
		course = CourseProfile.generate_course_profile(5.0, 0.05)
		current_surface = "asphalt"
		_update_physics_for_surface_and_grade(0.0, current_surface)

	TrainerService.data_received.connect(_on_trainer_data)
	TrainerService.connect_trainer()
	
	cadence = TrainerService.mock_cadence if TrainerService.is_mock_mode else 0.0
	
	# Setup UI
	progress_bar.max_value = course.total_distance_m
	progress_bar.value = 0.0
	
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized() # This now handles _build_elevation_graph via process_frame
	
	# Spawn Ghosts
	_spawn_ghosts()

	RunManager.item_discovered.connect(_on_item_discovered)
	
	cadence = TrainerService.mock_cadence if TrainerService.is_mock_mode else 0.0

	# Dev-only speed control
	var hostname = JavaScriptBridge.eval("window.location.hostname")
	if typeof(hostname) == TYPE_STRING and hostname.begins_with("spokesdev"):
		is_dev_build = true
		_create_speed_control()

func _update_physics_for_surface_and_grade(p_grade: float, p_surface: String) -> void:
	current_grade = p_grade
	current_surface = p_surface
	
	var crr_mult = CourseProfile.get_crr_for_surface(p_surface) / CourseProfile.get_crr_for_surface("asphalt")
	player_stats.crr = base_crr * crr_mult * run_modifiers.get("crrMult", 1.0)

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
		var color = Color.from_hsv(0.6 + i * 0.1, 0.5, 0.8)
		if g_node.has_node("Frame"):
			g_node.get_node("Frame").modulate = color
		if g_node.has_node("Crank"):
			g_node.get_node("Crank").modulate = color
		if g_node.has_node("Rider"):
			var rider = g_node.get_node("Rider")
			if rider is Sprite2D:
				rider.modulate = color
			else:
				rider.color = color
		if g_node.has_node("RiderPoly"):
			g_node.get_node("RiderPoly").color = color
		
		# Legacy support for old single-sprite
		if g_node.has_node("Sprite2D"):
			g_node.get_node("Sprite2D").modulate = color
			
		var ghost_state = {
			"label": labels[i],
			"distance_m": 10.0 + i * 5.0,
			"velocity_ms": 0.0,
			"power_w": base_power * offsets[i],
			"node": g_node,
			"wheel_rotation": 0.0,
			"crank_rotation": 0.0,
			"stats": player_stats.duplicate()
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
	$Environment/RoadFill.color = color.lerp(Color.BLACK, 0.4)

func _build_elevation_graph() -> void:
	if not is_inside_tree() or course == null: return
	
	elevation_line.clear_points()
	var total_dist = course.total_distance_m
	var width = $HUD/MarginContainer/VBoxContainer/ElevationContainer.size.x
	if width <= 0: width = 1240
	
	var container_height = 100.0
	var points = 100
	
	var elev_points = []
	for i in range(points + 1):
		var d = (float(i) / points) * total_dist
		elev_points.append(course.get_elevation_at_distance(d))
	
	var min_elev = elev_points[0]
	var max_elev = elev_points[0]
	for e in elev_points:
		min_elev = min(min_elev, e)
		max_elev = max(max_elev, e)
		
	var range_elev = max(5.0, max_elev - min_elev) # Minimum 5m scale
	
	# Add 10% vertical padding
	var padding = range_elev * 0.1
	min_elev -= padding
	range_elev += padding * 2.0
	
	for i in range(elev_points.size()):
		var x = (float(i) / points) * width
		if travel_direction < 0:
			x = width - x
		var y = container_height - ((elev_points[i] - min_elev) / range_elev) * container_height
		elevation_line.add_point(Vector2(x, y))

func _update_ground_line() -> void:
	if course == null: return
	
	var vw = get_viewport_rect().size.x
	if vw <= 0: vw = 1280
	
	var points = []
	var start_x = -500.0 # Relative to environment (which is at x=0)
	var end_x = vw + 500.0 
	var step_x = 25.0   # pixels (0.25m per step at 100px/m)
	
	var total_dist = course.total_distance_m
	var base_elev = course.get_elevation_at_distance(distance_m)
	
	# Cache grades for extrapolation
	var start_grade = course.get_grade_at_distance(0.0)
	var end_grade = course.get_grade_at_distance(total_dist - 0.1)
	
	var player_anchor_x = vw - 300.0 if travel_direction < 0 else 300.0
	
	for x in range(int(start_x), int(end_x) + int(step_x), int(step_x)):
		var d = distance_m + travel_direction * (float(x) - player_anchor_x) / 100.0
		
		var elev: float
		if d < 0:
			# Extrapolate backward from start
			elev = d * start_grade
		elif d > total_dist:
			# Extrapolate forward from end
			var final_elev = course.get_elevation_at_distance(total_dist)
			elev = final_elev + (d - total_dist) * end_grade
		else:
			elev = course.get_elevation_at_distance(d)
			
		# Match the steepness scaling of the physics exaggeration (3.0 factor)
		var y = -(elev - base_elev) * 100.0 * 3.0
		points.append(Vector2(x, y))
	
	ground_line.points = PackedVector2Array(points)
	
	# Update RoadFill polygon to cover the area below the line
	var poly_points = points.duplicate()
	poly_points.append(Vector2(end_x, 1000.0)) # Far below screen
	poly_points.append(Vector2(start_x, 1000.0))
	$Environment/RoadFill.polygon = PackedVector2Array(poly_points)

func _physics_process(delta: float) -> void:
	if is_complete: return
	
	# 0. Mock Power Simulation (if no real trainer is active)
	if TrainerService.is_mock_mode:
		latest_power = float(RunManager.run_data.get("ftpW", 200.0))
	
	# 1. Update Drafting Logic
	var best_draft = 0.0
	
	for g in ghosts:
		var gap_behind = g["distance_m"] - distance_m # Ghost is in front
		var gap_ahead = distance_m - g["distance_m"]  # Ghost is behind
		
		# Benefit from ghost in front (standard draft)
		var draft = DraftingPhysics.get_draft_factor(player_stats, gap_behind)
		# Benefit from ghost behind (push)
		var push = DraftingPhysics.get_leading_draft_factor(player_stats, gap_ahead)
		
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
	var new_grade = course.get_grade_at_distance(distance_m)
	var new_surface = course.get_surface_at_distance(distance_m)
	
	# Track metrics for Elite Challenges
	if RunManager.active_challenge != null:
		challenge_power_sum += latest_power
		challenge_tick_count += 1
		challenge_peak_power = max(challenge_peak_power, latest_power)
		if velocity_ms < 0.1 and distance_m > 10.0: # Ignore very start
			challenge_ever_stopped = true
	
	if new_grade != current_grade or new_surface != current_surface:
		_update_physics_for_surface_and_grade(new_grade, new_surface)
		if new_surface != current_surface:
			parallax.set_surface(new_surface)
	
	var draft_mods = run_modifiers.duplicate()
	draft_mods["dragReduction"] = min(0.99, draft_mods.get("dragReduction", 0.0) + player_draft_factor)
	
	var power_mult = run_modifiers.get("powerMult", 1.0)
	var effective_power = latest_power
	if surge_timer > 0:
		effective_power *= SURGE_POWER_MULT
	elif recovery_timer > 0:
		effective_power *= RECOVERY_POWER_MULT
	
	# Net power for HUD display and physics (includes stat boosts)
	var net_power = effective_power * power_mult
	
	if not TrainerService.is_mock_mode:
		# Directly tie in-game speed to the physical flywheel's speed (bypassing virtual inertia)
		# We apply the surge/recovery multiplier and stat boosts to the speed
		var target_speed = raw_trainer_speed_ms
		
		# Apply surge/recovery speed adjustments
		if surge_timer > 0: target_speed *= 1.15
		elif recovery_timer > 0: target_speed *= 0.90
		
		# Apply stat boost speed adjustment (Direct 1:1 boost)
		target_speed *= power_mult
		
		velocity_ms += (target_speed - velocity_ms) * delta * 5.0
	else:
		# Mock mode uses the pure physics engine
		# Note: CyclistPhysics.calculate_acceleration also applies powerMult from draft_mods
		var acceleration = CyclistPhysics.calculate_acceleration(
			effective_power, 
			velocity_ms, 
			player_stats,
			current_grade,
			draft_mods
		)
		
		velocity_ms += acceleration * delta
	
	velocity_ms = max(0.0, velocity_ms)
	distance_m += velocity_ms * delta
	
	# 3. Update Ghosts
	for g in ghosts:
		var g_dist = g["distance_m"]
		var g_grade = course.get_grade_at_distance(g_dist)
		var g_surface = course.get_surface_at_distance(g_dist)
		
		var g_crr_mult = CourseProfile.get_crr_for_surface(g_surface) / CourseProfile.get_crr_for_surface("asphalt")
		var g_stats: CyclistStats = g["stats"]
		g_stats.crr = base_crr * g_crr_mult
		
		# Ghost also drafts the player (following)
		var g_draft = DraftingPhysics.get_draft_factor(g_stats, distance_m - g_dist)
		# Ghost also gets pushed (leading player)
		g_draft = max(g_draft, DraftingPhysics.get_leading_draft_factor(g_stats, g_dist - distance_m))
		
		for other in ghosts:
			if other == g: continue
			# Drafting other ghosts
			g_draft = max(g_draft, DraftingPhysics.get_draft_factor(g_stats, other["distance_m"] - g_dist))
			# Getting pushed by other ghosts
			g_draft = max(g_draft, DraftingPhysics.get_leading_draft_factor(g_stats, g_dist - other["distance_m"]))
			
		var g_accel = CyclistPhysics.calculate_acceleration(g["power_w"], g["velocity_ms"], g_stats, g_grade, {"dragReduction": g_draft})
		g["velocity_ms"] = max(0.0, g["velocity_ms"] + g_accel * delta)
		g["distance_m"] += g["velocity_ms"] * delta
	
	# 4. Record every second
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
	if distance_m >= course.total_distance_m:
		_on_ride_complete()
	
	# 6. Update UI & Visuals
	_update_hud(net_power)
	_update_visuals(delta)
	
	if Engine.get_physics_frames() % 60 == 0:
		# Match Phaser's Trainer simulation parameters (scaling by massRatio)
		var assumed_trainer_mass = 83.0
		var mass_ratio = player_stats.mass_kg / assumed_trainer_mass
		
		var effective_grade = current_grade * mass_ratio
		var effective_crr = player_stats.crr * mass_ratio
		# CWA = CdA according to Phaser implementation (Rho scaling is commented out there)
		var cwa = player_stats.cda
		
		TrainerService.set_simulation_params(effective_grade, effective_crr, cwa)

func _update_visuals(delta: float) -> void:
	# Parallax scrolling
	parallax.scroll_offset.x -= travel_direction * velocity_ms * delta * 100.0
	
	# Deform road to match elevation graph
	_update_ground_line()
	
	# Animate Player
	wheel_rotation += velocity_ms * delta * 10.0
	crank_rotation += (cadence / 60.0) * 2.0 * PI * delta
	_animate_cyclist(player_cyclist, wheel_rotation, velocity_ms, crank_rotation)
	
	# Position and Rotate Player on road (Pivot at player distance)
	var p_grade = course.get_grade_at_distance(distance_m)
	player_cyclist.position.y = 0 
	player_cyclist.rotation = lerp_angle(player_cyclist.rotation, -travel_direction * atan(p_grade * 3.0), delta * 10.0)
	player_cyclist.scale.x = travel_direction
	
	# Animate and Position Ghosts
	var base_elev = course.get_elevation_at_distance(distance_m)
	for g in ghosts:
		var g_node = g["node"]
		var relative_x = travel_direction * (g["distance_m"] - distance_m) * 100.0
		g_node.position.x = (1280 - 300.0 if travel_direction < 0 else 300.0) + relative_x
		
		var g_elev = course.get_elevation_at_distance(g["distance_m"])
		var g_grade = course.get_grade_at_distance(g["distance_m"])
		g_node.position.y = -(g_elev - base_elev) * 100.0 * 3.0
		g_node.rotation = lerp_angle(g_node.rotation, -travel_direction * atan(g_grade * 3.0), delta * 10.0)
		g_node.scale.x = travel_direction
		
		g["wheel_rotation"] += g["velocity_ms"] * delta * 10.0
		var g_crank_rot = g.get("crank_rotation", 0.0) + (90.0 / 60.0) * 2.0 * PI * delta
		g["crank_rotation"] = g_crank_rot
		_animate_cyclist(g_node, g["wheel_rotation"], g["velocity_ms"], g_crank_rot)
	
	# Environment stays level as the ground itself is now deformed
	environment.rotation = 0
	
	# Update Player marker on elevation graph
	var total_dist = course.total_distance_m
	var graph_width = $HUD/MarginContainer/VBoxContainer/ElevationContainer.size.x
	if graph_width <= 0: graph_width = 1240
	
	var progress = clamp(distance_m / total_dist, 0.0, 1.0)
	if travel_direction < 0:
		player_marker.position.x = (1.0 - progress) * graph_width
	else:
		player_marker.position.x = progress * graph_width

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
	
	# Wait for layout update to get correct ElevationContainer width
	get_tree().process_frame.connect(_build_elevation_graph, CONNECT_ONE_SHOT)

func _animate_cyclist(node: Node2D, w_rot: float, vel: float, crank_rot: float = 0.0) -> void:
	var frames = 12
	
	# Frame Index for Wheels/Chain/Frame (Speed-based)
	var wheel_idx = 0
	if vel > 0.1:
		wheel_idx = int(fmod(w_rot, 2.0 * PI) / (2.0 * PI) * frames)
		if wheel_idx < 0: wheel_idx += frames
	
	# Frame Index for Crank (Cadence-based)
	var crank_idx = int(fmod(crank_rot, 2.0 * PI) / (2.0 * PI) * frames)
	if crank_idx < 0: crank_idx += frames
	
	# Update Sprites
	for child in node.get_children():
		if child is Sprite2D:
			if child.name == "Crank":
				child.frame = crank_idx
			else:
				child.frame = wheel_idx
	
	# Bob ONLY the Rider (the person)
	var bob = 0.0
	if vel > 0.1:
		bob = sin(Time.get_ticks_msec() * 0.01) * 3.0
	
	# Rider could be the Sprite2D or the Polygon2D (for legacy/ghost support)
	for node_name in ["Rider", "RiderPoly"]:
		if node.has_node(node_name):
			var rider = node.get_node(node_name)
			var base_y = -45.0 if rider is Sprite2D else -62.0
			rider.position.y = base_y + bob
	
	# Ensure Bike parts stay stationary (at their base_y)
	for node_name in ["Frame", "Crank", "Chain", "Wheels", "Sprite2D"]:
		if node.has_node(node_name) and node_name != "Rider":
			var child = node.get_node(node_name)
			if child is Sprite2D:
				child.position.y = -45.0



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
		btn.text = str(speed) + "x"
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

func _on_item_discovered(item_id: String) -> void:
	if RunManager.autoplay_enabled: return
	
	var overlay = load("res://src/ui/screens/DiscoveryOverlay.tscn").instantiate()
	add_child(overlay)
	overlay.setup(item_id)

func _on_ride_complete() -> void:
	is_complete = true
	velocity_ms = 0.0
	Engine.time_scale = 1.0
	
	if RunManager.item_discovered.is_connected(_on_item_discovered):
		RunManager.item_discovered.disconnect(_on_item_discovered)
	
	var run = RunManager.get_run()
	var current_node = null
	for n in run["nodes"]:
		if n["id"] == run["currentNodeId"]:
			current_node = n
			break
			
	var is_first_clear = RunManager.complete_active_edge()
	
	# Evaluate Elite Challenge
	if RunManager.active_challenge != null:
		var metrics = {
			"avgPowerW": challenge_power_sum / max(1, challenge_tick_count),
			"peakPowerW": challenge_peak_power,
			"everStopped": challenge_ever_stopped,
			"elapsedSeconds": (Time.get_ticks_msec() - ride_start_time) / 1000.0,
			"ftpW": RunManager.run_data.get("ftpW", 200)
		}
		
		var success = RunManager.active_challenge.evaluate(metrics)
		if success:
			RunManager.active_challenge.grant_reward()
			print("[ELITE] Challenge Succeeded!")
		else:
			print("[ELITE] Challenge Failed.")
			
		RunManager.active_challenge = null

	if current_node and current_node["type"] == "finish":
		get_tree().change_scene_to_file("res://src/features/progression/VictoryScene.tscn")
		return

	# Handle post-ride overlays
	var on_overlay_closed = func():
		get_tree().change_scene_to_file("res://src/features/map/MapScene.tscn")

	if is_first_clear:
		var overlay = load("res://src/ui/screens/RewardOverlay.tscn").instantiate()
		add_child(overlay)
		
		# Show boss medal if applicable
		var is_boss = current_node and current_node["type"] == "boss"
		overlay.setup(is_boss)
		
		overlay.reward_selected.connect(func(): 
			_check_and_show_pending_overlay(on_overlay_closed)
		)
	else:
		_check_and_show_pending_overlay(on_overlay_closed)

func _check_and_show_pending_overlay(callback: Callable) -> void:
	var pending = RunManager.pending_overlay
	RunManager.pending_overlay = "" # Clear it immediately
	
	if pending == "shop":
		var overlay = load("res://src/ui/screens/ShopOverlay.tscn").instantiate()
		add_child(overlay)
		overlay.closed.connect(callback)
	elif pending == "event":
		var overlay = load("res://src/ui/screens/EventOverlay.tscn").instantiate()
		add_child(overlay)
		overlay.closed.connect(callback)
	else:
		# No pending overlay, wait a bit then return to map
		get_tree().create_timer(2.0).timeout.connect(callback)

func _on_trainer_data(data: Dictionary) -> void:
	latest_power = data.get("power", 0.0)
	if data.has("speed_kmh"):
		raw_trainer_speed_ms = data["speed_kmh"] / 3.6
	
	if data.has("cadence"):
		cadence = float(data["cadence"])
		var cadence_node = hud_power_label.get_parent().get_parent().find_child("CadenceValue", true, false)
		if cadence_node:
			cadence_node.text = str(round(cadence)) + " RPM"

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var pause_menu = load("res://src/ui/screens/PauseOverlay.tscn").instantiate()
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
