extends Control

# Port of MenuScene.ts
# Handles initial run setup and settings persistence.

@onready var ftp_input: SpinBox = $MarginContainer/VBoxContainer/GridContainer/FTPInput
@onready var weight_input: SpinBox = $MarginContainer/VBoxContainer/GridContainer/WeightInput
@onready var units_toggle: OptionButton = $MarginContainer/VBoxContainer/GridContainer/UnitsToggle
@onready var diff_toggle: OptionButton = $MarginContainer/VBoxContainer/GridContainer/DiffToggle
@onready var dist_slider: HSlider = $MarginContainer/VBoxContainer/DistanceContainer/HSlider
@onready var dist_label: Label = $MarginContainer/VBoxContainer/DistanceContainer/HBox/DistValue

func _ready() -> void:
	# Load from settings
	ftp_input.value = SettingsManager.ftp_w
	weight_input.value = SettingsManager.weight_kg
	
	# Auto-select on focus for SpinBoxes
	ftp_input.get_line_edit().select_all_on_focus = true
	weight_input.get_line_edit().select_all_on_focus = true
	
	units_toggle.clear()
	units_toggle.add_item("Imperial (mi/lb)")
	units_toggle.add_item("Metric (km/kg)")
	units_toggle.selected = 0 if SettingsManager.units == "imperial" else 1
	
	diff_toggle.clear()
	diff_toggle.add_item("Easy")
	diff_toggle.add_item("Normal")
	diff_toggle.add_item("Hard")
	diff_toggle.selected = 1
	
	var bt_btn: Button = Button.new()
	bt_btn.text = "PAIR BLUETOOTH TRAINER"
	bt_btn.custom_minimum_size = Vector2(300, 60)
	bt_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not OS.has_feature("web"):
		bt_btn.disabled = true
		bt_btn.text += " (WEB ONLY)"
	else:
		bt_btn.pressed.connect(func() -> void:
			TrainerService.is_mock_mode = false
			TrainerService.request_bluetooth_if_needed()
			bt_btn.text = "PAIRING..."
			bt_btn.disabled = true
		)
		SignalBus.trainer_connected.connect(func() -> void:
			bt_btn.text = "CONNECTED!"
			bt_btn.disabled = true
			_show_trainer_status()
		)
	
	var vbox: VBoxContainer = $MarginContainer/VBoxContainer as VBoxContainer
	var start_btn: Button = $MarginContainer/VBoxContainer/StartButton as Button
	vbox.add_child(bt_btn)
	vbox.move_child(bt_btn, start_btn.get_index())
	
	# Add Load Game / Back button
	var load_btn: Button = Button.new()
	load_btn.text = "CHANGE SLOT / LOAD"
	load_btn.custom_minimum_size = Vector2(300, 60)
	load_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	load_btn.pressed.connect(_on_load_pressed)
	vbox.add_child(load_btn)
	vbox.move_child(load_btn, start_btn.get_index() + 1)

	if RunManager.current_slot_index != -1:
		start_btn.text = "START RUN (SLOT %d)" % (RunManager.current_slot_index + 1)
	else:
		start_btn.text = "SELECT SLOT"

	_on_dist_changed(dist_slider.value)
	start_btn.grab_focus()

func _exit_tree() -> void:
	if SignalBus.trainer_power_updated.is_connected(self._on_trainer_power_updated):
		SignalBus.trainer_power_updated.disconnect(self._on_trainer_power_updated)
	if SignalBus.trainer_cadence_updated.is_connected(self._on_trainer_cadence_updated):
		SignalBus.trainer_cadence_updated.disconnect(self._on_trainer_cadence_updated)
	if SignalBus.trainer_connected.is_connected(_show_trainer_status):
		# This one was connected with a lambda in _ready, 
		# but if we used a method we could disconnect.
		# For now, let's just make sure method connections are handled.
		pass

var status_label: Label

func _show_trainer_status() -> void:
	if not status_label:
		status_label = Label.new()
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.add_theme_color_override("font_color", Color.DARK_SLATE_GRAY)
		status_label.add_theme_font_size_override("font_size", 24)
		$MarginContainer/VBoxContainer.add_child(status_label)
		$MarginContainer/VBoxContainer.move_child(status_label, $MarginContainer/VBoxContainer/StartButton.get_index())
		
	if not SignalBus.trainer_power_updated.is_connected(self._on_trainer_power_updated):
		SignalBus.trainer_power_updated.connect(self._on_trainer_power_updated)
	if not SignalBus.trainer_cadence_updated.is_connected(self._on_trainer_cadence_updated):
		SignalBus.trainer_cadence_updated.connect(self._on_trainer_cadence_updated)

var _last_watts: float = 0.0
var _last_rpm: float = 0.0

func _on_trainer_power_updated(watts: float) -> void:
	_last_watts = watts
	_update_status_text()

func _on_trainer_cadence_updated(rpm: float) -> void:
	_last_rpm = rpm
	_update_status_text()

func _update_status_text() -> void:
	if status_label:
		status_label.text = "LIVE: %d W | %d RPM" % [int(_last_watts), int(_last_rpm)]

func _on_trainer_data_received(_data: Dictionary) -> void:
	# Deprecated, using individual signals now
	pass

func _on_bt_connected() -> void:
	pass

func _on_dist_changed(val: float) -> void:
	dist_label.text = str(val) + " km"

func _on_load_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/screens/SaveSelectionScene.tscn")

func _on_start_pressed() -> void:
	if RunManager.current_slot_index == -1:
		_on_load_pressed()
		return

	# Save settings
	SettingsManager.ftp_w = int(ftp_input.value)
	SettingsManager.weight_kg = weight_input.value
	SettingsManager.units = "imperial" if units_toggle.selected == 0 else "metric"
	SettingsManager.save_settings()
	
	# Start Run
	var diff_str: String = "normal"
	match diff_toggle.selected:
		0: diff_str = "easy"
		1: diff_str = "normal"
		2: diff_str = "hard"
		
	var dist_km: float = dist_slider.value
	var floors: int = int(max(4, round(dist_km / 1.25)))
	
	RunManager.start_new_run(
		floors,
		dist_km,
		diff_str,
		SettingsManager.ftp_w,
		SettingsManager.weight_kg,
		SettingsManager.units
	)
	
	get_tree().change_scene_to_file("res://src/features/map/MapScene.tscn")
