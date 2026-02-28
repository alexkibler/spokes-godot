extends Node2D

# Port of MapScene.ts visualization

@onready var hud: CanvasLayer = $MapHUD as CanvasLayer

var is_selecting: bool = false
var autoplay_timer: float = 0.0
var autoplay_target_node: Dictionary = {}

var selected_node_id: String = ""

func _process(delta: float) -> void:
	if is_selecting and not autoplay_target_node.is_empty():
		autoplay_timer -= delta
		if autoplay_timer <= 0:
			is_selecting = false
			var node: Dictionary = autoplay_target_node
			autoplay_target_node = {}
			if RunManager.autoplay_enabled:
				_on_node_clicked(node)
		queue_redraw()

func _ready() -> void:
	if not RunManager.is_active_run:
		# Emergency start for testing
		RunManager.start_new_run(3, 50.0, "normal", 200, 75.0, "imperial")
	
	UIUtils.handle_safe_area($MapHUD/MarginContainer)
	get_viewport().size_changed.connect(_on_viewport_resized)

	SignalBus.autoplay_changed.connect(_on_autoplay_changed)
	
	var run: Dictionary = RunManager.get_run()
	if not run.is_empty():
		selected_node_id = run["currentNodeId"]
		
	hud.update_hud()
	queue_redraw()
	_check_autoplay()

func _on_viewport_resized() -> void:
	UIUtils.handle_safe_area($MapHUD/MarginContainer)
	queue_redraw()

func _on_autoplay_changed(enabled: bool) -> void:
	if enabled:
		_check_autoplay()

func _draw() -> void:
	var run: Dictionary = RunManager.get_run()
	if run.is_empty(): return
	
	hud.update_hud()
	
	# Use fixed reference for world-space drawing
	# This matches the Camera2D position at (640, 360)
	var center: Vector2 = Vector2(640, 360)
	var scale_factor: float = 600.0 # 0.8 * 750 (approx)
	
	# Draw edges
	for edge: Dictionary in run["edges"]:
		var from_node: Dictionary = _find_node(run["nodes"], edge["from"])
		var to_node: Dictionary = _find_node(run["nodes"], edge["to"])
		
		if not from_node.is_empty() and not to_node.is_empty():
			var p1: Vector2 = center + (Vector2(from_node["x"], from_node["y"]) - Vector2(0.5, 0.5)) * scale_factor
			var p2: Vector2 = center + (Vector2(to_node["x"], to_node["y"]) - Vector2(0.5, 0.5)) * scale_factor
			
			var color: Color = Color.GRAY
			var width: float = 2.0
			var dashed: bool = false
			
			if edge.get("isCleared", false):
				color = Color.GREEN
			elif not RunManager.is_edge_traversable(edge):
				color = Color.RED
				width = 1.0
				dashed = true
			
			if dashed:
				# Simple dashed line implementation
				var dir: Vector2 = (p2 - p1).normalized()
				var dist: float = p1.distance_to(p2)
				var dash_len: float = 10.0
				var gap_len: float = 10.0
				var curr_dist: float = 0.0
				while curr_dist < dist:
					var end: Vector2 = p1 + dir * min(curr_dist + dash_len, dist)
					draw_line(p1 + dir * curr_dist, end, color, width)
					curr_dist += dash_len + gap_len
			else:
				draw_line(p1, p2, color, width, true)

	# Draw nodes
	for node: Dictionary in run["nodes"]:
		var pos: Vector2 = center + (Vector2(node["x"], node["y"]) - Vector2(0.5, 0.5)) * scale_factor
		
		var color: Color = Color.WHITE
		var radius: float = 10.0
		
		match node["type"]:
			"start":
				color = Color.YELLOW
				radius = 15.0
			"boss":
				color = Color.RED
				radius = 15.0
			"shop":
				color = Color.GOLD
			"event":
				color = Color.VIOLET
			"hard":
				color = Color.CRIMSON
			"finish":
				color = Color.CYAN
				radius = 20.0
		
		var is_locked: bool = false
		for edge: Dictionary in run["edges"]:
			if edge["to"] == node["id"]:
				if not RunManager.is_edge_traversable(edge):
					is_locked = true
					break
		
		if node["id"] == run["currentNodeId"]:
			draw_circle(pos, radius + 4, Color.WHITE) # Highlight current
		
		if node["id"] == selected_node_id:
			# Pulse animation or thick border for selected node
			var pulse: float = sin(Time.get_ticks_msec() / 150.0) * 2.0 + 4.0
			draw_arc(pos, radius + pulse, 0, TAU, 32, Color.GOLD, 2.0)
		
		var draw_color: Color = color
		if is_locked:
			draw_color = color.lerp(Color.BLACK, 0.4)
		elif node.get("isUsed", false) and node["id"] != run["currentNodeId"] and node["type"] != "start":
			draw_color = color.lerp(Color.BLACK, 0.7) # Heavily dim used nodes
			
		draw_circle(pos, radius + 1.5, Color.BLACK) # Outline
		draw_circle(pos, radius, draw_color)
		
		if is_locked:
			# Draw a small lock-like symbol
			var lock_rect: Rect2 = Rect2(pos.x - 4, pos.y - 1, 8, 6)
			draw_rect(lock_rect, Color.WHITE)
			draw_arc(pos + Vector2(0, -1), 3, PI, 2*PI, 8, Color.WHITE, 1.5)

	# Draw autoplay progress
	if is_selecting and not autoplay_target_node.is_empty():
		var ap_node: Dictionary = autoplay_target_node
		var ap_pos: Vector2 = center + (Vector2(ap_node["x"], ap_node["y"]) - Vector2(0.5, 0.5)) * scale_factor
		var ap_radius: float = 22.0
		var progress: float = 1.0 - (autoplay_timer / 2.0)
		draw_arc(ap_pos, ap_radius, -PI/2, -PI/2 + (2.0 * PI * progress), 32, Color.GOLD, 3.0, true)

