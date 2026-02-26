extends Node

# Represents the RunManager.ts from the Phaser project

signal run_started
# signal run_ended
# signal edge_completed
signal modifiers_changed
signal autoplay_changed(enabled: bool)
signal item_discovered(item_id: String)

var run_data: Dictionary = {}
var is_active_run: bool = false
var autoplay_enabled: bool = false
var autoplay_delay_ms: int = 2000
var active_challenge: Dictionary = {}
var pending_overlay: String = "" # "shop", "event", or ""

func toggle_autoplay() -> void:
	autoplay_enabled = !autoplay_enabled
	autoplay_changed.emit(autoplay_enabled)

func set_autoplay_enabled(enabled: bool) -> void:
	if autoplay_enabled != enabled:
		autoplay_enabled = enabled
		autoplay_changed.emit(autoplay_enabled)

func start_new_run(run_length: int, total_distance_km: float, difficulty: String, ftp_w: int, weight_kg: float, units: String) -> void:
	run_data = {
		"gold": 0,
		"inventory": [],
		"equipped": {},
		"modifiers": { "powerMult": 1.0, "dragReduction": 0.0, "weightMult": 1.0, "crrMult": 1.0 },
		"modifierLog": [],
		"currentNodeId": "",
		"visitedNodeIds": [],
		"activeEdge": null,
		"pendingNodeAction": null,
		"nodes": [],
		"edges": [],
		"runLength": run_length,
		"totalDistanceKm": total_distance_km,
		"difficulty": difficulty,
		"ftpW": ftp_w,
		"weightKg": weight_kg,
		"units": units,
		"isRealTrainerRun": false,
		"stats": {
			"totalMapDistanceM": 0,
			"totalRiddenDistanceM": 0,
			"totalRecordCount": 0,
			"totalPowerSum": 0,
			"totalCadenceSum": 0
		}
	}
	
	preload("res://src/core/MapGenerator.gd").generate_hub_and_spoke_map(run_data)
	
	is_active_run = true
	run_started.emit()

func is_edge_traversable(edge: Dictionary) -> bool:
	if edge.get("requiresAllMedals", false):
		var medals_held = 0
		for item in run_data["inventory"]:
			if item.begins_with("medal_"): medals_held += 1
		var medals_needed = run_data["runLength"]
		return medals_held >= medals_needed
	
	if edge.has("requiredMedal"):
		return edge["requiredMedal"] in run_data["inventory"]
		
	return true

func get_run() -> Dictionary:
	return run_data

func get_absolute_max_grade() -> float:
	var diff = run_data.get("difficulty", "normal")
	match diff:
		"easy": return 0.05
		"normal": return 0.07
		"hard": return 0.10
	return 0.07

func export_data() -> Dictionary:
	return run_data

func set_active_edge(edge: Dictionary) -> void:
	var current_id = run_data.get("currentNodeId", "")
	var processed_edge = edge.duplicate()
	
	# Identify actual start and end node IDs for direction determination
	var from_id = edge["from"]
	var to_id = edge["to"]
	
	# If we are going backwards (from 'to' to 'from'), invert the profile
	if current_id == edge["to"]:
		processed_edge["profile"] = CourseProfile.invert_course_profile(edge["profile"])
		processed_edge["direction"] = "backward"
		processed_edge["actual_from"] = edge["to"]
		processed_edge["actual_to"] = edge["from"]
	else:
		processed_edge["direction"] = "forward"
		processed_edge["actual_from"] = edge["from"]
		processed_edge["actual_to"] = edge["to"]
		
	run_data["active_edge"] = processed_edge

func get_active_edge() -> Dictionary:
	return run_data.get("active_edge", {})

