extends "res://addons/gut/test.gd"

func test_cyclist_physics_power_boost():
	var stats = CyclistStats.new()
	var base_power = 200.0
	
	# Test with no modifiers
	var no_mods = {"powerMult": 1.0}
	var accel_normal = CyclistPhysics.calculate_acceleration(base_power, 10.0, stats, 0.0, no_mods)
	
	# Test with 2x power boost
	var double_power = {"powerMult": 2.0}
	var accel_boosted = CyclistPhysics.calculate_acceleration(base_power, 10.0, stats, 0.0, double_power)
	
	# With 2x power at 10m/s (36km/h), propulsion force doubles.
	# F_prop = P/v. Normal: 200/10 = 20N. Boosted: 400/10 = 40N.
	# Net force should be significantly higher.
	assert_gt(accel_boosted, accel_normal, "Boosted power should result in higher acceleration")

func test_net_power_calculation_logic():
	# Replicating the logic from GameScene.gd
	var latest_power = 100.0
	var surge_mult = 1.25 # SURGE_POWER_MULT
	var power_mult = 1.5  # +50% stat boost
	
	var effective_power = latest_power * surge_mult
	var net_power = effective_power * power_mult
	
	assert_eq(net_power, 187.5, "Net power should be raw * surge * boost")
	assert_eq(latest_power, 100.0, "Raw power should remain unchanged for FIT recording")

func test_run_manager_modifier_stacking():
	# Reset RunManager or use a mock if possible, but RunManager is an autoload.
	# We'll just test the logic of apply_modifier.
	RunManager.start_new_run(5, 10.0, "normal", 200, 70.0, "metric")
	
	assert_eq(RunManager.run_data["modifiers"]["powerMult"], 1.0)
	
	RunManager.apply_modifier({"powerMult": 1.10}, "Boost 1")
	assert_almost_eq(RunManager.run_data["modifiers"]["powerMult"], 1.10, 0.01)
	
	RunManager.apply_modifier({"powerMult": 1.10}, "Boost 2")
	# 1.1 * 1.1 = 1.21
	assert_almost_eq(RunManager.run_data["modifiers"]["powerMult"], 1.21, 0.01)
