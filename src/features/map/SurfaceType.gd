class_name SurfaceType
extends Resource

## SurfaceType
## Defines physical and visual properties of a cycling surface.

@export var name: String = "asphalt"
@export var crr: float = 0.005 ## Coefficient of rolling resistance
@export var particle_color: Color = Color(0.2, 0.2, 0.2) ## For future particle effects
