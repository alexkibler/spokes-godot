class_name GameScene
extends Node2D

# Orchestrator for the riding experience

@onready var hud_power_label: Label = $HUD/MarginContainer/VBoxContainer/HBoxContainer/Stats/PowerValue
@onready var hud_speed_label: Label = $HUD/MarginContainer/VBoxContainer/HBoxContainer/Stats/SpeedValue
@onready var hud_dist_label: Label = $HUD/MarginContainer/VBoxContainer/HBoxContainer/Stats/DistValue
@onready var hud_grade_label: Label = $HUD/MarginContainer/VBoxContainer/HBoxContainer/Stats/GradeValue
@onready var progress_bar: ProgressBar = $HUD/MarginContainer/VBoxContainer/ProgressBar
@onready var environment: Node2D = $Environment
@onready var parallax: ParallaxBackground = $ParallaxBackground
@onready var elevation_line: Line2D = $HUD/MarginContainer/VBoxContainer/ElevationContainer/ElevationLine
@onready var player_marker: ColorRect = $HUD/MarginContainer/VBoxContainer/ElevationContainer/PlayerMarker
@onready var ground_line: Line2D = $Environment/Ground
@onready var draft_badge: PanelContainer = %DraftBadge
@onready var race_gap_panel: VBoxContainer = %RaceGapPanel

# The Player Entity (replaces the old simplistic node)
var player_cyclist: Cyclist

var wheel_rotation: float = 0.0 # Kept for parallax scrolling only? No, parallax uses player velocity.
var raw_trainer_speed_ms: float = 0.0
# var latest_power: float = 0.0 # Handled by PowerReceiverComponent
var travel_direction: float = 1.0 # 1.0 for L->R, -1.0 for R->L
# var cadence: float = 90.0 # Handled by Cyclist / SignalBus
# var crank_rotation: float = 0.0 # Handled by Visuals

var ghosts: Array[Cyclist] = [] # List of Cyclist entities
var cyclist_scene = preload("res://src/features/cycling/Cyclist.tscn")

var base_crr: float = 0.0041
var run_modifiers: Dictionary = { "powerMult": 1.0, "dragReduction": 0.0, "weightMult": 1.0, "crrMult": 1.0 }

var course: CourseProfile = null
var is_complete: bool = false

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
	
	# Create Player Entity
	player_cyclist = cyclist_scene.instantiate()
	player_cyclist.name = "PlayerCyclist"
	player_cyclist.is_player = true
	environment.add_child(player_cyclist)

	# Initialize stats from settings
	var weight_kg: float = SettingsManager.weight_kg
	var stats: CyclistStats = CyclistStats.new()
	stats.mass_kg = weight_kg + 8.0
	stats.cda = 0.416 * pow(weight_kg / 114.3, 0.66)
	stats.crr = 0.0041
	base_crr = stats.crr
	player_cyclist.stats = stats
	
	# Initialize Course from Active Edge
	if RunManager.is_active_run:
		run_modifiers = RunManager.run_data["modifiers"]
		var ae: Dictionary = RunManager.get_active_edge()
		if not ae.is_empty():
			course = ae["profile"]
			# Note: Cyclist entity updates its own physics state based on distance, so we just set start pos.
			var current_surface: String = course.get_surface_at_distance(0.0)
			
			# Determine direction from map coordinates
			var from_node: Dictionary = {}
			var to_node: Dictionary = {}
			for n: Dictionary in RunManager.run_data["nodes"]:
				if n["id"] == ae["actual_from"]: from_node = n
				if n["id"] == ae["actual_to"]: to_node = n
			
			if not from_node.is_empty() and not to_node.is_empty():
				var dx: float = to_node["x"] - from_node["x"]
				var dy: float = to_node["y"] - from_node["y"]
				if abs(dx) > 0.1:
					travel_direction = 1.0 if dx > 0 else -1.0
				else:
					# Straight vertical: North (decreasing Y) is L->R, South (increasing Y) is R->L
					travel_direction = 1.0 if dy < 0 else -1.0
			
			_apply_biome_theming(ae)
			
			var vw: float = get_viewport_rect().size.x
			if vw <= 0: vw = 1280.0
			player_cyclist.position.x = vw - 300.0 if travel_direction < 0 else 300.0
	else:
		run_modifiers = { "powerMult": 1.0, "dragReduction": 0.0, "weightMult": 1.0, "crrMult": 1.0 }
		course = CourseProfile.generate_course_profile(5.0, 0.05)

	# Subscribe to SignalBus for hardware updates
	# PlayerCyclist's PowerReceiverComponent listens to trainer_power_updated automatically.
	# We listen here for cadence to pass to player? Or let SignalBus handle it?
	# GameScene manages cadence for display HUD.
	SignalBus.trainer_cadence_updated.connect(_on_cadence_updated)
	SignalBus.trainer_speed_updated.connect(_on_speed_updated)

	TrainerService.connect_trainer()
	
	player_cyclist.cadence = TrainerService.mock_cadence if TrainerService.is_mock_mode else 0.0
	
	# Setup UI
	progress_bar.max_value = course.total_distance_m
	progress_bar.value = 0.0
	
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized() # This now handles _build_elevation_graph via process_frame
	
	# Remove old PlayerCyclist placeholder if it exists in the scene tree from .tscn
	if environment.has_node("PlayerCyclist") and environment.get_node("PlayerCyclist") != player_cyclist:
		environment.get_node("PlayerCyclist").queue_free()

	# Spawn Ghosts
	_spawn_ghosts()

	SignalBus.item_discovered.connect(_on_item_discovered)
	
	# Dev-only speed control
	var hostname = JavaScriptBridge.eval("window.location.hostname")
	if typeof(hostname) == TYPE_STRING and hostname.begins_with("spokesdev"):
		is_dev_build = true
		_create_speed_control()

