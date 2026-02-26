extends GutTest

# Tests for DraftingPhysics and the new DraftingComponent
const DraftingComponent = preload("res://src/features/cycling/components/DraftingComponent.gd")

func test_drafting_dropoff_curve() -> void:
	print("\n--- Drafting Factor (Trailing Rider) ---")
	print("Distance (m) | CdA Reduction (%)")
	print("--------------------------------")
	
	var distances: Array[float] = [0.0, 1.0, 2.0, 5.0, 10.0, 15.0, 19.9, 20.0, 25.0]
	var last_reduction: float = 1.0 # Start artificially high
	var stats: CyclistStats = CyclistStats.new()
	
	for d: float in distances:
		var reduction: float = DraftingPhysics.get_draft_factor(stats, d)
		print("%12.1f | %16.1f%%" % [d, reduction * 100.0])
		
		if d <= 0.0 or d >= 20.0:
			assert_eq(reduction, 0.0, "Drafting factor should be 0 outside of 0 < d < 20")
		else:
			assert_gt(reduction, 0.0, "Should have positive draft factor inside range")
			assert_true(reduction <= 0.30, "Should not exceed max reduction (30%)")
			assert_true(reduction >= 0.01, "Should be at least min reduction (1%) when in range")
			assert_lt(reduction, last_reduction, "Drafting benefit should decrease as distance increases")
			last_reduction = reduction

func test_leading_draft_push() -> void:
	print("\n--- Leading Draft (Rider in Front) ---")
	print("Distance (m) | CdA Reduction (%)")
	print("--------------------------------")
	
	var distances: Array[float] = [0.0, 0.5, 1.0, 2.0, 2.9, 3.0, 5.0]
	var last_reduction: float = 1.0
	var stats: CyclistStats = CyclistStats.new()
	
	for d: float in distances:
		var reduction: float = DraftingPhysics.get_leading_draft_factor(stats, d)
		print("%12.1f | %16.1f%%" % [d, reduction * 100.0])
		
		if d <= 0.0 or d >= 3.0:
			assert_eq(reduction, 0.0, "Leading draft factor should be 0 outside of 0 < d < 3")
		else:
			assert_gt(reduction, 0.0, "Should have positive leading draft factor inside range")
			assert_true(reduction <= 0.03, "Should not exceed max reduction (3%)")
			assert_lt(reduction, last_reduction, "Leading drafting benefit should decrease as distance increases")
			last_reduction = reduction

func test_drafting_sweet_spot() -> void:
	var stats: CyclistStats = CyclistStats.new()
	var close: float = DraftingPhysics.get_draft_factor(stats, 0.5)
	var mid: float = DraftingPhysics.get_draft_factor(stats, 10.0)
	var far: float = DraftingPhysics.get_draft_factor(stats, 19.0)
	
	assert_gt(close, mid, "Close draft should be stronger than mid")
	assert_gt(mid, far, "Mid draft should be stronger than far")
	
	# The pow(1.5) curve means the drop-off is not linear.
	assert_almost_eq(mid, 0.112, 0.01, "Curve should reduce mid-distance draft compared to linear")

func test_drafting_component() -> void:
	var comp: DraftingComponent = DraftingComponent.new()
	comp.stats = CyclistStats.new()

	var my_dist: float = 100.0
	
	var ghost1: Cyclist = Cyclist.new()
	ghost1.distance_m = 102.0
	ghost1.stats = comp.stats
	
	var ghost2: Cyclist = Cyclist.new()
	ghost2.distance_m = 99.0
	ghost2.stats = comp.stats
	
	var nearby: Array[Cyclist] = [ghost1, ghost2]

	# Initial update
	comp.update_drafting(my_dist, nearby)
	var factor: float = comp.get_draft_factor()

	# Should draft from the one ahead (2m gap)
	var expected_draft: float = DraftingPhysics.get_draft_factor(comp.stats, 2.0)
	# Should get pushed by the one behind (1m gap)
	var expected_push: float = DraftingPhysics.get_leading_draft_factor(comp.stats, 1.0)

	# Component logic takes the max of any single interaction
	var expected: float = max(expected_draft, expected_push)

	assert_almost_eq(factor, expected, 0.0001, "DraftingComponent should calculate max draft benefit")

	# Test update with no ghosts
	var empty_nearby: Array[Cyclist] = []
	comp.update_drafting(my_dist, empty_nearby)
	assert_eq(comp.get_draft_factor(), 0.0, "Should be zero with no ghosts")

	ghost1.free()
	ghost2.free()
	comp.free()
