extends CanvasLayer

# Port of ShopOverlay.ts
# Allows buying items and upgrades.

signal closed

@onready var gold_label: Label = %GoldLabel
@onready var catalog_container: VBoxContainer = %CatalogContainer
@onready var inventory_container: VBoxContainer = %InventoryContainer

const CATALOG = [
	{ "id": "tailwind",        "label": "Tailwind",        "desc": "2x Power toggle", "price": 100, "stackable": false },
	{ "id": "aero_helmet",     "label": "Aero Helmet",     "desc": "+3% Drag reduction", "price": 60, "stackable": true },
	{ "id": "carbon_frame",    "label": "Carbon Frame",    "desc": "-12% Weight, +3% Aero", "price": 150, "stackable": true },
	{ "id": "stat_power_1",    "label": "Energy Gel",      "desc": "+4% Power permanent", "price": 80, "stackable": true }
]

func _ready() -> void:
	refresh_all()
	
	if RunManager.autoplay_enabled:
		var pb = ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size.y = 8
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		# Find the close button by path or reference
		var close_btn = get_node("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton")
		close_btn.add_child(pb)
		
		var tween = create_tween()
		tween.tween_property(pb, "value", 100.0, 1.5).from(0.0)
		
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_inside_tree():
				_on_close_pressed()
		)

func refresh_all() -> void:
	var run = RunManager.get_run()
	gold_label.text = "GOLD: " + str(run["gold"])
	
	_build_catalog()
	_build_inventory()

func _build_catalog() -> void:
	for child in catalog_container.get_children():
		child.queue_free()
		
	var run = RunManager.get_run()
	
	for item in CATALOG:
		var owned_count = 0
		for inv_id in run["inventory"]:
			if inv_id == item["id"]: owned_count += 1
			
		var price = int(item["price"] * pow(1.5, owned_count))
		var can_afford = run["gold"] >= price
		var sold_out = not item["stackable"] and owned_count > 0
		
		var btn = Button.new()
		btn.custom_minimum_size.y = 60
		
		if sold_out:
			btn.text = item["label"] + "\n✓ OWNED"
			btn.disabled = true
		else:
			var owned_str = " (x" + str(owned_count) + ")" if owned_count > 0 else ""
			btn.text = item["label"] + owned_str + "\n" + item["desc"] + " - " + str(price) + "g"
			btn.disabled = not can_afford
			
		btn.pressed.connect(_on_buy_pressed.bind(item, price))
		catalog_container.add_child(btn)

func _build_inventory() -> void:
	for child in inventory_container.get_children():
		child.queue_free()
		
	var run = RunManager.get_run()
	var counts = {}
	for id in run["inventory"]:
		counts[id] = counts.get(id, 0) + 1
		
	if counts.is_empty():
		var l = Label.new()
		l.text = "-- empty --"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inventory_container.add_child(l)
		return
		
	for id in counts:
		var hbox = HBoxContainer.new()
		var l = Label.new()
		l.text = id.capitalize() + " x" + str(counts[id])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(l)
		
		var sell_btn = Button.new()
		var sell_price = 0
		for item in CATALOG:
			if item["id"] == id:
				sell_price = int(item["price"] / 2)
				break
		
		sell_btn.text = "SELL " + str(sell_price) + "g"
		sell_btn.pressed.connect(_on_sell_pressed.bind(id, sell_price))
		hbox.add_child(sell_btn)
		
		inventory_container.add_child(hbox)

func _on_buy_pressed(item: Dictionary, price: int) -> void:
	if RunManager.spend_gold(price):
		# Access RewardManager explicitly via the Root to avoid potential parse issues
		var rm = get_node("/root/RewardManager")
		
		# Special case: permanent stat boosts apply immediately
		if item["id"].begins_with("stat_"):
			rm.apply_reward(item["id"])
		else:
			RunManager.add_to_inventory(item["id"])
			
		refresh_all()

func _on_sell_pressed(id: String, price: int) -> void:
	var inv = RunManager.run_data["inventory"]
	var idx = inv.find(id)
	if idx != -1:
		inv.remove_at(idx)
		RunManager.add_gold(price)
		refresh_all()

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