func _spawn_ghosts() -> void:
	# Spawn 3 ghosts with slightly different powers
	var base_power: float = 200.0
	if RunManager.is_active_run:
		base_power = float(RunManager.run_data.get("ftpW", 200.0))
		
	var offsets: Array[float] = [0.95, 1.05, 1.15]
	var labels: Array[String] = ["ROOKIE", "PRO", "ELITE"]
	
	for i in range(3):
		var g_node: Cyclist = cyclist_scene.instantiate()
		g_node.is_player = false
		g_node.label = labels[i]

		# Set Stats
		var g_stats: CyclistStats = player_cyclist.stats.duplicate()
		g_node.stats = g_stats

		# Set Initial State
		g_node.distance_m = 10.0 + i * 5.0
		g_node.velocity_ms = 0.0

		# Set Power (Manual)
		g_node.get_node("PowerReceiver").set_power_manual(base_power * offsets[i])

		environment.add_child(g_node)
		
		# Style the ghost
		var color: Color = Color.from_hsv(0.6 + i * 0.1, 0.5, 0.8)
		g_node.set_color(color)
		
		ghosts.append(g_node)

func _apply_biome_theming(edge: Dictionary) -> void:
	var spoke_id: String = "plains"
	var run: Dictionary = RunManager.get_run()
	for n: Dictionary in run["nodes"]:
		if n["id"] == edge["to"]:
			spoke_id = n.get("metadata", {}).get("spokeId", "plains")
			break
	
	var color: Color = SpokesTheme.BIOME_COLORS.get(spoke_id, Color.DARK_GREEN)
	$ParallaxBackground/HillLayer/Hills.color = color.lerp(Color.BLACK, 0.2)
	$ParallaxBackground/GroundLayer/Field.color = color.lerp(Color.BLACK, 0.4)
	$Environment/RoadFill.color = color.lerp(Color.BLACK, 0.4)

