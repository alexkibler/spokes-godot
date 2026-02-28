extends CanvasLayer

signal resume_requested
signal quit_requested

@onready var resume_btn: Button = %ResumeButton
@onready var quit_btn: Button = %QuitButton
@onready var quit_map_btn: Button = %QuitMapButton
@onready var autoplay_toggle: CheckButton = %AutoplayToggle

func _ready() -> void:
	resume_btn.pressed.connect(_on_resume_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	quit_map_btn.pressed.connect(_on_quit_map_pressed)
	
	autoplay_toggle.button_pressed = RunManager.autoplay_enabled
	autoplay_toggle.toggled.connect(_on_autoplay_toggled)
	
	# Only show "Quit to Map" if we are in a GameScene
	var current_scene: Node = get_tree().current_scene
	quit_map_btn.visible = current_scene and current_scene.name == "GameScene"
	
	get_tree().paused = true
	resume_btn.grab_focus()

func _exit_tree() -> void:
	get_tree().paused = false

func _on_resume_pressed() -> void:
	get_tree().paused = false
	resume_requested.emit()
	queue_free()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	quit_requested.emit()
	get_tree().change_scene_to_file("res://src/ui/screens/MenuScene.tscn")
	queue_free()

func _on_quit_map_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/features/map/MapScene.tscn")
	queue_free()

func _on_autoplay_toggled(enabled: bool) -> void:
	RunManager.set_autoplay_enabled(enabled)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_autoplay"):
		autoplay_toggle.button_pressed = not autoplay_toggle.button_pressed
		get_viewport().set_input_as_handled()
		
	if event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()
