class_name InventoryPersistence
extends RefCounted

const SAVE_PATH := "user://equipment_inventory.json"
const SAVE_VERSION := 1
const ItemInstanceScript = preload("res://scripts/items/item_instance.gd")

static func save(capacity: int, inventory: Array[Resource], equipment: Dictionary) -> void:
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

static func load(capacity: int, equipment_template: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("Could not open equipment save: %s" % FileAccess.get_open_error())
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("version", 0)) != SAVE_VERSION:
		push_warning("Equipment save is invalid or from an unsupported version.")
		return {}
	var inventory: Array[Resource] = []
	inventory.resize(capacity)
	var saved_inventory: Array = parsed.get("inventory", [])
	for index in mini(inventory.size(), saved_inventory.size()):
		var item := _deserialize_item(saved_inventory[index])
		inventory[index] = item
		if item:
			item.inventory_index = index
			item.equipped_slot = &""
	var equipment := equipment_template.duplicate()
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
	return {"inventory": inventory, "equipment": equipment}

static func clear() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if error != OK:
		push_warning("Could not clear saved equipment and inventory: %s" % error)

static func _serialize_item(item: Resource) -> Variant:
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

static func _deserialize_item(data: Variant) -> Resource:
	if not data is Dictionary:
		return null
	var definition_path := String(data.get("definition", ""))
	if definition_path.is_empty() or not ResourceLoader.exists(definition_path):
		push_warning("Missing saved item definition: %s" % definition_path)
		return null
	var definition := ResourceLoader.load(definition_path) as Resource
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
			gem.inventory_index = -1
			gem.equipped_slot = &""
	return item
