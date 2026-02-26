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
	_add_version_watermark()
	# Load from settings
	ftp_input.value = SettingsManager.ftp_w
	weight_input.value = SettingsManager.weight_kg
	
	units_toggle.clear()
	units_toggle.add_item("Imperial (mi/lb)")
	units_toggle.add_item("Metric (km/kg)")
	units_toggle.selected = 0 if SettingsManager.units == "imperial" else 1
	
	diff_toggle.clear()
	diff_toggle.add_item("Easy")
	diff_toggle.add_item("Normal")
	diff_toggle.add_item("Hard")
	diff_toggle.selected = 1
	
	var bt_btn = Button.new()
	bt_btn.text = "PAIR BLUETOOTH TRAINER"
	bt_btn.custom_minimum_size = Vector2(300, 60)
	bt_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not OS.has_feature("web"):
		bt_btn.disabled = true
		bt_btn.text += " (WEB ONLY)"
	else:
		bt_btn.pressed.connect(func():
			TrainerService.is_mock_mode = false
			TrainerService.request_bluetooth_if_needed()
			bt_btn.text = "PAIRING..."
			bt_btn.disabled = true
		)
		TrainerService.connected.connect(func():
			bt_btn.text = "CONNECTED!"
			bt_btn.disabled = true
			_show_trainer_status()
		)
	
	var vbox = $MarginContainer/VBoxContainer
	var start_btn = $MarginContainer/VBoxContainer/StartButton
	vbox.add_child(bt_btn)
	vbox.move_child(bt_btn, start_btn.get_index())
	
	_on_dist_changed(dist_slider.value)

var status_label: Label

func _show_trainer_status() -> void:
	if not status_label:
		status_label = Label.new()
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.add_theme_color_override("font_color", Color.DARK_SLATE_GRAY)
		status_label.add_theme_font_size_override("font_size", 24)
		$MarginContainer/VBoxContainer.add_child(status_label)
		$MarginContainer/VBoxContainer.move_child(status_label, $MarginContainer/VBoxContainer/StartButton.get_index())
		
	if not TrainerService.data_received.is_connected(self._on_trainer_data_received):
		TrainerService.data_received.connect(self._on_trainer_data_received)

func _on_trainer_data_received(data: Dictionary) -> void:
	if status_label:
		status_label.text = "LIVE: %d W | %d RPM" % [int(data["power"]), int(data["cadence"])]

func _on_bt_connected() -> void:
	pass

func _on_dist_changed(val: float) -> void:
	dist_label.text = str(val) + " km"

func _on_start_pressed() -> void:
	# Save settings
	SettingsManager.ftp_w = int(ftp_input.value)
	SettingsManager.weight_kg = weight_input.value
	SettingsManager.units = "imperial" if units_toggle.selected == 0 else "metric"
	SettingsManager.save_settings()
	
	# Start Run
	var diff_str = "normal"
	match diff_toggle.selected:
		0: diff_str = "easy"
		1: diff_str = "normal"
		2: diff_str = "hard"
		
	var dist_km = dist_slider.value
	var floors = int(max(4, round(dist_km / 1.25)))
	
	RunManager.start_new_run(
		floors,
		dist_km,
		diff_str,
		SettingsManager.ftp_w,
		SettingsManager.weight_kg,
		SettingsManager.units
	)
	
	get_tree().change_scene_to_file("res://src/scenes/MapScene.tscn")

func _add_version_watermark() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 100 # Ensure it's on top of everything
	add_child(layer)
	
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	layer.add_child(margin)
	
	var watermark = Label.new()
	watermark.text = "v: " + BuildInfo.COMMIT_HASH.left(7)
	watermark.add_theme_font_size_override("font_size", 14)
	watermark.add_theme_color_override("font_color", Color(0, 0, 0, 0.5)) # Semi-transparent black
	margin.add_child(watermark)
