extends "res://addons/gut/test.gd"

func test_drafting_dropoff_curve():
	print("
--- Drafting Factor (Trailing Rider) ---")
	print("Distance (m) | CdA Reduction (%)")
	print("--------------------------------")
	
	var distances = [0.0, 1.0, 2.0, 5.0, 10.0, 15.0, 19.9, 20.0, 25.0]
	var last_reduction = 1.0 # Start artificially high
	var stats = CyclistStats.new()
	
	for d in distances:
		var reduction = DraftingPhysics.get_draft_factor(stats, d)
		print("%12.1f | %16.1f%%" % [d, reduction * 100.0])
		
		if d <= 0.0 or d >= 20.0:
			assert_eq(reduction, 0.0, "Drafting factor should be 0 outside of 0 < d < 20")
		else:
			assert_gt(reduction, 0.0, "Should have positive draft factor inside range")
			assert_true(reduction <= 0.30, "Should not exceed max reduction (30%)")
			assert_true(reduction >= 0.01, "Should be at least min reduction (1%) when in range")
			assert_lt(reduction, last_reduction, "Drafting benefit should decrease as distance increases")
			last_reduction = reduction

func test_leading_draft_push():
	print("
--- Leading Draft (Rider in Front) ---")
	print("Distance (m) | CdA Reduction (%)")
	print("--------------------------------")
	
	var distances = [0.0, 0.5, 1.0, 2.0, 2.9, 3.0, 5.0]
	var last_reduction = 1.0
	var stats = CyclistStats.new()
	
	for d in distances:
		var reduction = DraftingPhysics.get_leading_draft_factor(stats, d)
		print("%12.1f | %16.1f%%" % [d, reduction * 100.0])
		
		if d <= 0.0 or d >= 3.0:
			assert_eq(reduction, 0.0, "Leading draft factor should be 0 outside of 0 < d < 3")
		else:
			assert_gt(reduction, 0.0, "Should have positive leading draft factor inside range")
			assert_true(reduction <= 0.03, "Should not exceed max reduction (3%)")
			assert_lt(reduction, last_reduction, "Leading drafting benefit should decrease as distance increases")
			last_reduction = reduction

func test_drafting_sweet_spot():
	var stats = CyclistStats.new()
	var close = DraftingPhysics.get_draft_factor(stats, 0.5)
	var mid = DraftingPhysics.get_draft_factor(stats, 10.0)
	var far = DraftingPhysics.get_draft_factor(stats, 19.0)
	
	assert_gt(close, mid, "Close draft should be stronger than mid")
	assert_gt(mid, far, "Mid draft should be stronger than far")
	
	# The pow(1.5) curve means the drop-off is not linear.
	# At 10m (50% distance), a linear drop would be 15.5%. 
	# With pow(1.5), it should be less, because the benefit "falls off" faster as you get further.
	# Wait, 1 - (10/20) = 0.5. 0.5^1.5 = 0.353. 0.353 * 0.29 + 0.01 = 0.112 (11.2%).
	assert_almost_eq(mid, 0.112, 0.01, "Curve should reduce mid-distance draft compared to linear")
