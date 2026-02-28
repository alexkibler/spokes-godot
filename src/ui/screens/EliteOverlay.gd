extends CanvasLayer

# EliteOverlay.gd
# Shows the details of an Elite Challenge before the ride starts.

signal challenge_accepted(challenge: EliteChallenge)
signal challenge_declined

@onready var title_label: Label = %Title
@onready var flavor_label: Label = %FlavorText
@onready var condition_label: Label = %ConditionText
@onready var reward_label: Label = %RewardText
@onready var accept_btn: Button = %AcceptButton

var current_challenge: EliteChallenge = null

func setup(challenge: EliteChallenge) -> void:
	current_challenge = challenge
	
	if is_inside_tree():
		_update_ui()
	else:
		ready.connect(_update_ui, CONNECT_ONE_SHOT)

func _update_ui() -> void:
	title_label.text = current_challenge.title
	flavor_label.text = current_challenge.flavor_text
	
	var ftp: int = int(RunManager.run_data.get("ftpW", 200))
	condition_label.text = current_challenge.format_text(ftp)
	
	reward_label.text = "REWARD: " + current_challenge.reward_description
	
	if RunManager.autoplay_enabled:
		var pb: ProgressBar = ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size.y = 8
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		accept_btn.add_child(pb)
		
		var tween: Tween = create_tween()
		tween.tween_property(pb, "value", 100.0, 2.0).from(0.0)
		
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if is_inside_tree():
				_on_accept_pressed()
		)
		
	accept_btn.grab_focus()

func _on_accept_pressed() -> void:
	challenge_accepted.emit(current_challenge)
	queue_free()

func _on_decline_pressed() -> void:
	challenge_declined.emit()
	queue_free()
