extends CanvasLayer

# Port of EventOverlay.ts
# Handle purple node "Risk vs Reward" scenarios.

signal closed

@onready var title_label: Label = %Title
@onready var desc_label: Label = %Description
@onready var attempt_btn: Button = %AttemptButton
@onready var outcome_panel: PanelContainer = %OutcomePanel
@onready var outcome_title: Label = %OutcomeTitle
@onready var outcome_desc: Label = %OutcomeDesc

var current_item: Dictionary = {}
var success_chance: float = 0.9

func _ready() -> void:
	outcome_panel.visible = false
	_pick_event()
	
	if RunManager.autoplay_enabled:
		var pb = ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size.y = 6
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		attempt_btn.add_child(pb)
		
		var tween = create_tween()
		tween.tween_property(pb, "value", 100.0, 2.0).from(0.0)
		
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_inside_tree() and not outcome_panel.visible:
				_on_attempt_pressed()
		)

func _pick_event() -> void:
	var items = []
	for id in ContentRegistry.items:
		var def = ContentRegistry.get_item(id)
		if def.has("slot"): items.append(def)
		
	if items.is_empty():
		queue_free()
		return
		
	# Logic from pickEventItem: weight by progress
	var run = RunManager.get_run()
	var current_floor = run.get("visitedNodeIds", []).size()
	var total_floors = run.get("runLength", 10)
	var progress = float(current_floor) / float(max(1, total_floors))
	
	var weighted_items = []
	for item in items:
		var weight = 0.0
		var r = item.get("rarity", "common")
		if r == "common": weight = 100.0 * (1.0 - progress * 0.5)
		elif r == "uncommon": weight = 20.0 + progress * 80.0
		elif r == "rare": weight = max(0.0, (progress - 0.2) * 100.0)
		weighted_items.append({"item": item, "weight": weight})
		
	var total_weight = 0.0
	for entry in weighted_items: total_weight += entry["weight"]
	
	var rand = randf() * total_weight
	current_item = items[0]
	for entry in weighted_items:
		if rand < entry["weight"]:
			current_item = entry["item"]
			break
		rand -= entry["weight"]
		
	# Success chance by rarity
	var r = current_item.get("rarity", "common")
	success_chance = 0.9
	if r == "uncommon": success_chance = 0.7
	elif r == "rare": success_chance = 0.5
	
	title_label.text = "SHADY MECHANIC"
	desc_label.text = "A mysterious mechanic offers you a " + current_item["label"] + " if you let him 'tune' your bike. It looks risky..."
	attempt_btn.text = "ATTEMPT (%d%% CHANCE)" % int(success_chance * 100)

func _on_attempt_pressed() -> void:
	var roll = randf()
	if roll < success_chance:
		# Success!
		RunManager.add_to_inventory(current_item["id"])
		_show_outcome("SUCCESS!", "The mechanic was a genius! You received: " + current_item["label"], true)
	else:
		# Failure
		var run = RunManager.get_run()
		if run["gold"] >= 50:
			RunManager.spend_gold(50)
			_show_outcome("FAILURE", "He stripped the bolts and charged you 50g for the 'labor'.", false)
		else:
			RunManager.apply_modifier({"powerMult": 0.95}, "INJURY")
			_show_outcome("FAILURE", "He dropped a wrench on your foot. -5% Power.", false)

func _show_outcome(title: String, desc: String, success: bool) -> void:
	outcome_panel.visible = true
	outcome_title.text = title
	outcome_desc.text = desc
	outcome_title.add_theme_color_override("font_color", Color.GREEN if success else Color.RED)
	
	if RunManager.autoplay_enabled:
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_inside_tree():
				_on_close_pressed()
		)

func _on_leave_pressed() -> void:
	_on_close_pressed()

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
