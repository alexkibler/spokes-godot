extends CanvasLayer

@onready var gold_label: Label = $MarginContainer/TopRight/GoldValue
@onready var floor_label: Label = $MarginContainer/TopLeft/FloorLabel
@onready var modifier_container: HBoxContainer = $MarginContainer/TopCenter/ModifierContainer

func _ready() -> void:
    update_hud()

func update_hud() -> void:
    var run = RunManager.get_run()
    if run.is_empty(): return
    
    gold_label.text = str(run.get("gold", 0)) + " g"
    
    # Calculate current floor (deepest visited node floor)
    var current_floor = 0
    var current_node_id = run.get("currentNodeId", "")
    for n in run["nodes"]:
        if n["id"] == current_node_id:
            current_floor = n["floor"]
            break
    
    floor_label.text = "FLOOR " + str(current_floor)
    
    _update_modifiers(run["modifiers"])

func _update_modifiers(modifiers: Dictionary) -> void:
    # Clear existing
    for child in modifier_container.get_children():
        child.queue_free()
        
    # Add chips for non-baseline modifiers
    if modifiers.get("powerMult", 1.0) != 1.0:
        _add_modifier_chip("Power", "x%.2f" % modifiers["powerMult"], Color.GOLD)
    
    if modifiers.get("dragReduction", 0.0) != 0.0:
        _add_modifier_chip("Aero", "-%d%%" % int(modifiers["dragReduction"] * 100), Color.CYAN)
        
    if modifiers.get("weightMult", 1.0) != 1.0:
        _add_modifier_chip("Weight", "x%.2f" % modifiers["weightMult"], Color.SALMON)

func _add_modifier_chip(label: String, val: String, color: Color) -> void:
    var chip = PanelContainer.new()
    var style = StyleBoxFlat.new()
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
    
    var l = Label.new()
    l.text = label + " " + val
    l.add_theme_font_size_override("font_size", 14)
    l.add_theme_color_override("font_color", Color.WHITE)
    chip.add_child(l)
    
    modifier_container.add_child(chip)
