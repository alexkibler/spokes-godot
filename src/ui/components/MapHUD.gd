extends CanvasLayer

@onready var gold_label: Label = $MarginContainer/TopRight/GoldValue
@onready var floor_label: Label = $MarginContainer/TopLeft/FloorLabel
@onready var modifier_container: HBoxContainer = $MarginContainer/TopCenter/ModifierContainer
@onready var equip_button: Button = $MarginContainer/TopLeft/EquipButton
@onready var autoplay_button: Button = %AutoplayButton
@onready var resume_button: Button = %ResumeButton

func _ready() -> void:
	UIUtils.handle_safe_area($MarginContainer)
	equip_button.pressed.connect(_on_equip_pressed)
	autoplay_button.pressed.connect(_on_autoplay_pressed)
	resume_button.pressed.connect(_on_resume_pressed)

	SignalBus.gold_changed.connect(_on_gold_changed)
	SignalBus.modifiers_changed.connect(_on_modifiers_changed)
	SignalBus.autoplay_changed.connect(_on_autoplay_changed)

	_update_autoplay_ui(RunManager.autoplay_enabled)
	update_hud()

func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = str(new_gold) + " g"

func _on_modifiers_changed() -> void:
	var run: Dictionary = RunManager.get_run()
	if not run.is_empty():
		_update_modifiers(run["modifiers"])

func _on_autoplay_changed(enabled: bool) -> void:
	_update_autoplay_ui(enabled)

func _on_equip_pressed() -> void:
	var overlay: Node = (load("res://src/ui/screens/EquipmentOverlay.tscn") as PackedScene).instantiate()
	add_child(overlay)
	if overlay.has_signal("closed"):
		overlay.connect("closed", func() -> void: update_hud())

func _on_autoplay_pressed() -> void:
	RunManager.toggle_autoplay()
	# UI update handled by signal

func _on_resume_pressed() -> void:
	get_tree().change_scene_to_file("res://src/features/cycling/GameScene.tscn")

func _update_autoplay_ui(enabled: bool) -> void:
	if enabled:
		autoplay_button.text = "AUTOPLAY: ON"
		autoplay_button.add_theme_color_override("font_color", Color.GOLD)
	else:
		autoplay_button.text = "AUTOPLAY: OFF"
		autoplay_button.remove_theme_color_override("font_color")

func update_hud() -> void:
	var run: Dictionary = RunManager.get_run()
	if run.is_empty(): return
	
	gold_label.text = str(run.get("gold", 0)) + " g"
	
	# Calculate current floor (deepest visited node floor)
	var current_floor: int = 0
	var current_node_id: String = run.get("currentNodeId", "")
	var nodes: Array = run.get("nodes", [])
	for n: Dictionary in nodes:
		if n["id"] == current_node_id:
			current_floor = n["floor"]
			break
	
	floor_label.text = "FLOOR " + str(current_floor)
	
	_update_modifiers(run["modifiers"])
	
	# Show/Hide resume button
	resume_button.visible = not RunManager.get_active_edge().is_empty()

func _update_modifiers(modifiers: Dictionary) -> void:
	# Clear existing
	for child: Node in modifier_container.get_children():
		child.queue_free()
		
	# Add chips for non-baseline modifiers
	if modifiers.get("powerMult", 1.0) != 1.0:
		_add_modifier_chip("Power", "x%.2f" % modifiers["powerMult"], Color.GOLD)
	
	if modifiers.get("dragReduction", 0.0) != 0.0:
		_add_modifier_chip("Aero", "-%d%%" % int(modifiers["dragReduction"] * 100), Color.CYAN)
		
	if modifiers.get("weightMult", 1.0) != 1.0:
		_add_modifier_chip("Weight", "x%.2f" % modifiers["weightMult"], Color.SALMON)

func _add_modifier_chip(label: String, val: String, color: Color) -> void:
	var chip: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color.lerp(Color.BLACK, 0.6)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	chip.add_theme_stylebox_override("panel", style)
	
	var l: Label = Label.new()
	l.text = label + " " + val
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color.WHITE)
	chip.add_child(l)
	
	modifier_container.add_child(chip)
