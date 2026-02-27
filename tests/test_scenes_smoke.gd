extends GutTest

func before_each() -> void:
	# Initialize RunManager with a basic state so UI scenes don't crash on _ready
	RunManager.start_new_run(2, 20.0, "normal", 200, 75.0, "metric")
	# Some scenes expect an active edge
	var edge: Dictionary = RunManager.run_data["edges"][0]
	RunManager.set_active_edge(edge)

func after_each() -> void:
	RunManager.reset()

## Instantiates every .tscn file in the src/ directory to catch broken onready paths or script errors.
func test_all_scenes_instantiate_without_errors() -> void:
	var scenes: Array[String] = _get_all_tscn_files("res://src/")
	var passed_count: int = 0
	
	for scene_path: String in scenes:
		var packed_scene: PackedScene = load(scene_path)
		if not packed_scene:
			fail_test("Could not load scene: " + scene_path)
			continue
			
		var instance: Node = packed_scene.instantiate()
		assert_not_null(instance, "Scene failed to instantiate: " + scene_path)
		
		if instance:
			# Add to the SceneTree and wait a frame to trigger _ready() and node initialization
			add_child_autofree(instance)
			await get_tree().process_frame
			
			passed_count += 1
			
	gut.p("Successfully smoke-tested %d scenes." % passed_count)

## Attempts to load every .gd file to catch syntax or compilation errors early.
func test_all_scripts_compile_and_load() -> void:
	var scripts: Array[String] = _get_all_gd_files("res://src/")
	var passed_count: int = 0
	
	for script_path: String in scripts:
		var script: GDScript = load(script_path)
		assert_not_null(script, "Script failed to load/compile (check syntax): " + script_path)
		
		if script:
			passed_count += 1
			
	gut.p("Successfully checked %d scripts for syntax errors." % passed_count)

func _get_all_tscn_files(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				files.append_array(_get_all_tscn_files(path + file_name + "/"))
			elif file_name.ends_with(".tscn"):
				files.append(path + file_name)
			file_name = dir.get_next()
	return files

func _get_all_gd_files(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				files.append_array(_get_all_gd_files(path + file_name + "/"))
			elif file_name.ends_with(".gd"):
				files.append(path + file_name)
			file_name = dir.get_next()
	return files
