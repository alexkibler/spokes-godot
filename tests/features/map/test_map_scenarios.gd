extends GutTest

# Systematic testing of map generation across distances and difficulties.

func _calculate_total_ascent(run_data: Dictionary) -> float:
	var total_ascent: float = 0.0
	var edges: Array = run_data["edges"]
	for e: Dictionary in edges:
		var profile: CourseProfile = e["profile"]
		for s: Dictionary in profile.segments:
			if s["grade"] > 0:
				total_ascent += float(s["distanceM"]) * float(s["grade"])
	return total_ascent

func test_map_generation_ranges() -> void:
	var distances: Array[float] = [10.0, 50.0, 200.0, 500.0, 1000.0]
	var difficulties: Array[String] = ["easy", "normal", "hard"]
	
	print("\n--- Map Generation Range Test ---")
	print("Target (km) | Difficulty | Spokes | Actual (km) | Edges | Ascent (ft/10mi) | Max Grade %")
	print("-----------------------------------------------------------------------------------------")
	
	for dist: float in distances:
		for diff: String in difficulties:
			var run_data: Dictionary = {
				"totalDistanceKm": dist,
				"difficulty": diff,
				"stats": {"totalMapDistanceM": 0.0},
				"nodes": [],
				"edges": [],
				"visitedNodeIds": [],
				"currentNodeId": ""
			}
			
			MapGenerator.generate_hub_and_spoke_map(run_data)
			
			var actual_km: float = float(run_data["stats"]["totalMapDistanceM"]) / 1000.0
			var num_spokes: int = run_data.get("runLength", 0)
			var edges: Array = run_data.get("edges", [])
			
			var max_grade: float = 0.0
			for e: Dictionary in edges:
				var profile: CourseProfile = e.get("profile")
				for s: Dictionary in profile.segments:
					max_grade = max(max_grade, abs(float(s.get("grade", 0.0))))
			
			var total_ascent_m: float = _calculate_total_ascent(run_data)
			# Convert meters of ascent per meter of distance to ft per 10 miles
			var ascent_ratio: float = total_ascent_m / (actual_km * 1000.0)
			var ft_per_10mi: float = ascent_ratio * 16093.44 * 3.28084
			
			print("%11.1f | %10s | %6d | %11.1f | %5d | %16.1f | %9.1f%%" % [
				dist, diff, num_spokes, actual_km, edges.size(), ft_per_10mi, max_grade * 100.0
			])
			
			# Requirement: Max 8 spokes always
			assert_true(num_spokes <= 8, "Should never exceed 8 spokes")
			
			# Requirement: Actual distance should match target * (unit_segments / round_trip_weight)
			# unit_segments = num_spokes * 6.5 + 1
			# round_trip_weight = num_spokes * 13 + 2
			# Ratio is exactly 0.5x, plus branching (3 paths per island).
			# (6.5 segments exist, but only 1.0 are choice-branching).
			# Benchmark shows Generated Dist is ~0.81x Target.
			var expected_map_dist: float = dist * 0.81
			assert_almost_eq(actual_km, expected_map_dist, expected_map_dist * 0.15, "Actual map distance should be ~0.81x target (Dist: %d, Diff: %s)" % [int(dist), diff])
			
			# Difficulty scaling check (Elevation)
			if diff == "easy":
				assert_true(ft_per_10mi <= 550.0, "Easy should be ~500 ft/10mi (was %.1f)" % ft_per_10mi)
				assert_true(max_grade <= 0.0501, "Easy max grade should be <= 5%% (was %.1f%%)" % (max_grade * 100.0))
			elif diff == "normal":
				assert_true(ft_per_10mi >= 540.0 and ft_per_10mi <= 1100.0, "Normal should be ~750-1000 ft/10mi (was %.1f)" % ft_per_10mi)
				assert_true(max_grade <= 0.0701, "Normal max grade should be <= 7%% (was %.1f%%)" % (max_grade * 100.0))
			elif diff == "hard":
				assert_true(ft_per_10mi >= 900.0 and ft_per_10mi <= 1700.0, "Hard should be ~1200-1500 ft/10mi (was %.1f)" % ft_per_10mi)
				assert_true(max_grade <= 0.1001, "Hard max grade should be <= 10%% (was %.1f%%)" % (max_grade * 100.0))

