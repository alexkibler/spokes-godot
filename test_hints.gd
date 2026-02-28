extends "res://addons/gut/test.gd"
func test_hints() -> void:
    var hints = load("res://src/ui/components/InputHints.tscn").instantiate()
    hints.add_hint(0, "A")
    hints.add_hint(1, "B")
    assert_eq(hints.get_child_count(), 2)
    hints.clear_hints()
    assert_eq(hints.get_child_count(), 0)
    hints.queue_free()
