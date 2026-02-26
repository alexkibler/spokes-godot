extends "res://addons/gut/test.gd"

# Systematic testing of map generation across distances and difficulties.

func _calculate_total_ascent(run_data: Dictionary) -> float:
	var total_ascent = 0.0
	for e in run_data["edges"]:
		for s in e["profile"]["segments"]:
			if s["grade"] > 0:
				total_ascent += s["distanceM"] * s["grade"]
	return total_ascent

func test_map_generation_ranges():
	var distances = [10.0, 50.0, 200.0, 500.0, 1000.0]
	var difficulties = ["easy", "normal", "hard"]
	
	print("\n--- Map Generation Range Test ---")
	print("Target (km) | Difficulty | Spokes | Actual (km) | Edges | Ascent (ft/10mi) | Max Grade %")
	print("-----------------------------------------------------------------------------------------")
	
	for dist in distances:
		for diff in difficulties:
			var run_data = {
				"totalDistanceKm": dist,
				"difficulty": diff,
				"stats": {"totalMapDistanceM": 0.0},
				"nodes": [],
				"edges": [],
				"visitedNodeIds": [],
				"currentNodeId": ""
			}
			
			MapGenerator.generate_hub_and_spoke_map(run_data)
			
			var actual_km = run_data["stats"]["totalMapDistanceM"] / 1000.0
			var num_spokes = run_data.get("runLength", 0)
			var edges = run_data.get("edges", [])
			
			var max_grade = 0.0
			for e in edges:
				var profile = e.get("profile", {})
				for s in profile.get("segments", []):
					max_grade = max(max_grade, abs(s.get("grade", 0.0)))
			
			var total_ascent_m = _calculate_total_ascent(run_data)
			# Convert meters of ascent per meter of distance to ft per 10 miles
			# (ascent_m / dist_m) * (10 miles in meters) * (meters to feet)
			# (ascent_m / actual_km * 1000) * 16093.44 * 3.28084
			var ascent_ratio = total_ascent_m / (actual_km * 1000.0)
			var ft_per_10mi = ascent_ratio * 16093.44 * 3.28084
			
			print("%11.1f | %10s | %6d | %11.1f | %5d | %16.1f | %9.1f%%" % [
				dist, diff, num_spokes, actual_km, edges.size(), ft_per_10mi, max_grade * 100.0
			])
			
			# Requirement: Max 8 spokes always
			assert_true(num_spokes <= 8, "Should never exceed 8 spokes")
			
			# Requirement: Actual distance should match target * branches (~1.58x for hub-and-spoke)
			var expected_map_dist = dist * 1.58
			assert_almost_eq(actual_km, expected_map_dist, expected_map_dist * 0.1, "Actual map distance should be ~1.58x target (Dist: %d, Diff: %s)" % [dist, diff])
			
			# Difficulty scaling check (Elevation)
			if diff == "easy":
				assert_true(ft_per_10mi <= 550.0, "Easy should be ~500 ft/10mi (was %.1f)" % ft_per_10mi)
				assert_true(max_grade <= 0.0501, "Easy max grade should be <= 5%% (was %.1f%%)" % (max_grade * 100.0))
			elif diff == "normal":
				assert_true(ft_per_10mi >= 550.0 and ft_per_10mi <= 1100.0, "Normal should be ~750-1000 ft/10mi (was %.1f)" % ft_per_10mi)
				assert_true(max_grade <= 0.0701, "Normal max grade should be <= 7%% (was %.1f%%)" % (max_grade * 100.0))
			elif diff == "hard":
				assert_true(ft_per_10mi >= 1000.0 and ft_per_10mi <= 1700.0, "Hard should be ~1200-1500 ft/10mi (was %.1f)" % ft_per_10mi)
				assert_true(max_grade <= 0.1001, "Hard max grade should be <= 10%% (was %.1f%%)" % (max_grade * 100.0))

