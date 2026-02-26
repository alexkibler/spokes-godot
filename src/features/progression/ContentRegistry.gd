class_name ContentRegistry

# Autoload: ContentRegistry.gd
# Manages the database of items and rewards, and handles the loot pool.
# Replaces RewardManager.gd and internal ContentRegistry.gd class usage.

const RARITY_WEIGHTS: Dictionary = {
	"common": 60,
	"uncommon": 30,
	"rare": 10,
}

static var items: Dictionary = {} # ID -> Dictionary
static var rewards: Dictionary = {} # ID -> Dictionary

static func _static_init() -> void:
	bootstrap()

static func reset() -> void:
	items.clear()
	rewards.clear()
	bootstrap()

static func register_item(def: Dictionary) -> void:
	items[def["id"]] = def

static func register_reward(def: Dictionary) -> void:
	rewards[def["id"]] = def

static func get_item(id: String) -> Dictionary:
	return items.get(id, {})

static func get_reward(id: String) -> Dictionary:
	return rewards.get(id, {})

static func get_loot_pool(count: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for r: Dictionary in rewards.values():
		if not r.has("available") or (r["available"] as Callable).call(RunManager):
			pool.append(r)
			
	var results: Array[Dictionary] = []
	var used: Dictionary = {}
	
	if pool.size() <= count:
		return pool
		
	while results.size() < count:
		var candidates: Array[Dictionary] = []
		for r: Dictionary in pool:
			if not used.has(r["id"]):
				candidates.append(r)
		
		if candidates.is_empty(): break
		
		var total_weight: float = 0.0
		for r: Dictionary in candidates:
			var rarity: String = r.get("rarity", "common")
			total_weight += RARITY_WEIGHTS.get(rarity, 10)
			
		var rand: float = randf() * total_weight
		var picked: Dictionary = candidates[candidates.size() - 1]
		
		for r: Dictionary in candidates:
			var rarity: String = r.get("rarity", "common")
			rand -= RARITY_WEIGHTS.get(rarity, 10)
			if rand <= 0:
				picked = r
				break
		
		results.append(picked)
		used[picked["id"]] = true
		
	return results

## Apply a reward by ID
static func apply_reward(reward_id: String) -> void:
	var r: Dictionary = get_reward(reward_id)
	if r.has("apply"):
		(r["apply"] as Callable).call(RunManager)

# Factory method to populate with baseline content
static func bootstrap() -> void:
	# --- Items ---
	register_item({
		"id": "aero_helmet",
		"label": "Aero Helmet",
		"slot": "helmet",
		"rarity": "uncommon",
		"modifier": {"dragReduction": 0.03},
		"description": "-3% Drag"
	})
	
	register_item({
		"id": "carbon_frame",
		"label": "Carbon Frame",
		"slot": "frame",
		"rarity": "rare",
		"modifier": {"weightMult": 0.88, "dragReduction": 0.03},
		"description": "-12% Weight, -3% Drag"
	})

	# --- Rewards (Stat Boosts) ---
	register_reward({
		"id": "stat_power_1",
		"label": "Leg Day",
		"description": "+4% Power output",
		"rarity": "common",
		"modifier": {"powerMult": 1.04},
		"apply": func(rm: Node) -> void: rm.call("apply_modifier", {"powerMult": 1.04}, "Leg Day")
	})
	
	register_reward({
		"id": "stat_aero_1",
		"label": "Slammed Stem",
		"description": "-2% Aerodynamic drag",
		"rarity": "common",
		"modifier": {"dragReduction": 0.02},
		"apply": func(rm: Node) -> void: rm.call("apply_modifier", {"dragReduction": 0.02}, "Slammed Stem")
	})
	
	register_reward({
		"id": "stat_weight_1",
		"label": "Carbon Cages",
		"description": "-3% Total system weight",
		"rarity": "common",
		"modifier": {"weightMult": 0.97},
		"apply": func(rm: Node) -> void: rm.call("apply_modifier", {"weightMult": 0.97}, "Carbon Cages")
	})

	# --- Rewards (Items) ---
	register_reward({
		"id": "item_aero_helmet",
		"label": "Aero Helmet",
		"description": "Equipable: -3% Drag",
		"rarity": "uncommon",
		"apply": func(rm: Node) -> void: rm.call("add_to_inventory", "aero_helmet")
	})