func get_next_autoplay_node() -> Dictionary:
	if not is_active_run or run_data.get("currentNodeId", "") == "": return {}
	
	var current_id = run_data["currentNodeId"]
	var current_node = null
	for n in run_data["nodes"]:
		if n["id"] == current_id:
			current_node = n
			break
	if not current_node: return {}
	
	# Identify valid next steps (neighbors)
	var neighbors = []
	for edge in run_data["edges"]:
		var target_id = ""
		if edge["from"] == current_id: 
			if is_edge_traversable(edge): target_id = edge["to"]
		elif edge["to"] == current_id: 
			if is_edge_traversable(edge): target_id = edge["from"]
		
		if target_id != "":
			for n in run_data["nodes"]:
				if n["id"] == target_id:
					neighbors.append(n)
					break
					
	if neighbors.is_empty(): return {}
	
	# Logic: Path toward the "Finish" node, but only if all medals are held.
	# Otherwise, path toward unvisited "Boss" nodes.
	var medals_held = 0
	for item in run_data["inventory"]:
		if item.begins_with("medal_"): medals_held += 1
	var medals_needed = run_data["runLength"]
	
	var targets = []
	for n in run_data["nodes"]:
		if n["type"] == "finish" and medals_held >= medals_needed:
			targets.append(n)
		elif n["type"] == "boss" and not n["id"] in run_data["visitedNodeIds"]:
			targets.append(n)
			
	if targets.is_empty():
		# Fallback: just pick the first unvisited neighbor or any neighbor
		for n in neighbors:
			if not n["id"] in run_data["visitedNodeIds"]: return n
		return neighbors[0]
		
	# Simple heuristic: Pick neighbor that reduces distance to the nearest target
	var best_neighbor = neighbors[0]
	var min_dist = 999.0
	
	for n in neighbors:
		for t in targets:
			var d = Vector2(n["x"], n["y"]).distance_to(Vector2(t["x"], t["y"]))
			if d < min_dist:
				min_dist = d
				best_neighbor = n
				
	return best_neighbor

func complete_active_edge() -> bool:
	var ae = run_data.get("active_edge")
	return complete_node_visit(ae)

func complete_node_visit(edge: Dictionary) -> bool:
	if not edge: return false
	
	# Find destination node
	var dest_id = edge["to"]
	if edge["to"] == run_data["currentNodeId"]:
		dest_id = edge["from"]
		
	var dest_node = null
	for n in run_data["nodes"]:
		if n["id"] == dest_id:
			dest_node = n
			break
			
	# Award gold
	var reward_gold = 25
	if dest_node:
		if dest_node["type"] == "boss": reward_gold = 100
		elif dest_node["type"] == "finish": reward_gold = 500
	add_gold(reward_gold)
	
	# Award Medals for Bosses
	if dest_node and dest_node["type"] == "boss":
		var spoke_id = dest_node.get("metadata", {}).get("spokeId", "unknown")
		var medal_id = "medal_" + spoke_id
		if not medal_id in run_data["inventory"]:
			run_data["inventory"].append(medal_id)
			print("[RUN] Awarded Medal: ", medal_id)

	# Advance current node
	run_data["currentNodeId"] = dest_id
	if not dest_id in run_data["visitedNodeIds"]:
		run_data["visitedNodeIds"].append(dest_id)
		
	if dest_node:
		dest_node["isUsed"] = true
		
	if not edge.get("isCleared", false):
		edge["isCleared"] = true
		return true # First clear!
			
	return false

func get_best_reward(rewards: Array) -> Dictionary:
	if rewards.is_empty(): return {}
	
	var best_r = rewards[0]
	var max_score = -999.0
	
	for r in rewards:
		var score = _compute_reward_value(r)
		if score > max_score:
			max_score = score
			best_r = r
			
	return best_r

func _compute_reward_value(r: Dictionary) -> float:
	var benefit = _get_reward_net_benefit(r)
	
	# Penalize duplicates/downgrades
	if benefit <= 0:
		return -100.0
		
	# Score is the net benefit scaled for readability
	var score = benefit * 100.0 
	
	# Add rarity as a tie-breaker
	match r.get("rarity", "common"):
		"common": score += 1.0
		"uncommon": score += 2.0
		"rare": score += 5.0
		
	return score

func _get_reward_net_benefit(r: Dictionary) -> float:
	var reward_id = r["id"]
	var is_item = reward_id.begins_with("item_")
	
	if is_item:
		var item_id = reward_id.replace("item_", "")
		var item_def = ContentRegistry.get_item(item_id)
		
		# Already in inventory? Worthless for autoplay
		if item_id in run_data["inventory"]: return -1.0
		
		var slot = item_def.get("slot", "none")
		var current_item_id = run_data["equipped"].get(slot, "")
		
		if current_item_id != "":
			if current_item_id == item_id: return -1.0
			var current_def = ContentRegistry.get_item(current_item_id)
			return _compare_item_stats(item_def, current_def)
		else:
			# Empty slot, compare against baseline
			return _compare_item_stats(item_def, {})
	else:
		# Stat boost. Compare against baseline (0.0 benefit)
		return _compare_item_stats(r, {})

