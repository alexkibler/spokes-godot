extends Control

@onready var slots_container: VBoxContainer = $MarginContainer/VBoxContainer/SlotsContainer

func _ready() -> void:
	refresh_slots()

func refresh_slots() -> void:
	# Clear existing slot UI and rebuild
	for child in slots_container.get_children():
		child.queue_free()

	for i in range(SaveManager.SLOT_COUNT):
		var slot_data = SaveManager.get_slot_metadata(i)
		var slot_ui = preload("res://src/ui/components/SaveSlot.tscn").instantiate()
		slots_container.add_child(slot_ui)

		if slot_data.is_empty():
			slot_ui.call("setup_empty", i)
		else:
			slot_ui.call("setup_data", i, slot_data)

		slot_ui.connect("slot_selected", _on_slot_selected)
		slot_ui.connect("slot_deleted", _on_slot_deleted)

func _on_slot_selected(index: int, is_empty: bool) -> void:
	RunManager.current_slot_index = index
	if is_empty:
		# Transition to the standard MenuScene to configure a new run
		get_tree().change_scene_to_file("res://src/ui/screens/MenuScene.tscn")
	else:
		if SaveManager.load_game(index):
			get_tree().change_scene_to_file("res://src/features/map/MapScene.tscn")

func _on_slot_deleted(index: int) -> void:
	SaveManager.delete_save(index)
	refresh_slots()
