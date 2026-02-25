extends Node

const SAVE_PATH = "user://settings.cfg"

var ftp_w: int = 200
var weight_kg: float = 75.0
var units: String = "imperial" # 'metric' or 'imperial'
var volume_master: float = 1.0

func _ready() -> void:
    load_settings()

func save_settings() -> void:
    var config = ConfigFile.new()
    config.set_value("user", "ftp_w", ftp_w)
    config.set_value("user", "weight_kg", weight_kg)
    config.set_value("user", "units", units)
    config.set_value("audio", "volume_master", volume_master)
    config.save(SAVE_PATH)

func load_settings() -> void:
    var config = ConfigFile.new()
    var err = config.load(SAVE_PATH)
    if err == OK:
        ftp_w = config.get_value("user", "ftp_w", 200)
        weight_kg = config.get_value("user", "weight_kg", 75.0)
        units = config.get_value("user", "units", "imperial")
        volume_master = config.get_value("audio", "volume_master", 1.0)
