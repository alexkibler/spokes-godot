extends GutTest

# Simulates the Autoplay Pathfinding from RunManager.gd

func before_each() -> void:
	# Start a fresh run to get all dictionary keys initialized
	RunManager.start_new_run(2, 20.0, "normal", 200, 75.0, "metric")
	
	RunManager.is_active_run = true
	RunManager.run_data["inventory"] = []
	RunManager.run_data["equipped"] = {}

func after_each() -> void:
	ContentRegistry.reset()
	RunManager.reset()

func test_autoplay_no_medals_starts_at_hub() -> void:
	RunManager.run_data["currentNodeId"] = "node_hub"
	
	var next_node: Dictionary = RunManager.get_next_autoplay_node()
	assert_false(next_node.is_empty(), "Should find a next node from hub")
	assert_eq(next_node["id"], "node_plains_s1", "Autoplay should head into the first unlocked spoke")

func test_autoplay_seeks_boss() -> void:
	RunManager.run_data["currentNodeId"] = "node_plains_s1"
	var next_node: Dictionary = RunManager.get_next_autoplay_node()
	assert_false(next_node.is_empty())
	assert_eq(next_node["id"], "node_plains_s2")

func test_autoplay_with_all_medals_seeks_finish() -> void:
	RunManager.run_data["currentNodeId"] = "node_hub"
	RunManager.run_data["inventory"] = ["medal_plains", "medal_coast"]
	
	var next_node: Dictionary = RunManager.get_next_autoplay_node()
	assert_false(next_node.is_empty())
	assert_eq(next_node["id"], "node_final_boss")

func test_autoplay_avoids_locked_paths() -> void:
	RunManager.run_data["currentNodeId"] = "node_hub"
	var valid_edges: Array[Dictionary] = []
	var edges: Array = RunManager.run_data["edges"]
	for e: Dictionary in edges:
		if not (e["from"] == "node_hub" and e["to"] == "node_plains_s1"):
			valid_edges.append(e)
	RunManager.run_data["edges"] = valid_edges
	
	var next_node: Dictionary = RunManager.get_next_autoplay_node()
	assert_true(next_node.is_empty())

func test_autoplay_fallback_when_no_targets() -> void:
	var new_nodes: Array[Dictionary] = []
	var nodes: Array = RunManager.run_data["nodes"]
	for n: Dictionary in nodes:
		if n["type"] != "boss" and n["type"] != "finish":
			new_nodes.append(n)
	RunManager.run_data["nodes"] = new_nodes
	RunManager.run_data["currentNodeId"] = "node_hub"
	
	var next_node: Dictionary = RunManager.get_next_autoplay_node()
	assert_false(next_node.is_empty())
	assert_eq(next_node["id"], "node_plains_s1")

func test_autoplay_reward_selection_avoids_duplicates() -> void:
	RunManager.run_data["equipped"]["Rider"] = "aero_helmet"
	var reward_a: Dictionary = ContentRegistry.get_reward("item_aero_helmet")
	var reward_b: Dictionary = ContentRegistry.get_reward("stat_power_1")
	
	var best: Dictionary = RunManager.get_best_reward([reward_a, reward_b])
	assert_eq(best["id"], "stat_power_1")

func test_autoplay_reward_selection_prefers_better_item() -> void:
	var reward_a: Dictionary = ContentRegistry.get_reward("item_aero_helmet")
	
	# Register a superior item and its reward
	ContentRegistry.register_item({
		"id": "pro_frame_test",
		"slot": "Frame",
		"modifier": {"weightMult": 0.80} # 20% reduction vs baseline
	})
	ContentRegistry.register_reward({
		"id": "item_pro_frame_test",
		"label": "Pro Frame",
		"apply": func(rm_node: Node) -> void: rm_node.call("add_to_inventory", "pro_frame_test")
	})
	var reward_b: Dictionary = ContentRegistry.get_reward("item_pro_frame_test")
	
	var best: Dictionary = RunManager.get_best_reward([reward_a, reward_b])
	assert_eq(best["id"], "item_pro_frame_test", "Should pick the pro frame over aero helmet")

