class_name CyclistStats
extends Resource

## CyclistStats
## Defines physical properties and constants for a cyclist simulation.
## Replaces hardcoded values in CyclistPhysics and DraftingPhysics.

@export_group("Physics")
@export var mass_kg: float = 122.3 ## Combined rider + bike mass
@export var cda: float = 0.416 ## Drag coefficient * Area
@export var crr: float = 0.0041 ## Coefficient of Rolling Resistance
@export var rho_air: float = 1.225 ## Air density

@export_group("Drafting - Trailing")
@export var draft_max_distance_m: float = 20.0 ## Max distance to receive draft benefit
@export var draft_max_cda_reduction: float = 0.30 ## Max CdA reduction (right behind)
@export var draft_min_cda_reduction: float = 0.01 ## Min CdA reduction (at max distance)

@export_group("Drafting - Leading")
@export var leading_draft_max_reduction: float = 0.03 ## Max CdA reduction for leader (pushed)
@export var leading_draft_distance_m: float = 3.0 ## Max distance for leader benefit

## Static factory to create stats based on rider weight using established formulas.
static func create_from_weight(rider_weight_kg: float, bike_weight_kg: float = 8.0) -> CyclistStats:
	var stats: CyclistStats = CyclistStats.new()
	stats.mass_kg = rider_weight_kg + bike_weight_kg
	# Standard CdA formula from Phaser port
	stats.cda = 0.416 * pow(rider_weight_kg / 114.3, 0.66)
	stats.crr = 0.0041
	return stats
