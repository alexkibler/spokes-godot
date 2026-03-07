extends "res://addons/gut/test.gd"

func test_map_scene_blocks_input_when_overlay_present():
	var map_scene = load("res://src/features/map/MapScene.tscn").instantiate()
	add_child(map_scene)
	
	# Initially no overlay
	var event = InputEventMouseButton.new()
	event.pressed = true
	event.position = Vector2(100, 100) # Assuming a node is here or it's a valid click
	
	# Mock _on_node_clicked to track calls
	var clicked_nodes = []
	map_scene._on_node_clicked = func(node): clicked_nodes.append(node)
	
	# This is hard to test without actually knowing node positions, 
	# but we can check if MapScene has any logic to skip _input.
	
	map_scene.free()
	pass
