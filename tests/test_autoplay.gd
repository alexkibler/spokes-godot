extends "res://addons/gut/test.gd"

# Simulates the Autoplay Pathfinding from RunManager.gd

var rm
var cr

func before_each():
	# Use the actual RunManager singleton to ensure full logic is tested
	rm = RunManager
	cr = ContentRegistry
	
	# Start a fresh run to get all dictionary keys initialized
	rm.start_new_run(2, 20.0, "normal", 200, 75.0, "metric")
	
	rm.is_active_run = true
	rm.run_data["inventory"] = []
	rm.run_data["equipped"] = {}

func test_autoplay_no_medals_starts_at_hub():
	rm.run_data["currentNodeId"] = "node_hub"
	
	var next_node = rm.get_next_autoplay_node()
	assert_not_null(next_node, "Should find a next node from hub")
	
	# With no medals, we can only traverse to the first spoke (plains).
	# The edge to the second spoke (coast) requires "medal_plains".
	# The edge to finish requires all medals.
	assert_eq(next_node["id"], "node_plains_s1", "Autoplay should head into the first unlocked spoke")

func test_autoplay_seeks_boss():
	# Position at the first spoke entry
	rm.run_data["currentNodeId"] = "node_plains_s1"
	
	var next_node = rm.get_next_autoplay_node()
	assert_not_null(next_node)
	assert_eq(next_node["id"], "node_plains_s2", "Autoplay should continue down the spoke towards the boss")
	
	# Let's move to the island entry and see if it picks a path to the pre-boss
	rm.run_data["currentNodeId"] = "node_plains_ie"
	next_node = rm.get_next_autoplay_node()
	
	# The heuristic evaluates neighbors (il, ic, ir) and picks the one closest to the boss.
	# Depending on positions generated, it should pick one of them.
	var valid_islands = ["node_plains_il", "node_plains_ic", "node_plains_ir"]
	assert_true(valid_islands.has(next_node["id"]), "Autoplay should pick an island node: " + next_node["id"])

func test_autoplay_with_all_medals_seeks_finish():
	rm.run_data["currentNodeId"] = "node_hub"
	# Give player all medals
	rm.run_data["inventory"] = ["medal_plains", "medal_coast"]
	
	var next_node = rm.get_next_autoplay_node()
	assert_not_null(next_node)
	
	# Since it has all medals, target becomes the Finish node.
	# The Finish node is directly connected to the hub.
	assert_eq(next_node["id"], "node_final_boss", "Autoplay should head straight for the finish if it has all medals")

func test_autoplay_avoids_locked_paths():
	rm.run_data["currentNodeId"] = "node_hub"
	# We have no medals.
	
	# We know plains_s1 is valid. coast_s1 is locked. final_boss is locked.
	# Let's manually remove the plains edge so it has NO valid paths to the boss.
	var valid_edges = []
	for e in rm.run_data["edges"]:
		if not (e["from"] == "node_hub" and e["to"] == "node_plains_s1"):
			valid_edges.append(e)
	rm.run_data["edges"] = valid_edges
	
	var next_node = rm.get_next_autoplay_node()
	# Because all other paths from hub are locked, it should return empty
	assert_true(next_node.is_empty(), "Autoplay should return empty if no valid traversable edges exist")

func test_autoplay_fallback_when_no_targets():
	# If there are no bosses left and no finish node reachable (or it doesn't exist),
	# it should fallback to an unvisited neighbor.
	
	# Clear bosses and finish node
	var new_nodes = []
	for n in rm.run_data["nodes"]:
		if n["type"] != "boss" and n["type"] != "finish":
			new_nodes.append(n)
	rm.run_data["nodes"] = new_nodes
	
	rm.run_data["currentNodeId"] = "node_hub"
	
	var next_node = rm.get_next_autoplay_node()
	assert_not_null(next_node)
	assert_eq(next_node["id"], "node_plains_s1", "Autoplay should fallback to an available neighbor")

func test_autoplay_reward_selection_avoids_duplicates():
	# Current inventory/equipped has an aero helmet
	var item_id = "aero_helmet"
	rm.run_data["equipped"]["helmet"] = item_id
	
	# Offer two rewards: another aero helmet and a power boost
	var reward_a = ContentRegistry.get_reward("item_aero_helmet")
	var reward_b = ContentRegistry.get_reward("stat_power_1")
	
	var best = rm.get_best_reward([reward_a, reward_b])
	
	# Autoplay should pick the power boost because it already has the helmet
	assert_eq(best["id"], "stat_power_1", "Autoplay should prefer a new stat boost over a duplicate item")

