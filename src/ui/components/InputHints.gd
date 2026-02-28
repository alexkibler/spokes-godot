extends HBoxContainer
class_name InputHints

func _ready() -> void:
    alignment = BoxContainer.ALIGNMENT_CENTER
    set("theme_override_constants/separation", 32)
    custom_minimum_size.y = 40

func add_hint(action: int, label: String) -> void:
    var glyph = preload("res://src/ui/components/ControllerGlyph.tscn").instantiate()
    glyph.action = action
    glyph.label_text = label
    add_child(glyph)

func clear_hints() -> void:
    for child in get_children():
        child.queue_free()
