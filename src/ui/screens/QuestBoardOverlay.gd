extends CanvasLayer

# Quest Board: generates 2-3 delivery quests between shop nodes and lets the player accept one.

signal quest_accepted
signal closed
signal close_pressed

@onready var quest_container: VBoxContainer = %QuestContainer
@onready var gold_label: Label = %GoldLabel
@onready var status_label: Label = %StatusLabel

const MIN_QUESTS: int = 2
const MAX_QUESTS: int = 3
const BASE_GOLD: int = 50
const WEIGHT_PAYOUT_PER_KG: float = 15.0
const CROSS_SPOKE_PAYOUT: int = 200
const SAME_SPOKE_PAYOUT: int = 50

var _generated_quests: Array[Dictionary] = []

func _ready() -> void:
	var run: Dictionary = RunManager.get_run()
	gold_label.text = "GOLD: " + str(run.get("gold", 0))

	if not RunManager.active_quest.is_empty():
		status_label.text = "Active delivery in progress. Complete it first!"
		status_label.visible = true
		_build_active_quest_display()
	else:
		status_label.visible = false
		_generate_quests()
		_build_quest_list()

## Generate 2-3 delivery quests targeting reachable shop nodes.
func _generate_quests() -> void:
	_generated_quests.clear()
	var run: Dictionary = RunManager.get_run()
	var nodes: Array = run.get("nodes", [])
	var current_id: String = run.get("currentNodeId", "")
	var visited_ids: Array = run.get("visitedNodeIds", [])

	# Find current node metadata for cross-spoke detection
	var current_node: Dictionary = _find_node(nodes, current_id)
	var current_spoke: String = current_node.get("metadata", {}).get("spokeId", "")

	# Gather eligible destination shop nodes (type == "shop", not the current node)
	var shop_nodes: Array[Dictionary] = []
	for n: Dictionary in nodes:
		if n.get("type", "") == "shop" and n["id"] != current_id:
			shop_nodes.append(n)

	if shop_nodes.is_empty():
		return

	# Shuffle so we get varied options
	shop_nodes.shuffle()
	var count: int = mini(MAX_QUESTS, shop_nodes.size())
	count = maxi(count, mini(MIN_QUESTS, shop_nodes.size()))

	# Pick cargo options (random selection from CARGO_ITEMS)
	var cargo_pool: Array[Dictionary] = []
	for c: Dictionary in ContentRegistry.CARGO_ITEMS:
		cargo_pool.append(c)
	cargo_pool.shuffle()

	for i: int in range(count):
		var dest_node: Dictionary = shop_nodes[i]
		var dest_spoke: String = dest_node.get("metadata", {}).get("spokeId", "")
		var cargo: Dictionary = cargo_pool[i % cargo_pool.size()]

		var is_cross_spoke: bool = (current_spoke != dest_spoke) and dest_spoke != ""
		var weight_payout: float = cargo["weight_kg"] * WEIGHT_PAYOUT_KG()
		var distance_payout: int = CROSS_SPOKE_PAYOUT if is_cross_spoke else SAME_SPOKE_PAYOUT
		var total_reward: int = int(BASE_GOLD + weight_payout + distance_payout)

		var dest_name: String = _get_node_display_name(dest_node)
		var is_visited: bool = dest_node["id"] in visited_ids

		_generated_quests.append({
			"destination_id": dest_node["id"],
			"destination_name": dest_name,
			"cargo_name": cargo["name"] as String,
			"cargo_weight_kg": cargo["weight_kg"] as float,
			"reward_gold": total_reward,
			"is_cross_spoke": is_cross_spoke,
			"is_visited": is_visited,
			"dest_node": dest_node,
		})

func WEIGHT_PAYOUT_KG() -> float:
	return WEIGHT_PAYOUT_PER_KG

## Build the UI showing generated quests.
func _build_quest_list() -> void:
	for child: Node in quest_container.get_children():
		child.queue_free()

	if _generated_quests.is_empty():
		var lbl: Label = Label.new()
		lbl.text = "No delivery destinations available."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quest_container.add_child(lbl)
		return

	for quest: Dictionary in _generated_quests:
		quest_container.add_child(_build_quest_row(quest))

