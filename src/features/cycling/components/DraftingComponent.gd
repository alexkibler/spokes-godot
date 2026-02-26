class_name DraftingComponent
extends Node

## DraftingComponent
## Manages aerodynamic drag reduction based on nearby cyclists.
## Calculates the draft factor (CdA reduction) based on distance to other entities.

signal draft_factor_changed(factor: float)

@export var max_check_distance: float = 25.0
@export var stats: CyclistStats

var current_draft_factor: float = 0.0

## Updates the draft factor based on a list of nearby entities.
## Each entity is expected to be a Node2D (or dictionary from ghosts) with 'distance_m' and 'stats'.
## 'my_distance_m' is the current linear distance of the owner along the track.
func update_drafting(my_distance_m: float, nearby_entities: Array[Cyclist]) -> void:
	if not stats:
		push_warning("DraftingComponent: No CyclistStats assigned!")
		return

	var best_draft: float = 0.0

	for entity: Cyclist in nearby_entities:
		var other_dist: float = entity.distance_m
		var other_stats: CyclistStats = entity.stats

		if other_stats == null:
			continue

		var gap_behind: float = other_dist - my_distance_m # They are in front
		var gap_ahead: float = my_distance_m - other_dist  # They are behind

		# Benefit from entity in front (standard draft)
		if gap_behind > 0 and gap_behind < stats.draft_max_distance_m:
			var draft: float = DraftingPhysics.get_draft_factor(stats, gap_behind)
			best_draft = max(best_draft, draft)

		# Benefit from entity behind (push effect)
		if gap_ahead > 0 and gap_ahead < stats.leading_draft_distance_m:
			var push: float = DraftingPhysics.get_leading_draft_factor(stats, gap_ahead)
			best_draft = max(best_draft, push)

	if abs(best_draft - current_draft_factor) > 0.001:
		current_draft_factor = best_draft
		draft_factor_changed.emit(current_draft_factor)

func get_draft_factor() -> float:
	return current_draft_factor
