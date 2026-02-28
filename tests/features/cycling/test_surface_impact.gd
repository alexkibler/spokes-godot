extends GutTest

func test_surface_impact_on_acceleration() -> void:
	var power: float = 200.0
	var velocity: float = 10.0 # 36 km/h
	var stats: CyclistStats = CyclistStats.create_from_weight(75.0)
	var grade: float = 0.0
	
	# 1. Baseline: Asphalt (Crr = 0.005)
	# asphalt.tres has crr = 0.005
	# Cyclist.gd logic: surface_crr_mult = current_surface.get("crr") / 0.005
	# So asphalt has crrMult = 1.0
	var modifiers_asphalt: Dictionary = {"crrMult": 1.0}
	var acc_asphalt: float = CyclistPhysics.calculate_acceleration(power, velocity, stats, grade, modifiers_asphalt)
	
	# 2. Gravel (Crr = 0.012)
	# gravel.tres has crr = 0.012
	# crrMult = 0.012 / 0.005 = 2.4
	var modifiers_gravel: Dictionary = {"crrMult": 2.4}
	var acc_gravel: float = CyclistPhysics.calculate_acceleration(power, velocity, stats, grade, modifiers_gravel)
	
	# 3. Mud (Crr = 0.025)
	# mud.tres has crr = 0.025
	# crrMult = 0.025 / 0.005 = 5.0
	var modifiers_mud: Dictionary = {"crrMult": 5.0}
	var acc_mud: float = CyclistPhysics.calculate_acceleration(power, velocity, stats, grade, modifiers_mud)
	
	print("
--- Surface Impact on Acceleration at 200W/36kmh ---")
	print("Asphalt (1.0x Crr): %.4f m/s²" % acc_asphalt)
	print("Gravel  (2.4x Crr): %.4f m/s²" % acc_gravel)
	print("Mud     (5.0x Crr): %.4f m/s²" % acc_mud)
	
	assert_gt(acc_asphalt, acc_gravel, "Acceleration on asphalt should be greater than on gravel")
	assert_gt(acc_gravel, acc_mud, "Acceleration on gravel should be greater than in mud")
	
	# Verify that terminal velocity is also affected
	var v_asphalt: float = _find_steady_state_speed(power, stats, grade, modifiers_asphalt) * 3.6
	var v_gravel: float = _find_steady_state_speed(power, stats, grade, modifiers_gravel) * 3.6
	var v_mud: float = _find_steady_state_speed(power, stats, grade, modifiers_mud) * 3.6
	
	print("
--- Terminal Velocity at 200W ---")
	print("Asphalt: %.2f km/h" % v_asphalt)
	print("Gravel:  %.2f km/h" % v_gravel)
	print("Mud:     %.2f km/h" % v_mud)
	
	assert_gt(v_asphalt, v_gravel, "Terminal velocity on asphalt should be higher than on gravel")
	assert_gt(v_gravel, v_mud, "Terminal velocity on gravel should be higher than in mud")

func _find_steady_state_speed(power: float, stats: CyclistStats, grade: float, modifiers: Dictionary) -> float:
	var v_min: float = 0.0
	var v_max: float = 60.0
	for i in range(30):
		var v_mid: float = (v_min + v_max) / 2.0
		var acc: float = CyclistPhysics.calculate_acceleration(power, v_mid, stats, grade, modifiers)
		if acc > 0:
			v_min = v_mid
		else:
			v_max = v_mid
	return (v_min + v_max) / 2.0
