extends Control

# Port of VictoryScene.ts

func _on_return_pressed() -> void:
    # Reset run
    RunManager.is_active_run = false
    get_tree().change_scene_to_file("res://src/scenes/MapScene.tscn") # For now, back to map to restart

func _on_save_fit_pressed() -> void:
    # In a real build, we'd trigger a native save dialog
    # For now, let's just print to console or save to user://
    print("[VICTORY] FIT file export triggered")
    # Native dialogs are complex in Godot without a plugin, but on Web/Desktop:
    # ProjectSettings.globalize_path("user://")
    pass
