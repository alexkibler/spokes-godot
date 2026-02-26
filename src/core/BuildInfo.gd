extends Node

# This file is automatically updated by the CI/CD pipeline.
# DO NOT EDIT MANUALLY.

const COMMIT_HASH: String = "3652f84ef71b441febdb91273b5f8a549c09ee48"

func _ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log('Spokes: BuildInfo initializing [Hash: " + COMMIT_HASH.left(7) + "]')")
	
	if not DisplayServer.get_name() == "headless":
		_add_version_watermark.call_deferred()

func _add_version_watermark() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	
	# MarginContainer handles the anchoring properly
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(margin)
	
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = "v: " + COMMIT_HASH.left(7)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)
	
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log('Spokes: Version pill added to bottom-right via MarginContainer')")
