extends HBoxContainer
class_name InputHints

func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	set("theme_override_constants/separation", 32)
	custom_minimum_size.y = 40
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_update_visibility()

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_update_visibility()
	# Notify all glyph children to refresh their texture for the new controller
	for child: Node in get_children():
		if child is ControllerGlyph:
			(child as ControllerGlyph)._update_visuals()

func _update_visibility() -> void:
	visible = not Input.get_connected_joypads().is_empty()

func add_hint(action: int, label: String) -> void:
	var glyph: ControllerGlyph = preload("res://src/ui/components/ControllerGlyph.tscn").instantiate()
	glyph.action = action
	glyph.label_text = label
	add_child(glyph)

func clear_hints() -> void:
	for child: Node in get_children():
		child.queue_free()
