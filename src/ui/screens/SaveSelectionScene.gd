extends Control

@onready var slots_container: VBoxContainer = $MarginContainer/VBoxContainer/SlotsContainer

var _delete_dialog: ConfirmationDialog
var _slot_to_delete: int = -1

func _ready() -> void:
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Confirm Deletion"
	_delete_dialog.dialog_text = "Are you sure you want to delete this save? This cannot be undone."
	_delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(_delete_dialog)
	
	refresh_slots()

func refresh_slots() -> void:
	# Clear existing slot UI and rebuild
	for child: Node in slots_container.get_children():
		child.queue_free()

	for i: int in range(SaveManager.SLOT_COUNT):
		var slot_data: Dictionary = SaveManager.get_slot_metadata(i)
		var slot_scene: PackedScene = preload("res://src/ui/components/SaveSlot.tscn")
		var slot_ui: SaveSlot = slot_scene.instantiate() as SaveSlot
		slots_container.add_child(slot_ui)

		if slot_data.is_empty():
			slot_ui.setup_empty(i)
		else:
			slot_ui.setup_data(i, slot_data)

		slot_ui.slot_selected.connect(_on_slot_selected)
		slot_ui.slot_deleted.connect(_on_slot_deleted)

func _on_slot_selected(index: int, is_empty: bool) -> void:
	RunManager.current_slot_index = index
	if is_empty:
		# Transition to the standard MenuScene to configure a new run
		get_tree().change_scene_to_file("res://src/ui/screens/MenuScene.tscn")
	else:
		if SaveManager.load_game(index):
			get_tree().change_scene_to_file("res://src/features/map/MapScene.tscn")

func _on_slot_deleted(index: int) -> void:
	_slot_to_delete = index
	_delete_dialog.popup_centered()

func _on_delete_confirmed() -> void:
	if _slot_to_delete >= 0:
		SaveManager.delete_save(_slot_to_delete)
		refresh_slots()
		_slot_to_delete = -1
