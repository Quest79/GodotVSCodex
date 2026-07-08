class_name InventoryScreen
extends Control

@export var slot_scene: PackedScene

@onready var inventory_grid: GridContainer = %InventoryGrid

var was_paused := false
var model: Node
var inventory_slots: Array[Button] = []
var equipment_slots: Dictionary[StringName, Button] = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_equipment_slots()
	_build_inventory_grid()
	call_deferred("_attach_model")
	hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory") or _is_tab_press(event):
		_toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	if visible:
		_close()
	else:
		was_paused = get_tree().paused
		get_tree().paused = true
		show()

func _close() -> void:
	hide()
	get_tree().paused = was_paused

func _is_tab_press(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB

func _build_inventory_grid() -> void:
	for index in 60:
		var slot := slot_scene.instantiate() as Button
		slot.call("configure", index, &"inventory")
		slot.connect("drop_requested", _on_drop_requested)
		slot.connect("socket_clicked", _on_socket_clicked)
		inventory_grid.add_child(slot)
		inventory_slots.append(slot)

func _configure_equipment_slots() -> void:
	_register_equipment_slot(%PrimaryWeapon, &"primary_weapon", "PRIMARY\nWEAPON")
	_register_equipment_slot(%SecondaryWeapon, &"secondary_weapon", "SECONDARY WEAPON\nOR SHIELD")
	_register_equipment_slot(%Helm, &"helm", "HELM")
	_register_equipment_slot(%Armor, &"armor", "ARMOR")
	_register_equipment_slot(%Gloves, &"gloves", "GLOVES")
	_register_equipment_slot(%Boots, &"boots", "BOOTS")
	_register_equipment_slot(%Belt, &"belt", "BELT")
	_register_equipment_slot(%Amulet, &"amulet", "AMULET")
	_register_equipment_slot(%Ring1, &"ring_1", "RING")
	_register_equipment_slot(%Ring2, &"ring_2", "RING")
	_register_equipment_slot(%Implant, &"implant", "IMPLANT")
	_register_equipment_slot(%Core, &"core", "CORE")

func _register_equipment_slot(slot: Button, type: StringName, label: String) -> void:
	slot.call("configure", -1, type, label)
	slot.connect("drop_requested", _on_drop_requested)
	slot.connect("socket_clicked", _on_socket_clicked)
	equipment_slots[type] = slot

func _attach_model() -> void:
	model = get_tree().get_first_node_in_group("item_inventory")
	if not model:
		return
	model.connect("inventory_changed", _refresh)
	model.connect("equipment_changed", _on_equipment_changed)
	_refresh()

func _on_drop_requested(data: Dictionary, target_kind: StringName, target_key: Variant) -> void:
	if model and model.call("transfer", data.source_kind, data.source_key, target_kind, target_key):
		_refresh()

func _on_socket_clicked(item: Resource, socket_index: int) -> void:
	if model and model.call("unsocket_gem", item, socket_index):
		_refresh()

func _on_equipment_changed(_modifiers: Dictionary) -> void:
	_refresh()

func _refresh() -> void:
	if not model:
		return
	var inventory_data: Array = model.get("inventory")
	var equipment_data: Dictionary = model.get("equipment")
	var occupied := 0
	for index in inventory_slots.size():
		var item: Resource = inventory_data[index]
		inventory_slots[index].call("set_item", item)
		if item:
			occupied += 1
	for slot_type in equipment_slots:
		equipment_slots[slot_type].call("set_item", equipment_data[slot_type])
	%Capacity.text = "%d / %d" % [occupied, inventory_data.size()]
