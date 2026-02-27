class_name UIUtils
extends RefCounted

## UI Utility functions for safe area handling and other common UI tasks.

static func handle_safe_area(container: MarginContainer, min_margin: int = 20) -> void:
	if not container or not container.is_inside_tree():
		return

	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()

	# If running in editor or windowed mode where safe area matches window,
	# these might be 0 offsets.
	# We calculate margins needed to respect the safe area.

	var margin_left: int = safe_area.position.x
	var margin_top: int = safe_area.position.y
	var margin_right: int = window_size.x - (safe_area.position.x + safe_area.size.x)
	var margin_bottom: int = window_size.y - (safe_area.position.y + safe_area.size.y)

	container.add_theme_constant_override("margin_left", maxi(margin_left, min_margin))
	container.add_theme_constant_override("margin_top", maxi(margin_top, min_margin))
	container.add_theme_constant_override("margin_right", maxi(margin_right, min_margin))
	container.add_theme_constant_override("margin_bottom", maxi(margin_bottom, min_margin))
