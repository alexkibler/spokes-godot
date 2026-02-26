extends Node

# This file is automatically updated by the CI/CD pipeline.
# DO NOT EDIT MANUALLY.

const COMMIT_HASH: String = "dev"

func _ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log('Spokes: BuildInfo autoload initializing...')")
	_add_version_watermark.call_deferred()

func _add_version_watermark() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 128 # Max layer
	add_child(layer)
	
	var bg = ColorRect.new()
	bg.color = Color.MAGENTA # Extreme contrast
	bg.custom_minimum_size = Vector2(200, 40)
	layer.add_child(bg)
	
	var watermark = Label.new()
	# Hardcode string to rule out empty variable issues
	watermark.text = "VER: " + COMMIT_HASH.left(7) + " (TEST)"
	watermark.add_theme_font_size_override("font_size", 20)
	watermark.add_theme_color_override("font_color", Color.WHITE)
	watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(watermark)
	
	# Center text in BG
	watermark.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	# Position the whole thing in top-left
	bg.layout_mode = 1
	bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 50)
	
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log('Spokes: Watermark added to tree')")
