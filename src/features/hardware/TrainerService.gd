extends Node

signal connected
signal disconnected
signal data_received(data) # Dict with power, speed, cadence

var is_connected_to_device: bool = false
var is_mock_mode: bool = true

var mock_timer: Timer
var _js_data_callback = null
var _js_connected_callback = null
var _js_disconnected_callback = null

func _ready() -> void:
    mock_timer = Timer.new()
    mock_timer.wait_time = 1.0 # 1 second tick like FTMS
    mock_timer.timeout.connect(_on_mock_tick)
    add_child(mock_timer)
    
    if OS.has_feature("web"):
        _setup_js_bridge()

func _setup_js_bridge() -> void:
    _js_data_callback = JavaScriptBridge.create_callback(_on_js_data)
    _js_connected_callback = JavaScriptBridge.create_callback(_on_js_connected)
    _js_disconnected_callback = JavaScriptBridge.create_callback(_on_js_disconnected)
    
    var window = JavaScriptBridge.get_interface("window")
    if window:
        window.godot_ftms_callback = _js_data_callback
        window.godot_ftms_connected_callback = _js_connected_callback
        window.godot_ftms_disconnected_callback = _js_disconnected_callback
    
    var js_code = """
window.connectFTMS = async function() {
    if (!navigator.bluetooth) {
        console.error("Web Bluetooth is not supported in this browser.");
        alert("Bluetooth Error: This browser does not support Web Bluetooth. Please use Chrome or Edge.");
        return false;
    }
    try {
        const device = await navigator.bluetooth.requestDevice({
            filters: [{ services: ['fitness_machine'] }]
        });
        const server = await device.gatt.connect();
        
        device.addEventListener('gattserverdisconnected', () => {
            console.warn("FTMS: Trainer disconnected.");
            window.ftmsControl = null;
            if (window.godot_ftms_disconnected_callback) {
                window.godot_ftms_disconnected_callback();
            }
        });

        const service = await server.getPrimaryService('fitness_machine');
        
        // 1. Setup Indoor Bike Data (Notifications)
        const dataChar = await service.getCharacteristic('indoor_bike_data');
        await dataChar.startNotifications();
        dataChar.addEventListener('characteristicvaluechanged', (event) => {
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
                // Decouple from BT event thread to avoid message channel errors
                setTimeout(() => window.godot_ftms_callback(power, cadence, speed), 0);
            }
        });
        
        // 2. Setup Control Point (Indications + Handshake)
        try {
            window.ftmsControl = await service.getCharacteristic('fitness_machine_control_point');
            
            // Handle indications from the control point
            window.ftmsControl.addEventListener('characteristicvaluechanged', (event) => {
                let val = event.target.value;
                if (val.byteLength < 3 || val.getUint8(0) !== 0x80) return;
                
                let opCode = val.getUint8(1);
                let result = val.getUint8(2);
                
                if (opCode === 0x00 && result === 0x01) {
                    console.log("FTMS: Control granted. Starting session...");
                    window.ftmsControl.writeValueWithResponse(new Uint8Array([0x07]));
                } else if (opCode === 0x07 && result === 0x01) {
                    console.log("FTMS: Workout session started.");
                    if (window.godot_ftms_connected_callback) {
                        window.godot_ftms_connected_callback();
                    }
                }
            });
            
            await window.ftmsControl.startNotifications();
            console.log("FTMS: Requesting control...");
            await window.ftmsControl.writeValueWithResponse(new Uint8Array([0x00]));
            
        } catch(e) { 
            console.warn("FTMS: Control point handshake failed:", e);
            // If control point fails, we can still use data - consider it connected anyway
            if (window.godot_ftms_connected_callback) {
                window.godot_ftms_connected_callback();
            }
        }
        
        return true;
    } catch (e) {
        console.error("BT Error: ", e);
        return false;
    }
};

window._ftmsWriting = false;
window.setFTMSGrade = async function(grade, crr, cwa) {
    if (!window.ftmsControl || window._ftmsWriting) return;
    
    window._ftmsWriting = true;
    try {
        let gradeInt = Math.round(grade * 10000);
        let crrInt = Math.min(255, Math.round(crr / 0.0001));
        let cwaInt = Math.min(255, Math.round(cwa / 0.01));
        
        let buffer = new ArrayBuffer(7);
        let view = new DataView(buffer);
        view.setUint8(0, 0x11); // Op code 0x11 for Indoor Bike Simulation
        view.setInt16(1, 0, true); // Wind speed
        view.setInt16(3, gradeInt, true); // Grade
        view.setUint8(5, crrInt); // Crr
        view.setUint8(6, cwaInt); // CWA
        await window.ftmsControl.writeValueWithResponse(buffer);
    } catch(e) {
        console.warn("FTMS: Failed to set grade:", e);
    } finally {
        window._ftmsWriting = false;
    }
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

func _on_js_connected(_args: Array) -> void:
    is_connected_to_device = true
    is_mock_mode = false
    mock_timer.stop()
    connected.emit()

func _on_js_disconnected(_args: Array) -> void:
    is_connected_to_device = false
    disconnected.emit()

func request_bluetooth_if_needed() -> void:
    if OS.has_feature("web") and not is_connected_to_device:
        is_mock_mode = false # Explicitly disable mock mode
        mock_timer.stop()
        JavaScriptBridge.eval("window.connectFTMS();")

func connect_trainer() -> void:
    if is_mock_mode:
        is_connected_to_device = true
        mock_timer.start()
        connected.emit()

func disconnect_trainer() -> void:
    is_connected_to_device = false
    mock_timer.stop()
    disconnected.emit()

func set_simulation_params(grade: float, crr: float, cwa: float) -> void:
    if OS.has_feature("web") and not is_mock_mode and is_connected_to_device:
        var js_call = "window.setFTMSGrade(" + str(grade) + ", " + str(crr) + ", " + str(cwa) + ");"
        JavaScriptBridge.eval(js_call)

func _on_mock_tick() -> void:
    if not is_connected_to_device or not is_mock_mode: 
        mock_timer.stop() # Safety: stop if we shouldn't be running
        return
    
    var data = {
        "power": 200.0,
        "cadence": 90.0,
        "speed_kmh": 30.0
    }
    data_received.emit(data)
