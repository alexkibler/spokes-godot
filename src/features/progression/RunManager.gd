extends Node

# Represents the RunManager.ts from the Phaser project

var run_data: Dictionary = {}
var is_active_run: bool = false
var current_slot_index: int = -1
var autoplay_enabled: bool = false
var autoplay_delay_ms: int = 2000
var active_challenge: EliteChallenge = null
var pending_overlay: String = "" # "shop", "event", or ""

func reset() -> void:
	run_data = {}
	is_active_run = false
	current_slot_index = -1
	autoplay_enabled = false
	active_challenge = null
	pending_overlay = ""

func load_run_data(data: Dictionary) -> void:
	run_data = data
	
	# Reconstruct CourseProfiles in edges
	var edges: Array = run_data.get("edges", [])
	for edge: Dictionary in edges:
		if edge.has("profile"):
			var p_val: Variant = edge["profile"]
			if typeof(p_val) == TYPE_DICTIONARY:
				edge["profile"] = CourseProfile.from_dict(p_val as Dictionary)
	
	# Reconstruct active_edge profile if exists
	var active_edge: Variant = run_data.get("active_edge")
	if active_edge != null and typeof(active_edge) == TYPE_DICTIONARY:
		var ae_dict: Dictionary = active_edge
		if ae_dict.has("profile"):
			var p_val: Variant = ae_dict["profile"]
			if typeof(p_val) == TYPE_DICTIONARY:
				ae_dict["profile"] = CourseProfile.from_dict(p_val as Dictionary)

	is_active_run = true
	SignalBus.run_started.emit()
func toggle_autoplay() -> void:
	autoplay_enabled = !autoplay_enabled
	SignalBus.autoplay_changed.emit(autoplay_enabled)

func set_autoplay_enabled(enabled: bool) -> void:
	if autoplay_enabled != enabled:
		autoplay_enabled = enabled
		SignalBus.autoplay_changed.emit(autoplay_enabled)