func _build_elevation_graph() -> void:
	if not is_inside_tree() or course == null: return
	
	elevation_line.clear_points()
	var total_dist: float = course.total_distance_m
	var width: float = $HUD/MarginContainer/VBoxContainer/ElevationContainer.size.x
	if width <= 0: width = 1240.0
	
	var container_height: float = 100.0
	var points: int = 100
	
	var elev_points: Array[float] = []
	for i in range(points + 1):
		var d: float = (float(i) / points) * total_dist
		elev_points.append(course.get_elevation_at_distance(d))
	
	var min_elev: float = elev_points[0]
	var max_elev: float = elev_points[0]
	for e: float in elev_points:
		min_elev = min(min_elev, e)
		max_elev = max(max_elev, e)
		
	var range_elev: float = max(5.0, max_elev - min_elev) # Minimum 5m scale
	
	# Add 10% vertical padding
	var padding: float = range_elev * 0.1
	min_elev -= padding
	range_elev += padding * 2.0
	
	for i in range(elev_points.size()):
		var x: float = (float(i) / points) * width
		if travel_direction < 0:
			x = width - x
		var y: float = container_height - ((elev_points[i] - min_elev) / range_elev) * container_height
		elevation_line.add_point(Vector2(x, y))

func _update_ground_line() -> void:
	if course == null: return
	
	var vw: float = get_viewport_rect().size.x
	if vw <= 0: vw = 1280.0
	
	var points: Array[Vector2] = []
	var start_x: float = -500.0 # Relative to environment (which is at x=0)
	var end_x: float = vw + 500.0
	var step_x: float = 25.0   # pixels (0.25m per step at 100px/m)
	
	var total_dist: float = course.total_distance_m
	var distance_m: float = player_cyclist.distance_m
	var base_elev: float = course.get_elevation_at_distance(distance_m)
	
	# Cache grades for extrapolation
	var start_grade: float = course.get_grade_at_distance(0.0)
	var end_grade: float = course.get_grade_at_distance(total_dist - 0.1)
	
	var player_anchor_x: float = vw - 300.0 if travel_direction < 0 else 300.0
	
	for x in range(int(start_x), int(end_x) + int(step_x), int(step_x)):
		var d: float = distance_m + travel_direction * (float(x) - player_anchor_x) / 100.0
		
		var elev: float
		if d < 0:
			# Extrapolate backward from start
			elev = d * start_grade
		elif d > total_dist:
			# Extrapolate forward from end
			var final_elev: float = course.get_elevation_at_distance(total_dist)
			elev = final_elev + (d - total_dist) * end_grade
		else:
			elev = course.get_elevation_at_distance(d)
			
		# Match the steepness scaling of the physics exaggeration (3.0 factor)
		var y: float = -(elev - base_elev) * 100.0 * 3.0
		points.append(Vector2(x, y))
	
	ground_line.points = PackedVector2Array(points)
	
	# Update RoadFill polygon to cover the area below the line
	var poly_points: Array[Vector2] = points.duplicate()
	poly_points.append(Vector2(end_x, 1000.0)) # Far below screen
	poly_points.append(Vector2(start_x, 1000.0))
	$Environment/RoadFill.polygon = PackedVector2Array(poly_points)

