extends GutTest

# Benchmark for Autoplay Efficiency across a wide range of distances.
# Tests from 10km to 1000km in 5km increments.

func test_autoplay_efficiency_benchmark() -> void:
	var results: Array[Dictionary] = []
	
	gut.p("Starting Autoplay Efficiency Benchmark (10km - 1000km)...")
	
	for dist_km in range(10, 1005, 5):
		RunManager.reset()
		ContentRegistry.reset()
		
		# 1. Generate Map
		RunManager.start_new_run(1, float(dist_km), "normal", 200, 75.0, "metric")
		var run: Dictionary = RunManager.get_run()
		var num_spokes: int = run["runLength"]
		var map_total_m: float = run["stats"]["totalMapDistanceM"]
		
		# 2. Simulate Full Autoplay
		var ridden_m: float = 0.0
		var steps: int = 0
		var max_steps: int = 2000 # Higher safety for long runs
		
		while RunManager.is_active_run and steps < max_steps:
			steps += 1
			var current_id: String = RunManager.run_data["currentNodeId"]
			var next_node: Dictionary = RunManager.get_next_autoplay_node()
			
			if next_node.is_empty() or next_node["id"] == current_id:
				break
				
			var edge: Dictionary = _find_edge(current_id, next_node["id"])
			if edge.is_empty(): break
			
			ridden_m += (edge["profile"] as CourseProfile).total_distance_m
			RunManager.complete_node_visit(edge)
			
			if next_node["id"] == "node_final_boss":
				break
		
		var ratio: float = ridden_m / map_total_m if map_total_m > 0 else 0.0
		results.append({
			"target_km": dist_km,
			"spokes": num_spokes,
			"ridden_km": ridden_m / 1000.0,
			"map_km": map_total_m / 1000.0,
			"ratio": ratio,
			"steps": steps
		})
		
		if dist_km % 100 == 0:
			gut.p("  Processed %d km..." % dist_km)

	# 3. Output results summary for the user
	gut.p("
--- BENCHMARK SUMMARY ---")
	gut.p("Target | Spokes | Map Dist | Ridden Dist | Ratio | Steps")
	gut.p("-------|--------|----------|-------------|-------|------")
	for r in results:
		# Sample every 50km for the console log to avoid flooding, but tests check all
		if r["target_km"] % 50 == 0 or r["target_km"] == 10:
			gut.p("%dkm | %d | %.1fkm | %.1fkm | %.2fx | %d" % [
				r["target_km"], r["spokes"], r["map_km"], r["ridden_km"], r["ratio"], r["steps"]
			])

	# 4. Final Verification
	for r in results:
		assert_gt(r["ratio"], 1.0, "Ridden distance must always exceed map distance due to backtracking")
		assert_lt(r["ratio"], 1.8, "Ratio should remain efficient (below 1.8x) with the new algorithm")

func _find_edge(from_id: String, to_id: String) -> Dictionary:
	for e in RunManager.run_data["edges"]:
		if (e["from"] == from_id and e["to"] == to_id) or (e["to"] == from_id and e["from"] == to_id):
			return e
	return {}
