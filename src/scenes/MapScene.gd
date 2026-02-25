extends Node2D

# Port of MapScene.ts visualization

@onready var hud: CanvasLayer = $MapHUD

func _ready() -> void:
	if not RunManager.is_active_run:
		# Emergency start for testing
		RunManager.start_new_run(3, 50.0, "normal", 200, 75.0, "imperial")
	
	hud.update_hud()
	queue_redraw()

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
			if edge.get("isCleared", false):
				color = Color.GREEN
			
			draw_line(p1, p2, color, 2.0, true)

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
			"finish":
				color = Color.CYAN
				radius = 20.0
		
		if node["id"] == run["currentNodeId"]:
			draw_circle(pos, radius + 5, Color.WHITE) # Highlight current
		
		draw_circle(pos, radius, color)

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

func _on_node_clicked(node: Dictionary) -> void:
	var run = RunManager.get_run()
	if node["id"] == run["currentNodeId"]: return
	
	# Check if node is reachable
	var is_reachable = false
	for edge in run["edges"]:
		if (edge["from"] == run["currentNodeId"] and edge["to"] == node["id"]) or \
		   (edge["to"] == run["currentNodeId"] and edge["from"] == node["id"]):
			is_reachable = true
			break
			
	if not is_reachable:
		print("[MAP] Node not reachable from current node")
		return
		
	if node["type"] == "shop":
		var overlay = load("res://src/ui/ShopOverlay.tscn").instantiate()
		add_child(overlay)
		overlay.closed.connect(func(): queue_redraw())
		return

	# Start the ride!
	var connecting_edge = null
	for edge in run["edges"]:
		if (edge["from"] == run["currentNodeId"] and edge["to"] == node["id"]) or \
		   (edge["to"] == run["currentNodeId"] and edge["from"] == node["id"]):
			connecting_edge = edge
			break
			
	RunManager.set_active_edge(connecting_edge)
	get_tree().change_scene_to_file("res://src/scenes/GameScene.tscn")
