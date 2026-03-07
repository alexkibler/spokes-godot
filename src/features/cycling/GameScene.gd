class_name GameScene
extends Node2D

# Orchestrator for the riding experience

@onready var hud_power_label: Label = $HUD/MarginContainer/HUDLayout/Stats/PowerValue
@onready var hud_cadence_label: Label = $HUD/MarginContainer/HUDLayout/Stats/CadenceValue
@onready var hud_speed_label: Label = $HUD/MarginContainer/HUDLayout/Stats/SpeedValue
@onready var hud_dist_label: Label = $HUD/MarginContainer/HUDLayout/Stats/DistValue
@onready var hud_grade_label: Label = $HUD/MarginContainer/HUDLayout/Stats/GradeValue
@onready var hud_surface_label: Label = $HUD/MarginContainer/HUDLayout/Stats/SurfaceValue
@onready var progress_bar: ProgressBar = $HUD/MarginContainer/HUDLayout/BottomPanel/ProgressBar
@onready var environment: Node2D = $Environment
@onready var parallax: ParallaxBackground = $ParallaxBackground
@onready var elevation_line: Line2D = $HUD/MarginContainer/HUDLayout/BottomPanel/ElevationContainer/ElevationLine
@onready var player_marker: ColorRect = $HUD/MarginContainer/HUDLayout/BottomPanel/ElevationContainer/PlayerMarker
@onready var ground_line: Line2D = $Environment/Ground
@onready var draft_badge: PanelContainer = %DraftBadge
@onready var race_gap_panel: VBoxContainer = %RaceGapPanel

# The Player Entity (replaces the old simplistic node)
var player_cyclist: Cyclist

var wheel_rotation: float = 0.0 # Kept for parallax scrolling only? No, parallax uses player velocity.
# var latest_power: float = 0.0 # Handled by HardwareReceiverComponent
var travel_direction: float = 1.0 # 1.0 for L->R, -1.0 for R->L
var run_modifiers: Dictionary = { "powerMult": 1.0, "dragReduction": 0.0, "weightMult": 1.0, "crrMult": 1.0 }

var ghosts: Array[Cyclist] = [] # List of Cyclist entities
var cyclist_scene: PackedScene = preload("res://src/features/cycling/Cyclist.tscn")

var course: CourseProfile = null
var is_complete: bool = false

var fit_writer: FitWriter
var last_record_ms: int = 0
var ride_start_time: int = 0
var ride_elevation_gain_m: float = 0.0
var ride_power_sum: float = 0.0
var ride_tick_count: int = 0
var last_elevation: float = 0.0

var is_dev_build: bool = false

var _portrait_bg: ColorRect = null

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
	
	if course:
		last_elevation = course.get_elevation_at_distance(0.0)
	
	UIUtils.handle_safe_area($HUD/MarginContainer)

	# Create Player Entity
	player_cyclist = cyclist_scene.instantiate()
	player_cyclist.name = "PlayerCyclist"
	player_cyclist.is_player = true
	environment.add_child(player_cyclist)

	# Initialize stats from run state (includes cargo & inventory item weight)
	var player_stats: CyclistStats = CyclistStats.create_from_weight(SettingsManager.weight_kg)
	if RunManager.is_active_run:
		player_stats.mass_kg = RunManager.get_total_system_mass()
	player_cyclist.setup(true, player_stats, "Player", Color.WHITE)
	
	# Initialize Course from Active Edge
	if RunManager.is_active_run:
		run_modifiers = RunManager.run_data["modifiers"]
		var ae: Dictionary = RunManager.get_active_edge()
		if not ae.is_empty():
			course = ae["profile"]
			# Note: Cyclist entity updates its own physics state based on distance, so we just set start pos.
			var current_surface_res: Resource = course.get_surface_at_distance(0.0)
			var current_surface: String = "asphalt"
			if current_surface_res and "name" in current_surface_res:
				current_surface = current_surface_res.get("name")
			
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
	# PlayerCyclist's HardwareReceiverComponent handles telemetry automatically.
	TrainerService.connect_trainer()
	
	if TrainerService.is_mock_mode:
		var hr: Node = player_cyclist.get("hardware_receiver")
		if hr: (hr as HardwareReceiverComponent).set_cadence_manual(TrainerService.mock_cadence)
	
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
	var hostname: Variant = JavaScriptBridge.eval("window.location.hostname")
	if typeof(hostname) == TYPE_STRING and (hostname as String).begins_with("spokesdev"):
		is_dev_build = true
		_create_speed_control()

