extends GutTest

# Tests for ContentRegistry (Items/Rewards) and RunManager modifier stacking.

var rm
var cr

func before_each():
	rm = RunManager
	cr = ContentRegistry
	
	# Ensure rewards are populated
	if cr.rewards.is_empty():
		cr.bootstrap()
		
	rm.run_data = {
		"inventory": [],
		"equipped": {},
		"modifiers": { "powerMult": 1.0, "dragReduction": 0.0, "weightMult": 1.0, "crrMult": 1.0 },
		"modifierLog": [],
		"isRealTrainerRun": false
	}
	rm.is_active_run = true

func test_item_registration():
	var item_id = "test_item"
	cr.register_item({
		"id": item_id,
		"label": "Test Item",
		"slot": "helmet",
		"modifier": {"powerMult": 1.10}
	})
	
	var item = cr.get_item(item_id)
	assert_eq(item["label"], "Test Item")
	assert_eq(item["modifier"]["powerMult"], 1.10)

func test_loot_pool_basics():
	# Ensure bootstrap has run
	assert_gt(cr.rewards.size(), 0, "Loot pool should not be empty after bootstrap")
	
	var pool = cr.get_loot_pool(3)
	assert_eq(pool.size(), 3, "Should return requested number of rewards")
	
	# Check for duplicates
	var ids = {}
	for r in pool:
		assert_false(ids.has(r["id"]), "Loot pool should not contain duplicates")
		ids[r["id"]] = true

func test_apply_stat_reward():
	var initial_power = rm.run_data["modifiers"]["powerMult"]
	cr.apply_reward("stat_power_1") # +4% Power
	
	assert_almost_eq(rm.run_data["modifiers"]["powerMult"], initial_power * 1.04, 0.001)
	assert_eq(rm.run_data["modifierLog"].size(), 1)
	assert_eq(rm.run_data["modifierLog"][0]["label"], "Leg Day")

func test_equip_unequip_modifiers():
	var item_id = "aero_helmet" # -3% Drag from bootstrap
	rm.add_to_inventory(item_id)
	
	assert_true(item_id in rm.run_data["inventory"])
	assert_eq(rm.run_data["modifiers"]["dragReduction"], 0.0)
	
	# Equip
	var success = rm.equip_item(item_id)
	assert_true(success)
	assert_false(item_id in rm.run_data["inventory"])
	assert_eq(rm.run_data["equipped"]["helmet"], item_id)
	assert_almost_eq(rm.run_data["modifiers"]["dragReduction"], 0.03, 0.001)
	
	# Unequip
	var removed_id = rm.unequip_item("helmet")
	assert_eq(removed_id, item_id)
	assert_true(item_id in rm.run_data["inventory"])
	assert_eq(rm.run_data["modifiers"]["dragReduction"], 0.0)
	assert_false(rm.run_data["equipped"].has("helmet"))

func test_modifier_stacking_multiplicative():
	# Power and Weight are multiplicative
	rm.apply_modifier({"powerMult": 1.10}, "Boost 1")
	rm.apply_modifier({"powerMult": 1.10}, "Boost 2")
	
	# 1.0 * 1.1 * 1.1 = 1.21
	assert_almost_eq(rm.run_data["modifiers"]["powerMult"], 1.21, 0.001)
	
	rm.apply_modifier({"weightMult": 0.90}, "Light 1")
	rm.apply_modifier({"weightMult": 0.90}, "Light 2")
	
	# 1.0 * 0.9 * 0.9 = 0.81
	assert_almost_eq(rm.run_data["modifiers"]["weightMult"], 0.81, 0.001)

func test_modifier_stacking_additive_drag():
	# dragReduction is additive and capped at 0.99
	rm.apply_modifier({"dragReduction": 0.40}, "Aero 1")
	rm.apply_modifier({"dragReduction": 0.40}, "Aero 2")
	
	assert_almost_eq(rm.run_data["modifiers"]["dragReduction"], 0.80, 0.001)
	
	rm.apply_modifier({"dragReduction": 0.30}, "Aero 3")
	assert_almost_eq(rm.run_data["modifiers"]["dragReduction"], 0.99, 0.001, "Drag reduction should cap at 0.99")

func test_item_replacement_swaps_modifiers():
	# Equip Item A
	cr.register_item({
		"id": "heavy_helmet",
		"slot": "helmet",
		"label": "Heavy Helmet",
		"modifier": {"weightMult": 1.20}
	})
	rm.add_to_inventory("heavy_helmet")
	rm.equip_item("heavy_helmet")
	
	assert_almost_eq(rm.run_data["modifiers"]["weightMult"], 1.20, 0.001)
	
	# Equip Item B (same slot)
	cr.register_item({
		"id": "light_helmet",
		"slot": "helmet",
		"label": "Light Helmet",
		"modifier": {"weightMult": 0.80}
	})
	rm.add_to_inventory("light_helmet")
	rm.equip_item("light_helmet")
	
	# Should remove 1.20 and add 0.80.
	# 1.20 / 1.20 * 0.80 = 0.80
	assert_almost_eq(rm.run_data["modifiers"]["weightMult"], 0.80, 0.001)
	assert_true("heavy_helmet" in rm.run_data["inventory"], "Old item should return to inventory")
	assert_eq(rm.run_data["equipped"]["helmet"], "light_helmet")
