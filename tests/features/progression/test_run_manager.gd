extends GutTest

# Tests ported from ~/Repos/spokes/src/core/roguelike/__tests__/RunManager.test.ts

func before_each() -> void:
	# Ensure a clean state before each test
	RunManager.is_active_run = false
	RunManager.run_data = {}

func test_start_new_run() -> void:
	RunManager.start_new_run(3, 50.0, "normal", 200, 68.0, "imperial")
	var run: Dictionary = RunManager.get_run()
	
	assert_not_null(run, "run should be active")
	assert_eq(run.gold, 0, "initial gold should be 0")
	assert_eq(run.runLength, 3, "runLength should match")
	assert_eq(run.totalDistanceKm, 50.0, "totalDistanceKm should match")
	assert_eq(run.difficulty, "normal", "difficulty should match")
	assert_eq(run.ftpW, 200, "ftpW should match")
	assert_eq(run.weightKg, 68.0, "weightKg should match")
	assert_eq(run.units, "imperial", "units should match")
	assert_eq(run.inventory, [], "inventory should be empty")
	
	var m: Dictionary = run.modifiers
	assert_eq(m.powerMult, 1.0, "default powerMult")
	assert_eq(m.dragReduction, 0.0, "default dragReduction")
	assert_eq(m.weightMult, 1.0, "default weightMult")
	
	var s: Dictionary = run.stats
	assert_eq(s.totalRiddenDistanceM, 0, "initial stats")
	assert_eq(s.totalRecordCount, 0, "initial stats")
	assert_eq(s.totalPowerSum, 0, "initial stats")
	assert_eq(s.totalCadenceSum, 0, "initial stats")

func test_get_run_null() -> void:
	assert_eq(RunManager.get_run(), {}, "returns empty dict when no run active")

func test_add_gold() -> void:
	RunManager.start_new_run(3, 50.0, "normal", 200, 68.0, "imperial")
	RunManager.add_gold(50)
	assert_eq(RunManager.get_run().gold, 50)
	RunManager.add_gold(30)
	assert_eq(RunManager.get_run().gold, 80)

func test_spend_gold() -> void:
	RunManager.start_new_run(3, 50.0, "normal", 200, 68.0, "imperial")
	RunManager.add_gold(100)
	
	var result: bool = RunManager.spend_gold(40)
	assert_true(result, "should succeed")
	assert_eq(RunManager.get_run().gold, 60)
	
	result = RunManager.spend_gold(200)
	assert_false(result, "should fail")
	assert_eq(RunManager.get_run().gold, 60)

func test_inventory() -> void:
	RunManager.start_new_run(3, 50.0, "normal", 200, 68.0, "imperial")
	RunManager.add_to_inventory("tailwind")
	assert_has(RunManager.get_run().inventory, "tailwind")
	
	# Godot version doesn't have remove_from_inventory yet (based on read_file)
	# It has equip_item and unequip_item
	if RunManager.has_method("remove_from_inventory"):
		RunManager.has_method("remove_from_inventory") # dummy to match context if needed
		# Actually, let's just use the real code
		pass

func test_apply_modifier() -> void:
	RunManager.start_new_run(3, 50.0, "normal", 200, 68.0, "imperial")
	watch_signals(SignalBus)
	
	RunManager.apply_modifier({"powerMult": 1.1})
	assert_signal_emitted(SignalBus, "modifiers_changed", "should emit modifiers_changed on global bus")
	assert_almost_eq(RunManager.get_run().modifiers.powerMult, 1.1, 0.0001)
	RunManager.apply_modifier({"powerMult": 1.1})
	assert_almost_eq(RunManager.get_run().modifiers.powerMult, 1.21, 0.0001)
	
	RunManager.apply_modifier({"dragReduction": 0.1})
	assert_almost_eq(RunManager.get_run().modifiers.dragReduction, 0.1, 0.0001)
	RunManager.apply_modifier({"dragReduction": 0.2})
	assert_almost_eq(RunManager.get_run().modifiers.dragReduction, 0.3, 0.0001)
	
	RunManager.apply_modifier({"dragReduction": 0.8}) # total 1.1
	assert_eq(RunManager.get_run().modifiers.dragReduction, 0.99, "should cap at 0.99")
	
	RunManager.apply_modifier({"weightMult": 0.9})
	assert_almost_eq(RunManager.get_run().modifiers.weightMult, 0.9, 0.0001)
	
	# Floor at 0.01
	RunManager.apply_modifier({"weightMult": 0.001})
	assert_eq(RunManager.get_run().modifiers.weightMult, 0.01, "should floor at 0.01")

# Godot version has complete_node_visit instead of setCurrentNode
func test_complete_node_visit() -> void:
	RunManager.start_new_run(3, 50.0, "normal", 200, 68.0, "imperial")
	var run: Dictionary = RunManager.get_run()
	var hub_id: String = run.currentNodeId
	
	# Find an edge from hub
	var edge: Dictionary = {}
	for e: Dictionary in run.edges:
		if e.from == hub_id:
			edge = e
			break
	
	assert_false(edge.is_empty(), "should find an edge from hub")
	var dest_id: String = edge.to
	
	var first_clear: bool = RunManager.complete_node_visit(edge)
	assert_true(first_clear, "first visit should return true")
	assert_eq(run.currentNodeId, dest_id, "should advance to destination")
	assert_has(run.visitedNodeIds, dest_id, "should add to visited")
	
	var second_clear: bool = RunManager.complete_node_visit(edge)
	assert_false(second_clear, "second visit should return false")