func test_edge_length_scaling():
	# Verify that for the same number of spokes (e.g. at the cap), edges get longer
	var run_data_200 = { "totalDistanceKm": 200.0, "stats": {"totalMapDistanceM": 0.0} }
	var run_data_1000 = { "totalDistanceKm": 1000.0, "stats": {"totalMapDistanceM": 0.0} }
	
	MapGenerator.generate_hub_and_spoke_map(run_data_200)
	var avg_edge_200 = run_data_200["stats"]["totalMapDistanceM"] / run_data_200["edges"].size()
	
	MapGenerator.generate_hub_and_spoke_map(run_data_1000)
	var avg_edge_1000 = run_data_1000["stats"]["totalMapDistanceM"] / run_data_1000["edges"].size()
	
	print("\nAvg edge length (200km): %.2fm" % avg_edge_200)
	print("Avg edge length (1000km): %.2fm" % avg_edge_1000)
	
	assert_gt(avg_edge_1000, avg_edge_200, "Edges should scale up for longer total distances")
	assert_almost_eq(run_data_1000["stats"]["totalMapDistanceM"] / 1000.0, 1000.0 * 1.58, 20.0, "Should reach ~1580km total map distance")

func test_course_profile_long_distance():
	var dist_km = 20.0 # Single edge distance
	var profile = CourseProfile.generate_course_profile(dist_km, 0.08)
	
	assert_almost_eq(profile["totalDistanceM"], dist_km * 1000.0, 1.0, "Profile distance should match")
	
	# Check segments
	var segments = profile["segments"]
	assert_gt(segments.size(), 2, "Should have multiple segments")
	
	# Verify first and last are flat
	assert_eq(segments[0]["grade"], 0.0, "First segment should be flat")
	assert_eq(segments[segments.size()-1]["grade"], 0.0, "Last segment should be flat")
	
	# Verify middle segments have varied grades if max_grade > 0
	var has_variation = false
	for i in range(1, segments.size() - 1):
		if segments[i]["grade"] != 0.0:
			has_variation = true
			break
	assert_true(has_variation, "Should have non-zero grade segments in the middle")

func test_deep_distance_summation():
	var test_sizes = [10.0, 20.0, 50.0, 100.0, 250.0, 500.0, 1000.0]
	
	print("\n--- Deep Distance Summation Consistency Test ---")
	print("Target (km) | Reported (km) | Summed (km) | Status")
	print("--------------------------------------------------")
	
	for target_dist_km in test_sizes:
		var run_data = {
			"totalDistanceKm": target_dist_km,
			"stats": {"totalMapDistanceM": 0},
			"nodes": [], "edges": [], "visitedNodeIds": [], "currentNodeId": ""
		}
		
		MapGenerator.generate_hub_and_spoke_map(run_data)
		
		var edges = run_data["edges"]
		var total_summed_m = 0.0
		
		for e in edges:
			var profile = e["profile"]
			var edge_sum_m = 0.0
			for segment in profile["segments"]:
				edge_sum_m += segment["distanceM"]
			
			# Internal consistency check: profile.totalDistanceM vs sum of segments
			assert_almost_eq(edge_sum_m, profile["totalDistanceM"], 0.01, "Edge segments must sum to profile totalDistanceM")
			total_summed_m += edge_sum_m
		
		var actual_total_km = total_summed_m / 1000.0
		var reported_total_m = run_data["stats"]["totalMapDistanceM"]
		var reported_total_km = reported_total_m / 1000.0
		
		var status = "OK" if abs(total_summed_m - reported_total_m) < 0.1 else "FAIL"
		print("%11.1f | %13.2f | %11.2f | %6s" % [target_dist_km, reported_total_km, actual_total_km, status])
		
		assert_almost_eq(total_summed_m, reported_total_m, 0.1, "Deep sum should match reported totalMapDistanceM for %d km" % target_dist_km)
