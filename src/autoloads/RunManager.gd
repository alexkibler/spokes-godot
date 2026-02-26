extends Node

# Represents the RunManager.ts from the Phaser project

signal run_started
signal run_ended
signal edge_completed
signal modifiers_changed
signal autoplay_changed(enabled: bool)

var run_data: Dictionary = {}
var is_active_run: bool = false
var autoplay_enabled: bool = false
var autoplay_delay_ms: int = 2000

func toggle_autoplay() -> void:
	autoplay_enabled = !autoplay_enabled
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

func export_data() -> Dictionary:
	return run_data

func set_active_edge(edge: Dictionary) -> void:
	run_data["active_edge"] = edge

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
		
	if not edge.get("isCleared", false):
		edge["isCleared"] = true
		return true # First clear!
			
	return false

func get_best_reward(rewards: Array) -> Dictionary:
	if rewards.is_empty(): return {}
	
	var best_r = rewards[0]
	var max_score = -999.0
	
	var current_node_id = run_data.get("currentNodeId", "")
	var current_node = null
	for n in run_data["nodes"]:
		if n["id"] == current_node_id:
			current_node = n
			break
			
	# Identify current biome/spoke
	var current_spoke = "plains"
	if current_node:
		current_spoke = current_node.get("metadata", {}).get("spokeId", "plains")

	for r in rewards:
		var score = 0.0
		
		# Base score by rarity
		match r.get("rarity", "common"):
			"common": score += 10.0
			"uncommon": score += 25.0
			"rare": score += 50.0
			
		var id = r["id"]
		
		# Heuristics: Power is high priority early on
		if id.contains("power"):
			score += 15.0
			if run_data["visitedNodeIds"].size() < 15:
				score += 10.0
				
		# Heuristics: Weight reduction for climbing biomes
		if id.contains("weight"):
			if current_spoke == "mountain" or current_spoke == "canyon":
				score += 25.0
			else:
				score += 8.0
				
		# Heuristics: Aero for flat/fast biomes
		if id.contains("aero"):
			if current_spoke == "plains" or current_spoke == "coast":
				score += 18.0
			else:
				score += 12.0
				
		# Items are usually better than raw stat boosts
		if id.contains("item_"):
			score += 15.0
			
		if score > max_score:
			max_score = score
			best_r = r
			
	return best_r

func spend_gold(amount: int) -> bool:
	if run_data["gold"] >= amount:
		run_data["gold"] -= amount
		return true
	return false

func add_gold(amount: int) -> void:
	run_data["gold"] += amount

func add_to_inventory(item_id: String) -> void:
	run_data["inventory"].append(item_id)

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
