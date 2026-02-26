extends "res://addons/gut/test.gd"

# Tests ported from ~/Repos/spokes/src/utils/__tests__/UnitConversions.test.ts

# ─── Distance constants ───────────────────────────────────────────────────────

func test_distance_constants():
	assert_eq(Units.MI_TO_KM, 1.609344, "MI_TO_KM is exactly 1.609344")
	assert_almost_eq(Units.KM_TO_MI, 1.0 / 1.609344, 0.0000000001, "KM_TO_MI is the reciprocal of MI_TO_KM")
	
	# round-trips 3 miles through km without losing integer status
	var miles = 3.0
	var km = miles * Units.MI_TO_KM
	var back_to_miles = km * Units.KM_TO_MI
	
	assert_true(Units.is_close_to_integer(back_to_miles), "round-trip should be close to integer")
	assert_eq(Units.format_fixed(back_to_miles), "3", "format_fixed(3.0) should be '3'")
	
	assert_almost_eq(Units.KM_TO_MI, 0.621371, 0.00001, "1 km converts to ~0.621371 miles")
	assert_almost_eq(10.0 * Units.KM_TO_MI, 6.21371, 0.0001, "10 km converts to ~6.21371 miles")
	assert_almost_eq(Units.MI_TO_KM * Units.KM_TO_MI, 1.0, 0.000000000001, "MI_TO_KM * KM_TO_MI is very close to 1")

# ─── Weight constants ─────────────────────────────────────────────────────────

func test_weight_constants():
	assert_eq(Units.LB_TO_KG, 0.45359237, "LB_TO_KG is exactly 0.45359237")
	assert_almost_eq(Units.KG_TO_LB, 1.0 / 0.45359237, 0.00000001, "KG_TO_LB is the reciprocal of LB_TO_KG")
	assert_almost_eq(Units.LB_TO_KG * Units.KG_TO_LB, 1.0, 0.000000000001, "LB_TO_KG * KG_TO_LB is very close to 1")
	assert_almost_eq(Units.LB_TO_KG, 0.4536, 0.001, "1 pound is approximately 0.4536 kg")
	assert_almost_eq(Units.KG_TO_LB, 2.20462, 0.0001, "1 kg is approximately 2.2046 pounds")
	assert_almost_eq(68.0 * Units.KG_TO_LB, 149.9, 0.1, "68 kg converts to approximately 150 lb")
	
	# round-trips 70 kg through lb and back within floating-point precision
	var lb = 70.0 * Units.KG_TO_LB
	var back_to_kg = lb * Units.LB_TO_KG
	assert_almost_eq(back_to_kg, 70.0, 0.0000000001, "round-trip 70 kg should be precise")

# ─── isCloseToInteger ─────────────────────────────────────────────────────────

func test_is_close_to_integer():
	assert_true(Units.is_close_to_integer(3.0), "returns true for an exact integer (3)")
	assert_true(Units.is_close_to_integer(0.0), "returns true for an exact integer (0)")
	assert_true(Units.is_close_to_integer(-5.0), "returns true for an exact integer (-5)")
	
	assert_true(Units.is_close_to_integer(3.00009), "returns true for a value within default tolerance (3.00009)")
	assert_true(Units.is_close_to_integer(2.99991), "returns true for a value within default tolerance (2.99991)")
	
	assert_false(Units.is_close_to_integer(3.0002), "returns false for a value outside default tolerance (3.0002)")
	assert_false(Units.is_close_to_integer(3.5), "returns false for a value outside default tolerance (3.5)")
	
	assert_true(Units.is_close_to_integer(3.05, 0.1), "respects custom tolerance (3.05, 0.1)")
	assert_false(Units.is_close_to_integer(3.05, 0.01), "respects custom tolerance (3.05, 0.01)")
	
	assert_true(Units.is_close_to_integer(3.0000000000000004), "handles floating point jitter")
	
	assert_false(Units.is_close_to_integer(0.4999), "returns false for values near 0.5")
	assert_false(Units.is_close_to_integer(1.4999), "returns false for values near 1.5")

# ─── formatFixed ─────────────────────────────────────────────────────────────

func test_format_fixed():
	assert_eq(Units.format_fixed(3.0), "3", "strips decimal for exact integers (3)")
	assert_eq(Units.format_fixed(0.0), "0", "strips decimal for exact integers (0)")
	
	assert_eq(Units.format_fixed(3.5), "3.5", "formats decimals with default 1 decimal place (3.5)")
	assert_eq(Units.format_fixed(3.7), "3.7", "formats decimals with default 1 decimal place (3.7)")
	
	assert_eq(Units.format_fixed(3.00000000004), "3", "strips trailing digits for values that round to an integer (3.00...04)")
	assert_eq(Units.format_fixed(2.99999999996), "3", "strips trailing digits for values that round to an integer (2.99...96)")
	
	# Godot's format string behavior might differ from Phaser's formatFixed for rounding.
	# Phaser: formatFixed(3.14159, 2) -> "3.14" (seems it might be floor-like or just truncation?)
	# Let's check Phaser's UnitConversions.ts implementation.
	# Godot: "%.*f" % [2, 3.14159] -> "3.14" (standard rounding)
	
	assert_eq(Units.format_fixed(3.14159, 2), "3.14", "respects a custom decimal count (2)")
	assert_eq(Units.format_fixed(3.14159, 3), "3.142", "respects a custom decimal count (3)")
	
	assert_eq(Units.format_fixed(-3.5), "-3.5", "formats negative numbers correctly (-3.5)")
	assert_eq(Units.format_fixed(-3.0), "-3", "formats negative numbers correctly (-3)")
	
	# assert_eq(Units.format_fixed(3.7, 0), "4", "works with zero decimal places (integer display)")
	# Godot's format_fixed current implementation:
	# func format_fixed(val: float, decimals: int = 1) -> String:
	# 	if is_close_to_integer(val):
	# 		return str(round(val))
	# 	return "%.*f" % [decimals, val]
	# If decimals is 0, %.*f will round to 0 decimals.
	
	assert_eq(Units.format_fixed(3.7, 0), "4", "works with zero decimal places (integer display)")
	assert_eq(Units.format_fixed(5.0000001), "5", "treats values very close to an integer as that integer")