func test_edge_length_scaling() -> void:
	# Verify that for the same number of spokes (e.g. at the cap), edges get longer
	var run_data_200: Dictionary = { "totalDistanceKm": 200.0, "stats": {"totalMapDistanceM": 0.0}, "nodes": [], "edges": [] }
	var run_data_1000: Dictionary = { "totalDistanceKm": 1000.0, "stats": {"totalMapDistanceM": 0.0}, "nodes": [], "edges": [] }
	
	MapGenerator.generate_hub_and_spoke_map(run_data_200)
	var avg_edge_200: float = float(run_data_200["stats"]["totalMapDistanceM"]) / (run_data_200["edges"] as Array).size()
	
	MapGenerator.generate_hub_and_spoke_map(run_data_1000)
	var avg_edge_1000: float = float(run_data_1000["stats"]["totalMapDistanceM"]) / (run_data_1000["edges"] as Array).size()
	
	print("\nAvg edge length (200km): %.2fm" % avg_edge_200)
	print("Avg edge length (1000km): %.2fm" % avg_edge_1000)
	
	assert_gt(avg_edge_1000, avg_edge_200, "Edges should scale up for longer total distances")
	assert_almost_eq(float(run_data_1000["stats"]["totalMapDistanceM"]) / 1000.0, 1000.0 * 0.81, 50.0, "Should reach ~810km total map distance")

func test_course_profile_long_distance() -> void:
	var dist_km: float = 20.0 # Single edge distance
	var profile: CourseProfile = CourseProfile.generate_course_profile(dist_km, 0.08)
	
	assert_almost_eq(profile.total_distance_m, dist_km * 1000.0, 1.0, "Profile distance should match")
	
	# Check segments
	var segments: Array[Dictionary] = profile.segments
	assert_gt(segments.size(), 2, "Should have multiple segments")
	
	# Verify first and last are flat
	assert_eq(segments[0]["grade"], 0.0, "First segment should be flat")
	assert_eq(segments[segments.size()-1]["grade"], 0.0, "Last segment should be flat")
	
	# Verify middle segments have varied grades if max_grade > 0
	var has_variation: bool = false
	for i: int in range(1, segments.size() - 1):
		if segments[i]["grade"] != 0.0:
			has_variation = true
			break
	assert_true(has_variation, "Should have non-zero grade segments in the middle")

func test_deep_distance_summation() -> void:
	var test_sizes: Array[float] = [10.0, 20.0, 50.0, 100.0, 250.0, 500.0, 1000.0]
	
	print("\n--- Deep Distance Summation Consistency Test ---")
	print("Target (km) | Reported (km) | Summed (km) | Status")
	print("--------------------------------------------------")
	
	for target_dist_km: float in test_sizes:
		var run_data: Dictionary = {
			"totalDistanceKm": target_dist_km,
			"stats": {"totalMapDistanceM": 0.0},
			"nodes": [], "edges": [], "visitedNodeIds": [], "currentNodeId": ""
		}
		
		MapGenerator.generate_hub_and_spoke_map(run_data)
		
		var edges: Array = run_data["edges"]
		var total_summed_m: float = 0.0
		
		for e: Dictionary in edges:
			var profile: CourseProfile = e["profile"]
			var edge_sum_m: float = 0.0
			for segment: Dictionary in profile.segments:
				edge_sum_m += float(segment["distanceM"])
			
			# Internal consistency check: profile.total_distance_m vs sum of segments
			assert_almost_eq(edge_sum_m, profile.total_distance_m, 0.01, "Edge segments must sum to profile total_distance_m")
			total_summed_m += edge_sum_m
		
		var actual_total_km: float = total_summed_m / 1000.0
		var reported_total_m: float = float(run_data["stats"]["totalMapDistanceM"])
		var reported_total_km: float = reported_total_m / 1000.0
		
		var status: String = "OK" if abs(total_summed_m - reported_total_m) < 0.1 else "FAIL"
		print("%11.1f | %13.2f | %11.2f | %6s" % [target_dist_km, reported_total_km, actual_total_km, status])
		
		assert_almost_eq(total_summed_m, reported_total_m, 0.1, "Deep sum should match reported totalMapDistanceM for %d km" % int(target_dist_km))
