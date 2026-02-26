extends "res://addons/gut/test.gd"

const TEST_SAVE_DIR: String = "user://test_saves/"

func before_all() -> void:
	# Ensure the test save directory exists
	if not DirAccess.dir_exists_absolute(TEST_SAVE_DIR):
		DirAccess.make_dir_absolute(TEST_SAVE_DIR)
	
	# Override SAVE_DIR in SaveManager if possible, but it's a constant.
	# For now, we'll just test the SaveManager as is, which uses user://saves/
	pass

func before_each() -> void:
	# Clear saves before each test
	for i: int in range(SaveManager.SLOT_COUNT):
		SaveManager.delete_save(i)

func test_save_and_load() -> void:
	var slot: int = 0
	assert_false(SaveManager.has_save(slot), "Slot should be empty initially")
	
	# Mock data in RunManager
	RunManager.start_new_run(3, 10.0, "normal", 200, 75.0, "metric")
	var initial_run_data: Dictionary = RunManager.get_run().duplicate(true)
	initial_run_data["gold"] = 123 # Manually set some data
	RunManager.run_data["gold"] = 123
	
	SaveManager.save_game(slot)
	assert_true(SaveManager.has_save(slot), "Slot should have a save file now")
	
	# Reset RunManager
	RunManager.reset()
	assert_eq(int(RunManager.get_run().get("gold", 0)), 0, "RunManager should be reset")
	
	var success: bool = SaveManager.load_game(slot)
	assert_true(success, "Load game should return true")
	assert_eq(int(RunManager.get_run()["gold"]), 123, "Loaded gold should match saved gold")

func test_slot_metadata() -> void:
	var slot: int = 1
	RunManager.start_new_run(2, 5.5, "hard", 250, 80.0, "imperial")
	RunManager.add_gold(50)
	SaveManager.save_game(slot)
	
	var metadata: Dictionary = SaveManager.get_slot_metadata(slot)
	assert_false(metadata.is_empty(), "Metadata should not be empty")
	assert_eq(int(metadata["gold"]), 50, "Metadata gold should match")
	assert_eq(float(metadata["distance"]), 5.5, "Metadata distance should match")
	assert_eq(str(metadata["difficulty"]), "hard", "Metadata difficulty should match")
	assert_true(metadata.has("timestamp"), "Metadata should have a timestamp")

func test_delete_save() -> void:
	var slot: int = 2
	RunManager.start_new_run(3, 10.0, "normal", 200, 75.0, "metric")
	SaveManager.save_game(slot)
	assert_true(SaveManager.has_save(slot), "Save should exist")
	
	SaveManager.delete_save(slot)
	assert_false(SaveManager.has_save(slot), "Save should be deleted")
