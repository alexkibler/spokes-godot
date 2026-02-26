extends GutTest

# Tests ported from ~/Repos/spokes/src/core/physics/__tests__/CyclistPhysics.test.ts
# Updated to use Cyclist entity where appropriate, or verify the static library is still correct.

func test_calculate_acceleration_basic() -> void:
	var stats: CyclistStats = CyclistStats.new()
	
	# it('gives negative acceleration (deceleration) when coasting at 10 m/s on flat')
	var acc: float = CyclistPhysics.calculate_acceleration(0, 10, stats)
	assert_lt(acc, 0.0, "should decelerate when coasting at 10m/s on flat")

	# it('gives positive acceleration when pedaling hard (400W) at low speed (5 m/s) on flat')
	acc = CyclistPhysics.calculate_acceleration(400, 5, stats)
	assert_gt(acc, 0.0, "should accelerate when pedaling hard at low speed")

	# it('gives positive acceleration when coasting downhill at low speed')
	var grade: float = -0.05
	acc = CyclistPhysics.calculate_acceleration(0, 2, stats, grade)
	assert_gt(acc, 0.0, "should accelerate when coasting downhill at low speed")

	# it('gives near-zero acceleration at terminal velocity on a descent')
	var v_terminal: float = 14.69
	acc = CyclistPhysics.calculate_acceleration(0, v_terminal, stats, grade)
	assert_almost_eq(acc, 0.0, 0.1, "should be near zero acceleration at terminal velocity")

	# it('gives stronger deceleration on a climb than on flat at the same speed')
	var speed: float = 8.0
	var flat: float = CyclistPhysics.calculate_acceleration(0, speed, stats)
	var climb_grade: float = 0.08
	var climb: float = CyclistPhysics.calculate_acceleration(0, speed, stats, climb_grade)
	assert_lt(climb, flat, "climb deceleration should be greater than flat")

	# it('gives greater positive acceleration downhill than on flat at the same power')
	speed = 5.0
	flat = CyclistPhysics.calculate_acceleration(200, speed, stats)
	var downhill: float = CyclistPhysics.calculate_acceleration(200, speed, stats, grade)
	assert_gt(downhill, flat, "downhill acceleration should be greater than flat at same power")

	# it('treats zero velocity without division by zero')
	acc = CyclistPhysics.calculate_acceleration(200, 0, stats)
	assert_true(is_finite(acc), "zero velocity should result in finite acceleration")

	# it('handles negative velocity inputs and returns finite results')
	acc = CyclistPhysics.calculate_acceleration(0, -1, stats)
	assert_true(is_finite(acc), "negative velocity should result in finite acceleration")

func test_calculate_acceleration_modifiers() -> void:
	var stats: CyclistStats = CyclistStats.new()
	var grade: float = 0.0
	
	# it('powerMult > 1 gives higher acceleration than no modifier')
	var no_mod: Dictionary = {"powerMult": 1.0, "dragReduction": 0.0, "weightMult": 1.0}
	var boost: Dictionary = {"powerMult": 2.0, "dragReduction": 0.0, "weightMult": 1.0}
	assert_gt(
		CyclistPhysics.calculate_acceleration(200, 5, stats, grade, boost),
		CyclistPhysics.calculate_acceleration(200, 5, stats, grade, no_mod),
		"powerMult > 1 should increase acceleration"
	)

	# it('dragReduction > 0 reduces aero losses and increases acceleration at speed')
	var slippery: Dictionary = {"powerMult": 1.0, "dragReduction": 0.5, "weightMult": 1.0}
	assert_gt(
		CyclistPhysics.calculate_acceleration(0, 10, stats, grade, slippery),
		CyclistPhysics.calculate_acceleration(0, 10, stats, grade, no_mod),
		"dragReduction > 0 should increase acceleration at speed"
	)

	# it('weightMult < 1 reduces effective mass and improves acceleration')
	var lighter: Dictionary = {"powerMult": 1.0, "dragReduction": 0.0, "weightMult": 0.5}
	assert_gt(
		CyclistPhysics.calculate_acceleration(200, 5, stats, grade, lighter),
		CyclistPhysics.calculate_acceleration(200, 5, stats, grade, no_mod),
		"weightMult < 1 should increase acceleration"
	)

	# it('powerMult of 0 is equivalent to zero power input')
	var zero_mod: Dictionary = {"powerMult": 0.0, "dragReduction": 0.0, "weightMult": 1.0}
	assert_almost_eq(
		CyclistPhysics.calculate_acceleration(300, 5, stats, grade, zero_mod),
		CyclistPhysics.calculate_acceleration(0, 5, stats, grade),
		0.00001,
		"powerMult of 0 should be same as zero power"
	)

func test_ms_to_kmh() -> void:
	assert_eq(CyclistPhysics.ms_to_kmh(0), 0.0)
	assert_almost_eq(CyclistPhysics.ms_to_kmh(10), 36.0, 0.00001)
	assert_almost_eq(CyclistPhysics.ms_to_kmh(1), 3.6, 0.00001)
	assert_almost_eq(CyclistPhysics.ms_to_kmh(100.0 / 3.6), 100.0, 0.001)
	assert_almost_eq(CyclistPhysics.ms_to_kmh(-5), -18.0, 0.00001)

func test_ms_to_mph() -> void:
	assert_eq(CyclistPhysics.ms_to_mph(0), 0.0)
	assert_almost_eq(CyclistPhysics.ms_to_mph(1), 2.23694, 0.00001)
	assert_almost_eq(CyclistPhysics.ms_to_mph(44.704), 100.0, 0.1)
	assert_almost_eq(CyclistPhysics.ms_to_mph(8.9408), 20.0, 0.1)
	assert_almost_eq(CyclistPhysics.ms_to_mph(-10), -22.3694, 0.001)