func _spawn_ghosts() -> void:
	# Spawn ghosts or a single boss
	var base_power: float = 200.0
	if RunManager.is_active_run:
		base_power = float(RunManager.run_data.get("ftpW", 200.0))
		
	var ae: Dictionary = RunManager.get_active_edge()
	var dest_node_id: String = ae.get("actual_to", "")
	var dest_node: Dictionary = {}
	var spoke_id: String = "plains"
	
	if RunManager.is_active_run:
		for n: Dictionary in RunManager.run_data.get("nodes", []):
			if n["id"] == dest_node_id:
				dest_node = n
				spoke_id = n.get("metadata", {}).get("spokeId", "plains")
				break
			
	if not dest_node.is_empty() and (dest_node["type"] == "boss" or dest_node["type"] == "finish"):
		# Spawn a single boss
		var BossRegistryScript: Script = load("res://src/features/cycling/BossRegistry.gd")
		var boss_data: Dictionary = BossRegistryScript.get_boss(spoke_id if dest_node["type"] == "boss" else "final")
		var g_node: Cyclist = cyclist_scene.instantiate()
		environment.add_child(g_node)
		
		var g_stats: CyclistStats = player_cyclist.stats.duplicate()
		g_node.setup(
			false, 
			g_stats, 
			boss_data["name"], 
			boss_data["color"], 
			15.0, 
			base_power * boss_data.get("power_mult", 1.0),
			boss_data.get("modifiers", {})
		)
		
		if boss_data.has("surge_config"):
			g_node.apply_surge_config(boss_data["surge_config"])
			
		ghosts.append(g_node)
	else:
		# Spawn 3 ghosts with slightly different powers
		var offsets: Array[float] = [0.95, 1.05, 1.15]
		var labels: Array[String] = ["ROOKIE", "PRO", "ELITE"]
		
		for i: int in range(3):
			var g_node: Cyclist = cyclist_scene.instantiate()
			environment.add_child(g_node) # Add to tree first so @onready are ready

			var g_stats: CyclistStats = player_cyclist.stats.duplicate()
			var color: Color = Color.from_hsv(0.6 + i * 0.1, 0.5, 0.8)
			
			g_node.setup(false, g_stats, labels[i], color, 10.0 + i * 5.0, base_power * offsets[i])
			
			ghosts.append(g_node)

func _apply_biome_theming(edge: Dictionary) -> void:
	var spoke_id: String = "plains"
	var run: Dictionary = RunManager.get_run()
	for n: Dictionary in run["nodes"]:
		if n["id"] == edge["to"]:
			var metadata: Dictionary = n.get("metadata", {})
			spoke_id = metadata.get("spokeId", "plains")
			break
	
	var color: Color = SpokesTheme.BIOME_COLORS.get(spoke_id, Color.DARK_GREEN)
	($ParallaxBackground/HillLayer/Hills as Polygon2D).color = color.lerp(Color.BLACK, 0.2)
	($ParallaxBackground/GroundLayer/Field as ColorRect).color = color.lerp(Color.BLACK, 0.4)
	($Environment/RoadFill as Polygon2D).color = color.lerp(Color.BLACK, 0.4)

