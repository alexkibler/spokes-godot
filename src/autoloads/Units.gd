extends Node

## Units.gd
## Centralized unit conversion utility following Phaser implementation.

# Precise constants based on international standards
const MI_TO_KM: float = 1.609344
const KM_TO_MI: float = 1.0 / MI_TO_KM # approx 0.621371192

const LB_TO_KG: float = 0.45359237
const KG_TO_LB: float = 1.0 / LB_TO_KG # approx 2.20462262

const M_TO_KM: float = 0.001
const KM_TO_M: float = 1000.0

const M_TO_MI: float = M_TO_KM * KM_TO_MI
const MI_TO_M: float = MI_TO_KM * KM_TO_M

## Converts meters to kilometers
func m_to_km(m: float) -> float:
	return m * M_TO_KM

## Converts meters to miles
func m_to_mi(m: float) -> float:
	return m * M_TO_MI

## Converts kilograms to pounds
func kg_to_lb(kg: float) -> float:
	return kg * KG_TO_LB

## Converts pounds to kilograms
func lb_to_kg(lb: float) -> float:
	return lb * LB_TO_KG

## Converts meters per second to kilometers per hour
func ms_to_kmh(ms: float) -> float:
	return ms * 3.6

## Converts meters per second to miles per hour
func ms_to_mph(ms: float) -> float:
	return ms * 2.23694

## Formats a value for display, stripping trailing .0 for integers.
func format_fixed(val: float, decimals: int = 1) -> String:
	if is_close_to_integer(val):
		return str(int(round(val)))
	
	# Round to requested decimals manually
	var multiplier = pow(10, decimals)
	var rounded_val = round(val * multiplier) / multiplier
	
	# After rounding, it might have become an integer
	if is_close_to_integer(rounded_val):
		return str(int(round(rounded_val)))
		
	return str(rounded_val).pad_decimals(decimals)

## Checks if a number is "close enough" to an integer to be displayed as one.
func is_close_to_integer(val: float, tolerance: float = 0.0001) -> bool:
	return abs(val - round(val)) < tolerance
