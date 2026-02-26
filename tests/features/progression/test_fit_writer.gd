extends GutTest

# Tests ported from ~/Repos/spokes/src/fit/__tests__/FitWriter.test.ts

const START_MS = 1700000000000

func make_record(overrides: Dictionary = {}) -> Dictionary:
	var rec: Dictionary = {
		"timestampMs": START_MS + 1000,
		"powerW": 200,
		"cadenceRpm": 90,
		"speedMs": 8.33,
		"distanceM": 100.0,
		"heartRateBpm": 0,
		"altitudeM": 0.0
	}
	for key: String in overrides:
		rec[key] = overrides[key]
	return rec

# ─── FitWriter construction ────────────────────────────────────────────────────

func test_construction() -> void:
	var fw: FitWriter = autofree(FitWriter.new(START_MS))
	assert_eq(fw.get_record_count(), 0, "starts with zero records")

# ─── add_record / get_record_count ──────────────────────────────────────────────

func test_add_record() -> void:
	var fw: FitWriter = autofree(FitWriter.new(START_MS))
	fw.add_record(make_record())
	assert_eq(fw.get_record_count(), 1)
	fw.add_record(make_record())
	assert_eq(fw.get_record_count(), 2)

# ─── export_fit() – basic structure ──────────────────────────────────────────────

func test_export_basic_structure() -> void:
	var fw: FitWriter = autofree(FitWriter.new(START_MS))
	var data: PackedByteArray = fw.export_fit()
	assert_true(data is PackedByteArray, "returns a PackedByteArray")
	assert_gt(data.size(), 16, "at least 16 bytes (14 header + 2 file CRC)")
	assert_eq(data[0], 0x0E, "header size 14")
	assert_eq(data[1], 0x10, "protocol version 0x10")
	
	# magic bytes 8–11 spell ".FIT"
	assert_eq(data[8], 0x2e, "'.' at 8")
	assert_eq(data[9], 0x46, "'F' at 9")
	assert_eq(data[10], 0x49, "'I' at 10")
	assert_eq(data[11], 0x54, "'T' at 11")

func test_data_size_header() -> void:
	var fw: FitWriter = autofree(FitWriter.new(START_MS))
	fw.add_record(make_record())
	var data: PackedByteArray = fw.export_fit()
	
	var data_size: int = data[4] | (data[5] << 8) | (data[6] << 16) | (data[7] << 24)
	assert_gt(data_size, 0, "data size should be non-zero")
	
	var expected_data_size: int = data.size() - 14 - 2 # 14 header, 2 file crc
	assert_eq(data_size, expected_data_size, "header data size should match actual data size")

func test_optional_fields() -> void:
	# Godot implementation of FitWriter currently does NOT handle HR or Altitude
	# based on the read_file output. It only exports timestamp, speed, power, cadence, distance.
	# So these tests SHOULD fail if we check for file size increase.
	
	var base: FitWriter = autofree(FitWriter.new(START_MS))
	base.add_record(make_record({"heartRateBpm": 0, "altitudeM": 0.0}))
	var base_data: PackedByteArray = base.export_fit()
	
	var with_hr: FitWriter = autofree(FitWriter.new(START_MS))
	with_hr.add_record(make_record({"heartRateBpm": 150, "altitudeM": 0.0}))
	var with_hr_data: PackedByteArray = with_hr.export_fit()
	
	# This might fail in Godot if it doesn't implement HR
	assert_gt(with_hr_data.size(), base_data.size(), "HR data should increase file size")
	
	var with_alt: FitWriter = autofree(FitWriter.new(START_MS))
	with_alt.add_record(make_record({"heartRateBpm": 0, "altitudeM": 500.0}))
	var with_alt_data: PackedByteArray = with_alt.export_fit()
	
	assert_gt(with_alt_data.size(), base_data.size(), "Altitude data should increase file size")

func test_crc_presence() -> void:
	var fw: FitWriter = autofree(FitWriter.new(START_MS))
	fw.add_record(make_record())
	var data: PackedByteArray = fw.export_fit()
	
	var header_crc: int = data[12] | (data[13] << 8)
	assert_ne(header_crc, 0, "header CRC should be non-zero")
	
	var file_crc: int = data[data.size() - 2] | (data[data.size() - 1] << 8)
	assert_ne(file_crc, 0, "file CRC should be non-zero")

func test_empty_export() -> void:
	var fw: FitWriter = autofree(FitWriter.new(START_MS))
	var data: PackedByteArray = fw.export_fit()
	assert_gt(data.size(), 16)
	
	var data2: PackedByteArray = fw.export_fit()
	assert_eq(data, data2, "repeated export should be identical")
