extends Node

const SAVE_DIR = "user://saves/"
const SLOT_COUNT = 3

func _ready() -> void:
	# Ensure the save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

func get_save_path(slot_index: int) -> String:
	return SAVE_DIR + "slot_%d.sav" % slot_index

## Checks if a slot has a valid save file
func has_save(slot_index: int) -> bool:
	return FileAccess.file_exists(get_save_path(slot_index))

## Returns metadata for the UI (Zelda-style: Gold, Distance, Difficulty)
func get_slot_metadata(slot_index: int) -> Dictionary:
	if not has_save(slot_index):
		return {}

	var file: FileAccess = FileAccess.open(get_save_path(slot_index), FileAccess.READ)
	if not file:
		return {}

	var text: String = file.get_as_text()
	var data: Variant = JSON.parse_string(text)

	if data and typeof(data) == TYPE_DICTIONARY:
		var dict: Dictionary = data
		return {
			"gold": dict.get("gold", 0),
			"distance": dict.get("totalDistanceKm", 0.0),
			"difficulty": dict.get("difficulty", "normal"),
			"timestamp": FileAccess.get_modified_time(get_save_path(slot_index))
		}
	return {}

func save_game(slot_index: int) -> void:
	var path: String = get_save_path(slot_index)
	var data: Dictionary = RunManager.get_run() # Fetches the current run_data
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_game(slot_index: int) -> bool:
	var path: String = get_save_path(slot_index)
	if not FileAccess.file_exists(path): return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file: return false

	var data: Variant = JSON.parse_string(file.get_as_text())
	if data and typeof(data) == TYPE_DICTIONARY:
		# RunManager must implement load_run_data
		if RunManager.has_method("load_run_data"):
			RunManager.load_run_data(data as Dictionary)
			return true
	return false

func delete_save(slot_index: int) -> void:
	if has_save(slot_index):
		DirAccess.remove_absolute(get_save_path(slot_index))
