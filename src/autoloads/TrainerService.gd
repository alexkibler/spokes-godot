extends Node

signal connected
signal disconnected
signal data_received(data) # Dict with power, speed, cadence

var is_connected_to_device: bool = false
var is_mock_mode: bool = true

var mock_timer: Timer
var _js_data_callback = null

func _ready() -> void:
    mock_timer = Timer.new()
    mock_timer.wait_time = 1.0 # 1 second tick like FTMS
    mock_timer.timeout.connect(_on_mock_tick)
    add_child(mock_timer)
    
    if OS.has_feature("web"):
        _setup_js_bridge()

func _setup_js_bridge() -> void:
    _js_data_callback = JavaScriptBridge.create_callback(_on_js_data)
    var window = JavaScriptBridge.get_interface("window")
    if window:
        window.godot_ftms_callback = _js_data_callback
    
    var js_code = """
window.connectFTMS = async function() {
    try {
        const device = await navigator.bluetooth.requestDevice({
            filters: [{ services: ['fitness_machine'] }]
        });
        const server = await device.gatt.connect();
        const service = await server.getPrimaryService('fitness_machine');
        const characteristic = await service.getCharacteristic('indoor_bike_data');
        
        await characteristic.startNotifications();
        characteristic.addEventListener('characteristicvaluechanged', (event) => {
            let value = event.target.value;
            let flags = value.getUint16(0, true);
            let offset = 2;
            let speed = 0; let cadence = 0; let power = 0;
            
            if ((flags & 0x01) === 0) { speed = value.getUint16(offset, true) / 100.0; offset += 2; }
            if ((flags & 0x02) !== 0) { offset += 2; }
            if ((flags & 0x04) !== 0) { cadence = value.getUint16(offset, true) * 0.5; offset += 2; }
            if ((flags & 0x08) !== 0) { offset += 2; }
            if ((flags & 0x10) !== 0) { offset += 3; }
            if ((flags & 0x20) !== 0) { offset += 2; }
            if ((flags & 0x40) !== 0) { power = value.getInt16(offset, true); offset += 2; }
            
            if (window.godot_ftms_callback) {
                window.godot_ftms_callback(power, cadence, speed);
            }
        });
        
        try {
            window.ftmsControl = await service.getCharacteristic('fitness_machine_control_point');
            let reqControl = new Uint8Array([0x00]);
            await window.ftmsControl.writeValue(reqControl);
        } catch(e) { console.log("Control point not available or error:", e); }
        
        return true;
    } catch (e) {
        console.error("BT Error: ", e);
        return false;
    }
};

window.setFTMSGrade = async function(grade) {
    if (!window.ftmsControl) return;
    try {
        let gradePercent = grade * 100.0;
        let gradeInt = Math.round(gradePercent * 100.0);
        let buffer = new ArrayBuffer(7);
        let view = new DataView(buffer);
        view.setUint8(0, 0x11); // Op code 0x11 for Indoor Bike Simulation
        view.setInt16(1, 0, true); // Wind speed
        view.setInt16(3, gradeInt, true); // Grade
        view.setUint8(5, 0); // Crr
        view.setUint8(6, 0); // Cw
        await window.ftmsControl.writeValue(buffer);
    } catch(e) {}
};
"""
    JavaScriptBridge.eval(js_code)

func _on_js_data(args: Array) -> void:
    if args.size() >= 3:
        var data = {
            "power": float(args[0]),
            "cadence": float(args[1]),
            "speed_kmh": float(args[2])
        }
        data_received.emit(data)

func request_bluetooth_if_needed() -> void:
    if OS.has_feature("web") and not is_mock_mode and not is_connected_to_device:
        JavaScriptBridge.eval("window.connectFTMS();")
        is_connected_to_device = true
        connected.emit()

func connect_trainer() -> void:
    if is_mock_mode:
        is_connected_to_device = true
        mock_timer.start()
        connected.emit()

func disconnect_trainer() -> void:
    is_connected_to_device = false
    mock_timer.stop()
    disconnected.emit()

func set_simulation_params(grade: float, crr: float) -> void:
    if OS.has_feature("web") and not is_mock_mode:
        JavaScriptBridge.eval("window.setFTMSGrade(%f);" % grade)

func _on_mock_tick() -> void:
    if not is_connected_to_device or not is_mock_mode: return
    
    var data = {
        "power": 200 + randi_range(-5, 5),
        "cadence": 90 + randi_range(-2, 2),
        "speed_kmh": 30.0
    }
    data_received.emit(data)
