class_name DraftingPhysics
extends Object

# Port of DraftingPhysics.ts
# Shared constants and logic for aerodynamic drafting calculations.

const DRAFT_MAX_DISTANCE_M: float = 30.0
const DRAFT_MAX_CDA_REDUCTION: float = 0.50
const DRAFT_MIN_CDA_REDUCTION: float = 0.01

## Returns the CdA reduction fraction for a trailing rider at `gap_m` metres
## behind the leading rider.
static func get_draft_factor(gap_m: float) -> float:
    if gap_m <= 0.0 or gap_m >= DRAFT_MAX_DISTANCE_M:
        return 0.0
    
    return DRAFT_MIN_CDA_REDUCTION + (DRAFT_MAX_CDA_REDUCTION - DRAFT_MIN_CDA_REDUCTION) * (1.0 - gap_m / DRAFT_MAX_DISTANCE_M)
