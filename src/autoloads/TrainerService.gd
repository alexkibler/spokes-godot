extends Node

signal connected
signal disconnected
signal data_received(data) # Dict with power, speed, cadence

var is_connected_to_device: bool = false
var is_mock_mode: bool = true

var mock_timer: Timer

func _ready() -> void:
    mock_timer = Timer.new()
    mock_timer.wait_time = 1.0 # 1 second tick like FTMS
    mock_timer.timeout.connect(_on_mock_tick)
    add_child(mock_timer)

func connect_trainer() -> void:
    # In full implementation, this will check if Web Bluetooth or Mock
    is_connected_to_device = true
    if is_mock_mode:
        mock_timer.start()
    connected.emit()

func disconnect_trainer() -> void:
    is_connected_to_device = false
    mock_timer.stop()
    disconnected.emit()

func set_simulation_params(grade: float, crr: float) -> void:
    # Send 0x2AD9 to real trainer, or ignore for mock
    pass

func _on_mock_tick() -> void:
    if not is_connected_to_device or not is_mock_mode: return
    
    # Simulate some data (e.g. steady 200W, 90rpm)
    var data = {
        "power": 200 + randi_range(-5, 5),
        "cadence": 90 + randi_range(-2, 2),
        "speed_kmh": 30.0 # This would normally be calculated from physics, or trainer speed
    }
    data_received.emit(data)