func _check_autoplay() -> void:
	if not RunManager.autoplay_enabled or is_selecting: return
	
	autoplay_target_node = RunManager.get_next_autoplay_node()
	if not autoplay_target_node.is_empty():
		is_selecting = true
		autoplay_timer = 2.0

func _find_node(nodes: Array, id: String) -> Dictionary:
	for n: Dictionary in nodes:
		if n["id"] == id:
			return n
	return {}

func _get_adjacent_nodes(node_id: String) -> Array[Dictionary]:
	var run: Dictionary = RunManager.get_run()
	var adjacent: Array[Dictionary] = []
	for edge: Dictionary in run["edges"]:
		if edge["from"] == node_id:
			adjacent.append(_find_node(run["nodes"], edge["to"]))
		elif edge["to"] == node_id:
			adjacent.append(_find_node(run["nodes"], edge["from"]))
	return adjacent

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		var run: Dictionary = RunManager.get_run()
		if run.is_empty(): return
		
		# Stable World Coordinates
		var center: Vector2 = Vector2(640, 360)
		var scale_factor: float = 600.0
		
		# Translate Screen/Viewport position to World position
		var event_pos: Vector2 = Vector2.ZERO
		if event is InputEventMouseButton: event_pos = (event as InputEventMouseButton).position
		elif event is InputEventScreenTouch: event_pos = (event as InputEventScreenTouch).position
		
		var world_click_pos: Vector2 = get_canvas_transform().affine_inverse() * event_pos
		
		# Check node clicks
		for node: Dictionary in run["nodes"]:
			var pos: Vector2 = center + (Vector2(node["x"], node["y"]) - Vector2(0.5, 0.5)) * scale_factor
			var dist: float = world_click_pos.distance_to(pos)
			
			if dist < 25.0:
				selected_node_id = node["id"]
				queue_redraw()
				_on_node_clicked(node)
				return
				
	var run_data: Dictionary = RunManager.get_run()
	if not run_data.is_empty() and selected_node_id != "":
		var dir: Vector2 = Vector2.ZERO
		if event.is_action_pressed("ui_up"): dir.y -= 1
		elif event.is_action_pressed("ui_down"): dir.y += 1
		elif event.is_action_pressed("ui_left"): dir.x -= 1
		elif event.is_action_pressed("ui_right"): dir.x += 1
		
		if dir != Vector2.ZERO:
			var current_node: Dictionary = _find_node(run_data["nodes"], selected_node_id)
			var adjacent_nodes: Array[Dictionary] = _get_adjacent_nodes(selected_node_id)
			
			var best_node: Dictionary = {}
			var best_score: float = -INF
			
			for adj: Dictionary in adjacent_nodes:
				var node_dir: Vector2 = Vector2(adj["x"] - current_node["x"], adj["y"] - current_node["y"]).normalized()
				var score: float = node_dir.dot(dir)
				if score > 0.5 and score > best_score:
					best_score = score
					best_node = adj
			
			if not best_node.is_empty():
				selected_node_id = best_node["id"]
				queue_redraw()
				get_viewport().set_input_as_handled()
				return
				
		if event.is_action_pressed("ui_accept"):
			var node: Dictionary = _find_node(run_data["nodes"], selected_node_id)
			if not node.is_empty():
				_on_node_clicked(node)
				get_viewport().set_input_as_handled()
				return
	
	if event is InputEventKey and (event as InputEventKey).pressed:
		if (event as InputEventKey).keycode == KEY_R:
			var overlay: Node = (load("res://src/ui/screens/RewardOverlay.tscn") as PackedScene).instantiate()
			add_child(overlay)
			if overlay.has_signal("reward_selected"):
				overlay.connect("reward_selected", func() -> void: queue_redraw())

	if event.is_action_pressed("toggle_autoplay"):
		RunManager.toggle_autoplay()
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_cancel"):
		var pause_menu: Node = (load("res://src/ui/screens/PauseOverlay.tscn") as PackedScene).instantiate()
		add_child(pause_menu)
		get_viewport().set_input_as_handled()

