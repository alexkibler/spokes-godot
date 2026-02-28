extends CanvasLayer

# Port of RewardOverlay.ts
# Shows 3 random cards for the player to choose from.

signal reward_selected

@onready var card_container: HBoxContainer = $MarginContainer/VBoxContainer/CardContainer

var current_rewards: Array[Dictionary] = []
var is_autoplay_selecting: bool = false
var boss_reward_id: String = ""

func setup(is_boss_clear: bool = false, boss_name: String = "", p_boss_reward_id: String = "") -> void:
	boss_reward_id = p_boss_reward_id
	
	# Pick 3 rewards, forcing the boss unique item if applicable
	current_rewards = ContentRegistry.get_loot_pool(3, boss_reward_id)
	_render_cards()
	_check_autoplay()

	if is_boss_clear:
		var boss_label: Label = Label.new()
		if boss_name != "":
			boss_label.text = "🏆 %s DEFEATED! 🏆" % boss_name.to_upper()
		else:
			boss_label.text = "🏆 MEDAL EARNED! 🏆"
		boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boss_label.add_theme_font_size_override("font_size", 48)
		boss_label.add_theme_color_override("font_color", Color.GOLD)
		# Add at the top of the VBoxContainer
		var vbox: VBoxContainer = $MarginContainer/VBoxContainer
		vbox.add_child(boss_label)
		vbox.move_child(boss_label, 0)
		
		# Optional: Add spacing
		var spacer: Control = Control.new()
		spacer.custom_minimum_size.y = 20
		vbox.add_child(spacer)
		vbox.move_child(spacer, 1)

func _ready() -> void:
	SignalBus.autoplay_changed.connect(_on_autoplay_changed)
	# Initial _check_autoplay is now also handled in setup()

func _exit_tree() -> void:
	if SignalBus.autoplay_changed.is_connected(_on_autoplay_changed):
		SignalBus.autoplay_changed.disconnect(_on_autoplay_changed)

func _on_autoplay_changed(enabled: bool) -> void:
	if enabled:
		_check_autoplay()

func _check_autoplay() -> void:
	if not RunManager.autoplay_enabled or is_autoplay_selecting:
		return
		
	var best_r: Dictionary = RunManager.get_best_reward(current_rewards)
	if best_r.is_empty(): return
	
	is_autoplay_selecting = true
	var best_idx: int = 0
	for i in range(current_rewards.size()):
		if current_rewards[i]["id"] == best_r["id"]:
			best_idx = i
			break
			
	# Add indicator after cards are rendered
	if card_container.get_child_count() > best_idx:
		_start_autoplay_timer(best_idx, best_r["id"])
	else:
		# Wait for render
		get_tree().process_frame.connect(func() -> void:
			if card_container.get_child_count() > best_idx:
				_start_autoplay_timer(best_idx, best_r["id"])
		, CONNECT_ONE_SHOT)

func _start_autoplay_timer(idx: int, reward_id: String) -> void:
	var target_card: Button = card_container.get_child(idx)
	var pb: ProgressBar = ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size.y = 8
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	target_card.add_child(pb)
	
	var tween: Tween = create_tween()
	tween.tween_property(pb, "value", 100.0, 2.0).from(0.0)

	# Auto-pick best card after delay
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_inside_tree() and RunManager.autoplay_enabled:
			_on_card_pressed(reward_id)
		else:
			# If autoplay was disabled during the timer, cleanup
			is_autoplay_selecting = false
			pb.queue_free()
	)

func _render_cards() -> void:
	# Clear existing
	for child: Node in card_container.get_children():
		child.queue_free()
		
	for r: Dictionary in current_rewards:
		var card: Button = Button.new()
		card.custom_minimum_size = Vector2(280, 400)
		card.text = str(r["label"]) + "\n\n" + str(r["description"]) + "\n\n[" + str(r["rarity"]).to_upper() + "]"
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		# Rarity Colors
		var color: Color = Color.WHITE
		match str(r["rarity"]):
			"common": color = Color("#bdc3c7")   # Silver
			"uncommon": color = Color("#3498db") # Blue
			"rare": color = Color("#f1c40f")     # Gold
			
		# StyleBox for the Card
		var style: StyleBoxFlat = StyleBoxFlat.new()
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
		
		var hover_style: StyleBoxFlat = style.duplicate()
		hover_style.bg_color = Color(0.2, 0.2, 0.25, 1.0)
		
		card.add_theme_stylebox_override("normal", style)
		card.add_theme_stylebox_override("hover", hover_style)
		card.add_theme_stylebox_override("pressed", hover_style)
		card.add_theme_color_override("font_color", Color.WHITE)
		card.add_theme_font_size_override("font_size", 18)
			
		card.pressed.connect(_on_card_pressed.bind(r["id"]))
		card_container.add_child(card)

	if card_container.get_child_count() > 0:
		(card_container.get_child(0) as Control).grab_focus()

func _on_card_pressed(reward_id: String) -> void:
	ContentRegistry.apply_reward(reward_id)
	reward_selected.emit()
	queue_free()