func test_get_total_system_mass_base() -> void:
	RunManager.start_new_run(3, 50.0, "normal", 200, 68.0, "imperial")
	RunManager.active_quest = {}

	# Base mass = rider (68) + bike (8.0) = 76.0
	var mass: float = RunManager.get_total_system_mass()
	assert_almost_eq(mass, 76.0, 0.01, "Base mass should be rider + 8kg bike")

func test_get_total_system_mass_with_cargo() -> void:
	RunManager.start_new_run(3, 50.0, "normal", 200, 68.0, "imperial")
	RunManager.active_quest = {
		"destination_id": "node_test",
		"destination_name": "Test Shop",
		"cargo_name": "Bulk Coffee Beans",
		"cargo_weight_kg": 5.0,
		"reward_gold": 125,
	}

	# Base mass (76.0) + cargo (5.0) = 81.0
	var mass: float = RunManager.get_total_system_mass()
	assert_almost_eq(mass, 81.0, 0.01, "Mass should include quest cargo weight")
	RunManager.active_quest = {}

func test_get_total_system_mass_with_items() -> void:
	RunManager.start_new_run(3, 50.0, "normal", 200, 68.0, "imperial")
	RunManager.active_quest = {}

	# Register a test item with actual weight
	ContentRegistry.register_item({
		"id": "heavy_test_bag",
		"label": "Heavy Test Bag",
		"slot": "Rider",
		"modifier": {},
		"weight_kg": 3.0,
	})
	RunManager.run_data["inventory"] = ["heavy_test_bag"]
	RunManager.run_data["equipped"] = {}

	# Base (76.0) + inventory item (3.0) = 79.0
	var mass: float = RunManager.get_total_system_mass()
	assert_almost_eq(mass, 79.0, 0.01, "Mass should include inventory item weight")

func test_accept_quest() -> void:
	RunManager.active_quest = {}
	watch_signals(SignalBus)

	var quest_data: Dictionary = {
		"destination_id": "node_plains_shop",
		"destination_name": "Plains Shop",
		"cargo_name": "Emergency Medical Supplies",
		"cargo_weight_kg": 1.0,
		"reward_gold": 115,
	}
	RunManager.accept_quest(quest_data)

	assert_false(RunManager.active_quest.is_empty(), "active_quest should be set after accept")
	assert_eq(RunManager.active_quest["cargo_name"], "Emergency Medical Supplies")
	assert_signal_emitted(SignalBus, "quest_updated", "should emit quest_updated")
	RunManager.active_quest = {}

func test_quest_completion_on_node_visit() -> void:
	RunManager.start_new_run(3, 50.0, "normal", 200, 68.0, "imperial")
	var run: Dictionary = RunManager.get_run()
	var hub_id: String = run.currentNodeId

	# Find an edge from hub
	var edge: Dictionary = {}
	for e: Dictionary in run.edges:
		if e.from == hub_id:
			edge = e
			break

	assert_false(edge.is_empty(), "should find an edge")
	var dest_id: String = edge.to

	# Set up an active quest targeting that destination
	RunManager.active_quest = {
		"destination_id": dest_id,
		"destination_name": "Target Node",
		"cargo_name": "Test Cargo",
		"cargo_weight_kg": 2.5,
		"reward_gold": 200,
	}

	var gold_before: int = run.gold
	watch_signals(SignalBus)

	RunManager.complete_node_visit(edge)

	# Quest should be cleared and gold awarded
	assert_true(RunManager.active_quest.is_empty(), "active_quest should be cleared on delivery")
	assert_eq(run.gold, gold_before + 25 + 200, "Should award node gold + quest reward")
	assert_signal_emitted(SignalBus, "quest_updated", "should emit quest_updated on completion")

func test_reset_clears_active_quest() -> void:
	RunManager.active_quest = {
		"destination_id": "test",
		"cargo_name": "Cargo",
		"cargo_weight_kg": 1.0,
		"destination_name": "Test",
		"reward_gold": 50,
	}
	RunManager.reset()
	assert_true(RunManager.active_quest.is_empty(), "reset should clear active_quest")

func test_is_edge_traversable() -> void:
	RunManager.start_new_run(3, 50.0, "normal", 200, 68.0, "imperial")
	var run: Dictionary = RunManager.get_run()
	
	# Find a locked edge (Spoke Gate)
	var locked_edge: Dictionary = {}
	for e: Dictionary in run.edges:
		if e.has("requiredMedal"):
			locked_edge = e
			break
	
	if not locked_edge.is_empty():
		assert_false(RunManager.is_edge_traversable(locked_edge), "should be locked without medal")
		(run.inventory as Array).append(locked_edge.requiredMedal)
		assert_true(RunManager.is_edge_traversable(locked_edge), "should be traversable with medal")

	# Final boss edge
	var final_edge: Dictionary = {}
	for e: Dictionary in run.edges:
		if e.get("requiresAllMedals", false):
			final_edge = e
			break
			
	if not final_edge.is_empty():
		assert_false(RunManager.is_edge_traversable(final_edge), "should be locked without all medals")
		# Add medals
		for i: int in range(run.runLength):
			(run.inventory as Array).append("medal_spoke_" + str(i))
		# Wait, the logic in is_edge_traversable checks begins_with("medal_")
		# and medals_needed = run_data["runLength"]
		assert_true(RunManager.is_edge_traversable(final_edge), "should be traversable with all medals")
