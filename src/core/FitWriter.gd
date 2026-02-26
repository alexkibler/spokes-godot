class_name FitWriter
extends Object

# Port of FitWriter.ts
# Minimal binary FIT file encoder for cycling activities.

const FIT_EPOCH_OFFSET_S = 631065600

# Base type codes
const T_ENUM   = 0x00
const T_UINT8  = 0x02
const T_UINT16 = 0x84
const T_UINT32 = 0x86

const TYPE_SIZE = {
    T_ENUM: 1, T_UINT8: 1, T_UINT16: 2, T_UINT32: 4
}

const INVALID = {
    T_ENUM: 0xFF, T_UINT8: 0xFF, T_UINT16: 0xFFFF, T_UINT32: 0xFFFFFFFF
}

const CRC_TABLE = [
    0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
    0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
]

var records: Array = []
var start_time_ms: int = 0

func _init(p_start_time_ms: int) -> void:
    start_time_ms = p_start_time_ms

func add_record(rec: Dictionary) -> void:
    records.append(rec)

func get_record_count() -> int:
    return records.size()

func _to_fit_ts(unix_ms: int) -> int:
    return int(unix_ms / 1000.0) - FIT_EPOCH_OFFSET_S

func _fit_crc(data: PackedByteArray) -> int:
    var crc = 0
    for byte in data:
        var tmp = CRC_TABLE[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ CRC_TABLE[byte & 0xF]
        tmp = CRC_TABLE[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ CRC_TABLE[(byte >> 4) & 0xF]
    return crc

func export_fit() -> PackedByteArray:
    var buf = PackedByteArray()
    
    # Helpers
    var w8 = func(v: int): buf.append(v & 0xFF)
    var w16 = func(v: int): 
        buf.append(v & 0xFF)
        buf.append((v >> 8) & 0xFF)
    var w32 = func(v: int):
        buf.append(v & 0xFF)
        buf.append((v >> 8) & 0xFF)
        buf.append((v >> 16) & 0xFF)
        buf.append((v >> 24) & 0xFF)
        
    var write_def = func(local_type: int, global_mesg_num: int, fields: Array):
        w8.call(0x40 | local_type)
        w8.call(0x00)
        w8.call(0x00) # Little-endian
        w16.call(global_mesg_num)
        w8.call(fields.size())
        for f in fields:
            w8.call(f[0]) # field num
            var bt = f[1]
            var size = 1
            if bt == T_UINT16: size = 2
            elif bt == T_UINT32: size = 4
            w8.call(size)
            w8.call(bt)
            
    var write_val = func(bt: int, v):
        var raw = INVALID[bt] if v == null else int(round(v))
        if bt == T_UINT8 or bt == T_ENUM: w8.call(raw)
        elif bt == T_UINT16: w16.call(raw)
        elif bt == T_UINT32: w32.call(raw)

    # Stats
    var n = records.size()
    var last = records[n-1] if n > 0 else null
    var start_ts = _to_fit_ts(start_time_ms)
    var end_ts = _to_fit_ts(last["timestampMs"]) if last else start_ts
    var elapsed_s = max(0, end_ts - start_ts)
    var total_dist_m = last["distanceM"] if last else 0.0
    
    # 1. File ID
    write_def.call(0, 0, [[0, T_ENUM], [1, T_UINT16], [2, T_UINT16], [4, T_UINT32]])
    w8.call(0)
    write_val.call(T_ENUM, 4) # Activity
    write_val.call(T_UINT16, 255) # Dev
    write_val.call(T_UINT16, 1)
    write_val.call(T_UINT32, start_ts)
    
    # 2. Records
    var has_hr = false
    var has_alt = false
    for r in records:
        if r.get("heartRateBpm", 0) > 0: has_hr = true
        if r.get("altitudeM", 0.0) != 0.0: has_alt = true
        
    var record_fields = [
        [253, T_UINT32], # timestamp
        [6,   T_UINT16], # speed (m/s * 1000)
        [7,   T_UINT16], # power (W)
        [4,   T_UINT8],  # cadence
        [5,   T_UINT32], # distance (m * 100)
    ]
    if has_hr: record_fields.append([3, T_UINT8]) # heart rate
    if has_alt: record_fields.append([2, T_UINT16]) # altitude (m * 5 + 500)
    
    write_def.call(1, 20, record_fields)
    for r in records:
        w8.call(1)
        write_val.call(T_UINT32, _to_fit_ts(r["timestampMs"]))
        write_val.call(T_UINT16, r["speedMs"] * 1000)
        write_val.call(T_UINT16, r["powerW"])
        write_val.call(T_UINT8, r["cadenceRpm"])
        write_val.call(T_UINT32, r["distanceM"] * 100)
        if has_hr: write_val.call(T_UINT8, r.get("heartRateBpm", 0))
        if has_alt: write_val.call(T_UINT16, (r.get("altitudeM", 0.0) + 500.0) * 5.0)
        
    # 3. Lap
    write_def.call(2, 19, [
        [253, T_UINT32], [2, T_UINT32], [7, T_UINT32], [8, T_UINT32], [9, T_UINT32]
    ])
    w8.call(2)
    write_val.call(T_UINT32, end_ts)
    write_val.call(T_UINT32, start_ts)
    write_val.call(T_UINT32, elapsed_s * 1000)
    write_val.call(T_UINT32, elapsed_s * 1000)
    write_val.call(T_UINT32, total_dist_m * 100)
    
    # Assemble Header
    var data_size = buf.size()
    var header = PackedByteArray()
    header.append(0x0E) # size
    header.append(0x10) # protocol
    header.append(0x54) # profile LE
    header.append(0x08)
    header.append(data_size & 0xFF)
    header.append((data_size >> 8) & 0xFF)
    header.append((data_size >> 16) & 0xFF)
    header.append((data_size >> 24) & 0xFF)
    header.append_array(".FIT".to_utf8_buffer())
    
    var h_crc = _fit_crc(header)
    header.append(h_crc & 0xFF)
    header.append((h_crc >> 8) & 0xFF)
    
    var full_buf = header + buf
    var f_crc = _fit_crc(full_buf)
    full_buf.append(f_crc & 0xFF)
    full_buf.append((f_crc >> 8) & 0xFF)
    
    return full_buf
