extends Node2D

# Port of MapScene.ts visualization

@onready var hud: CanvasLayer = $MapHUD

var is_selecting: bool = false
var autoplay_timer: float = 0.0
var autoplay_target_node: Dictionary = {}

func _process(delta: float) -> void:
	if is_selecting and not autoplay_target_node.is_empty():
		autoplay_timer -= delta
		if autoplay_timer <= 0:
			is_selecting = false
			var node = autoplay_target_node
			autoplay_target_node = {}
			if RunManager.autoplay_enabled:
				_on_node_clicked(node)
		queue_redraw()

func _ready() -> void:
	if not RunManager.is_active_run:
		# Emergency start for testing
		RunManager.start_new_run(3, 50.0, "normal", 200, 75.0, "imperial")
	
	RunManager.autoplay_changed.connect(_on_autoplay_changed)
	hud.update_hud()
	queue_redraw()
	_check_autoplay()

func _on_autoplay_changed(enabled: bool) -> void:
	if enabled:
		_check_autoplay()

func _draw() -> void:
	var run = RunManager.get_run()
	if run.is_empty(): return
	
	hud.update_hud()
	
	var center = get_viewport_rect().size / 2.0
	var scale_factor = min(get_viewport_rect().size.x, get_viewport_rect().size.y) * 0.8
	
	# Draw edges
	for edge in run["edges"]:
		var from_node = _find_node(run["nodes"], edge["from"])
		var to_node = _find_node(run["nodes"], edge["to"])
		
		if from_node and to_node:
			var p1 = center + (Vector2(from_node["x"], from_node["y"]) - Vector2(0.5, 0.5)) * scale_factor
			var p2 = center + (Vector2(to_node["x"], to_node["y"]) - Vector2(0.5, 0.5)) * scale_factor
			
			var color = Color.GRAY
			var width = 2.0
			var dashed = false
			
			if edge.get("isCleared", false):
				color = Color.GREEN
			elif not RunManager.is_edge_traversable(edge):
				color = Color.RED
				width = 1.0
				dashed = true
			
			if dashed:
				# Simple dashed line implementation
				var dir = (p2 - p1).normalized()
				var dist = p1.distance_to(p2)
				var dash_len = 10.0
				var gap_len = 10.0
				var curr_dist = 0.0
				while curr_dist < dist:
					var end = p1 + dir * min(curr_dist + dash_len, dist)
					draw_line(p1 + dir * curr_dist, end, color, width)
					curr_dist += dash_len + gap_len
			else:
				draw_line(p1, p2, color, width, true)

	# Draw nodes
	for node in run["nodes"]:
		var pos = center + (Vector2(node["x"], node["y"]) - Vector2(0.5, 0.5)) * scale_factor
		
		var color = Color.WHITE
		var radius = 10.0
		
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
		
		var is_locked = false
		for edge in run["edges"]:
			if edge["to"] == node["id"]:
				if not RunManager.is_edge_traversable(edge):
					is_locked = true
					break
		
		if node["id"] == run["currentNodeId"]:
			draw_circle(pos, radius + 4, Color.WHITE) # Highlight current
		
		var draw_color = color
		if is_locked:
			draw_color = color.lerp(Color.BLACK, 0.4)
		elif node.get("isUsed", false) and node["id"] != run["currentNodeId"] and node["type"] != "start":
			draw_color = color.lerp(Color.BLACK, 0.7) # Heavily dim used nodes
			
		draw_circle(pos, radius + 1.5, Color.BLACK) # Outline
		draw_circle(pos, radius, draw_color)
		
		if is_locked:
			# Draw a small lock-like symbol
			var lock_rect = Rect2(pos.x - 4, pos.y - 1, 8, 6)
			draw_rect(lock_rect, Color.WHITE)
			draw_arc(pos + Vector2(0, -1), 3, PI, 2*PI, 8, Color.WHITE, 1.5)

	# Draw autoplay progress
	if is_selecting and not autoplay_target_node.is_empty():
		var node = autoplay_target_node
		var pos = center + (Vector2(node["x"], node["y"]) - Vector2(0.5, 0.5)) * scale_factor
		var radius = 22.0
		var progress = 1.0 - (autoplay_timer / 2.0)
		draw_arc(pos, radius, -PI/2, -PI/2 + (2.0 * PI * progress), 32, Color.GOLD, 3.0, true)

