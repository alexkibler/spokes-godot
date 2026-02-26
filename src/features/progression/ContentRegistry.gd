extends Node

# Autoload: ContentRegistry.gd
# Manages the database of items and rewards, and handles the loot pool.
# Replaces RewardManager.gd and internal ContentRegistry.gd class usage.

const RARITY_WEIGHTS = {
	"common": 60,
	"uncommon": 30,
	"rare": 10,
}

var items: Dictionary = {} # ID -> Dictionary
var rewards: Dictionary = {} # ID -> Dictionary

func _ready() -> void:
	bootstrap()

func register_item(def: Dictionary) -> void:
	items[def["id"]] = def

func register_reward(def: Dictionary) -> void:
	rewards[def["id"]] = def

func get_item(id: String) -> Dictionary:
	return items.get(id, {})

func get_reward(id: String) -> Dictionary:
	return rewards.get(id, {})

func get_loot_pool(count: int) -> Array:
	var pool = []
	for r in rewards.values():
		if not r.has("available") or r["available"].call(RunManager):
			# Note: We use global RunManager for now as most rewards are static,
			# but check if we should be using a passed rm?
			# Actually, RewardManager usually calls this.
			pool.append(r)
			
	var results = []
	var used = {}
	
	if pool.size() <= count:
		return pool
		
	while results.size() < count:
		var candidates = []
		for r in pool:
			if not used.has(r["id"]):
				candidates.append(r)
		
		if candidates.is_empty(): break
		
		var total_weight = 0
		for r in candidates:
			var rarity = r.get("rarity", "common")
			total_weight += RARITY_WEIGHTS.get(rarity, 10)
			
		var rand = randf() * total_weight
		var picked = candidates[candidates.size() - 1]
		
		for r in candidates:
			var rarity = r.get("rarity", "common")
			rand -= RARITY_WEIGHTS.get(rarity, 10)
			if rand <= 0:
				picked = r
				break
		
		results.append(picked)
		used[picked["id"]] = true
		
	return results

## Apply a reward by ID
func apply_reward(reward_id: String) -> void:
	var r = get_reward(reward_id)
	if r.has("apply"):
		r["apply"].call(RunManager)

# Factory method to populate with baseline content
func bootstrap() -> void:
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
		"apply": func(rm): rm.apply_modifier({"powerMult": 1.04}, "Leg Day")
	})
	
	register_reward({
		"id": "stat_aero_1",
		"label": "Slammed Stem",
		"description": "-2% Aerodynamic drag",
		"rarity": "common",
		"modifier": {"dragReduction": 0.02},
		"apply": func(rm): rm.apply_modifier({"dragReduction": 0.02}, "Slammed Stem")
	})
	
	register_reward({
		"id": "stat_weight_1",
		"label": "Carbon Cages",
		"description": "-3% Total system weight",
		"rarity": "common",
		"modifier": {"weightMult": 0.97},
		"apply": func(rm): rm.apply_modifier({"weightMult": 0.97}, "Carbon Cages")
	})

	# --- Rewards (Items) ---
	register_reward({
		"id": "item_aero_helmet",
		"label": "Aero Helmet",
		"description": "Equipable: -3% Drag",
		"rarity": "uncommon",
		"apply": func(rm): rm.add_to_inventory("aero_helmet")
	})
