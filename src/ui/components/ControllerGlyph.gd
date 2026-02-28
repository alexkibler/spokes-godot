extends HBoxContainer
class_name ControllerGlyph

enum ActionType { ACCEPT, CANCEL, START, AUTOPLAY, DPAD, X, Y, RB, LB, LT, RT }

@export var action: ActionType = ActionType.ACCEPT
@export var label_text: String = ""

var _icon: Control
var _label: Label

func _ready() -> void:
    alignment = BoxContainer.ALIGNMENT_CENTER
    set("theme_override_constants/separation", 8)
    
    _icon = Control.new()
    _icon.custom_minimum_size = Vector2(24, 24)
    _icon.draw.connect(_on_icon_draw)
    add_child(_icon)
    
    _label = Label.new()
    _label.add_theme_font_size_override("font_size", 16)
    _label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
    add_child(_label)
    
    _update_visuals()

func _update_visuals() -> void:
    if not is_inside_tree(): return
    _label.text = label_text
    _icon.queue_redraw()

func _on_icon_draw() -> void:
    var center = Vector2(12, 12)
    var radius = 10.0
    
    var bg_color = Color.DARK_GRAY
    var text_color = Color.WHITE
    var char_str = ""
    
    match action:
        ActionType.ACCEPT:
            bg_color = Color("#2ecc71") # Green A
            char_str = "A"
        ActionType.CANCEL:
            bg_color = Color("#e74c3c") # Red B
            char_str = "B"
        ActionType.X:
            bg_color = Color("#3498db") # Blue X
            char_str = "X"
        ActionType.Y, ActionType.AUTOPLAY:
            bg_color = Color("#f1c40f") # Yellow Y
            char_str = "Y"
            text_color = Color.BLACK
        ActionType.START:
            bg_color = Color.WHITE
            text_color = Color.BLACK
            char_str = "☰"
        ActionType.DPAD:
            bg_color = Color.GRAY
            char_str = "✛"
            
    # Draw circle
    _icon.draw_circle(center, radius, bg_color)
    
    # Draw outline
    _icon.draw_arc(center, radius, 0, TAU, 16, Color.BLACK, 1.5, true)
    
    # Draw character
    var font = ThemeDB.fallback_font
    var font_size = 14
    var text_size = font.get_string_size(char_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
    var text_pos = center - text_size / 2.0 + Vector2(0, font.get_ascent(font_size) / 2.0 - 2)
    _icon.draw_string(font, text_pos, char_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)
