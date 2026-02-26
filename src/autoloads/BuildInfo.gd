extends Node

# This file is automatically updated by the CI/CD pipeline.
# DO NOT EDIT MANUALLY.

const COMMIT_HASH: String = "dev"

func _ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log('Spokes: BuildInfo initializing [Hash: " + COMMIT_HASH + "]...')")
	_add_version_watermark.call_deferred()

func _add_version_watermark() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 128 # Very high layer
	add_child(layer)
	
	var watermark = Label.new()
	watermark.text = "v: " + COMMIT_HASH.left(7)
	watermark.add_theme_font_size_override("font_size", 14)
	watermark.add_theme_color_override("font_color", Color(0, 0, 0, 0.6)) # Slightly darker semi-transparent black
	watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	layer.add_child(watermark)
	
	# Use the combined preset function which is more reliable for direct children of CanvasLayer
	watermark.layout_mode = 1
	watermark.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log('Spokes: Watermark positioned at bottom-right')")
