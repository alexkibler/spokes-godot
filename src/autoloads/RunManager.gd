extends Node

# Represents the RunManager.ts from the Phaser project

signal run_started
signal run_ended
signal edge_completed
signal modifiers_changed

var run_data: Dictionary = {}
var is_active_run: bool = false

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
	
	MapGenerator.generate_hub_and_spoke_map(run_data)
	
	is_active_run = true
	run_started.emit()

func get_run() -> Dictionary:
	return run_data

func export_data() -> Dictionary:
	return run_data

func set_active_edge(edge: Dictionary) -> void:
	run_data["active_edge"] = edge

func get_active_edge() -> Dictionary:
	return run_data.get("active_edge", {})

func complete_active_edge() -> bool:
	var ae = run_data.get("active_edge")
	if not ae: return false
	
	# Find the edge in the main list
	var found_edge = null
	for e in run_data["edges"]:
		if e["from"] == ae["from"] and e["to"] == ae["to"]:
			found_edge = e
			break
			
	if found_edge:
		# Advance current node
		run_data["currentNodeId"] = found_edge["to"]
		if not found_edge["to"] in run_data["visitedNodeIds"]:
			run_data["visitedNodeIds"].append(found_edge["to"])
			
		if not found_edge["isCleared"]:
			found_edge["isCleared"] = true
			return true # First clear!
			
	return false

func spend_gold(amount: int) -> bool:
	if run_data["gold"] >= amount:
		run_data["gold"] -= amount
		return true
	return false

func add_gold(amount: int) -> void:
	run_data["gold"] += amount

func add_to_inventory(item_id: String) -> void:
	run_data["inventory"].append(item_id)

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
