class_name ItemDefinition
extends Resource

enum ItemType { WEAPON, ARMOR, BOOTS, IMPLANT, CORE, GEM, HELM, GLOVES, BELT, AMULET, RING }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, MYTHIC }

@export var id: StringName
@export var display_name := "Item"
@export var item_type := ItemType.WEAPON
@export var default_rarity := Rarity.COMMON
@export var allowed_slots: Array[StringName] = []
@export var base_modifiers: Dictionary[StringName, float] = {}
@export_range(0, 6) var socket_count := 0
@export var accent_color := Color(0.55, 0.8, 0.85)
@export var inventory_icon: Texture2D
@export var tooltip_art: Texture2D
@export var tier_label := ""
@export_multiline var flavor_text := ""
@export_range(0, 999) var required_level := 0
@export var account_bound := false

func allows_sockets() -> bool:
	return item_type not in [ItemType.BELT, ItemType.AMULET, ItemType.RING]