func _build_elevation_graph() -> void:
	if not is_inside_tree() or course == null: return
	
	elevation_line.clear_points()
	var total_dist: float = course.total_distance_m
	var elevation_container: Control = $HUD/MarginContainer/HUDLayout/BottomPanel/ElevationContainer as Control
	var width: float = elevation_container.size.x
	if width <= 0: width = 1240.0
	
	var container_height: float = 100.0
	var points: int = 100
	
	var elev_points: Array[float] = []
	for i: int in range(points + 1):
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
	
	for i: int in range(elev_points.size()):
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
	
	for x_int: int in range(int(start_x), int(end_x) + int(step_x), int(step_x)):
		var x: float = float(x_int)
		var d: float = distance_m + travel_direction * (x - player_anchor_x) / 100.0
		
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
	($Environment/RoadFill as Polygon2D).polygon = PackedVector2Array(poly_points)

func _physics_process(delta: float) -> void:
	if is_complete: return
	
	# 0. Mock Power Simulation (if no real trainer is active)
	if TrainerService.is_mock_mode:
		# In mock mode, we feed the mock power to the player's component
		var ftp: float = float(RunManager.run_data.get("ftpW", 200.0))
		var hr: Node = player_cyclist.get("hardware_receiver")
		if hr: (hr as HardwareReceiverComponent).set_power_manual(ftp)
	
	# 1. Gather all cyclists for drafting
	var all_entities: Array[Cyclist] = []
	# For player, nearby are ghosts
	for g: Cyclist in ghosts:
		all_entities.append(g)
	
	# Process Player
	player_cyclist.process_cyclist(delta, course, all_entities, run_modifiers)
	
	# Update Ride Stats
	var current_elevation: float = course.get_elevation_at_distance(player_cyclist.distance_m)
	var elev_diff: float = current_elevation - last_elevation
	if elev_diff > 0:
		ride_elevation_gain_m += elev_diff
	last_elevation = current_elevation
	
	ride_power_sum += player_cyclist.effective_power
	ride_tick_count += 1
	
	# For Ghosts, nearby is player + other ghosts
	for g: Cyclist in ghosts:
		var nearby: Array[Cyclist] = [player_cyclist]
		for other: Cyclist in ghosts:
			if other != g: nearby.append(other)
		# Ghosts use their own modifiers (e.g. for bosses)
		g.process_cyclist(delta, course, nearby, g.ghost_modifiers)
	
	# Elite Challenge Tracking
	if RunManager.active_challenge != null:
		var hr: Node = player_cyclist.get("hardware_receiver")
		var latest_power: float = (hr as HardwareReceiverComponent).get_power() if hr else 0.0
		challenge_power_sum += latest_power
		challenge_tick_count += 1
		challenge_peak_power = max(challenge_peak_power, latest_power)
		if player_cyclist.velocity_ms < 0.1 and player_cyclist.distance_m > 10.0: # Ignore very start
			challenge_ever_stopped = true
	
	var current_surface_name: String = player_cyclist.current_surface.get("name")
	_set_surface(current_surface_name)
	
	# 4. Record every second
	var now: int = Time.get_ticks_msec()
	if now - last_record_ms >= 1000:
		last_record_ms = now
		var hr: Node = player_cyclist.get("hardware_receiver")
		fit_writer.add_record({
			"timestampMs": Time.get_unix_time_from_system() * 1000,
			"powerW": (hr as HardwareReceiverComponent).get_power() if hr else 0.0,
			"cadenceRpm": (hr as HardwareReceiverComponent).get_cadence() if hr else 0.0,
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
		var params: Dictionary = CyclistPhysics.get_trainer_simulation_params(player_cyclist.stats, player_cyclist.current_grade)
		TrainerService.set_simulation_params(params.grade, params.crr, params.cwa)

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
	var elevation_container: Control = $HUD/MarginContainer/HUDLayout/BottomPanel/ElevationContainer as Control
	var graph_width: float = elevation_container.size.x
	if graph_width <= 0: graph_width = 1240.0
	
	var progress: float = clamp(player_cyclist.distance_m / total_dist, 0.0, 1.0)
	if travel_direction < 0:
		player_marker.position.x = (1.0 - progress) * graph_width
	else:
		player_marker.position.x = progress * graph_width

func _on_viewport_resized() -> void:
	UIUtils.handle_safe_area($HUD/MarginContainer)
	var vw: float = get_viewport_rect().size.x
	var mirror_val: Vector2 = Vector2(max(1280.0, vw), 0)
	if parallax:
		for layer: Node in parallax.get_children():
			if layer is ParallaxLayer:
				(layer as ParallaxLayer).motion_mirroring = mirror_val
				for child: Node in layer.get_children():
					if child is Control:
						(child as Control).custom_minimum_size.x = mirror_val.x

	# Wait for layout update to get correct sizes before repositioning
	get_tree().process_frame.connect(_build_elevation_graph, CONNECT_ONE_SHOT)
	get_tree().process_frame.connect(_update_portrait_layout, CONNECT_ONE_SHOT)

func _update_portrait_layout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var is_portrait: bool = vp.y > vp.x

	var stats: VBoxContainer = $HUD/MarginContainer/HUDLayout/Stats as VBoxContainer
	var race_gap: VBoxContainer = %RaceGapPanel as VBoxContainer
	var hud_layout: Control = $HUD/MarginContainer/HUDLayout as Control

	if is_portrait:
		# The 1280x720 game content is scaled to fit the portrait width.
		# Game content screen height ≈ viewport_width * (720 / 1280).
		var hud_margin: float = 20.0
		var game_h: float = vp.x * (720.0 / 1280.0)
		var y_top: float = maxf(0.0, game_h - hud_margin)
		var hud_w: float = maxf(1.0, hud_layout.size.x)
		var half_w: float = hud_w * 0.5

		# Stats: left half, below game area
		stats.anchor_left = 0.0
		stats.anchor_top = 0.0
		stats.anchor_right = 0.0
		stats.anchor_bottom = 0.0
		stats.offset_left = 0.0
		stats.offset_top = y_top
		stats.offset_right = half_w - 5.0
		stats.offset_bottom = y_top + 320.0

		# RaceGapPanel: right half, below game area
		race_gap.anchor_left = 0.0
		race_gap.anchor_top = 0.0
		race_gap.anchor_right = 0.0
		race_gap.anchor_bottom = 0.0
		race_gap.offset_left = half_w + 5.0
		race_gap.offset_top = y_top
		race_gap.offset_right = hud_w
		race_gap.offset_bottom = y_top + 320.0

		# Background panel filling the space between game content and bottom panel
		if not _portrait_bg:
			_portrait_bg = ColorRect.new()
			_portrait_bg.color = Color(0.06, 0.06, 0.09, 0.95)
			_portrait_bg.layout_mode = 1
			hud_layout.add_child(_portrait_bg)
			hud_layout.move_child(_portrait_bg, 0)
		_portrait_bg.visible = true
		_portrait_bg.anchor_left = 0.0
		_portrait_bg.anchor_top = 0.0
		_portrait_bg.anchor_right = 1.0
		_portrait_bg.anchor_bottom = 1.0
		_portrait_bg.offset_left = 0.0
		_portrait_bg.offset_top = y_top
		_portrait_bg.offset_right = 0.0
		_portrait_bg.offset_bottom = -124.0
	else:
		# Restore landscape layout
		stats.anchor_left = 0.0
		stats.anchor_top = 0.0
		stats.anchor_right = 0.0
		stats.anchor_bottom = 0.0
		stats.offset_left = 0.0
		stats.offset_top = 0.0
		stats.offset_right = 200.0
		stats.offset_bottom = 200.0

		race_gap.anchor_left = 1.0
		race_gap.anchor_top = 0.0
		race_gap.anchor_right = 1.0
		race_gap.anchor_bottom = 0.0
		race_gap.offset_left = -200.0
		race_gap.offset_top = 0.0
		race_gap.offset_right = 0.0
		race_gap.offset_bottom = 200.0

		if _portrait_bg:
			_portrait_bg.visible = false

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

	for speed: float in [1.0, 2.0, 5.0, 10.0]:
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
	
	var overlay: Node = (load("res://src/ui/screens/DiscoveryOverlay.tscn") as PackedScene).instantiate()
	add_child(overlay)
	if overlay.has_method("setup"):
		overlay.setup(item_id)

func _set_surface(surface: String) -> void:
	var road_color: Color = Color(0.2, 0.2, 0.2) # Default Asphalt
	var field_color: Color = (SpokesTheme.BIOME_COLORS.get("plains", Color.DARK_GREEN) as Color).lerp(Color.BLACK, 0.4)
	
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
		($Environment/RoadFill as Polygon2D).color = road_color
	if has_node("ParallaxBackground/GroundLayer/Field"):
		($ParallaxBackground/GroundLayer/Field as ColorRect).color = field_color

func _on_ride_complete() -> void:
	is_complete = true
	# player_cyclist.velocity_ms = 0.0 # Handled via physics loop stop or ignored
	Engine.time_scale = 1.0
	
	# Cleanup global signal connections
	if SignalBus.item_discovered.is_connected(_on_item_discovered):
		SignalBus.item_discovered.disconnect(_on_item_discovered)
	
	var run: Dictionary = RunManager.get_run()
	if not run.is_empty() and run.has("stats"):
		var s: Dictionary = run["stats"]
		var ride_time_s: float = (Time.get_ticks_msec() - ride_start_time) / 1000.0
		s["totalRiddenDistanceM"] += player_cyclist.distance_m
		s["totalTimeS"] += ride_time_s
		s["totalElevationGainM"] += ride_elevation_gain_m
		s["totalPowerSum"] += ride_power_sum
		s["totalRecordCount"] += ride_tick_count
		
	var current_node: Dictionary = {}
	for n: Dictionary in run["nodes"]:
		if n["id"] == run["currentNodeId"]:
			current_node = n
			break
			
	var completion_results: Dictionary = RunManager.complete_active_edge()
	var is_first_clear: bool = completion_results.get("is_first_clear", false)
	var quest_info: Dictionary = completion_results.get("quest", {})
	
	
	# Re-fetch current node from RunManager directly to ensure we have the destination node data
	var dest_node: Dictionary = {}
	var current_node_id: String = RunManager.run_data.get("currentNodeId", "")
	for n: Dictionary in RunManager.run_data.get("nodes", []):
		if n["id"] == current_node_id:
			dest_node = n
			break

	# Evaluate Elite Challenge
	# ... (Elite logic)

	if not dest_node.is_empty() and dest_node["type"] == "finish":
		get_tree().change_scene_to_file("res://src/features/progression/VictoryScene.tscn")
		return

	# Handle post-ride overlays
	var on_overlay_closed: Callable = func() -> void:
		get_tree().change_scene_to_file("res://src/features/map/MapScene.tscn")

	# Sequence of potential overlays:
	# 1. Quest Complete
	# 2. Reward (if first clear)
	# 3. Pending (Shop/Event)

	var show_pending: Callable = func() -> void:
		_check_and_show_pending_overlay(on_overlay_closed)

	var show_reward: Callable = func() -> void:
		if is_first_clear:
			var overlay: Node = (load("res://src/ui/screens/RewardOverlay.tscn") as PackedScene).instantiate()
			add_child(overlay)
			
			# Show boss medal if applicable
			var is_boss: bool = not current_node.is_empty() and current_node["type"] == "boss"
			var b_name: String = ""
			var b_reward: String = ""
			if is_boss:
				if ghosts.size() > 0: b_name = ghosts[0].label
				var spoke_id: String = current_node.get("metadata", {}).get("spokeId", "plains")
				var BossRegistryScript: Script = load("res://src/features/cycling/BossRegistry.gd")
				var boss_data: Dictionary = BossRegistryScript.get_boss(spoke_id)
				b_reward = boss_data.get("reward_id", "")

			if overlay.has_method("setup"):
				overlay.setup(is_boss, b_name, b_reward)
			
			if overlay.has_signal("reward_selected"):
				overlay.connect("reward_selected", show_pending)
		else:
			show_pending.call()

	if quest_info.get("quest_completed", false):
		var q_overlay: Node = (load("res://src/ui/screens/QuestCompleteOverlay.tscn") as PackedScene).instantiate()
		add_child(q_overlay)
		if q_overlay.has_method("setup"):
			q_overlay.setup(
				quest_info.get("cargo_name", ""),
				quest_info.get("destination_name", ""),
				quest_info.get("reward_gold", 0)
			)
		if q_overlay.has_signal("closed"):
			q_overlay.connect("closed", show_reward)
	else:
		show_reward.call()

func _check_and_show_pending_overlay(callback: Callable) -> void:
	var pending: String = RunManager.pending_overlay
	RunManager.pending_overlay = "" # Clear it immediately
	
	if pending == "shop":
		var overlay: Node = (load("res://src/ui/screens/ShopOverlay.tscn") as PackedScene).instantiate()
		add_child(overlay)
		if overlay.has_signal("closed"):
			overlay.connect("closed", callback)
	elif pending == "event":
		var overlay: Node = (load("res://src/ui/screens/EventOverlay.tscn") as PackedScene).instantiate()
		add_child(overlay)
		if overlay.has_signal("closed"):
			overlay.connect("closed", callback)
	else:
		# No pending overlay, wait a bit then return to map
		get_tree().create_timer(2.0).timeout.connect(callback)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_autoplay"):
		RunManager.toggle_autoplay()
		get_viewport().set_input_as_handled()
		
	if event.is_action_pressed("open_pause_menu"):
		var pause_menu: Node = (load("res://src/ui/screens/PauseOverlay.tscn") as PackedScene).instantiate()
		add_child(pause_menu)
		get_viewport().set_input_as_handled()

func _update_hud(p_effective_power: float) -> void:
	if hud_power_label:
		hud_power_label.text = str(round(p_effective_power)) + " W"
	if hud_cadence_label:
		var hr: Node = player_cyclist.get("hardware_receiver")
		var cadence: float = (hr as HardwareReceiverComponent).get_cadence() if hr else 0.0
		hud_cadence_label.text = str(round(cadence)) + " RPM"
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
	if hud_surface_label:
		var s: Resource = player_cyclist.current_surface
		var s_name: String = s.get("name").capitalize() if s else "Asphalt"
		var s_crr: float = s.get("crr") if s else 0.005
		var crr_mult: float = s_crr / 0.005
		hud_surface_label.text = "Surface: %s (%.1fx)" % [s_name, crr_mult]
	if progress_bar:
		progress_bar.value = player_cyclist.distance_m
		
	# Update Draft/Surge Badge
	var surge_comp: Node = player_cyclist.get("surge")
	var state: String = (surge_comp as SurgeComponent).get_state() if surge_comp else "normal"

	if state == "surge":
		draft_badge.visible = true
		(draft_badge.get_node("Label") as Label).text = "ATTACK! +25% POWER"
		draft_badge.modulate = Color.ORANGE_RED
	elif state == "recovery":
		draft_badge.visible = true
		(draft_badge.get_node("Label") as Label).text = "RECOVERING... -15% POWER"
		draft_badge.modulate = Color.SKY_BLUE
	elif player_cyclist.draft_factor > 0.01:
		draft_badge.visible = true
		(draft_badge.get_node("Label") as Label).text = "SLIPSTREAM  −%d%% DRAG" % int(player_cyclist.draft_factor * 100)
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

func _exit_tree() -> void:
	# Clean up non-node objects
	fit_writer = null
