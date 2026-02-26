extends GutTest

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
	# Using the new component structure to verify power flow
	var power_comp = PowerReceiverComponent.new()
	var fatigue_comp = FatigueComponent.new()
	
	# Mock input power
	power_comp.set_power_manual(100.0)

	# Scenario: Surge Active (+25%)
	fatigue_comp.surge_timer = 5.0
	var surge_mult = fatigue_comp.get_power_multiplier()
	assert_eq(surge_mult, 1.25, "Surge multiplier should be 1.25")

	# Scenario: Run Modifier Active (+50%)
	var run_power_mult = 1.5

	var effective_power = power_comp.get_power() * surge_mult
	var net_power = effective_power * run_power_mult
	
	assert_eq(net_power, 187.5, "Net power should be raw * surge * boost")
	assert_eq(power_comp.get_power(), 100.0, "Raw power should remain unchanged")

	power_comp.free()
	fatigue_comp.free()

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

func test_power_receiver_smoothing():
	var pr = PowerReceiverComponent.new()
	pr.smoothing_factor = 0.5

	# Initial state 0
	pr._on_power_updated(100.0)
	# Lerp(0, 100, 0.5) = 50
	assert_eq(pr.get_power(), 50.0, "Should smooth initial spike")

	pr._on_power_updated(100.0)
	# Lerp(50, 100, 0.5) = 75
	assert_eq(pr.get_power(), 75.0, "Should approach target")

	pr.free()
