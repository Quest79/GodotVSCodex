class_name ItemInventory
extends Node

signal inventory_changed
signal equipment_changed(modifiers: Dictionary[StringName, float])
signal skill_loadout_changed(loadout: Dictionary)

const ItemInstanceScript = preload("res://scripts/items/item_instance.gd")
const SAVE_PATH := "user://equipment_inventory.json"
const SAVE_VERSION := 1

@export var capacity := 60
@export var starter_items: Array[Resource] = []

var inventory: Array[Resource] = []
var equipment := {
	&"primary_weapon": null,
	&"secondary_weapon": null,
	&"helm": null,
	&"armor": null,
	&"gloves": null,
	&"boots": null,
	&"belt": null,
	&"amulet": null,
	&"ring_1": null,
	&"ring_2": null,
	&"implant": null,
	&"core": null,
}
var persistence_ready := false

func _ready() -> void:
	add_to_group("item_inventory")
	inventory_changed.connect(_save_inventory)
	inventory.resize(capacity)
	if not _load_inventory():
		for definition in starter_items:
			var item := ItemInstanceScript.new()
			item.initialize(definition)
			add_item(item)
	persistence_ready = true
	_save_inventory()
	_emit_all_changed()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_save_inventory()

func clear_saved_run() -> void:
	# Disable persistence first so freeing the old scene cannot recreate the
	# save through NOTIFICATION_PREDELETE after it has been removed.
	persistence_ready = false
	if FileAccess.file_exists(SAVE_PATH):
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if error != OK:
			push_warning("Could not clear saved equipment and inventory: %s" % error)

