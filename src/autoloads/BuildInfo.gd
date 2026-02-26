extends Node

# This file is automatically updated by the CI/CD pipeline.
# DO NOT EDIT MANUALLY.

const COMMIT_HASH: String = "dev"

func _ready() -> void:
	_add_version_watermark()

func _add_version_watermark() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 128 # Very high layer
	add_child(layer)
	
	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE # Don't block clicks
	layer.add_child(margin)
	
	# Explicitly set anchoring to bottom-right
	margin.layout_mode = 1 # Use Anchors
	margin.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	
	var watermark = Label.new()
	watermark.text = "v: " + COMMIT_HASH.left(7)
	watermark.add_theme_font_size_override("font_size", 14)
	watermark.add_theme_color_override("font_color", Color(0, 0, 0, 0.4)) # Semi-transparent black
	watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(watermark)
