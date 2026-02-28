extends CanvasLayer

# Port of EquipmentOverlay.ts
# Shows equipped items and inventory for gear management.

signal closed

@onready var slot_container: HBoxContainer = %SlotContainer
@onready var inventory_list: VBoxContainer = %InventoryList

const ALL_SLOTS: Array[String] = ["Rider", "Frame", "Wheels", "Handlebars", "Crank"]
const SLOT_LABELS: Dictionary = {
	"Rider": "HELMET",
	"Frame": "FRAME",
	"Wheels": "WHEELS",
	"Handlebars": "BARS",
	"Crank": "CRANK"
}

func _ready() -> void:
	refresh_all()
	SignalBus.inventory_changed.connect(refresh_all)

func refresh_all() -> void:
	# Ensure the container is ready (might be called via signal before @onready)
	if is_inside_tree():
		_build_slots()
		_build_inventory()
		
		if not get_viewport().gui_get_focus_owner():
			var close_btn: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton")
			if close_btn:
				close_btn.grab_focus()

func _build_slots() -> void:
	for child in slot_container.get_children():
		child.queue_free()
		
	var run: Dictionary = RunManager.get_run()
	
	for slot: String in ALL_SLOTS:
		var equipped_id: String = (run["equipped"] as Dictionary).get(slot, "")
		var slot_panel: PanelContainer = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(120, 100)
		
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var slot_label: Label = Label.new()
		slot_label.text = SLOT_LABELS.get(slot, slot.to_upper())
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.add_theme_font_size_override("font_size", 12)
		slot_label.add_theme_color_override("font_color", Color.GRAY)
		vbox.add_child(slot_label)
		
		if equipped_id != "":
			var def: Dictionary = ContentRegistry.get_item(equipped_id)
			var item_label: Label = Label.new()
			item_label.text = def["label"]
			item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(item_label)
			
			var unequip_btn: Button = Button.new()
			unequip_btn.text = "UNEQUIP"
			unequip_btn.add_theme_font_size_override("font_size", 10)
			var current_slot: String = slot # Capture for closure
			unequip_btn.pressed.connect(func() -> void:
				RunManager.unequip_item(current_slot)
				refresh_all()
			)
			vbox.add_child(unequip_btn)
		else:
			var empty: Label = Label.new()
			empty.text = "---"
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(empty)
			
		slot_panel.add_child(vbox)
		slot_container.add_child(slot_panel)

func _build_inventory() -> void:
	for child in inventory_list.get_children():
		child.queue_free()
		
	var run: Dictionary = RunManager.get_run()
	
	var gear_in_inv: Array[String] = []
	for id: String in run["inventory"]:
		var def: Dictionary = ContentRegistry.get_item(id)
		if def.has("slot"):
			gear_in_inv.append(id)
			
	if gear_in_inv.is_empty():
		var l: Label = Label.new()
		l.text = "-- no equipment in inventory --"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inventory_list.add_child(l)
		return
		
	for id: String in gear_in_inv:
		var def: Dictionary = ContentRegistry.get_item(id)
		var hbox: HBoxContainer = HBoxContainer.new()
		
		var l: Label = Label.new()
		l.text = def["label"] + " (" + def["slot"] + ") - " + def["description"]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(l)
		
		var equip_btn: Button = Button.new()
		equip_btn.text = "EQUIP"
		var target_id: String = id # Capture for closure
		equip_btn.pressed.connect(func() -> void:
			print("[EQUIPMENT] Equipping item: ", target_id)
			RunManager.equip_item(target_id)
			refresh_all()
		)
		hbox.add_child(equip_btn)
		
		inventory_list.add_child(hbox)

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