func _physics_process(delta: float) -> void:
	if is_complete: return
	
	# 0. Mock Power Simulation (if no real trainer is active)
	if TrainerService.is_mock_mode:
		# In mock mode, we feed the mock power to the player's component
		var ftp: float = float(RunManager.run_data.get("ftpW", 200.0))
		player_cyclist.power_receiver.set_power_manual(ftp)
	
	# 1. Gather all cyclists for drafting
	var all_entities: Array = []
	# For player, nearby are ghosts
	for g: Cyclist in ghosts:
		all_entities.append(g)
	
	# Process Player
	player_cyclist.process_cyclist(delta, course, all_entities, run_modifiers)
	
	# For Ghosts, nearby is player + other ghosts
	for g: Cyclist in ghosts:
		var nearby: Array = [player_cyclist]
		for other: Cyclist in ghosts:
			if other != g: nearby.append(other)
		# Ghosts don't have run modifiers
		g.process_cyclist(delta, course, nearby, {})
	
	# Elite Challenge Tracking
	if RunManager.active_challenge != null:
		var latest_power: float = player_cyclist.power_receiver.get_power()
		challenge_power_sum += latest_power
		challenge_tick_count += 1
		challenge_peak_power = max(challenge_peak_power, latest_power)
		if player_cyclist.velocity_ms < 0.1 and player_cyclist.distance_m > 10.0: # Ignore very start
			challenge_ever_stopped = true
	
	var current_surface: String = player_cyclist.current_surface
	_set_surface(current_surface)
	
	# 4. Record every second
	var now: int = Time.get_ticks_msec()
	if now - last_record_ms >= 1000:
		last_record_ms = now
		fit_writer.add_record({
			"timestampMs": Time.get_unix_time_from_system() * 1000,
			"powerW": player_cyclist.power_receiver.get_power(),
			"cadenceRpm": player_cyclist.cadence,
			"speedMs": player_cyclist.velocity_ms,
			"distanceM": player_cyclist.distance_m
		})
	
	# 5. Check Completion
	if player_cyclist.distance_m >= course.total_distance_m:
		_on_ride_complete()
	
	# 6. Update UI & Visuals
	_update_hud(player_cyclist.effective_power)
	_update_visuals(delta)
	
	if Engine.get_physics_frames() % 60 == 0:
		# Match Phaser's Trainer simulation parameters (scaling by massRatio)
		var assumed_trainer_mass: float = 83.0
		var mass_ratio: float = player_cyclist.stats.mass_kg / assumed_trainer_mass

		var effective_grade: float = player_cyclist.current_grade * mass_ratio
		var effective_crr: float = player_cyclist.stats.crr * mass_ratio
		
		# CWA = CdA according to Phaser implementation (Rho scaling is commented out there)
		var cwa: float = player_cyclist.stats.cda
		
		TrainerService.set_simulation_params(effective_grade, effective_crr, cwa)

func _update_visuals(delta: float) -> void:
	# Parallax scrolling
	parallax.scroll_offset.x -= travel_direction * player_cyclist.velocity_ms * delta * 100.0
	
	# Deform road to match elevation graph
	_update_ground_line()
	
	# Position and Rotate Player on road (Pivot at player distance)
	var p_grade: float = player_cyclist.current_grade
	player_cyclist.position.y = 0 
	player_cyclist.rotation = lerp_angle(player_cyclist.rotation, -travel_direction * atan(p_grade * 3.0), delta * 10.0)
	player_cyclist.scale.x = travel_direction
	
	# Animate and Position Ghosts
	var base_elev: float = course.get_elevation_at_distance(player_cyclist.distance_m)

	for g: Cyclist in ghosts:
		var relative_x: float = travel_direction * (g.distance_m - player_cyclist.distance_m) * 100.0
		g.position.x = (1280 - 300.0 if travel_direction < 0 else 300.0) + relative_x
		
		var g_elev: float = course.get_elevation_at_distance(g.distance_m)
		var g_grade: float = course.get_grade_at_distance(g.distance_m)
		g.position.y = -(g_elev - base_elev) * 100.0 * 3.0
		g.rotation = lerp_angle(g.rotation, -travel_direction * atan(g_grade * 3.0), delta * 10.0)
		g.scale.x = travel_direction
	
	# Environment stays level as the ground itself is now deformed
	environment.rotation = 0
	
	# Update Player marker on elevation graph
	var total_dist: float = course.total_distance_m
	var graph_width: float = $HUD/MarginContainer/VBoxContainer/ElevationContainer.size.x
	if graph_width <= 0: graph_width = 1240.0
	
	var progress: float = clamp(player_cyclist.distance_m / total_dist, 0.0, 1.0)
	if travel_direction < 0:
		player_marker.position.x = (1.0 - progress) * graph_width
	else:
		player_marker.position.x = progress * graph_width

func _on_viewport_resized() -> void:
	var vw: float = get_viewport_rect().size.x
	var mirror_val: Vector2 = Vector2(max(1280.0, vw), 0)
	if parallax:
		for layer in parallax.get_children():
			if layer is ParallaxLayer:
				layer.motion_mirroring = mirror_val
				for child in layer.get_children():
					if child is Control:
						child.custom_minimum_size.x = mirror_val.x
	
	# Wait for layout update to get correct ElevationContainer width
	get_tree().process_frame.connect(_build_elevation_graph, CONNECT_ONE_SHOT)

