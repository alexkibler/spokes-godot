extends GutTest

# Tests for the new FatigueComponent which manages the Surge/Recovery State Machine

func test_surge_recovery_cycle():
	var fc = FatigueComponent.new()
	var delta = 1.0 # 1 second steps
	
	# Initial state
	assert_eq(fc.get_state(), "normal", "Should be normal initially")
	assert_eq(fc.get_power_multiplier(), 1.0, "Multiplier should be 1.0")
	
	# Enter draft (> 0.01)
	var draft_factor = 0.05
	fc.process_fatigue(delta, draft_factor)
	
	# Should trigger surge
	assert_eq(fc.get_state(), "surge", "Should enter surge state")
	assert_eq(fc.get_power_multiplier(), 1.25, "Surge multiplier should be 1.25")
	assert_eq(fc.get_time_remaining(), 5.0, "Surge duration should start at 5s")
	
	# Step through surge (5 seconds)
	fc.process_fatigue(delta, draft_factor) # 4s remaining
	fc.process_fatigue(delta, draft_factor) # 3s remaining
	fc.process_fatigue(delta, draft_factor) # 2s remaining
	fc.process_fatigue(delta, draft_factor) # 1s remaining
	assert_eq(fc.get_state(), "surge", "Still in surge")
	
	# Next step -> Recovery
	fc.process_fatigue(delta, draft_factor) # 0s remaining -> switch
	assert_eq(fc.get_state(), "recovery", "Should switch to recovery")
	assert_eq(fc.get_power_multiplier(), 0.85, "Recovery multiplier should be 0.85")
	assert_eq(fc.get_time_remaining(), 4.0, "Recovery duration should start at 4s")
	
	# Step through recovery
	fc.process_fatigue(delta, draft_factor) # 3s remaining
	fc.process_fatigue(delta, draft_factor) # 2s remaining
	fc.process_fatigue(delta, draft_factor) # 1s remaining
	assert_eq(fc.get_state(), "recovery", "Still in recovery")
	
	# End of recovery
	fc.process_fatigue(delta, draft_factor) # 0s remaining -> normal
	assert_eq(fc.get_state(), "normal", "Should return to normal")
	assert_eq(fc.get_power_multiplier(), 1.0, "Multiplier should return to 1.0")

	fc.free()

func test_no_double_trigger():
	var fc = FatigueComponent.new()
	var delta = 1.0
	
	# Trigger surge
	fc.process_fatigue(delta, 0.10)
	assert_eq(fc.get_state(), "surge")
	
	# Lose draft
	fc.process_fatigue(delta, 0.0)
	assert_eq(fc.get_state(), "surge", "Surge continues without draft")
	assert_eq(fc.get_time_remaining(), 4.0)
	
	# Regain draft
	fc.process_fatigue(delta, 0.20)
	assert_eq(fc.get_state(), "surge")
	assert_eq(fc.get_time_remaining(), 3.0, "Timer should not reset")
	
	# Fast forward to recovery
	fc.process_fatigue(3.0, 0.20) # 0s -> recovery
	assert_eq(fc.get_state(), "recovery")
	
	# Try to draft during recovery
	fc.process_fatigue(delta, 0.30)
	assert_eq(fc.get_state(), "recovery", "Cannot surge during recovery")
	assert_eq(fc.get_time_remaining(), 3.0)

	fc.free()
