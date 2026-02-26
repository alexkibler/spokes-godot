class_name DraftingPhysics
extends Object

# Port of DraftingPhysics.ts
# Shared constants and logic for aerodynamic drafting calculations.

## Returns the CdA reduction fraction for a trailing rider at `gap_m` metres
## behind the leading rider.
static func get_draft_factor(stats: CyclistStats, gap_m: float) -> float:
	if gap_m <= 0.0 or gap_m >= stats.draft_max_distance_m:
		return 0.0
	
	var range_red: float = stats.draft_max_cda_reduction - stats.draft_min_cda_reduction
	var dist_pct: float = 1.0 - (gap_m / stats.draft_max_distance_m)
	# Use a slight curve instead of purely linear to make the drop-off feel more natural
	return stats.draft_min_cda_reduction + (range_red * pow(dist_pct, 1.5))

## Returns the CdA reduction for the rider IN FRONT (pushed from behind)
static func get_leading_draft_factor(stats: CyclistStats, gap_m: float) -> float:
	if gap_m <= 0.0 or gap_m >= stats.leading_draft_distance_m:
		return 0.0
	var dist_pct: float = 1.0 - (gap_m / stats.leading_draft_distance_m)
	return stats.leading_draft_max_reduction * dist_pct