func _on_node_clicked(node: Dictionary) -> void:
	var run: Dictionary = RunManager.get_run()
	if node["id"] == run["currentNodeId"]: return
	
	# 1. Find the connecting edge
	var connecting_edge: Dictionary = {}
	for edge: Dictionary in run["edges"]:
		if (edge["from"] == run["currentNodeId"] and edge["to"] == node["id"]) or \
		   (edge["to"] == run["currentNodeId"] and edge["from"] == node["id"]):
			connecting_edge = edge
			break
			
	if connecting_edge.is_empty():
		print("[MAP] Node not reachable from current node")
		return
		
	# 2. Check traversability FIRST (applies to shops/events too!)
	if not RunManager.is_edge_traversable(connecting_edge):
		print("[MAP] Path is locked! Need more medals.")
		# Visual feedback: subtle shake
		var tween: Tween = create_tween()
		var orig_pos: Vector2 = position
		tween.tween_property(self, "position", orig_pos + Vector2(4, 0), 0.05)
		tween.tween_property(self, "position", orig_pos - Vector2(4, 0), 0.05)
		tween.tween_property(self, "position", orig_pos, 0.05)
		# Re-check autoplay in case we picked a bad node
		get_tree().create_timer(0.5).timeout.connect(_check_autoplay)
		return

	# 3. Handle by type (Only if NOT already used)
	if not node.get("isUsed", false):
		if node["type"] == "shop":
			RunManager.pending_overlay = "shop"
		elif node["type"] == "event":
			RunManager.pending_overlay = "event"
		elif node["type"] == "hard":
			var challenge: EliteChallenge = EliteChallenge.get_random_challenge()
			if RunManager.autoplay_enabled:
				# Auto-accept: skip the dialog and start the challenge directly
				RunManager.active_challenge = challenge
				var max_g: float = RunManager.get_absolute_max_grade()
				var profile: CourseProfile = challenge.generate_course_profile(max_g)
				var elite_edge: Dictionary = connecting_edge.duplicate()
				elite_edge["profile"] = profile
				RunManager.set_active_edge(elite_edge)
				get_tree().change_scene_to_file("res://src/features/cycling/GameScene.tscn")
				return
			var overlay: Node = (load("res://src/ui/screens/EliteOverlay.tscn") as PackedScene).instantiate()
			add_child(overlay)
			if overlay.has_method("setup"):
				overlay.setup(challenge)
			if overlay.has_signal("challenge_accepted"):
				overlay.connect("challenge_accepted", func(accepted_challenge: EliteChallenge) -> void:
					RunManager.active_challenge = accepted_challenge
					var max_g: float = RunManager.get_absolute_max_grade()
					var profile: CourseProfile = accepted_challenge.generate_course_profile(max_g)
					var elite_edge: Dictionary = connecting_edge.duplicate()
					elite_edge["profile"] = profile
					RunManager.set_active_edge(elite_edge)
					get_tree().change_scene_to_file("res://src/features/cycling/GameScene.tscn")
				)
			if overlay.has_signal("challenge_declined"):
				overlay.connect("challenge_declined", func() -> void:
					_check_autoplay()
				)
			return

	# Start the ride for all other cases (standard, used nodes, etc.)
	RunManager.set_active_edge(connecting_edge)
	get_tree().change_scene_to_file("res://src/features/cycling/GameScene.tscn")