func _check_autoplay() -> void:
	if not RunManager.autoplay_enabled or is_selecting: return
	
	autoplay_target_node = RunManager.get_next_autoplay_node()
	if not autoplay_target_node.is_empty():
		is_selecting = true
		autoplay_timer = 2.0

func _find_node(nodes: Array, id: String) -> Dictionary:
	for n in nodes:
		if n["id"] == id:
			return n
	return {}

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var run = RunManager.get_run()
		if run.is_empty(): return
		
		var center = get_viewport_rect().size / 2.0
		var scale_factor = min(get_viewport_rect().size.x, get_viewport_rect().size.y) * 0.8
		
		# Check node clicks
		for node in run["nodes"]:
			var pos = center + (Vector2(node["x"], node["y"]) - Vector2(0.5, 0.5)) * scale_factor
			if event.position.distance_to(pos) < 25.0:
				_on_node_clicked(node)
				return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			var overlay = load("res://src/ui/RewardOverlay.tscn").instantiate()
			add_child(overlay)
			overlay.reward_selected.connect(func(): queue_redraw())

	if event.is_action_pressed("ui_cancel"):
		var pause_menu = load("res://src/ui/PauseOverlay.tscn").instantiate()
		add_child(pause_menu)
		get_viewport().set_input_as_handled()

func _on_node_clicked(node: Dictionary) -> void:
	var run = RunManager.get_run()
	if node["id"] == run["currentNodeId"]: return
	
	# 1. Find the connecting edge
	var connecting_edge = null
	for edge in run["edges"]:
		if (edge["from"] == run["currentNodeId"] and edge["to"] == node["id"]) or \
		   (edge["to"] == run["currentNodeId"] and edge["from"] == node["id"]):
			connecting_edge = edge
			break
			
	if not connecting_edge:
		print("[MAP] Node not reachable from current node")
		return
		
	# 2. Check traversability FIRST (applies to shops/events too!)
	if not RunManager.is_edge_traversable(connecting_edge):
		print("[MAP] Path is locked! Need more medals.")
		# Visual feedback: subtle shake
		var tween = create_tween()
		var orig_pos = position
		tween.tween_property(self, "position", orig_pos + Vector2(4, 0), 0.05)
		tween.tween_property(self, "position", orig_pos - Vector2(4, 0), 0.05)
		tween.tween_property(self, "position", orig_pos, 0.05)
		# Re-check autoplay in case we picked a bad node
		get_tree().create_timer(0.5).timeout.connect(_check_autoplay)
		return

	# NEW: Skip interactions if already used
	if node.get("isUsed", false):
		RunManager.complete_node_visit(connecting_edge)
		queue_redraw()
		_check_autoplay()
		return

	# 3. Handle by type
	if node["type"] == "shop":
		RunManager.pending_overlay = "shop"
	elif node["type"] == "event":
		RunManager.pending_overlay = "event"
	elif node["type"] == "hard":
		var challenge = EliteChallenge.get_random_challenge()
		var overlay = load("res://src/ui/EliteOverlay.tscn").instantiate()
		add_child(overlay)
		overlay.setup(challenge)
		overlay.challenge_accepted.connect(func(accepted_challenge):
			RunManager.active_challenge = accepted_challenge
			# Use specialized elite profile
			var max_g = RunManager.get_absolute_max_grade()
			connecting_edge["profile"] = EliteChallenge.generate_elite_course_profile(accepted_challenge, max_g)
			RunManager.set_active_edge(connecting_edge)
			get_tree().change_scene_to_file("res://src/scenes/GameScene.tscn")
		)
		overlay.challenge_declined.connect(func():
			_check_autoplay()
		)
		return

	# Start the ride for all other types (standard, shop, event, etc.)
	RunManager.set_active_edge(connecting_edge)
	get_tree().change_scene_to_file("res://src/scenes/GameScene.tscn")
