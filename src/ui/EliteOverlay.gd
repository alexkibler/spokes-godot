extends CanvasLayer

# EliteOverlay.gd
# Shows the details of an Elite Challenge before the ride starts.

signal challenge_accepted(challenge: Dictionary)
signal challenge_declined

@onready var title_label: Label = %Title
@onready var flavor_label: Label = %FlavorText
@onready var condition_label: Label = %ConditionText
@onready var reward_label: Label = %RewardText
@onready var accept_btn: Button = %AcceptButton

var current_challenge: Dictionary = {}

func setup(challenge: Dictionary) -> void:
	current_challenge = challenge
	
	if is_inside_tree():
		_update_ui()
	else:
		ready.connect(_update_ui, CONNECT_ONE_SHOT)

func _update_ui() -> void:
	title_label.text = current_challenge.get("title", "ELITE CHALLENGE")
	flavor_label.text = current_challenge.get("flavorText", "")
	
	var ftp = RunManager.run_data.get("ftpW", 200)
	condition_label.text = EliteChallenge.format_challenge_text(current_challenge, ftp)
	
	var reward = current_challenge.get("reward", {})
	reward_label.text = "REWARD: " + reward.get("description", "??")
	
	if RunManager.autoplay_enabled:
		var pb = ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size.y = 8
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		accept_btn.add_child(pb)
		
		var tween = create_tween()
		tween.tween_property(pb, "value", 100.0, 2.0).from(0.0)
		
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_inside_tree():
				_on_accept_pressed()
		)

func _on_accept_pressed() -> void:
	challenge_accepted.emit(current_challenge)
	queue_free()

func _on_decline_pressed() -> void:
	challenge_declined.emit()
	queue_free()
