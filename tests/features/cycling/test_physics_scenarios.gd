extends GutTest

# Systematic profiling of cyclist physics across weights, FTPs, and grades.

func find_steady_state_speed(power: float, stats: CyclistStats, grade: float = 0.0, tolerance: float = 0.001) -> float:
	# Use binary search to find v where acceleration is 0
	var v_min: float = 0.0
	var v_max: float = 40.0 # 144 km/h is a safe upper bound
	
	# Handle downhill coasting or high power where terminal velocity might be higher
	if grade < -0.05 or power > 600:
		v_max = 100.0 # 360 km/h
		
	for i in range(50): # 50 iterations for high precision
		var v_mid: float = (v_min + v_max) / 2.0
		var acc: float = CyclistPhysics.calculate_acceleration(power, v_mid, stats, grade)
		if acc > 0:
			v_min = v_mid
		else:
			v_max = v_mid
			
	return (v_min + v_max) / 2.0

func test_physics_profile_matrix() -> void:
	var weights: Array[float] = [45.0, 60.0, 75.0, 90.0, 120.0, 150.0] # kg (rider only)
	var ftps: Array[float] = [50.0, 100.0, 150.0, 200.0, 250.0, 300.0, 350.0, 400.0, 450.0, 500.0, 600.0, 700.0, 800.0, 1000.0] # Watts
	var grades: Array[float] = [-0.10, -0.05, 0.0, 0.05, 0.10, 0.15] # % grade
	
	var bike_weight: float = 8.0
	
	print("\n--- Massive Physics Profile Matrix (km/h) ---")
	print("W_rider | FTP  | Grade | Speed (km/h)")
	print("-------------------------------------")
	
	for w: float in weights:
		for ftp: float in ftps:
			var last_speed: float = 999.0
			for g: float in grades:
				var stats: CyclistStats = CyclistStats.new()
				stats.mass_kg = w + bike_weight
				
				var v_ms: float = find_steady_state_speed(ftp, stats, g)
				var v_kmh: float = v_ms * 3.6
				
				# Print every few to keep output manageable but representative
				if int(ftp) % 100 == 0 or ftp == 50.0:
					print("%7.1f | %4d | %5.1f%% | %6.2f" % [w, int(ftp), g * 100.0, v_kmh])
				
				# Sanity checks
				assert_gt(v_kmh, 0.0, "Speed should always be positive for positive power")
				assert_lt(v_kmh, 300.0, "Speed should be physically plausible")
				
				# Speed should decrease as grade increases
				if last_speed != 999.0:
					assert_lt(v_kmh, last_speed, "Speed should decrease as grade increases (W:%d FTP:%d G:%.1f%%)" % [int(w), int(ftp), g*100])
				last_speed = v_kmh

func test_weight_impact_on_climbs() -> void:
	# Heavier riders should be significantly slower on steep climbs for the same power
	var ftp: float = 300.0
	var grade: float = 0.10 # 10%
	
	var stats_light: CyclistStats = CyclistStats.new()
	stats_light.mass_kg = 60.0 + 8.0
	
	var stats_heavy: CyclistStats = CyclistStats.new()
	stats_heavy.mass_kg = 90.0 + 8.0
	
	var speed_light: float = find_steady_state_speed(ftp, stats_light, grade) * 3.6
	var speed_heavy: float = find_steady_state_speed(ftp, stats_heavy, grade) * 3.6
	
	assert_gt(speed_light, speed_heavy, "Light rider should be faster on 10% climb")
	assert_gt(speed_light - speed_heavy, 2.0, "Weight impact should be significant on 10% climb")

func test_aero_dominance_on_flats() -> void:
	# On flats, power-to-weight matters less than absolute power (and CdA, but we hold CdA constant here)
	var grade: float = 0.0
	
	# Rider A: 60kg, 200W (3.33 W/kg)
	# Rider B: 90kg, 200W (2.22 W/kg)
	var stats_a: CyclistStats = CyclistStats.new()
	stats_a.mass_kg = 60.0 + 8.0
	
	var stats_b: CyclistStats = CyclistStats.new()
	stats_b.mass_kg = 90.0 + 8.0
	
	var speed_a: float = find_steady_state_speed(200.0, stats_a, grade) * 3.6
	var speed_b: float = find_steady_state_speed(200.0, stats_b, grade) * 3.6
	
	# They should be relatively close on the flat, though rolling resistance will favor the lighter rider slightly
	assert_almost_eq(speed_a, speed_b, 2.0, "Flat speed should be similar for same power despite weight diff")
	assert_gt(speed_a, speed_b, "Lighter rider still slightly faster on flat due to Crr")

func test_coasting_terminal_velocities() -> void:
	var weights: Array[float] = [45.0, 75.0, 150.0]
	var grades: Array[float] = [-0.02, -0.05, -0.10] # -2%, -5%, -10%
	
	print("\n--- Coasting Terminal Velocities (km/h) ---")
	print("W_rider | Grade | Speed (km/h)")
	print("-------------------------------------")
	
	for w: float in weights:
		for g: float in grades:
			var stats: CyclistStats = CyclistStats.new()
			stats.mass_kg = w + 8.0
			
			var v_ms: float = find_steady_state_speed(0.0, stats, g)
			var v_kmh: float = v_ms * 3.6
			
			print("%7.1f | %5.1f%% | %6.2f" % [w, g * 100.0, v_kmh])
			
			assert_gt(v_kmh, 0.0, "Should have positive terminal velocity on descent")
			if g < -0.05:
				assert_gt(v_kmh, 40.0, "Should coast fast on steep descent")

func test_child_proportions() -> void:
	# 15kg child + 8kg standard bike (using standard bike weight since it's also not exposed)
	var rider_w: float = 15.0
	var total_mass: float = rider_w + 8.0
	
	# Using standard adult CdA (0.416) as per user instruction
	var child_stats: CyclistStats = CyclistStats.new()
	child_stats.mass_kg = total_mass
	
	var powers: Array[float] = [10.0, 25.0, 50.0, 100.0]
	var grades: Array[float] = [0.0, 0.05, 0.10]
	
	print("\n--- Child Weight Matrix (15kg Rider, Standard Adult CdA) ---")
	print("Power (W) | Grade | Speed (km/h) | W/kg")
	print("---------------------------------------")
	
	for p: float in powers:
		for g: float in grades:
			var v_ms: float = find_steady_state_speed(p, child_stats, g)
			var v_kmh: float = v_ms * 3.6
			var w_kg: float = p / rider_w
			
			print("%9.1f | %5.1f%% | %12.2f | %4.1f" % [p, g * 100.0, v_kmh, w_kg])
			
			assert_gt(v_kmh, 0.5, "Rider should move even at low power")

	# Comparison: 100W Child vs 100W Adult on 10% climb
	var grade: float = 0.10
	var adult_stats: CyclistStats = CyclistStats.new() # ~122.3kg total (default)
	
	var adult_speed: float = find_steady_state_speed(100.0, adult_stats, grade) * 3.6
	var child_speed: float = find_steady_state_speed(100.0, child_stats, grade) * 3.6
	
	print("\nComparison at 100W on 10% Climb:")
	print("Child (23kg total): %.2f km/h" % child_speed)
	print("Adult (122kg total): %.2f km/h" % adult_speed)
	
	assert_gt(child_speed, adult_speed * 3.0, "Child should be >3x faster uphill at same absolute power")