func _create_speed_control() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(20, -60)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	var lbl: Label = Label.new()
	lbl.text = "SPEED:"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(lbl)

	for speed in [1.0, 2.0, 5.0, 10.0]:
		var btn: Button = Button.new()
		btn.text = str(speed) + "x"
		btn.custom_minimum_size = Vector2(48, 32)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color.WHITE)
		var s_normal: StyleBoxFlat = StyleBoxFlat.new()
		s_normal.bg_color = Color(0.25, 0.25, 0.25, 1.0)
		s_normal.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", s_normal)
		var s_hover: StyleBoxFlat = s_normal.duplicate()
		s_hover.bg_color = Color(0.45, 0.45, 0.45, 1.0)
		btn.add_theme_stylebox_override("hover", s_hover)
		var s_pressed: StyleBoxFlat = s_normal.duplicate()
		s_pressed.bg_color = Color(1.0, 0.55, 0.0, 1.0)
		btn.add_theme_stylebox_override("pressed", s_pressed)
		btn.pressed.connect(func() -> void: Engine.time_scale = speed)
		hbox.add_child(btn)

func _on_item_discovered(item_id: String) -> void:
	if RunManager.autoplay_enabled: return
	
	var overlay = load("res://src/ui/screens/DiscoveryOverlay.tscn").instantiate()
	add_child(overlay)
	overlay.setup(item_id)

func _set_surface(surface: String) -> void:
	var road_color: Color = Color(0.2, 0.2, 0.2) # Default Asphalt
	var field_color: Color = SpokesTheme.BIOME_COLORS.get("plains", Color.DARK_GREEN).lerp(Color.BLACK, 0.4)
	
	match surface:
		"gravel":
			road_color = Color("#7a6b55")
			field_color = Color("#5a5a40")
		"dirt":
			road_color = Color("#5d4037")
			field_color = Color("#3e2723")
		"mud":
			road_color = Color("#3e2723")
			field_color = Color("#1b1b1b")
	
	if has_node("Environment/RoadFill"):
		$Environment/RoadFill.color = road_color
	if has_node("ParallaxBackground/GroundLayer/Field"):
		$ParallaxBackground/GroundLayer/Field.color = field_color

func _on_ride_complete() -> void:
	is_complete = true
	# player_cyclist.velocity_ms = 0.0 # Handled via physics loop stop or ignored
	Engine.time_scale = 1.0
	
	# Cleanup global signal connections
	if SignalBus.item_discovered.is_connected(_on_item_discovered):
		SignalBus.item_discovered.disconnect(_on_item_discovered)
	# Power/Cadence/Speed connected to SignalBus are handled via components or local connections
	if SignalBus.trainer_cadence_updated.is_connected(_on_cadence_updated):
		SignalBus.trainer_cadence_updated.disconnect(_on_cadence_updated)
	if SignalBus.trainer_speed_updated.is_connected(_on_speed_updated):
		SignalBus.trainer_speed_updated.disconnect(_on_speed_updated)
	
	var run: Dictionary = RunManager.get_run()
	var current_node = null
	for n: Dictionary in run["nodes"]:
		if n["id"] == run["currentNodeId"]:
			current_node = n
			break
			
	var is_first_clear: bool = RunManager.complete_active_edge()
	
	# Evaluate Elite Challenge
	if RunManager.active_challenge != null:
		var metrics: Dictionary = {
			"avgPowerW": challenge_power_sum / max(1, challenge_tick_count),
			"peakPowerW": challenge_peak_power,
			"everStopped": challenge_ever_stopped,
			"elapsedSeconds": (Time.get_ticks_msec() - ride_start_time) / 1000.0,
			"ftpW": RunManager.run_data.get("ftpW", 200)
		}
		
		var success: bool = RunManager.active_challenge.evaluate(metrics)
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
	var on_overlay_closed: Callable = func() -> void:
		get_tree().change_scene_to_file("res://src/features/map/MapScene.tscn")

	if is_first_clear:
		var overlay = load("res://src/ui/screens/RewardOverlay.tscn").instantiate()
		add_child(overlay)
		
		# Show boss medal if applicable
		var is_boss: bool = current_node and current_node["type"] == "boss"
		overlay.setup(is_boss)
		
		overlay.reward_selected.connect(func() -> void:
			_check_and_show_pending_overlay(on_overlay_closed)
		)
	else:
		_check_and_show_pending_overlay(on_overlay_closed)

