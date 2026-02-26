extends GutTest

const SurgeComponent = preload("res://src/features/cycling/components/SurgeComponent.gd")

# Tests for the new SurgeComponent which manages the Surge/Recovery State Machine

func test_surge_recovery_cycle() -> void:
	var sc: SurgeComponent = SurgeComponent.new()
	var delta: float = 1.0 # 1 second steps
	
	# Initial state
	assert_eq(sc.get_state(), "normal", "Should be normal initially")
	assert_eq(sc.get_power_multiplier(), 1.0, "Multiplier should be 1.0")
	
	# Enter draft (> 0.01)
	var draft_factor: float = 0.05
	sc.process_surge(delta, draft_factor)
	
	# Should trigger surge
	assert_eq(sc.get_state(), "surge", "Should enter surge state")
	assert_eq(sc.get_power_multiplier(), 1.25, "Surge multiplier should be 1.25")
	assert_eq(sc.get_time_remaining(), 5.0, "Surge duration should start at 5s")
	
	# Step through surge (5 seconds)
	sc.process_surge(delta, draft_factor) # 4s remaining
	sc.process_surge(delta, draft_factor) # 3s remaining
	sc.process_surge(delta, draft_factor) # 2s remaining
	sc.process_surge(delta, draft_factor) # 1s remaining
	assert_eq(sc.get_state(), "surge", "Still in surge")
	
	# Next step -> Recovery
	sc.process_surge(delta, draft_factor) # 0s remaining -> switch
	assert_eq(sc.get_state(), "recovery", "Should switch to recovery")
	assert_eq(sc.get_power_multiplier(), 0.85, "Recovery multiplier should be 0.85")
	assert_eq(sc.get_time_remaining(), 4.0, "Recovery duration should start at 4s")
	
	# Step through recovery
	sc.process_surge(delta, draft_factor) # 3s remaining
	sc.process_surge(delta, draft_factor) # 2s remaining
	sc.process_surge(delta, draft_factor) # 1s remaining
	assert_eq(sc.get_state(), "recovery", "Still in recovery")
	
	# End of recovery
	sc.process_surge(delta, draft_factor) # 0s remaining -> normal
	assert_eq(sc.get_state(), "normal", "Should return to normal")
	assert_eq(sc.get_power_multiplier(), 1.0, "Multiplier should return to 1.0")

	sc.free()

func test_no_double_trigger() -> void:
	var sc: SurgeComponent = SurgeComponent.new()
	var delta: float = 1.0
	
	# Trigger surge
	sc.process_surge(delta, 0.10)
	assert_eq(sc.get_state(), "surge")
	
	# Lose draft
	sc.process_surge(delta, 0.0)
	assert_eq(sc.get_state(), "surge", "Surge continues without draft")
	assert_eq(sc.get_time_remaining(), 4.0)
	
	# Regain draft
	sc.process_surge(delta, 0.20)
	assert_eq(sc.get_state(), "surge")
	assert_eq(sc.get_time_remaining(), 3.0, "Timer should not reset")
	
	# Fast forward to recovery
	sc.process_surge(3.0, 0.20) # 0s -> recovery
	assert_eq(sc.get_state(), "recovery")
	
	# Try to draft during recovery
	sc.process_surge(delta, 0.30)
	assert_eq(sc.get_state(), "recovery", "Cannot surge during recovery")
	assert_eq(sc.get_time_remaining(), 3.0)

	sc.free()
