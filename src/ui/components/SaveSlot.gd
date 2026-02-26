extends MarginContainer

signal slot_selected(index: int, is_empty: bool)
signal slot_deleted(index: int)

var _slot_index: int = -1
var _is_empty: bool = true

@onready var container: PanelContainer = $PanelContainer
@onready var empty_view: Control = $PanelContainer/VBoxContainer/EmptyView
@onready var data_view: Control = $PanelContainer/VBoxContainer/DataView

@onready var gold_label: Label = $PanelContainer/VBoxContainer/DataView/HBoxContainer/GoldLabel
@onready var dist_label: Label = $PanelContainer/VBoxContainer/DataView/HBoxContainer/DistLabel
@onready var diff_label: Label = $PanelContainer/VBoxContainer/DataView/HBoxContainer/DiffLabel
@onready var date_label: Label = $PanelContainer/VBoxContainer/DataView/DateLabel
@onready var delete_btn: Button = $PanelContainer/VBoxContainer/DataView/HBoxContainer/DeleteButton

func setup_empty(index: int) -> void:
	_slot_index = index
	_is_empty = true
	empty_view.visible = true
	data_view.visible = false

func setup_data(index: int, data: Dictionary) -> void:
	_slot_index = index
	_is_empty = false
	empty_view.visible = false
	data_view.visible = true

	gold_label.text = "Gold: %d" % data.get("gold", 0)
	dist_label.text = "Dist: %.1f km" % data.get("distance", 0.0)
	diff_label.text = "Mode: " + str(data.get("difficulty", "normal")).capitalize()

	var time = Time.get_datetime_dict_from_unix_time(data.get("timestamp", 0))
	date_label.text = "%04d-%02d-%02d %02d:%02d" % [time.year, time.month, time.day, time.hour, time.minute]

func _on_select_button_pressed() -> void:
	slot_selected.emit(_slot_index, _is_empty)

func _on_delete_button_pressed() -> void:
	# Add confirmation dialog if desired, for now direct delete
	slot_deleted.emit(_slot_index)
