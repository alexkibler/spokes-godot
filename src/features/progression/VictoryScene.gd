extends Control

# Port of VictoryScene.ts

@onready var time_value: Label = %TimeValue
@onready var dist_value: Label = %DistValue
@onready var elev_value: Label = %ElevValue
@onready var work_value: Label = %WorkValue

func _ready() -> void:
    var run: Dictionary = RunManager.get_run()
    if run.is_empty() or not run.has("stats"):
        return
        
    var stats: Dictionary = run["stats"]
    var units: String = SettingsManager.units
    
    # 1. Total Time (HH:MM:SS)
    var total_seconds: int = int(stats.get("totalTimeS", 0))
    var hours: int = total_seconds / 3600
    var minutes: int = (total_seconds % 3600) / 60
    var seconds: int = total_seconds % 60
    time_value.text = "%02d:%02d:%02d" % [hours, minutes, seconds]
    
    # 2. Total Distance
    var m: float = stats.get("totalRiddenDistanceM", 0.0)
    if units == "imperial":
        dist_value.text = "%.2f mi" % (m * Units.M_TO_MI)
    else:
        dist_value.text = "%.2f km" % (m * Units.M_TO_KM)
        
    # 3. Total Elevation
    var elev_m: float = stats.get("totalElevationGainM", 0.0)
    if units == "imperial":
        elev_value.text = "%d ft" % int(round(elev_m * Units.M_TO_FT))
    else:
        elev_value.text = "%d m" % int(round(elev_m))
        
    # 4. Total Work (kJ)
    # Energy (kJ) = (Avg Power * Time) / 1000
    var p_sum: float = stats.get("totalPowerSum", 0.0)
    var ticks: int = stats.get("totalRecordCount", 1)
    if ticks == 0: ticks = 1
    
    var avg_p: float = p_sum / float(ticks)
    var work_kj: float = (avg_p * float(total_seconds)) / 1000.0
    work_value.text = "%d kJ" % int(round(work_kj))
    
    var return_btn: Button = $CenterContainer/VBoxContainer/ReturnButton as Button
    if return_btn:
        return_btn.grab_focus()

func _on_return_pressed() -> void:    # Delete the save for the current run as it's completed (victory!)
    if RunManager.current_slot_index != -1:
        SaveManager.delete_save(RunManager.current_slot_index)
        
    # Reset run
    RunManager.reset()
    get_tree().change_scene_to_file("res://src/ui/screens/MenuScene.tscn")

func _on_save_fit_pressed() -> void:
    # In a real build, we'd trigger a native save dialog
    # For now, let's just print to console or save to user://
    print("[VICTORY] FIT file export triggered")
    # Native dialogs are complex in Godot without a plugin, but on Web/Desktop:
    # ProjectSettings.globalize_path("user://")
    pass
