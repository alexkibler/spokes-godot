class_name BossRegistry

# Static registry for Spoke Bosses and their unique gimmicks.

const BOSSES: Dictionary = {
	"plains": {
		"name": "THE SLIPSTREAMER",
		"color": Color.SKY_BLUE,
		"power_mult": 1.05,
		"surge_config": {
			"surge_multiplier": 1.4,
			"surge_duration": 6.0
		},
		"reward_id": "item_aero_overshoes",
		"description": "Masters the draft. Extreme surge power."
	},
	"coast": {
		"name": "THE SEA WALL",
		"color": Color.AQUAMARINE,
		"power_mult": 1.0,
		"modifiers": {
			"dragReduction": 0.25,
			"weightMult": 1.15
		},
		"reward_id": "item_sea_wall_frame",
		"description": "Aerodynamic but heavy. Hard to drop on flats."
	},
	"mountain": {
		"name": "THE GOAT",
		"color": Color.LIGHT_SLATE_GRAY,
		"power_mult": 0.95,
		"modifiers": {
			"weightMult": 0.75
		},
		"reward_id": "item_ti_skewers",
		"description": "Featherweight climber. Deadly on the gradients."
	},
	"forest": {
		"name": "THE BEAR",
		"color": Color.SADDLE_BROWN,
		"power_mult": 1.25,
		"modifiers": {
			"dragReduction": -0.1,
			"weightMult": 1.1
		},
		"reward_id": "item_bear_claws",
		"description": "Massive power, but catches a lot of wind."
	},
	"desert": {
		"name": "THE MIRAGE",
		"color": Color.SANDY_BROWN,
		"power_mult": 1.0,
		"surge_config": {
			"recovery_multiplier": 1.0,
			"surge_duration": 4.0
		},
		"reward_id": "item_mirage_bottle",
		"description": "Endless stamina. No recovery penalty after surging."
	},
	"tundra": {
		"name": "THE SNOWPLOW",
		"color": Color.AZURE,
		"power_mult": 1.05,
		"modifiers": {
			"crrMult": 0.5
		},
		"reward_id": "item_studded_tires",
		"description": "Ignores rough terrain. Maintains speed on all surfaces."
	},
	"canyon": {
		"name": "THE GUST",
		"color": Color.ORANGE_RED,
		"power_mult": 1.0,
		"surge_config": {
			"surge_duration": 10.0,
			"recovery_duration": 2.0
		},
		"reward_id": "item_gust_bars",
		"description": "Long, sustained attacks with minimal rest."
	},
	"jungle": {
		"name": "THE PANTHER",
		"color": Color.FOREST_GREEN,
		"power_mult": 1.15,
		"modifiers": {
			"dragReduction": 0.05
		},
		"reward_id": "item_panther_kit",
		"description": "Agile and powerful. A balanced, dangerous foe."
	},
	"final": {
		"name": "THE ARCHITECT",
		"color": Color.GOLD,
		"power_mult": 1.2,
		"modifiers": {
			"dragReduction": 0.1,
			"weightMult": 0.9
		},
		"surge_config": {
			"surge_multiplier": 1.3
		},
		"reward_id": "item_architect_crown",
		"description": "The ultimate challenge. No weaknesses."
	}
}

static func get_boss(spoke_id: String) -> Dictionary:
	return BOSSES.get(spoke_id, BOSSES["plains"])
