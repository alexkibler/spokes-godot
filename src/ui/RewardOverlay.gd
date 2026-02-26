extends CanvasLayer

# Port of RewardOverlay.ts
# Shows 3 random cards for the player to choose from.

signal reward_selected

@onready var card_container: HBoxContainer = $MarginContainer/VBoxContainer/CardContainer

var current_rewards: Array = []

func _ready() -> void:
	# Pick 3 random rewards
	current_rewards = ContentRegistry.get_loot_pool(3)
	_render_cards()
	
	if RunManager.autoplay_enabled:
		var best_r = RunManager.get_best_reward(current_rewards)
		var best_idx = 0
		for i in range(current_rewards.size()):
			if current_rewards[i]["id"] == best_r["id"]:
				best_idx = i
				break
				
		# Add indicator after cards are rendered
		get_tree().process_frame.connect(func():
			if card_container.get_child_count() > best_idx:
				var target_card = card_container.get_child(best_idx)
				var pb = ProgressBar.new()
				pb.show_percentage = false
				pb.custom_minimum_size.y = 8
				pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
				pb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
				target_card.add_child(pb)
				
				var tween = create_tween()
				tween.tween_property(pb, "value", 100.0, 2.0).from(0.0)
		, CONNECT_ONE_SHOT)

		# Auto-pick best card after delay
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_inside_tree() and not best_r.is_empty():
				_on_card_pressed(best_r["id"])
		)

func _render_cards() -> void:
	# Clear existing
	for child in card_container.get_children():
		child.queue_free()
		
	for r in current_rewards:
		var card = Button.new()
		card.custom_minimum_size = Vector2(280, 400)
		card.text = r["label"] + "\n\n" + r["description"] + "\n\n[" + r["rarity"].to_upper() + "]"
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		# Rarity Colors
		var color = Color.WHITE
		match r["rarity"]:
			"common": color = Color("#bdc3c7")   # Silver
			"uncommon": color = Color("#3498db") # Blue
			"rare": color = Color("#f1c40f")     # Gold
			
		# StyleBox for the Card
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = color
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.content_margin_left = 20
		style.content_margin_right = 20
		
		var hover_style = style.duplicate()
		hover_style.bg_color = Color(0.2, 0.2, 0.25, 1.0)
		
		card.add_theme_stylebox_override("normal", style)
		card.add_theme_stylebox_override("hover", hover_style)
		card.add_theme_stylebox_override("pressed", hover_style)
		card.add_theme_color_override("font_color", Color.WHITE)
		card.add_theme_font_size_override("font_size", 18)
			
		card.pressed.connect(_on_card_pressed.bind(r["id"]))
		card_container.add_child(card)

func _on_card_pressed(reward_id: String) -> void:
	ContentRegistry.apply_reward(reward_id)
	reward_selected.emit()
	queue_free()
