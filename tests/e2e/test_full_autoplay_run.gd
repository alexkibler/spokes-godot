extends GutTest

# End-to-End test: verifies that autoplay can drive a complete run from start
# to the finish node, collecting medals and rewards along the way, without
# crashing or hanging.
#
# Strategy: Scene transitions (MapScene -> GameScene -> MapScene) are skipped
# because they are not reliably testable in a headless GUT context (GameScene
# resets Engine.time_scale on every ride completion, and scene changes require
# a live SceneTree root). Instead, we drive the RunManager autoplay loop
# directly — exercising all pathfinding, medal-gating, and reward logic —
# and use `wait_until` to validate the terminal condition asynchronously.

const RUN_LENGTH: int = 2
const TOTAL_DISTANCE_KM: float = 20.0
const AUTOPLAY_TIMEOUT_SECONDS: float = 60.0
const MAX_LOOP_STEPS: int = 200  # Safety guard against infinite loops


func before_each() -> void:
	ContentRegistry.reset()
	RunManager.reset()
	_delete_all_saves()


func after_each() -> void:
	# Critical: always restore time scale so subsequent tests run at 1x.
	Engine.time_scale = 1.0
	ContentRegistry.reset()
	RunManager.reset()
	_delete_all_saves()


func test_full_game_loop_autoplay() -> void:
	Engine.time_scale = 16.0
	RunManager.set_autoplay_enabled(true)

	# Bypass the Menu UI: start a run directly with sensible defaults.
	RunManager.start_new_run(RUN_LENGTH, TOTAL_DISTANCE_KM, "normal", 200, 75.0, "metric")

	assert_true(RunManager.is_active_run, "Run should be active after start_new_run")
	assert_gt(
		(RunManager.run_data.get("nodes", []) as Array).size(),
		0,
		"Map should have been generated with at least one node"
	)
	assert_false(
		RunManager.run_data.get("currentNodeId", "") == "",
		"currentNodeId should be set after map generation"
	)

	# Launch the autoplay driver as a background coroutine.
	# It yields each iteration so wait_until can poll the condition below.
	_drive_autoplay_loop()

	# Condition: the run has reached a terminal node (finish-type or the
	# final boss node, which serves as the run's last destination).
	var done: Callable = func() -> bool:
		if not RunManager.is_active_run:
			return true
		var current_id: String = RunManager.run_data.get("currentNodeId", "")
		var nodes: Array = RunManager.run_data.get("nodes", [])
		for n: Dictionary in nodes:
			if n["id"] == current_id:
				return n["type"] == "finish" or n["id"] == "node_final_boss"
		return false

	await wait_until(done, AUTOPLAY_TIMEOUT_SECONDS)

	# --- Assertions ---

	assert_true(
		done.call(),
		"Autoplay run should reach the finish node within %.0f real-world seconds" % AUTOPLAY_TIMEOUT_SECONDS
	)

	var inventory: Array = RunManager.run_data.get("inventory", [])
	assert_true(
		inventory.size() > 0,
		"Inventory should contain at least one item (medals + any rewards) after a full run"
	)

	var medals_held: int = 0
	for item: String in inventory:
		if item.begins_with("medal_"):
			medals_held += 1
	assert_true(
		medals_held >= RUN_LENGTH,
		"Player should hold at least %d medals to have unlocked the final node (had %d)" % [RUN_LENGTH, medals_held]
	)

	var visited: Array = RunManager.run_data.get("visitedNodeIds", [])
	assert_true(visited.size() > 1, "Multiple nodes should have been visited during the run")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Drives the autoplay map-traversal loop as a coroutine.
## Each iteration picks the best next node, completes the visit (simulating
## a finished ride), then auto-grants the best reward — mirroring what
## MapScene → GameScene → RewardOverlay do at runtime.
func _drive_autoplay_loop() -> void:
	var step: int = 0

	while RunManager.is_active_run and step < MAX_LOOP_STEPS:
		step += 1

		var next_node: Dictionary = RunManager.get_next_autoplay_node()
		if next_node.is_empty():
			gut.p("[E2E] Autoplay: no next node found, stopping loop")
			break

		var current_id: String = RunManager.run_data.get("currentNodeId", "")
		var edge: Dictionary = _find_connecting_edge(current_id, next_node["id"])
		if edge.is_empty():
			gut.p("[E2E] Autoplay: no connecting edge found, stopping loop")
			break

		if not RunManager.is_edge_traversable(edge):
			gut.p("[E2E] Autoplay: edge not traversable, stopping loop")
			break

		gut.p("[E2E] Autoplay step %d: %s -> %s (%s)" % [step, current_id, next_node["id"], next_node.get("type", "?")])

		var is_first_clear: bool = RunManager.complete_node_visit(edge)

		# Simulate the RewardOverlay: on the first clear of any node, pick the
		# best available reward from the loot pool and apply it automatically.
		if is_first_clear:
			_autoplay_grant_best_reward()

		# Check terminal condition before yielding.
		var arrived_id: String = RunManager.run_data.get("currentNodeId", "")
		var nodes: Array = RunManager.run_data.get("nodes", [])
		for n: Dictionary in nodes:
			if n["id"] == arrived_id and (n["type"] == "finish" or n["id"] == "node_final_boss"):
				gut.p("[E2E] Autoplay: reached terminal node '%s', loop complete" % arrived_id)
				return

		# Yield to allow wait_until to evaluate the condition each frame.
		await get_tree().process_frame

	if step >= MAX_LOOP_STEPS:
		gut.p("[E2E] Autoplay: hit MAX_LOOP_STEPS safety limit (%d)" % MAX_LOOP_STEPS)


## Mirrors the logic in RewardOverlay._check_autoplay(): pick the highest-
## scoring reward from a random pool of 3 and apply it immediately.
func _autoplay_grant_best_reward() -> void:
	var pool: Array[Dictionary] = ContentRegistry.get_loot_pool(3)
	if pool.is_empty():
		return
	var best: Dictionary = RunManager.get_best_reward(pool)
	if best.is_empty() or not best.has("apply"):
		return
	(best["apply"] as Callable).call(RunManager)
	gut.p("[E2E] Autoplay reward granted: %s" % best.get("id", "?"))


## Returns the edge that connects `from_id` to `to_id` (undirected).
func _find_connecting_edge(from_id: String, to_id: String) -> Dictionary:
	var edges: Array = RunManager.run_data.get("edges", [])
	for e: Dictionary in edges:
		if (e["from"] == from_id and e["to"] == to_id) or \
		   (e["to"] == from_id and e["from"] == to_id):
			return e
	return {}


## Removes all save slots so tests start with a clean filesystem state.
func _delete_all_saves() -> void:
	for i: int in range(SaveManager.SLOT_COUNT):
		SaveManager.delete_save(i)
