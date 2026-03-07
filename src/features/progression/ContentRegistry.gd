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

## Delivery cargo options for quest generation.
## Each entry: { "name": String, "weight_kg": float }
const CARGO_ITEMS: Array[Dictionary] = [
	{"name": "Emergency Medical Supplies", "weight_kg": 1.0},
	{"name": "Low-Profile Keyboard Parts", "weight_kg": 1.5},
	{"name": "Box of Spare Tubes & Tools", "weight_kg": 2.5},
	{"name": "PETG Filament Spools", "weight_kg": 4.0},
	{"name": "Bulk Coffee Beans", "weight_kg": 5.0},
	{"name": "Cast-Iron Dutch Oven", "weight_kg": 6.0},
	{"name": "E-Bike Conversion Kit", "weight_kg": 8.0},
	{"name": "Direct-Drive Trainer Flywheel", "weight_kg": 15.0},
	{"name": "Loaded Child Trailer", "weight_kg": 22.0},
]

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

static func get_loot_pool(count: int, forced_reward_id: String = "") -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for r: Dictionary in rewards.values():
		if not r.has("available") or (r["available"] as Callable).call(RunManager):
			pool.append(r)
			
	var results: Array[Dictionary] = []
	var used: Dictionary = {}
	
	if forced_reward_id != "" and rewards.has(forced_reward_id):
		var forced: Dictionary = rewards[forced_reward_id]
		results.append(forced)
		used[forced_reward_id] = true

	if pool.size() <= count and forced_reward_id == "":
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
		"slot": "Rider", # Helmet/Rider are same for now
		"rarity": "uncommon",
		"visuals": { "color": Color.CORAL },
		"modifier": {"dragReduction": 0.03},
		"description": "-3% Drag",
		"weight_kg": 0.0,
	})
	
	register_item({
		"id": "carbon_frame",
		"label": "Carbon Frame",
		"slot": "Frame",
		"rarity": "rare",
		"visuals": { "color": Color(0.2, 0.2, 0.2) }, # Carbon dark gray
		"modifier": {"weightMult": 0.88, "dragReduction": 0.03},
		"description": "-12% Weight, -3% Drag",
		"weight_kg": 0.0,
	})

	register_item({
		"id": "aero_wheels",
		"label": "Deep-Section Wheels",
		"slot": "Wheels",
		"rarity": "rare",
		"visuals": { "color": Color.SKY_BLUE },
		"modifier": {"dragReduction": 0.05, "weightMult": 1.05}, # Aero but heavy
		"description": "-5% Drag, +5% Weight",
		"weight_kg": 0.0,
	})

	register_item({
		"id": "race_bars",
		"label": "Race Handlebars",
		"slot": "Handlebars",
		"rarity": "uncommon",
		"visuals": { "color": Color.DARK_ORCHID },
		"modifier": {"dragReduction": 0.02},
		"description": "-2% Drag",
		"weight_kg": 0.0,
	})

	# --- Rewards (Stat Boosts) ---
	register_reward({
		"id": "stat_power_1",
		"label": "Leg Day",
		"description": "+4% Power output",
		"rarity": "common",
		"modifier": {"powerMult": 1.04},
		"apply": func(rm: Node) -> void: RunManager.apply_modifier({"powerMult": 1.04}, "Leg Day")
	})
	
	register_reward({
		"id": "stat_aero_1",
		"label": "Slammed Stem",
		"description": "-2% Aerodynamic drag",
		"rarity": "common",
		"modifier": {"dragReduction": 0.02},
		"apply": func(rm: Node) -> void: RunManager.apply_modifier({"dragReduction": 0.02}, "Slammed Stem")
	})
	
	register_reward({
		"id": "stat_weight_1",
		"label": "Carbon Cages",
		"description": "-3% Total system weight",
		"rarity": "common",
		"modifier": {"weightMult": 0.97},
		"apply": func(rm: Node) -> void: RunManager.apply_modifier({"weightMult": 0.97}, "Carbon Cages")
	})

	# --- Rewards (Items) ---
	register_reward({
		"id": "item_aero_helmet",
		"label": "Aero Helmet",
		"description": "Equipable: -3% Drag",
		"rarity": "uncommon",
		"apply": func(rm: Node) -> void: RunManager.add_to_inventory("aero_helmet")
	})

	# --- Boss Unique Items ---
	register_item({
		"id": "aero_overshoes",
		"label": "Aero Overshoes",
		"slot": "BackPedal",
		"rarity": "rare",
		"visuals": { "color": Color.SKY_BLUE },
		"modifier": {"dragReduction": 0.04},
		"description": "-4% Drag",
		"weight_kg": 0.0,
	})
	register_reward({
		"id": "item_aero_overshoes",
		"label": "Aero Overshoes",
		"description": "Unique: -4% Drag",
		"rarity": "rare",
		"apply": func(rm: Node) -> void: RunManager.add_to_inventory("aero_overshoes")
	})

	register_item({
		"id": "sea_wall_frame",
		"label": "Sea Wall Frame",
		"slot": "Frame",
		"rarity": "rare",
		"visuals": { "color": Color.AQUAMARINE },
		"modifier": {"dragReduction": 0.06, "weightMult": 1.05},
		"description": "-6% Drag, +5% Weight",
		"weight_kg": 0.0,
	})
	register_reward({
		"id": "item_sea_wall_frame",
		"label": "Sea Wall Frame",
		"description": "Unique: Extreme aerodynamics",
		"rarity": "rare",
		"apply": func(rm: Node) -> void: RunManager.add_to_inventory("sea_wall_frame")
	})

	register_item({
		"id": "ti_skewers",
		"label": "Titanium Skewers",
		"slot": "Wheels",
		"rarity": "rare",
		"visuals": { "color": Color.LIGHT_SLATE_GRAY },
		"modifier": {"weightMult": 0.94},
		"description": "-6% Weight",
		"weight_kg": 0.0,
	})
	register_reward({
		"id": "item_ti_skewers",
		"label": "Titanium Skewers",
		"description": "Unique: Ultralight hardware",
		"rarity": "rare",
		"apply": func(rm: Node) -> void: RunManager.add_to_inventory("ti_skewers")
	})

	register_item({
		"id": "bear_claws",
		"label": "Bear Claw Cranks",
		"slot": "Crank",
		"rarity": "rare",
		"visuals": { "color": Color.SADDLE_BROWN },
		"modifier": {"powerMult": 1.06},
		"description": "+6% Power",
		"weight_kg": 0.0,
	})
	register_reward({
		"id": "item_bear_claws",
		"label": "Bear Claw Cranks",
		"description": "Unique: Massive power transfer",
		"rarity": "rare",
		"apply": func(rm: Node) -> void: RunManager.add_to_inventory("bear_claws")
	})

	register_item({
		"id": "mirage_bottle",
		"label": "Mirage Bottle",
		"slot": "Rider",
		"rarity": "rare",
		"visuals": { "color": Color.SANDY_BROWN },
		"modifier": {"powerMult": 1.03, "dragReduction": 0.02},
		"description": "+3% Power, -2% Drag",
		"weight_kg": 0.0,
	})
	register_reward({
		"id": "item_mirage_bottle",
		"label": "Mirage Bottle",
		"description": "Unique: Endless hydration",
		"rarity": "rare",
		"apply": func(rm: Node) -> void: RunManager.add_to_inventory("mirage_bottle")
	})

	register_item({
		"id": "studded_tires",
		"label": "Studded Tires",
		"slot": "Wheels",
		"rarity": "rare",
		"visuals": { "color": Color.AZURE },
		"modifier": {"crrMult": 0.8},
		"description": "-20% Rolling resistance",
		"weight_kg": 0.0,
	})
	register_reward({
		"id": "item_studded_tires",
		"label": "Studded Tires",
		"description": "Unique: All-terrain grip",
		"rarity": "rare",
		"apply": func(rm: Node) -> void: RunManager.add_to_inventory("studded_tires")
	})

	register_item({
		"id": "gust_bars",
		"label": "Gust Handlebars",
		"slot": "Handlebars",
		"rarity": "rare",
		"visuals": { "color": Color.ORANGE_RED },
		"modifier": {"dragReduction": 0.05},
		"description": "-5% Drag",
		"weight_kg": 0.0,
	})
	register_reward({
		"id": "item_gust_bars",
		"label": "Gust Handlebars",
		"description": "Unique: Slices through wind",
		"rarity": "rare",
		"apply": func(rm: Node) -> void: RunManager.add_to_inventory("gust_bars")
	})

	register_item({
		"id": "panther_kit",
		"label": "Panther Kit",
		"slot": "Rider",
		"rarity": "rare",
		"visuals": { "color": Color.FOREST_GREEN },
		"modifier": {"powerMult": 1.04, "weightMult": 0.98},
		"description": "+4% Power, -2% Weight",
		"weight_kg": 0.0,
	})
	register_reward({
		"id": "item_panther_kit",
		"label": "Panther Kit",
		"description": "Unique: Agile performance",
		"rarity": "rare",
		"apply": func(rm: Node) -> void: RunManager.add_to_inventory("panther_kit")
	})

	register_item({
		"id": "architect_crown",
		"label": "The Crown",
		"slot": "Rider",
		"rarity": "rare",
		"visuals": { "color": Color.GOLD },
		"modifier": {"powerMult": 1.1, "dragReduction": 0.1, "weightMult": 0.9},
		"description": "+10% Power, -10% Drag/Weight",
		"weight_kg": 0.0,
	})
	register_reward({
		"id": "item_architect_crown",
		"label": "The Crown",
		"description": "Unique: The mark of the master",
		"rarity": "rare",
		"apply": func(rm: Node) -> void: RunManager.add_to_inventory("architect_crown")
	})
