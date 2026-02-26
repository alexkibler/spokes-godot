extends GutTest

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
		assert_not_null(instance, "Scene failed to instantiate (check onready vars): " + scene_path)
		
		if instance:
			passed_count += 1
			instance.queue_free()
			
	gut.p("Successfully smoke-tested %d scenes." % passed_count)

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
