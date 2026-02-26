extends GutTest

const HardwareReceiverComponent = preload("res://src/features/cycling/components/HardwareReceiverComponent.gd")
const SurgeComponent = preload("res://src/features/cycling/components/SurgeComponent.gd")

func test_cyclist_physics_power_boost() -> void:
	var stats: CyclistStats = CyclistStats.new()
	var base_power: float = 200.0
	
	# Test with no modifiers
	var no_mods: Dictionary = {"powerMult": 1.0}
	var accel_normal: float = CyclistPhysics.calculate_acceleration(base_power, 10.0, stats, 0.0, no_mods)
	
	# Test with 2x power boost
	var double_power: Dictionary = {"powerMult": 2.0}
	var accel_boosted: float = CyclistPhysics.calculate_acceleration(base_power, 10.0, stats, 0.0, double_power)
	
	# With 2x power at 10m/s (36km/h), propulsion force doubles.
	# F_prop = P/v. Normal: 200/10 = 20N. Boosted: 400/10 = 40N.
	# Net force should be significantly higher.
	assert_gt(accel_boosted, accel_normal, "Boosted power should result in higher acceleration")

func test_net_power_calculation_logic() -> void:
	# Using the new component structure to verify power flow
	var hw_comp: HardwareReceiverComponent = HardwareReceiverComponent.new()
	var surge_comp: SurgeComponent = SurgeComponent.new()
	
	# Mock input power
	hw_comp.set_power_manual(100.0)

	# Scenario: Surge Active (+25%)
	surge_comp.surge_timer = 5.0
	var surge_mult: float = surge_comp.get_power_multiplier()
	assert_eq(surge_mult, 1.25, "Surge multiplier should be 1.25")

	# Scenario: Run Modifier Active (+50%)
	var run_power_mult: float = 1.5

	var effective_power: float = hw_comp.get_power() * surge_mult
	var net_power: float = effective_power * run_power_mult
	
	assert_eq(net_power, 187.5, "Net power should be raw * surge * boost")
	assert_eq(hw_comp.get_power(), 100.0, "Raw power should remain unchanged")

	hw_comp.free()
	surge_comp.free()

func test_run_manager_modifier_stacking() -> void:
	# Reset RunManager or use a mock if possible, but RunManager is an autoload.
	# We'll just test the logic of apply_modifier.
	RunManager.start_new_run(5, 10.0, "normal", 200, 70.0, "metric")
	
	assert_eq(RunManager.run_data["modifiers"]["powerMult"], 1.0)
	
	RunManager.apply_modifier({"powerMult": 1.10}, "Boost 1")
	assert_almost_eq(RunManager.run_data["modifiers"]["powerMult"], 1.10, 0.01)
	
	RunManager.apply_modifier({"powerMult": 1.10}, "Boost 2")
	# 1.1 * 1.1 = 1.21
	assert_almost_eq(RunManager.run_data["modifiers"]["powerMult"], 1.21, 0.01)

func test_power_receiver_smoothing() -> void:
	var pr: HardwareReceiverComponent = HardwareReceiverComponent.new()
	pr.smoothing_factor = 0.5

	# Initial state 0
	pr._on_power_updated(100.0)
	# Lerp(0, 100, 0.5) = 50
	assert_eq(pr.get_power(), 50.0, "Should smooth initial spike")

	pr._on_power_updated(100.0)
	# Lerp(50, 100, 0.5) = 75
	assert_eq(pr.get_power(), 75.0, "Should approach target")

	pr.free()