func start_new_run(run_length: int, total_distance_km: float, difficulty: String, ftp_w: int, weight_kg: float, units: String) -> void:
	run_data = {
		"gold": 0,
		"inventory": [],
		"equipped": {},
		"modifiers": { "powerMult": 1.0, "dragReduction": 0.0, "weightMult": 1.0, "crrMult": 1.0 },
		"modifierLog": [],
		"currentNodeId": "",
		"visitedNodeIds": [],
		"active_edge": null,
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
	
	MapGenerator.generate_hub_and_spoke_map(run_data)
	
	is_active_run = true
	_maybe_save()
	SignalBus.run_started.emit()

func is_edge_traversable(edge: Dictionary) -> bool:
	if edge.get("requiresAllMedals", false):
		var medals_held: int = 0
		var inventory: Array = run_data["inventory"]
		for item: String in inventory:
			if item.begins_with("medal_"): medals_held += 1
		var medals_needed: int = run_data["runLength"]
		return medals_held >= medals_needed
	
	if edge.has("requiredMedal"):
		var inventory: Array = run_data["inventory"]
		return edge["requiredMedal"] in inventory
		
	return true

func get_run() -> Dictionary:
	return run_data

func get_absolute_max_grade() -> float:
	var diff: String = run_data.get("difficulty", "normal")
	match diff:
		"easy": return 0.05
		"normal": return 0.07
		"hard": return 0.10
	return 0.07

func export_data() -> Dictionary:
	# Create a deep-ish copy for serialization
	var data: Dictionary = run_data.duplicate(true)
	
	# Serialize CourseProfiles in edges
	var edges: Array = data.get("edges", [])
	for edge: Dictionary in edges:
		if edge.has("profile") and edge["profile"] is CourseProfile:
			edge["profile"] = (edge["profile"] as CourseProfile).to_dict()
			
	# Serialize active_edge profile if exists
	var active_edge: Variant = data.get("active_edge")
	if active_edge != null and typeof(active_edge) == TYPE_DICTIONARY:
		var ae_dict: Dictionary = active_edge
		if ae_dict.has("profile") and ae_dict["profile"] is CourseProfile:
			ae_dict["profile"] = (ae_dict["profile"] as CourseProfile).to_dict()
			
	return data

func set_active_edge(edge: Dictionary) -> void:
	var current_id: String = run_data.get("currentNodeId", "")
	var processed_edge: Dictionary = edge.duplicate()
	
	# If we are going backwards (from 'to' to 'from'), invert the profile
	if current_id == edge["to"]:
		processed_edge["profile"] = (edge["profile"] as CourseProfile).invert_course_profile()
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
	
	var current_id: String = run_data["currentNodeId"]
	var current_node: Dictionary = {}
	var nodes: Array = run_data["nodes"]
	for n: Dictionary in nodes:
		if n["id"] == current_id:
			current_node = n
			break
	if current_node.is_empty(): return {}
	
	# Identify valid next steps (neighbors)
	var neighbors: Array[Dictionary] = []
	var edges: Array = run_data["edges"]
	for edge: Dictionary in edges:
		var target_id: String = ""
		if edge["from"] == current_id: 
			if is_edge_traversable(edge): target_id = edge["to"]
		elif edge["to"] == current_id: 
			if is_edge_traversable(edge): target_id = edge["from"]
		
		if target_id != "":
			for n: Dictionary in nodes:
				if n["id"] == target_id:
					neighbors.append(n)
					break
					
	if neighbors.is_empty(): return {}
	
	# Logic: Path toward the "Finish" node, but only if all medals are held.
	# Otherwise, path toward unvisited "Boss" nodes.
	var medals_held: int = 0
	var inventory: Array = run_data["inventory"]
	for item: String in inventory:
		if item.begins_with("medal_"): medals_held += 1
	var medals_needed: int = run_data["runLength"]
	
	var targets: Array[Dictionary] = []
	var visited: Array = run_data["visitedNodeIds"]
	for n: Dictionary in nodes:
		if n["type"] == "finish" and medals_held >= medals_needed:
			targets.append(n)
		elif n["type"] == "boss" and not n["id"] in visited:
			targets.append(n)
			
	if targets.is_empty():
		# Fallback: just pick the first unvisited neighbor or any neighbor
		for n: Dictionary in neighbors:
			if not n["id"] in visited: return n
		return neighbors[0]
		
	# Simple heuristic: Pick neighbor that reduces distance to the nearest target
	var best_neighbor: Dictionary = neighbors[0]
	var min_dist: float = 999.0
	
	for n: Dictionary in neighbors:
		for t: Dictionary in targets:
			var d: float = Vector2(n["x"], n["y"]).distance_to(Vector2(t["x"], t["y"]))
			if d < min_dist:
				min_dist = d
				best_neighbor = n
				
	return best_neighbor

func complete_active_edge() -> bool:
	var ae: Dictionary = run_data.get("active_edge", {})
	return complete_node_visit(ae)

func complete_node_visit(edge: Dictionary) -> bool:
	if edge.is_empty(): return false
	
	# Find destination node
	var dest_id: String = edge["to"]
	if edge["to"] == run_data["currentNodeId"]:
		dest_id = edge["from"]
		
	var dest_node: Dictionary = {}
	var nodes: Array = run_data["nodes"]
	for n: Dictionary in nodes:
		if n["id"] == dest_id:
			dest_node = n
			break
			
	# Award gold
	var reward_gold: int = 25
	if not dest_node.is_empty():
		if dest_node["type"] == "boss": reward_gold = 100
		elif dest_node["type"] == "finish": reward_gold = 500
	add_gold(reward_gold)
	
	# Award Medals for Bosses
	if not dest_node.is_empty() and dest_node["type"] == "boss":
		var metadata: Dictionary = dest_node.get("metadata", {})
		var spoke_id: String = metadata.get("spokeId", "unknown")
		var medal_id: String = "medal_" + spoke_id
		var inventory: Array = run_data["inventory"]
		if not medal_id in inventory:
			inventory.append(medal_id)
			print("[RUN] Awarded Medal: ", medal_id)

	# Advance current node
	run_data["currentNodeId"] = dest_id
	var visited: Array = run_data["visitedNodeIds"]
	if not dest_id in visited:
		visited.append(dest_id)
		
	if not dest_node.is_empty():
		dest_node["isUsed"] = true
		
	var is_first_clear: bool = false
	if not edge.get("isCleared", false):
		edge["isCleared"] = true
		is_first_clear = true

	# Clear active edge as the ride is now complete
	run_data["active_edge"] = null

	# Auto-save after completing a node (end of EACH ride)
	_maybe_save()

	return is_first_clear

func get_best_reward(rewards: Array[Dictionary]) -> Dictionary:
	if rewards.is_empty(): return {}
	
	var best_r: Dictionary = rewards[0]
	var max_score: float = -999.0
	
	for r: Dictionary in rewards:
		var score: float = _compute_reward_value(r)
		if score > max_score:
			max_score = score
			best_r = r
			
	return best_r

func _compute_reward_value(r: Dictionary) -> float:
	var benefit: float = _get_reward_net_benefit(r)
	
	# Penalize duplicates/downgrades
	if benefit <= 0:
		return -100.0
		
	# Score is the net benefit scaled for readability
	var score: float = benefit * 100.0
	
	# Add rarity as a tie-breaker
	var rarity: String = r.get("rarity", "common")
	match rarity:
		"common": score += 1.0
		"uncommon": score += 2.0
		"rare": score += 5.0
		
	return score

func _get_reward_net_benefit(r: Dictionary) -> float:
	var reward_id: String = r["id"]
	var is_item: bool = reward_id.begins_with("item_")
	
	if is_item:
		var item_id: String = reward_id.replace("item_", "")
		var item_def: Dictionary = ContentRegistry.get_item(item_id)
		
		# Already in inventory? Worthless for autoplay
		var inventory: Array = run_data["inventory"]
		if item_id in inventory: return -1.0
		
		var slot: String = item_def.get("slot", "none")
		var equipped: Dictionary = run_data["equipped"]
		var current_item_id: String = equipped.get(slot, "")
		
		if current_item_id != "":
			if current_item_id == item_id: return -1.0
			var current_def: Dictionary = ContentRegistry.get_item(current_item_id)
			return _compare_item_stats(item_def, current_def)
		else:
			# Empty slot, compare against baseline
			return _compare_item_stats(item_def, {})
	else:
		# Stat boost. Compare against baseline (0.0 benefit)
		return _compare_item_stats(r, {})

func _compare_item_stats(new_def: Dictionary, old_def: Dictionary) -> float:
	var benefit: float = 0.0
	var n_mod: Dictionary = new_def.get("modifier", {})
	var o_mod: Dictionary = old_def.get("modifier", {})
	
	# Power: 10x Weighting (1% = 0.1 benefit)
	benefit += (n_mod.get("powerMult", 1.0) - o_mod.get("powerMult", 1.0)) * 10.0
	# Weight: 6x Weighting (1% = 0.06 benefit)
	benefit += (o_mod.get("weightMult", 1.0) - n_mod.get("weightMult", 1.0)) * 6.0
	# Aero: 8x Weighting (1% = 0.08 benefit)
	benefit += (n_mod.get("dragReduction", 0.0) - o_mod.get("dragReduction", 0.0)) * 8.0
	
	return benefit

func add_to_inventory(item_id: String) -> void:
	var inventory: Array = run_data["inventory"]
	inventory.append(item_id)
	
	SignalBus.inventory_changed.emit()
	_maybe_save()
	if autoplay_enabled:
		var def: Dictionary = ContentRegistry.get_item(item_id)
		if def.has("slot"):
			var equipped: Dictionary = run_data["equipped"]
			var current: String = equipped.get(def["slot"], "")
			if current == "":
				equip_item(item_id)
			else:
				var current_def: Dictionary = ContentRegistry.get_item(current)
				if _compare_item_stats(def, current_def) > 0:
					equip_item(item_id)
	else:
		SignalBus.item_discovered.emit(item_id)

func equip_item(item_id: String) -> bool:
	var def: Dictionary = ContentRegistry.get_item(item_id)
	if not def.has("slot"): return false
	
	var inventory: Array = run_data["inventory"]
	var idx: int = inventory.find(item_id)
	if idx == -1: return false
	
	var slot: String = def["slot"]
	# Unequip current if any
	var equipped: Dictionary = run_data["equipped"]
	if equipped.has(slot):
		unequip_item(slot)
		# Re-fetch index as unequip might shift inventory
		idx = inventory.find(item_id)
		
	inventory.remove_at(idx)
	equipped[slot] = item_id
	
	SignalBus.inventory_changed.emit()
	_maybe_save()
	if def.has("modifier"):
		var label: String = def.get("label", item_id)
		apply_modifier(def["modifier"], label + " (equipped)")
		
	return true

func unequip_item(slot: String) -> String:
	var equipped: Dictionary = run_data["equipped"]
	var item_id: String = equipped.get(slot, "")
	if item_id == "": return ""
	
	var def: Dictionary = ContentRegistry.get_item(item_id)
	
	if def.has("modifier"):
		_reverse_modifier(def["modifier"])
		# Remove from log
		var label: String = def.get("label", item_id)
		var log_label: String = label + " (equipped)"
		var mod_log: Array = run_data["modifierLog"]
		for i: int in range(mod_log.size() - 1, -1, -1):
			if mod_log[i]["label"] == log_label:
				mod_log.remove_at(i)
				break
				
	equipped.erase(slot)
	var inventory: Array = run_data["inventory"]
	inventory.append(item_id)
	SignalBus.modifiers_changed.emit()
	SignalBus.inventory_changed.emit()
	_maybe_save()
	return item_id

func _reverse_modifier(delta: Dictionary) -> void:
	var m: Dictionary = run_data["modifiers"]
	if delta.has("powerMult"): m["powerMult"] /= delta["powerMult"]
	if delta.has("dragReduction"): m["dragReduction"] = max(0.0, m["dragReduction"] - delta["dragReduction"])
	if delta.has("weightMult"): m["weightMult"] /= delta["weightMult"]
	if delta.has("crrMult"): m["crrMult"] /= delta["crrMult"]

func apply_modifier(delta: Dictionary, label: String = "") -> void:
	if not is_active_run: return
	var m: Dictionary = run_data["modifiers"]
	if delta.has("powerMult"): m["powerMult"] *= delta["powerMult"]
	if delta.has("dragReduction"): m["dragReduction"] = min(0.99, m["dragReduction"] + delta["dragReduction"])
	if delta.has("weightMult"): m["weightMult"] = max(0.01, m["weightMult"] * delta["weightMult"])
	if delta.has("crrMult"): m["crrMult"] = max(0.01, m["crrMult"] * delta["crrMult"])
	
	if label != "":
		var log_entry: Dictionary = delta.duplicate()
		log_entry["label"] = label
		var mod_log: Array = run_data["modifierLog"]
		mod_log.append(log_entry)
		
	SignalBus.modifiers_changed.emit()
	_maybe_save()

func spend_gold(amount: int) -> bool:
	var current_gold: int = run_data["gold"]
	if current_gold >= amount:
		current_gold -= amount
		run_data["gold"] = current_gold
		SignalBus.gold_changed.emit(current_gold)
		_maybe_save()
		return true
	return false

func add_gold(amount: int) -> void:
	var current_gold: int = run_data["gold"]
	current_gold += amount
	run_data["gold"] = current_gold
	SignalBus.gold_changed.emit(current_gold)
	_maybe_save()

func _maybe_save() -> void:
	if current_slot_index != -1:
		SaveManager.save_game(current_slot_index)
