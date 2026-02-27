extends GutTest

# Unit test for the Spoke-Aware Autoplay Pathfinding logic.
# Verifies that autoplay prioritizes spokes one-by-one, clears them,
# returns to the hub, and eventually challenges the final boss.

func before_each() -> void:
	RunManager.reset()
	ContentRegistry.reset()

func after_each() -> void:
	RunManager.reset()
	ContentRegistry.reset()

func test_autoplay_path_logic_2_spokes() -> void:
	_run_path_test(2)

func test_autoplay_path_logic_4_spokes() -> void:
	_run_path_test(4)

## Helper to run a full autoplay path simulation and validate its structure.
func _run_path_test(num_spokes: int) -> void:
	# 1. Generate a map with the specified length
	# total_distance_km = num_spokes * KM_PER_SPOKE (20)
	var dist_km: float = float(num_spokes * 20)
	RunManager.start_new_run(num_spokes, dist_km, "normal", 200, 75.0, "metric")
	
	var run: Dictionary = RunManager.get_run()
	var path: Array[String] = [run["currentNodeId"]]
	var max_steps: int = 200
	var steps: int = 0
	
	gut.p("[TEST] Starting simulation for %d spokes..." % num_spokes)
	
	# 2. Simulate the traversal
	while RunManager.is_active_run and steps < max_steps:
		steps += 1
		var next_node: Dictionary = RunManager.get_next_autoplay_node()
		
		if next_node.is_empty():
			break
			
		var current_id: String = RunManager.run_data["currentNodeId"]
		var edge: Dictionary = _find_edge(current_id, next_node["id"])
		
		assert_true(!edge.is_empty(), "Autoplay should only pick adjacent nodes (Step %d: %s -> %s)" % [steps, current_id, next_node["id"]])
		assert_true(RunManager.is_edge_traversable(edge), "Autoplay should only pick traversable edges")
		
		gut.p("  Step %d: %s -> %s (%s)" % [steps, current_id, next_node["id"], next_node.get("type", "standard")])
		
		# Move
		RunManager.complete_node_visit(edge)
		path.append(next_node["id"])
		
		# If we hit the final boss, we are done
		if next_node["id"] == "node_final_boss":
			gut.p("[TEST] Reached Final Boss in %d steps" % steps)
			break
			
	# 3. Assertions
	
	assert_eq(path.back(), "node_final_boss", "Should reach the final boss")
	
	# Validate Spoke-by-Spoke behavior:
	# Once we enter a spoke, we should not visit any other spoke until we return to Hub.
	var current_spoke: String = ""
	var hubs_visited: int = 0
	var spokes_sequence: Array[String] = []
	
	for node_id in path:
		var n: Dictionary = _find_node(node_id)
		var spoke_id: String = n.get("metadata", {}).get("spokeId", "")
		
		if node_id == "node_hub":
			hubs_visited += 1
			current_spoke = ""
		elif spoke_id != "":
			if spoke_id != current_spoke:
				# We entered a new spoke
				assert_eq(current_spoke, "", "Should return to Hub before entering a new spoke (Step: %s)" % node_id)
				current_spoke = spoke_id
				spokes_sequence.append(spoke_id)
	
	assert_eq(spokes_sequence.size(), num_spokes, "Should visit all %d generated spokes" % num_spokes)
	
	# Validate ordering: spokes should be completed in MapGenerator.SPOKE_IDS order
	for i in range(spokes_sequence.size()):
		assert_eq(spokes_sequence[i], MapGenerator.SPOKE_IDS[i], "Spokes should be visited in order")

# --- Helpers ---

func _find_edge(from_id: String, to_id: String) -> Dictionary:
	for e in RunManager.run_data["edges"]:
		if (e["from"] == from_id and e["to"] == to_id) or (e["to"] == from_id and e["from"] == to_id):
			return e
	return {}

func _find_node(id: String) -> Dictionary:
	for n in RunManager.run_data["nodes"]:
		if n["id"] == id: return n
	return {}
