extends CanvasLayer

# QuestCompleteOverlay.gd
# Pops up when a delivery quest is completed.

signal closed

@onready var cargo_label: Label = %CargoLabel
@onready var reward_label: Label = %RewardLabel
@onready var close_button: Button = %CloseButton

func setup(cargo_name: String, dest_name: String, reward_gold: int) -> void:
	if not is_inside_tree():
		await ready
	
	cargo_label.text = "Delivered %s to %s" % [cargo_name, dest_name]
	reward_label.text = "+%dg Reward" % reward_gold
	close_button.grab_focus()

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
