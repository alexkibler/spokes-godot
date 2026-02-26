extends GutTest

# Simulates the Autoplay Pathfinding from RunManager.gd

var rm: Node
var cr: ContentRegistry

func before_each() -> void:
	# Use the actual RunManager singleton to ensure full logic is tested
	rm = RunManager
	cr = ContentRegistry
	
	# Start a fresh run to get all dictionary keys initialized
	rm.start_new_run(2, 20.0, "normal", 200, 75.0, "metric")
	
	rm.is_active_run = true
	rm.run_data["inventory"] = []
	rm.run_data["equipped"] = {}

func after_each() -> void:
	ContentRegistry.reset()
	RunManager.reset()

func test_autoplay_no_medals_starts_at_hub() -> void:
	rm.run_data["currentNodeId"] = "node_hub"
	
	var next_node: Dictionary = rm.get_next_autoplay_node()
	assert_not_null(next_node, "Should find a next node from hub")
	assert_eq(next_node["id"], "node_plains_s1", "Autoplay should head into the first unlocked spoke")

func test_autoplay_seeks_boss() -> void:
	rm.run_data["currentNodeId"] = "node_plains_s1"
	var next_node: Dictionary = rm.get_next_autoplay_node()
	assert_not_null(next_node)
	assert_eq(next_node["id"], "node_plains_s2")

func test_autoplay_with_all_medals_seeks_finish() -> void:
	rm.run_data["currentNodeId"] = "node_hub"
	rm.run_data["inventory"] = ["medal_plains", "medal_coast"]
	
	var next_node: Dictionary = rm.get_next_autoplay_node()
	assert_not_null(next_node)
	assert_eq(next_node["id"], "node_final_boss")

func test_autoplay_avoids_locked_paths() -> void:
	rm.run_data["currentNodeId"] = "node_hub"
	var valid_edges: Array[Dictionary] = []
	for e: Dictionary in rm.run_data["edges"]:
		if not (e["from"] == "node_hub" and e["to"] == "node_plains_s1"):
			valid_edges.append(e)
	rm.run_data["edges"] = valid_edges
	
	var next_node: Dictionary = rm.get_next_autoplay_node()
	assert_true(next_node.is_empty())

func test_autoplay_fallback_when_no_targets() -> void:
	var new_nodes: Array[Dictionary] = []
	for n: Dictionary in rm.run_data["nodes"]:
		if n["type"] != "boss" and n["type"] != "finish":
			new_nodes.append(n)
	rm.run_data["nodes"] = new_nodes
	rm.run_data["currentNodeId"] = "node_hub"
	
	var next_node: Dictionary = rm.get_next_autoplay_node()
	assert_not_null(next_node)
	assert_eq(next_node["id"], "node_plains_s1")

func test_autoplay_reward_selection_avoids_duplicates() -> void:
	rm.run_data["equipped"]["helmet"] = "aero_helmet"
	var reward_a: Dictionary = ContentRegistry.get_reward("item_aero_helmet")
	var reward_b: Dictionary = ContentRegistry.get_reward("stat_power_1")
	
	var best: Dictionary = rm.get_best_reward([reward_a, reward_b])
	assert_eq(best["id"], "stat_power_1")

func test_autoplay_reward_selection_prefers_better_item() -> void:
	var reward_a: Dictionary = ContentRegistry.get_reward("item_aero_helmet")
	
	# Register a superior item and its reward
	cr.register_item({
		"id": "pro_frame_test",
		"slot": "frame",
		"modifier": {"weightMult": 0.80} # 20% reduction vs baseline
	})
	cr.register_reward({
		"id": "item_pro_frame_test",
		"label": "Pro Frame",
		"apply": func(rm: Node) -> void: rm.add_to_inventory("pro_frame_test")
	})
	var reward_b: Dictionary = ContentRegistry.get_reward("item_pro_frame_test")
	
	var best: Dictionary = rm.get_best_reward([reward_a, reward_b])
	assert_eq(best["id"], "item_pro_frame_test", "Should pick the pro frame over aero helmet")

