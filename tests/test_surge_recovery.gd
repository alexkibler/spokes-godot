extends "res://addons/gut/test.gd"

# Simulating the Surge/Recovery State Machine from GameScene.gd
# This validates that timers transition correctly and multipliers apply.

class SurgeStateMachine:
	var surge_timer: float = 0.0
	var recovery_timer: float = 0.0
	var player_draft_factor: float = 0.0
	
	const SURGE_DURATION: float = 5.0
	const SURGE_POWER_MULT: float = 1.25
	const RECOVERY_DURATION: float = 4.0
	const RECOVERY_POWER_MULT: float = 0.85
	
	func process(delta: float, base_power: float) -> float:
		# 1. State Transitions
		if surge_timer > 0:
			surge_timer -= delta
			if surge_timer <= 0:
				recovery_timer = RECOVERY_DURATION
		elif recovery_timer > 0:
			recovery_timer -= delta
		elif player_draft_factor > 0.01:
			surge_timer = SURGE_DURATION
			
		# 2. Power Application
		var effective_power = base_power
		if surge_timer > 0:
			effective_power *= SURGE_POWER_MULT
		elif recovery_timer > 0:
			effective_power *= RECOVERY_POWER_MULT
			
		return effective_power

func test_surge_recovery_cycle():
	var sm = SurgeStateMachine.new()
	var base_power = 200.0
	var delta = 1.0 # 1 second steps
	
	# Initial state: no draft, no surge
	assert_eq(sm.process(delta, base_power), 200.0, "Should be base power initially")
	
	# Enter draft
	sm.player_draft_factor = 0.05
	
	# Second 1: Surge triggers immediately upon draft detection (previous frame was > 0.01)
	# Actually, in GameScene:
	# elif player_draft_factor > 0.01: surge_timer = SURGE_DURATION
	# So it triggers on this frame's process.
	var p1 = sm.process(delta, base_power)
	assert_eq(p1, 200.0 * 1.25, "Surge should apply 1.25x multiplier")
	assert_eq(sm.surge_timer, 5.0, "Surge timer should be set to 5s")
	
	# Step through surge (5 seconds)
	sm.process(delta, base_power) # 4s remaining
	sm.process(delta, base_power) # 3s remaining
	sm.process(delta, base_power) # 2s remaining
	var p_last_surge = sm.process(delta, base_power) # 1s remaining
	assert_eq(p_last_surge, 200.0 * 1.25, "Still in surge")
	
	# The next step should deplete the surge timer to 0 and transition to recovery
	var p_transition = sm.process(delta, base_power)
	assert_eq(sm.surge_timer, 0.0, "Surge should end")
	assert_eq(sm.recovery_timer, 4.0, "Recovery timer should start")
	# In the tick it hits 0, it applies recovery multiplier
	assert_eq(p_transition, 200.0 * 0.85, "Should immediately transition to recovery multiplier")
	
	# Step through recovery
	sm.process(delta, base_power) # 3s remaining
	sm.process(delta, base_power) # 2s remaining
	var p_last_rec = sm.process(delta, base_power) # 1s remaining
	assert_eq(p_last_rec, 200.0 * 0.85, "Still in recovery")
	
	# End of recovery
	var p_end_rec = sm.process(delta, base_power) # 0s remaining
	assert_eq(sm.recovery_timer, 0.0, "Recovery should end")
	assert_eq(p_end_rec, 200.0, "Should return to base power after recovery")

func test_no_double_trigger():
	var sm = SurgeStateMachine.new()
	var base_power = 200.0
	
	sm.player_draft_factor = 0.10
	sm.process(1.0, base_power)
	
	assert_eq(sm.surge_timer, 5.0, "Started surge")
	
	# Turn draft factor off
	sm.player_draft_factor = 0.0
	sm.process(1.0, base_power)
	assert_eq(sm.surge_timer, 4.0, "Surge continues even if draft is lost")
	
	# Turn draft factor back on
	sm.player_draft_factor = 0.20
	sm.process(1.0, base_power)
	assert_eq(sm.surge_timer, 3.0, "Surge timer should NOT reset or double trigger while active")
	
	# Finish surge, enter recovery
	sm.process(3.0, base_power)
	assert_eq(sm.surge_timer, 0.0)
	assert_eq(sm.recovery_timer, 4.0)
	
	# Try to draft during recovery
	sm.player_draft_factor = 0.30
	sm.process(1.0, base_power)
	assert_eq(sm.recovery_timer, 3.0, "Recovery timer should tick down")
	assert_eq(sm.surge_timer, 0.0, "Should NOT trigger new surge while in recovery")