func test_autoplay_prefers_net_stat_gain() -> void:
	ContentRegistry.register_item({
		"id": "basic_helmet_test",
		"slot": "Rider",
		"modifier": {"dragReduction": 0.03}
	})
	RunManager.run_data["equipped"]["Rider"] = "basic_helmet_test"
	
	ContentRegistry.register_item({
		"id": "pro_helmet_test",
		"slot": "Rider",
		"modifier": {"dragReduction": 0.04}
	})
	ContentRegistry.register_reward({
		"id": "item_pro_helmet_test",
		"apply": func(rm_node: Node) -> void: rm_node.call("add_to_inventory", "pro_helmet_test")
	})
	var reward_a: Dictionary = ContentRegistry.get_reward("item_pro_helmet_test")
	var reward_b: Dictionary = ContentRegistry.get_reward("stat_aero_1") # +2% permanent
	
	var best: Dictionary = RunManager.get_best_reward([reward_a, reward_b])
	assert_eq(best["id"], "stat_aero_1", "Should pick +2% permanent over +1% net item boost")

func test_autoplay_automatic_equip_on_grant() -> void:
	RunManager.autoplay_enabled = true
	RunManager.add_to_inventory("aero_helmet")
	assert_eq((RunManager.run_data["equipped"] as Dictionary).get("Rider"), "aero_helmet")
	
	ContentRegistry.register_item({
		"id": "super_helmet_test",
		"slot": "Rider",
		"modifier": {"dragReduction": 0.10}
	})
	RunManager.add_to_inventory("super_helmet_test")
	assert_eq((RunManager.run_data["equipped"] as Dictionary).get("Rider"), "super_helmet_test")

func test_autoplay_pathfinding_complex_navigation() -> void:
	RunManager.run_data["currentNodeId"] = "node_hub"
	var next: Dictionary = RunManager.get_next_autoplay_node()
	assert_eq(next["id"], "node_plains_s1")
	RunManager.complete_node_visit({"from": "node_hub", "to": "node_plains_s1", "profile": CourseProfile.new()})
	
	RunManager.run_data["currentNodeId"] = "node_plains_ip"
	next = RunManager.get_next_autoplay_node()
	assert_eq(next["id"], "node_plains_boss")
	
	RunManager.complete_node_visit({"from": "node_plains_ip", "to": "node_plains_boss", "profile": CourseProfile.new()})
	assert_true("medal_plains" in RunManager.run_data["inventory"])
	
	RunManager.run_data["currentNodeId"] = "node_hub"
	next = RunManager.get_next_autoplay_node()
	assert_eq(next["id"], "node_coast_s1")

func test_autoplay_reward_grand_prix() -> void:
	RunManager.run_data["equipped"] = {}
	var r_a: Dictionary = {"id": "r_a", "modifier": {"powerMult": 1.02}}
	var r_b: Dictionary = {"id": "r_b", "modifier": {"dragReduction": 0.03}}
	var r_c: Dictionary = {"id": "r_c", "modifier": {"weightMult": 0.95}}
	
	var best: Dictionary = RunManager.get_best_reward([r_a, r_b, r_c])
	assert_eq(best["id"], "r_c")

func test_autoplay_backtracking_prevention() -> void:
	RunManager.run_data["currentNodeId"] = "node_plains_s2"
	var next: Dictionary = RunManager.get_next_autoplay_node()
	assert_eq(next["id"], "node_plains_ie")
	
	(RunManager.run_data["visitedNodeIds"] as Array).append("node_plains_ie")
	RunManager.run_data["currentNodeId"] = "node_plains_ie"
	next = RunManager.get_next_autoplay_node()
	assert_ne(next["id"], "node_plains_s2")

func test_autoplay_set_explicit() -> void:
	RunManager.autoplay_enabled = false
	RunManager.set_autoplay_enabled(true)
	assert_true(RunManager.autoplay_enabled)

func test_autoplay_signal_emission() -> void:
	watch_signals(SignalBus)
	RunManager.set_autoplay_enabled(true)
	assert_signal_emitted(SignalBus, "autoplay_changed")