func test_autoplay_reward_selection_prefers_better_item():
	# Currently equipped: nothing
	# Offer: Aero Helmet (-3% drag) vs Carbon Frame (-12% weight, -3% drag)
	var reward_a = ContentRegistry.get_reward("item_aero_helmet")
	
	# We need to register a carbon frame reward if it doesn't exist
	ContentRegistry.register_reward({
		"id": "item_carbon_frame",
		"label": "Carbon Frame",
		"rarity": "rare",
		"apply": func(rm): rm.add_to_inventory("carbon_frame")
	})
	var reward_b = ContentRegistry.get_reward("item_carbon_frame")
	
	var best = rm.get_best_reward([reward_a, reward_b])
	assert_eq(best["id"], "item_carbon_frame", "Autoplay should prefer higher quality/more modifiers")

func test_autoplay_prefers_net_stat_gain():
	# Current Helmet: +3% Aero (0.03 dragReduction)
	cr.register_item({
		"id": "basic_helmet",
		"slot": "helmet",
		"label": "Basic Helmet",
		"modifier": {"dragReduction": 0.03}
	})
	rm.run_data["equipped"]["helmet"] = "basic_helmet"
	
	# Option A: Pro Helmet +4% Aero (0.04 dragReduction) -> Net Gain +1%
	cr.register_item({
		"id": "pro_helmet",
		"slot": "helmet",
		"label": "Pro Helmet",
		"modifier": {"dragReduction": 0.04}
	})
	cr.register_reward({
		"id": "item_pro_helmet",
		"label": "Pro Helmet Reward",
		"apply": func(rm): rm.add_to_inventory("pro_helmet")
	})
	var reward_a = cr.get_reward("item_pro_helmet")
	
	# Option B: Stat Boost +2% Aero (0.02 dragReduction) -> Net Gain +2%
	# (stat_aero_1 from bootstrap is 0.02)
	var reward_b = cr.get_reward("stat_aero_1")
	
	var best = rm.get_best_reward([reward_a, reward_b])
	
	# Option B (+2% net) should beat Option A (+1% net)
	assert_eq(best["id"], "stat_aero_1", "Should pick +2% permanent stat over +1% net item upgrade")

func test_autoplay_automatic_equip_on_grant():
	rm.autoplay_enabled = true
	rm.run_data["equipped"] = {}
	rm.run_data["inventory"] = []
	
	# Grant an item
	rm.add_to_inventory("aero_helmet")
	
	# Should be automatically equipped because slot was empty
	assert_eq(rm.run_data["equipped"].get("helmet"), "aero_helmet", "Should auto-equip to empty slot")
	
	# Grant a better item (we'll register one)
	cr.register_item({
		"id": "super_helmet",
		"slot": "helmet",
		"label": "Super Helmet",
		"modifier": {"dragReduction": 0.10} # 10% vs 3%
	})
	
	rm.add_to_inventory("super_helmet")
	
	# Should have swapped
	assert_eq(rm.run_data["equipped"].get("helmet"), "super_helmet", "Should auto-swap to superior item")
	assert_true("aero_helmet" in rm.run_data["inventory"], "Old item should be back in inventory")

func test_autoplay_pathfinding_complex_navigation():
	# Test navigating through multiple spokes and unlocking gates
	rm.run_data["currentNodeId"] = "node_hub"
	rm.run_data["inventory"] = []
	
	# 1. Hub -> Spoke 1
	var next = rm.get_next_autoplay_node()
	assert_eq(next["id"], "node_plains_s1", "Path 1: Must enter plains spoke first")
	rm.complete_node_visit({"from": "node_hub", "to": "node_plains_s1", "profile": {"totalDistanceM": 1000}})
	
	# 2. Spoke 1 -> Boss 1
	# We'll skip ahead to the boss node for brevity in the test
	rm.run_data["currentNodeId"] = "node_plains_pre"
	next = rm.get_next_autoplay_node()
	assert_eq(next["id"], "node_plains_boss", "Path 2: Must target the unvisited boss")
	
	# 3. Defeat Boss 1 -> Unlock Spoke 2
	rm.complete_node_visit({"from": "node_plains_pre", "to": "node_plains_boss", "profile": {"totalDistanceM": 1000}})
	assert_true("medal_plains" in rm.run_data["inventory"], "Should have earned medal_plains")
	
	# 4. Return to Hub
	# (MapGenerator connects boss back to hub or pre-boss back to hub)
	rm.run_data["currentNodeId"] = "node_hub"
	next = rm.get_next_autoplay_node()
	assert_eq(next["id"], "node_coast_s1", "Path 3: With medal_plains, must now target the coast spoke")