## Builds a single quest row widget.
func _build_quest_row(quest: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	# Info column
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# Destination + visited tag
	var dest_hbox: HBoxContainer = HBoxContainer.new()
	info_vbox.add_child(dest_hbox)

	var dest_lbl: Label = Label.new()
	dest_lbl.text = "→ " + (quest["destination_name"] as String)
	dest_lbl.add_theme_color_override("font_color", Color.WHITE)
	dest_lbl.add_theme_font_size_override("font_size", 18)
	dest_hbox.add_child(dest_lbl)

	var tag_lbl: Label = Label.new()
	tag_lbl.text = " [Visited]" if quest["is_visited"] else " [Unexplored]"
	tag_lbl.add_theme_color_override("font_color", Color.LIGHT_GRAY if quest["is_visited"] else Color.YELLOW)
	tag_lbl.add_theme_font_size_override("font_size", 12)
	dest_hbox.add_child(tag_lbl)

	# Cargo info
	var cargo_lbl: Label = Label.new()
	cargo_lbl.text = "%s  |  %.1f kg  |  %dg reward" % [
		quest["cargo_name"] as String,
		quest["cargo_weight_kg"] as float,
		quest["reward_gold"] as int,
	]
	cargo_lbl.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	cargo_lbl.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(cargo_lbl)

	# Cross-spoke badge
	if quest["is_cross_spoke"]:
		var cross_lbl: Label = Label.new()
		cross_lbl.text = "Cross-Spoke Bonus"
		cross_lbl.add_theme_color_override("font_color", Color.MAGENTA)
		cross_lbl.add_theme_font_size_override("font_size", 12)
		info_vbox.add_child(cross_lbl)

	# Button column
	var btn_vbox: VBoxContainer = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(btn_vbox)

	var accept_btn: Button = Button.new()
	accept_btn.text = "ACCEPT"
	accept_btn.custom_minimum_size = Vector2(100, 40)
	accept_btn.pressed.connect(_on_accept_quest.bind(quest))
	btn_vbox.add_child(accept_btn)

	var locate_btn: Button = Button.new()
	locate_btn.text = "LOCATE"
	locate_btn.custom_minimum_size = Vector2(100, 40)
	locate_btn.pressed.connect(_on_locate_quest.bind(quest))
	btn_vbox.add_child(locate_btn)

	return panel

## Display currently active quest (read-only).
func _build_active_quest_display() -> void:
	for child: Node in quest_container.get_children():
		child.queue_free()

	var quest: Dictionary = RunManager.active_quest
	var panel: PanelContainer = PanelContainer.new()
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "ACTIVE DELIVERY"
	title.add_theme_color_override("font_color", Color.MAGENTA)
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var info: Label = Label.new()
	info.text = "%s  →  %s  (%.1f kg)  |  %dg on delivery" % [
		quest.get("cargo_name", "?") as String,
		quest.get("destination_name", "?") as String,
		quest.get("cargo_weight_kg", 0.0) as float,
		quest.get("reward_gold", 0) as int,
	]
	info.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(info)

	quest_container.add_child(panel)

func _on_accept_quest(quest: Dictionary) -> void:
	# Strip internal-only keys before storing
	var quest_data: Dictionary = {
		"destination_id": quest["destination_id"] as String,
		"destination_name": quest["destination_name"] as String,
		"cargo_name": quest["cargo_name"] as String,
		"cargo_weight_kg": quest["cargo_weight_kg"] as float,
		"reward_gold": quest["reward_gold"] as int,
	}
	RunManager.accept_quest(quest_data)
	quest_accepted.emit()
	closed.emit()
	queue_free()

var _locating: bool = false

func _on_locate_quest(quest: Dictionary) -> void:
	# Temporarily hide overlay, highlight destination on map, then restore on next click/tap.
	visible = false
	_locating = true

	# Find MapScene in the tree to set selected_node_id
	var map_scene: Node = _find_map_scene()
	if map_scene != null:
		map_scene.set("selected_node_id", quest["destination_id"] as String)
		var dest_node: Dictionary = quest.get("dest_node", {})
		if not dest_node.is_empty():
			var hud: Node = map_scene.get_node_or_null("MapHUD")
			if hud and hud.has_method("update_selected_node_name"):
				hud.update_selected_node_name(dest_node)
		map_scene.call("queue_redraw")

func _input(event: InputEvent) -> void:
	if not _locating: return
	if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or \
	   (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		_locating = false
		visible = true
		get_viewport().set_input_as_handled()

## Find the MapScene by checking the current scene root and parent chain.
func _find_map_scene() -> Node:
	# Check current scene root first
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.get_script() != null:
		if (current_scene.get_script() as Script).get_path().ends_with("MapScene.gd"):
			return current_scene
	# Fall back to traversing parent chain
	var node: Node = get_parent()
	while node != null:
		if node.get_script() != null:
			if (node.get_script() as Script).get_path().ends_with("MapScene.gd"):
				return node
		node = node.get_parent()
	return null

func _find_node(nodes: Array, id: String) -> Dictionary:
	for n: Dictionary in nodes:
		if n["id"] == id:
			return n
	return {}

func _get_node_display_name(node: Dictionary) -> String:
	var node_type: String = node.get("type", "")
	var spoke_id: String = node.get("metadata", {}).get("spokeId", "")

	match node_type:
		"start":
			return "Hub"
		"finish":
			return "Final Boss"
		_:
			if spoke_id != "":
				var biome: String = spoke_id.capitalize()
				match node_type:
					"boss": return biome + " Boss"
					"shop": return biome + " Shop"
					"event": return biome + " Event"
					"hard": return biome + " Challenge"
					_: return biome + " Trail"
			return node_type.capitalize()

func _on_close_pressed() -> void:
	close_pressed.emit()
	closed.emit()
	queue_free()
