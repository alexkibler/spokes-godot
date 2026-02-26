class_name SpokesTheme
extends Resource

## SpokesTheme
## Defines the color palette and visual style for different biomes.

const BIOME_COLORS: Dictionary = {
	"plains":   Color("#88cc44"),
	"coast":    Color("#4a90e2"), # Match MapGenerator.gd
	"mountain": Color("#9b9b9b"),
	"forest":   Color("#2d5a27"),
	"desert":   Color("#e2b14a"),
	"tundra":   Color("#d1e8e2"),
	"canyon":   Color("#a0522d"),
	"jungle":   Color("#228b22"),
}

const PARALLAX_COLORS: Dictionary = {
	"mountains": Color("#b8aa96"),
	"hills":     Color("#7a9469"),
	"ground":    Color("#4a6e38"),
}

@export var biome_colors: Dictionary = BIOME_COLORS
@export var parallax_colors: Dictionary = PARALLAX_COLORS