func _compare_item_stats(new_def: Dictionary, old_def: Dictionary) -> float:
	var benefit = 0.0
	var n_mod = new_def.get("modifier", {})
	var o_mod = old_def.get("modifier", {})
	
	# Power: 10x Weighting (1% = 0.1 benefit)
	benefit += (n_mod.get("powerMult", 1.0) - o_mod.get("powerMult", 1.0)) * 10.0
	# Weight: 6x Weighting (1% = 0.06 benefit)
	benefit += (o_mod.get("weightMult", 1.0) - n_mod.get("weightMult", 1.0)) * 6.0
	# Aero: 8x Weighting (1% = 0.08 benefit)
	benefit += (n_mod.get("dragReduction", 0.0) - o_mod.get("dragReduction", 0.0)) * 8.0
	
	return benefit

func add_to_inventory(item_id: String) -> void:
	run_data["inventory"].append(item_id)
	
	if autoplay_enabled:
		var def = ContentRegistry.get_item(item_id)
		if def.has("slot"):
			var current = run_data["equipped"].get(def["slot"], "")
			if current == "":
				equip_item(item_id)
			else:
				var current_def = ContentRegistry.get_item(current)
				if _compare_item_stats(def, current_def) > 0:
					equip_item(item_id)
	else:
		item_discovered.emit(item_id)

func equip_item(item_id: String) -> bool:
	var def = ContentRegistry.get_item(item_id)
	if not def.has("slot"): return false
	
	var idx = run_data["inventory"].find(item_id)
	if idx == -1: return false
	
	var slot = def["slot"]
	# Unequip current if any
	if run_data["equipped"].has(slot):
		unequip_item(slot)
		# Re-fetch index as unequip might shift inventory
		idx = run_data["inventory"].find(item_id)
		
	run_data["inventory"].remove_at(idx)
	run_data["equipped"][slot] = item_id
	
	if def.has("modifier"):
		apply_modifier(def["modifier"], def["label"] + " (equipped)")
		
	return true

func unequip_item(slot: String) -> String:
	var item_id = run_data["equipped"].get(slot, "")
	if item_id == "": return ""
	
	var def = ContentRegistry.get_item(item_id)
	
	if def.has("modifier"):
		_reverse_modifier(def["modifier"])
		# Remove from log
		var log_label = def["label"] + " (equipped)"
		for i in range(run_data["modifierLog"].size() - 1, -1, -1):
			if run_data["modifierLog"][i]["label"] == log_label:
				run_data["modifierLog"].remove_at(i)
				break
				
	run_data["equipped"].erase(slot)
	run_data["inventory"].append(item_id)
	modifiers_changed.emit()
	return item_id

func _reverse_modifier(delta: Dictionary) -> void:
	var m = run_data["modifiers"]
	if delta.has("powerMult"): m["powerMult"] /= delta["powerMult"]
	if delta.has("dragReduction"): m["dragReduction"] = max(0.0, m["dragReduction"] - delta["dragReduction"])
	if delta.has("weightMult"): m["weightMult"] /= delta["weightMult"]
	if delta.has("crrMult"): m["crrMult"] /= delta["crrMult"]

func apply_modifier(delta: Dictionary, label: String = "") -> void:
	if not is_active_run: return
	var m = run_data["modifiers"]
	if delta.has("powerMult"): m["powerMult"] *= delta["powerMult"]
	if delta.has("dragReduction"): m["dragReduction"] = min(0.99, m["dragReduction"] + delta["dragReduction"])
	if delta.has("weightMult"): m["weightMult"] = max(0.01, m["weightMult"] * delta["weightMult"])
	if delta.has("crrMult"): m["crrMult"] = max(0.01, m["crrMult"] * delta["crrMult"])
	
	if label != "":
		var log_entry = delta.duplicate()
		log_entry["label"] = label
		run_data["modifierLog"].append(log_entry)
		
	modifiers_changed.emit()

func spend_gold(amount: int) -> bool:
	if run_data["gold"] >= amount:
		run_data["gold"] -= amount
		return true
	return false

func add_gold(amount: int) -> void:
	run_data["gold"] += amount
