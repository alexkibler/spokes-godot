extends CanvasLayer

# DiscoveryOverlay.gd
# Pops up when a new item is added to inventory, allowing the player to equip it immediately.

signal choice_made

@onready var item_label: Label = %ItemLabel
@onready var desc_label: Label = %DescLabel
@onready var equip_btn: Button = %EquipButton
@onready var keep_btn: Button = %KeepButton

var current_item_id: String = ""

func setup(item_id: String) -> void:
	current_item_id = item_id
	var def: Dictionary = ContentRegistry.get_item(item_id)
	
	# These will be set once the scene is ready if setup is called from outside
	if is_inside_tree():
		_update_ui(def)
	else:
		ready.connect(func() -> void: _update_ui(def), CONNECT_ONE_SHOT)

func _update_ui(def: Dictionary) -> void:
	item_label.text = str(def["label"])
	desc_label.text = str(def["description"])
	
	var slot: String = def.get("slot", "none")
	var current: String = (RunManager.run_data["equipped"] as Dictionary).get(slot, "")
	if current != "":
		var c_def: Dictionary = ContentRegistry.get_item(current)
		keep_btn.text = "KEEP " + str(c_def["label"])
	else:
		keep_btn.text = "STASH IN BAG"

func _on_equip_pressed() -> void:
	RunManager.equip_item(current_item_id)
	choice_made.emit()
	queue_free()

func _on_keep_pressed() -> void:
	choice_made.emit()
	queue_free()
