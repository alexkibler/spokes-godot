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
	
	units_toggle.clear()
	units_toggle.add_item("Imperial (mi/lb)")
	units_toggle.add_item("Metric (km/kg)")
	units_toggle.selected = 0 if SettingsManager.units == "imperial" else 1
	
	diff_toggle.clear()
	diff_toggle.add_item("Easy")
	diff_toggle.add_item("Normal")
	diff_toggle.add_item("Hard")
	diff_toggle.selected = 1
	
	_on_dist_changed(dist_slider.value)

func _on_dist_changed(val: float) -> void:
	dist_label.text = str(val) + " km"

func _on_start_pressed() -> void:
	# Save settings
	SettingsManager.ftp_w = int(ftp_input.value)
	SettingsManager.weight_kg = weight_input.value
	SettingsManager.units = "imperial" if units_toggle.selected == 0 else "metric"
	SettingsManager.save_settings()
	
	# Configure Trainer (Mock for now)
	TrainerService.is_mock_mode = true
	
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