func _save_inventory() -> void:
	if not persistence_ready:
		return
	var inventory_data: Array = []
	for item in inventory:
		inventory_data.append(_serialize_item(item))
	var equipment_data := {}
	for slot in equipment:
		equipment_data[String(slot)] = _serialize_item(equipment[slot])
	var save_data := {
		"version": SAVE_VERSION,
		"capacity": capacity,
		"inventory": inventory_data,
		"equipment": equipment_data,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_warning("Could not save equipment and inventory: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(save_data))

func _load_inventory() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("Could not open equipment save: %s" % FileAccess.get_open_error())
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("version", 0)) != SAVE_VERSION:
		push_warning("Equipment save is invalid or from an unsupported version.")
		return false
	var saved_inventory: Array = parsed.get("inventory", [])
	for index in mini(inventory.size(), saved_inventory.size()):
		var item := _deserialize_item(saved_inventory[index])
		inventory[index] = item
		_update_inventory_location(index)
	var saved_equipment: Dictionary = parsed.get("equipment", {})
	for slot in equipment:
		var item := _deserialize_item(saved_equipment.get(String(slot), null))
		if item and not item.can_equip_to(slot):
			push_warning("Ignored saved item in incompatible equipment slot: %s" % slot)
			item = null
		equipment[slot] = item
		if item:
			item.inventory_index = -1
			item.equipped_slot = slot
	return true

func _serialize_item(item: Resource) -> Variant:
	if not item or not item.definition:
		return null
	var modifiers := {}
	for stat in item.rolled_modifiers:
		modifiers[String(stat)] = item.rolled_modifiers[stat]
	var socket_data: Array = []
	for gem in item.sockets:
		socket_data.append(_serialize_item(gem))
	return {
		"definition": item.definition.resource_path,
		"rarity": item.rarity,
		"rolled_modifiers": modifiers,
		"sockets": socket_data,
	}

func _deserialize_item(data: Variant) -> Resource:
	if not data is Dictionary:
		return null
	var definition_path := String(data.get("definition", ""))
	if definition_path.is_empty() or not ResourceLoader.exists(definition_path):
		push_warning("Missing saved item definition: %s" % definition_path)
		return null
	var definition := load(definition_path) as Resource
	if not definition:
		return null
	var item := ItemInstanceScript.new()
	item.initialize(definition, int(data.get("rarity", definition.default_rarity)))
	var saved_modifiers: Dictionary = data.get("rolled_modifiers", {})
	for stat in saved_modifiers:
		item.rolled_modifiers[StringName(stat)] = float(saved_modifiers[stat])
	var saved_sockets: Array = data.get("sockets", [])
	for socket_index in mini(item.sockets.size(), saved_sockets.size()):
		var gem := _deserialize_item(saved_sockets[socket_index])
		if gem and gem.definition is GemDefinition:
			item.sockets[socket_index] = gem
			_mark_socketed(gem)
	return item

func add_item(item: Resource) -> bool:
	for index in inventory.size():
		if inventory[index] == null:
			inventory[index] = item
			item.inventory_index = index
			item.equipped_slot = &""
			inventory_changed.emit()
			return true
	return false

func transfer(source_kind: StringName, source_key: Variant, target_kind: StringName, target_key: Variant) -> bool:
	if source_kind == &"inventory" and target_kind == &"socket":
		return _socket_from_inventory(int(source_key), target_key["item"], int(target_key["index"]))
	if source_kind == &"socket" and target_kind == &"inventory":
		return _unsocket_to_inventory(source_key["item"], int(source_key["index"]), int(target_key))
	if source_kind == &"socket" and target_kind == &"socket":
		return _move_socket(source_key["item"], int(source_key["index"]), target_key["item"], int(target_key["index"]))
	if source_kind == &"inventory" and target_kind == &"inventory":
		return _swap_inventory(int(source_key), int(target_key))
	if source_kind == &"inventory" and target_kind == &"equipment":
		return _equip_from_inventory(int(source_key), StringName(target_key))
	if source_kind == &"equipment" and target_kind == &"inventory":
		return _move_equipment_to_inventory(StringName(source_key), int(target_key))
	if source_kind == &"equipment" and target_kind == &"equipment":
		return _swap_equipment(StringName(source_key), StringName(target_key))
	return false

func get_total_modifiers() -> Dictionary[StringName, float]:
	var totals: Dictionary[StringName, float] = {}
	for item in equipment.values():
		if item:
			for stat in item.get_modifiers():
				totals[stat] = totals.get(stat, 0.0) + item.get_modifiers()[stat]
	return totals

func get_skill_loadout() -> Dictionary:
	for item in equipment.values():
		if not item:
			continue
		var configs: Array[Dictionary] = item.get_skill_configs()
		if not configs.is_empty():
			return configs[0]
	return {}

func socket_gem(item: Resource, socket_index: int, gem: Resource) -> bool:
	if not item or not _is_gem(gem) or socket_index < 0 or socket_index >= item.sockets.size() or item.sockets[socket_index]:
		return false
	item.sockets[socket_index] = gem
	_mark_socketed(gem)
	inventory_changed.emit()
	equipment_changed.emit(get_total_modifiers())
	return true

func unsocket_gem(item: Resource, socket_index: int) -> bool:
	if not _valid_socket(item, socket_index) or not item.sockets[socket_index]:
		return false
	for inventory_index in inventory.size():
		if inventory[inventory_index] == null:
			var gem: Resource = item.sockets[socket_index]
			item.sockets[socket_index] = null
			inventory[inventory_index] = gem
			_update_inventory_location(inventory_index)
			_emit_all_changed()
			return true
	return false

func _socket_from_inventory(inventory_index: int, target_item: Resource, socket_index: int) -> bool:
	if not _valid_inventory_index(inventory_index) or not _valid_socket(target_item, socket_index):
		return false
	var gem := inventory[inventory_index]
	if not _is_gem(gem):
		return false
	if target_item.sockets[socket_index]:
		return false
	target_item.sockets[socket_index] = gem
	_mark_socketed(gem)
	inventory[inventory_index] = null
	_update_inventory_location(inventory_index)
	_emit_all_changed()
	return true

func _unsocket_to_inventory(source_item: Resource, socket_index: int, inventory_index: int) -> bool:
	if not _valid_socket(source_item, socket_index) or not _valid_inventory_index(inventory_index):
		return false
	var gem: Resource = source_item.sockets[socket_index]
	if not gem:
		return false
	var target: Resource = inventory[inventory_index]
	if target and not _is_gem(target):
		return false
	source_item.sockets[socket_index] = target
	if target:
		_mark_socketed(target)
	inventory[inventory_index] = gem
	_update_inventory_location(inventory_index)
	_emit_all_changed()
	return true

func _move_socket(source_item: Resource, source_index: int, target_item: Resource, target_index: int) -> bool:
	if not _valid_socket(source_item, source_index) or not _valid_socket(target_item, target_index):
		return false
	if target_item.sockets[target_index]:
		return false
	var held: Resource = source_item.sockets[source_index]
	if not held:
		return false
	source_item.sockets[source_index] = null
	target_item.sockets[target_index] = held
	_mark_socketed(held)
	_emit_all_changed()
	return true

func _valid_socket(item: Resource, index: int) -> bool:
	return item != null and index >= 0 and index < item.sockets.size()

func _is_gem(item: Resource) -> bool:
	return item != null and item.definition is GemDefinition

func _mark_socketed(gem: Resource) -> void:
	gem.inventory_index = -1
	gem.equipped_slot = &""

func _swap_inventory(first: int, second: int) -> bool:
	if not _valid_inventory_index(first) or not _valid_inventory_index(second):
		return false
	var held := inventory[first]
	inventory[first] = inventory[second]
	inventory[second] = held
	_update_inventory_location(first)
	_update_inventory_location(second)
	inventory_changed.emit()
	return true

func _equip_from_inventory(index: int, slot: StringName) -> bool:
	if not _valid_inventory_index(index) or not equipment.has(slot):
		return false
	var item := inventory[index]
	if not item or not item.can_equip_to(slot):
		return false
	var replaced = equipment[slot]
	equipment[slot] = item
	inventory[index] = replaced
	item.inventory_index = -1
	item.equipped_slot = slot
	_update_inventory_location(index)
	_emit_all_changed()
	return true

func _move_equipment_to_inventory(slot: StringName, index: int) -> bool:
	if not equipment.has(slot) or not _valid_inventory_index(index):
		return false
	var equipped = equipment[slot]
	if not equipped:
		return false
	var target = inventory[index]
	if target and not target.can_equip_to(slot):
		return false
	equipment[slot] = target
	inventory[index] = equipped
	equipped.equipped_slot = &""
	_update_inventory_location(index)
	if target:
		target.inventory_index = -1
		target.equipped_slot = slot
	_emit_all_changed()
	return true

func _swap_equipment(first: StringName, second: StringName) -> bool:
	if not equipment.has(first) or not equipment.has(second):
		return false
	var first_item = equipment[first]
	var second_item = equipment[second]
	if first_item and not first_item.can_equip_to(second):
		return false
	if second_item and not second_item.can_equip_to(first):
		return false
	equipment[first] = second_item
	equipment[second] = first_item
	if first_item:
		first_item.equipped_slot = second
	if second_item:
		second_item.equipped_slot = first
	_emit_all_changed()
	return true

func _valid_inventory_index(index: int) -> bool:
	return index >= 0 and index < inventory.size()

func _update_inventory_location(index: int) -> void:
	var item := inventory[index]
	if item:
		item.inventory_index = index
		item.equipped_slot = &""

func _emit_all_changed() -> void:
	inventory_changed.emit()
	equipment_changed.emit(get_total_modifiers())
	skill_loadout_changed.emit(get_skill_loadout())
