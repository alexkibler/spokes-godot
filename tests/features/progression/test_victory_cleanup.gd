extends "res://addons/gut/test.gd"

func before_each() -> void:
	# Clear saves before each test
	for i: int in range(SaveManager.SLOT_COUNT):
		SaveManager.delete_save(i)
	RunManager.reset()

func test_victory_deletes_save_and_resets_manager() -> void:
	var slot: int = 1
	RunManager.start_new_run(3, 10.0, "normal", 200, 75.0, "metric")
	RunManager.current_slot_index = slot
	
	# Save the game
	SaveManager.save_game(slot)
	assert_true(SaveManager.has_save(slot), "Save should exist before victory")
	assert_true(RunManager.is_active_run, "Run should be active")
	assert_eq(RunManager.current_slot_index, slot, "Slot index should be set")
	
	# Instantiate VictoryScene to test its logic
	var victory_scene_script: GDScript = load("res://src/features/progression/VictoryScene.gd")
	var victory_scene: Control = Control.new()
	victory_scene.set_script(victory_scene_script)
	add_child(victory_scene)
	
	# Simulate pressing the return button
	victory_scene._on_return_pressed()
	
	# Verify
	assert_false(SaveManager.has_save(slot), "Save should be deleted after victory")
	assert_false(RunManager.is_active_run, "Run should not be active")
	assert_eq(RunManager.current_slot_index, -1, "Slot index should be reset")
	
	victory_scene.queue_free()
