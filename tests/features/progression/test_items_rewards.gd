extends GutTest

# Tests for ContentRegistry (Items/Rewards) and RunManager modifier stacking.

func before_each() -> void:
	# Ensure rewards are populated
	if ContentRegistry.rewards.is_empty():
		ContentRegistry.bootstrap()
		
	RunManager.run_data = {
		"inventory": [],
		"equipped": {},
		"modifiers": { "powerMult": 1.0, "dragReduction": 0.0, "weightMult": 1.0, "crrMult": 1.0 },
		"modifierLog": [],
		"isRealTrainerRun": false
	}
	RunManager.is_active_run = true

func test_item_registration() -> void:
	var item_id: String = "test_item"
	ContentRegistry.register_item({
		"id": item_id,
		"label": "Test Item",
		"slot": "Rider",
		"modifier": {"powerMult": 1.10}
	})
	
	var item: Dictionary = ContentRegistry.get_item(item_id)
	assert_eq(item["label"], "Test Item")
	assert_eq(item["modifier"]["powerMult"], 1.10)

func test_loot_pool_basics() -> void:
	# Ensure bootstrap has run
	assert_gt(ContentRegistry.rewards.size(), 0, "Loot pool should not be empty after bootstrap")
	
	var pool: Array[Dictionary] = ContentRegistry.get_loot_pool(3)
	assert_eq(pool.size(), 3, "Should return requested number of rewards")
	
	# Check for duplicates
	var ids: Dictionary = {}
	for r: Dictionary in pool:
		assert_false(ids.has(r["id"]), "Loot pool should not contain duplicates")
		ids[r["id"]] = true

func test_apply_stat_reward() -> void:
	var initial_power: float = RunManager.run_data["modifiers"]["powerMult"]
	ContentRegistry.apply_reward("stat_power_1") # +4% Power
	
	assert_almost_eq(RunManager.run_data["modifiers"]["powerMult"], initial_power * 1.04, 0.001)
	assert_eq(RunManager.run_data["modifierLog"].size(), 1)
	assert_eq(RunManager.run_data["modifierLog"][0]["label"], "Leg Day")

func test_equip_unequip_modifiers() -> void:
	var item_id: String = "aero_helmet" # -3% Drag from bootstrap
	RunManager.add_to_inventory(item_id)
	
	assert_true(item_id in RunManager.run_data["inventory"])
	assert_eq(RunManager.run_data["modifiers"]["dragReduction"], 0.0)
	
	# Equip
	var success: bool = RunManager.equip_item(item_id)
	assert_true(success)
	assert_false(item_id in RunManager.run_data["inventory"])
	assert_eq(RunManager.run_data["equipped"]["Rider"], item_id)
	assert_almost_eq(RunManager.run_data["modifiers"]["dragReduction"], 0.03, 0.001)
	
	# Unequip
	var removed_id: String = RunManager.unequip_item("Rider")
	assert_eq(removed_id, item_id)
	assert_true(item_id in RunManager.run_data["inventory"])
	assert_eq(RunManager.run_data["modifiers"]["dragReduction"], 0.0)
	assert_false(RunManager.run_data["equipped"].has("Rider"))

func test_modifier_stacking_multiplicative() -> void:
	# Power and Weight are multiplicative
	RunManager.apply_modifier({"powerMult": 1.10}, "Boost 1")
	RunManager.apply_modifier({"powerMult": 1.10}, "Boost 2")
	
	# 1.0 * 1.1 * 1.1 = 1.21
	assert_almost_eq(RunManager.run_data["modifiers"]["powerMult"], 1.21, 0.001)
	
	RunManager.apply_modifier({"weightMult": 0.90}, "Light 1")
	RunManager.apply_modifier({"weightMult": 0.90}, "Light 2")
	
	# 1.0 * 0.9 * 0.9 = 0.81
	assert_almost_eq(RunManager.run_data["modifiers"]["weightMult"], 0.81, 0.001)

func test_modifier_stacking_additive_drag() -> void:
	# dragReduction is additive and capped at 0.99
	RunManager.apply_modifier({"dragReduction": 0.40}, "Aero 1")
	RunManager.apply_modifier({"dragReduction": 0.40}, "Aero 2")
	
	assert_almost_eq(RunManager.run_data["modifiers"]["dragReduction"], 0.80, 0.001)
	
	RunManager.apply_modifier({"dragReduction": 0.30}, "Aero 3")
	assert_almost_eq(RunManager.run_data["modifiers"]["dragReduction"], 0.99, 0.001, "Drag reduction should cap at 0.99")

func test_item_replacement_swaps_modifiers() -> void:
	# Equip Item A
	ContentRegistry.register_item({
		"id": "heavy_helmet",
		"slot": "Rider",
		"label": "Heavy Helmet",
		"modifier": {"weightMult": 1.20}
	})
	RunManager.add_to_inventory("heavy_helmet")
	RunManager.equip_item("heavy_helmet")
	
	assert_almost_eq(RunManager.run_data["modifiers"]["weightMult"], 1.20, 0.001)
	
	# Equip Item B (same slot)
	ContentRegistry.register_item({
		"id": "light_helmet",
		"slot": "Rider",
		"label": "Light Helmet",
		"modifier": {"weightMult": 0.80}
	})
	RunManager.add_to_inventory("light_helmet")
	RunManager.equip_item("light_helmet")
	
	# Should remove 1.20 and add 0.80.
	# 1.20 / 1.20 * 0.80 = 0.80
	assert_almost_eq(RunManager.run_data["modifiers"]["weightMult"], 0.80, 0.001)
	assert_true("heavy_helmet" in RunManager.run_data["inventory"], "Old item should return to inventory")
	assert_eq(RunManager.run_data["equipped"]["Rider"], "light_helmet")
