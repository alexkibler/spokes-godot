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
		"description": "Aerodynamic but heavy. Hard to drop on flats."
	},
	"mountain": {
		"name": "THE GOAT",
		"color": Color.LIGHT_SLATE_GRAY,
		"power_mult": 0.95,
		"modifiers": {
			"weightMult": 0.75
		},
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
		"description": "Endless stamina. No recovery penalty after surging."
	},
	"tundra": {
		"name": "THE SNOWPLOW",
		"color": Color.AZURE,
		"power_mult": 1.05,
		"modifiers": {
			"crrMult": 0.5 # Special handling in GameScene/Cyclist needed for this to be effective
		},
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
		"description": "Long, sustained attacks with minimal rest."
	},
	"jungle": {
		"name": "THE PANTHER",
		"color": Color.FOREST_GREEN,
		"power_mult": 1.15,
		"modifiers": {
			"dragReduction": 0.05
		},
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
		"description": "The ultimate challenge. No weaknesses."
	}
}

static func get_boss(spoke_id: String) -> Dictionary:
	return BOSSES.get(spoke_id, BOSSES["plains"])
