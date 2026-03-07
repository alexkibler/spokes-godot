extends "res://addons/gut/test.gd"

func test_quest_completion_returns_correct_data():
	RunManager.start_new_run(3, 50.0, "normal", 200, 75.0, "metric")
	var run = RunManager.get_run()
	var current_id = run["currentNodeId"]
	
	# Find a neighbor to create an edge
	var target_id = ""
	for edge in run["edges"]:
		if edge["from"] == current_id:
			target_id = edge["to"]
			break
	
	assert_ne(target_id, "", "Should find a target node")
	
	# Set up a quest to that node
	var quest_data = {
		"destination_id": target_id,
		"destination_name": "Target Shop",
		"cargo_name": "Test Cargo",
		"cargo_weight_kg": 5.0,
		"reward_gold": 150
	}
	RunManager.accept_quest(quest_data)
	
	# Complete the ride to that node
	var edge = {"from": current_id, "to": target_id}
	var results = RunManager.complete_node_visit(edge)
	
	assert_true(results["quest"]["quest_completed"], "Quest should be completed")
	assert_eq(results["quest"]["reward_gold"], 150, "Reward should match")
	assert_eq(results["quest"]["cargo_name"], "Test Cargo", "Cargo name should match")
	assert_true(RunManager.active_quest.is_empty(), "Active quest should be cleared")