func test_autoplay_prefers_net_stat_gain() -> void:
	cr.register_item({
		"id": "basic_helmet_test",
		"slot": "helmet",
		"modifier": {"dragReduction": 0.03}
	})
	rm.run_data["equipped"]["helmet"] = "basic_helmet_test"
	
	cr.register_item({
		"id": "pro_helmet_test",
		"slot": "helmet",
		"modifier": {"dragReduction": 0.04}
	})
	cr.register_reward({
		"id": "item_pro_helmet_test",
		"apply": func(rm: Node) -> void: rm.add_to_inventory("pro_helmet_test")
	})
	var reward_a: Dictionary = cr.get_reward("item_pro_helmet_test")
	var reward_b: Dictionary = cr.get_reward("stat_aero_1") # +2% permanent
	
	var best: Dictionary = rm.get_best_reward([reward_a, reward_b])
	assert_eq(best["id"], "stat_aero_1", "Should pick +2% permanent over +1% net item boost")

func test_autoplay_automatic_equip_on_grant() -> void:
	rm.autoplay_enabled = true
	rm.add_to_inventory("aero_helmet")
	assert_eq(rm.run_data["equipped"].get("helmet"), "aero_helmet")
	
	cr.register_item({
		"id": "super_helmet_test",
		"slot": "helmet",
		"modifier": {"dragReduction": 0.10}
	})
	rm.add_to_inventory("super_helmet_test")
	assert_eq(rm.run_data["equipped"].get("helmet"), "super_helmet_test")

func test_autoplay_pathfinding_complex_navigation() -> void:
	rm.run_data["currentNodeId"] = "node_hub"
	var next: Dictionary = rm.get_next_autoplay_node()
	assert_eq(next["id"], "node_plains_s1")
	rm.complete_node_visit({"from": "node_hub", "to": "node_plains_s1", "profile": CourseProfile.new()})
	
	rm.run_data["currentNodeId"] = "node_plains_ip"
	next = rm.get_next_autoplay_node()
	assert_eq(next["id"], "node_plains_boss")
	
	rm.complete_node_visit({"from": "node_plains_ip", "to": "node_plains_boss", "profile": CourseProfile.new()})
	assert_true("medal_plains" in rm.run_data["inventory"])
	
	rm.run_data["currentNodeId"] = "node_hub"
	next = rm.get_next_autoplay_node()
	assert_eq(next["id"], "node_coast_s1")

func test_autoplay_reward_grand_prix() -> void:
	rm.run_data["equipped"] = {}
	var r_a: Dictionary = {"id": "r_a", "modifier": {"powerMult": 1.02}}
	var r_b: Dictionary = {"id": "r_b", "modifier": {"dragReduction": 0.03}}
	var r_c: Dictionary = {"id": "r_c", "modifier": {"weightMult": 0.95}}
	
	var best: Dictionary = rm.get_best_reward([r_a, r_b, r_c])
	assert_eq(best["id"], "r_c")

func test_autoplay_backtracking_prevention() -> void:
	rm.run_data["currentNodeId"] = "node_plains_s2"
	var next: Dictionary = rm.get_next_autoplay_node()
	assert_eq(next["id"], "node_plains_ie")
	
	rm.run_data["visitedNodeIds"].append("node_plains_ie")
	rm.run_data["currentNodeId"] = "node_plains_ie"
	next = rm.get_next_autoplay_node()
	assert_ne(next["id"], "node_plains_s2")

func test_autoplay_set_explicit() -> void:
	rm.autoplay_enabled = false
	rm.set_autoplay_enabled(true)
	assert_true(rm.autoplay_enabled)

func test_autoplay_signal_emission() -> void:
	watch_signals(SignalBus)
	rm.set_autoplay_enabled(true)
	assert_signal_emitted(SignalBus, "autoplay_changed")