func test_autoplay_reward_grand_prix():
	# Offer a mix of items and stats. 
	# Weighting: Power (10), Aero (8), Weight (6)
	
	# Current State: Empty
	rm.run_data["equipped"] = {}
	
	# Reward A: +2% Power (Value: 0.02 * 10 = 0.20)
	var r_a = {"id": "r_a", "modifier": {"powerMult": 1.02}, "rarity": "common"}
	# Reward B: +3% Aero (Value: 0.03 * 8 = 0.24)
	var r_b = {"id": "r_b", "modifier": {"dragReduction": 0.03}, "rarity": "common"}
	# Reward C: -5% Weight (Value: 0.05 * 6 = 0.30)
	var r_c = {"id": "r_c", "modifier": {"weightMult": 0.95}, "rarity": "common"}
	
	var best = rm.get_best_reward([r_a, r_b, r_c])
	assert_eq(best["id"], "r_c", "GP 1: Should pick -5% Weight (0.30) over others")
	
	# Now equip a Frame that gives -10% Weight
	cr.register_item({"id": "heavy_frame", "slot": "frame", "modifier": {"weightMult": 0.90}, "label": "Heavy Frame"})
	rm.run_data["equipped"]["frame"] = "heavy_frame"
	
	# Offer Reward D: -12% Weight Item (Net gain -2% = 0.12 benefit)
	cr.register_item({"id": "light_frame", "slot": "frame", "modifier": {"weightMult": 0.88}, "label": "Light Frame"})
	var r_d = {"id": "item_light_frame", "rarity": "common"}
	
	# Offer Reward E: +2% Power Stat (Net gain +2% = 0.20 benefit)
	var r_e = {"id": "stat_power_2", "modifier": {"powerMult": 1.02}, "rarity": "common"}
	
	best = rm.get_best_reward([r_d, r_e])
	assert_eq(best["id"], "stat_power_2", "GP 2: Should pick +2% Power (0.20) over incremental Weight upgrade (0.12)")

func test_autoplay_backtracking_prevention():
	# Current node is S2. Neighbors are S1 (backwards) and Pre-Boss (forwards).
	# Heuristic should pick Pre-Boss because it's closer to the Boss.
	rm.run_data["currentNodeId"] = "node_plains_s2"
	
	var next = rm.get_next_autoplay_node()
	assert_eq(next["id"], "node_plains_ie", "Should proceed to Island Entry, not return to S1")
	
	# Mark IE as visited
	rm.run_data["visitedNodeIds"].append("node_plains_ie")
	rm.run_data["currentNodeId"] = "node_plains_ie"
	
	# From IE, don't go back to S2 even if it's "close"
	next = rm.get_next_autoplay_node()
	assert_true(not next["id"] == "node_plains_s2", "Should not backtrack to a recently visited node if targets exist")

func test_autoplay_set_explicit():
	rm.autoplay_enabled = false
	rm.set_autoplay_enabled(true)
	assert_true(rm.autoplay_enabled)
	
	rm.set_autoplay_enabled(true) # Should stay true
	assert_true(rm.autoplay_enabled)
	
	rm.set_autoplay_enabled(false)
	assert_false(rm.autoplay_enabled)

func test_autoplay_signal_emission():
	watch_signals(rm)
	rm.set_autoplay_enabled(true)
	assert_signal_emitted(rm, "autoplay_changed", "Should emit signal on state change")
	
	rm.set_autoplay_enabled(true) # No change
	assert_signal_emit_count(rm, "autoplay_changed", 1, "Should NOT emit if state is identical")
	
	rm.set_autoplay_enabled(false)
	assert_signal_emit_count(rm, "autoplay_changed", 2, "Should emit on second change")
