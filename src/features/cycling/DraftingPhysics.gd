class_name DraftingPhysics
extends Object

# Port of DraftingPhysics.ts
# Shared constants and logic for aerodynamic drafting calculations.

# Reduced max reduction from 0.50 to 0.30 to prevent rubber-banding
const DRAFT_MAX_DISTANCE_M: float = 20.0 # Reduced from 30 to make the "sweet spot" tighter
const DRAFT_MAX_CDA_REDUCTION: float = 0.30 
const DRAFT_MIN_CDA_REDUCTION: float = 0.01

# The "Leading Draft" benefit (push from behind)
const LEADING_DRAFT_MAX_REDUCTION: float = 0.03
const LEADING_DRAFT_DISTANCE_M: float = 3.0

## Returns the CdA reduction fraction for a trailing rider at `gap_m` metres
## behind the leading rider.
static func get_draft_factor(gap_m: float) -> float:
	if gap_m <= 0.0 or gap_m >= DRAFT_MAX_DISTANCE_M:
		return 0.0
	
	var range_red = DRAFT_MAX_CDA_REDUCTION - DRAFT_MIN_CDA_REDUCTION
	var dist_pct = 1.0 - (gap_m / DRAFT_MAX_DISTANCE_M)
	# Use a slight curve instead of purely linear to make the drop-off feel more natural
	return DRAFT_MIN_CDA_REDUCTION + (range_red * pow(dist_pct, 1.5))

## Returns the CdA reduction for the rider IN FRONT (pushed from behind)
static func get_leading_draft_factor(gap_m: float) -> float:
	if gap_m <= 0.0 or gap_m >= LEADING_DRAFT_DISTANCE_M:
		return 0.0
	var dist_pct = 1.0 - (gap_m / LEADING_DRAFT_DISTANCE_M)
	return LEADING_DRAFT_MAX_REDUCTION * dist_pct
