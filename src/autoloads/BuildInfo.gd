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
	
	var watermark = Label.new()
	watermark.text = "v: " + COMMIT_HASH.left(7)
	watermark.add_theme_font_size_override("font_size", 24)
	watermark.add_theme_color_override("font_color", Color.YELLOW)
	watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	layer.add_child(watermark)
	
	# Move to Top-Left for maximum visibility test
	watermark.layout_mode = 1
	watermark.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 20)