func _check_and_show_pending_overlay(callback: Callable) -> void:
	var pending: String = RunManager.pending_overlay
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

func _on_speed_updated(p_kmh: float) -> void:
	raw_trainer_speed_ms = p_kmh / 3.6

func _on_cadence_updated(p_rpm: float) -> void:
	player_cyclist.cadence = p_rpm
	var cadence_node: Label = hud_power_label.get_parent().get_parent().find_child("CadenceValue", true, false)
	if cadence_node:
		cadence_node.text = str(round(p_rpm)) + " RPM"

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var pause_menu = load("res://src/ui/screens/PauseOverlay.tscn").instantiate()
		add_child(pause_menu)
		get_viewport().set_input_as_handled()

func _update_hud(p_effective_power: float) -> void:
	if hud_power_label:
		hud_power_label.text = str(round(p_effective_power)) + " W"
	if hud_speed_label:
		var speed: float = Units.ms_to_kmh(player_cyclist.velocity_ms) if SettingsManager.units == "metric" else Units.ms_to_mph(player_cyclist.velocity_ms)
		var unit_suffix: String = " km/h" if SettingsManager.units == "metric" else " mph"
		hud_speed_label.text = Units.format_fixed(speed, 1) + unit_suffix
	if hud_dist_label:
		var dist: float = Units.m_to_km(player_cyclist.distance_m) if SettingsManager.units == "metric" else Units.m_to_mi(player_cyclist.distance_m)
		var unit_suffix: String = " km" if SettingsManager.units == "metric" else " mi"
		hud_dist_label.text = Units.format_fixed(dist, 2) + unit_suffix
	if hud_grade_label:
		hud_grade_label.text = "Grade: " + Units.format_fixed(player_cyclist.current_grade * 100.0, 1) + "%"
	if progress_bar:
		progress_bar.value = player_cyclist.distance_m
		
	# Update Draft/Surge Badge
	var state: String = player_cyclist.fatigue.get_state()

	if state == "surge":
		draft_badge.visible = true
		draft_badge.get_node("Label").text = "ATTACK! +25% POWER"
		draft_badge.modulate = Color.ORANGE_RED
	elif state == "recovery":
		draft_badge.visible = true
		draft_badge.get_node("Label").text = "RECOVERING... -15% POWER"
		draft_badge.modulate = Color.SKY_BLUE
	elif player_cyclist.draft_factor > 0.01:
		draft_badge.visible = true
		draft_badge.get_node("Label").text = "SLIPSTREAM  −%d%% DRAG" % int(player_cyclist.draft_factor * 100)
		draft_badge.modulate = Color.WHITE
	else:
		draft_badge.visible = false
		
	# Update Race Gap Panel (Only every 10 frames to prevent layout churn)
	if Engine.get_physics_frames() % 10 == 0:
		for child in race_gap_panel.get_children():
			child.queue_free()
			
		# Sort ghosts by distance
		var sorted_ghosts: Array[Cyclist] = ghosts.duplicate()
		sorted_ghosts.sort_custom(func(a: Cyclist, b: Cyclist) -> bool: return a.distance_m > b.distance_m)
		
		for g: Cyclist in sorted_ghosts:
			var gap: float = g.distance_m - player_cyclist.distance_m
			var l: Label = Label.new()
			var dist_str: String = "%+.1f m" % gap
			l.text = g.label + ": " + dist_str
			l.add_theme_font_size_override("font_size", 14)
			if gap > 0: l.add_theme_color_override("font_color", Color.SALMON)
			else: l.add_theme_color_override("font_color", Color.LIGHT_GREEN)
			race_gap_panel.add_child(l)
