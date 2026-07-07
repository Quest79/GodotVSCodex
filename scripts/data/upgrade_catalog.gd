class_name UpgradeCatalog
extends RefCounted

const UPGRADES := {
	&"might": {"title": "Might", "description": "+25% projectile damage"},
	&"haste": {"title": "Haste", "description": "+15% attack speed"},
	&"vitality": {"title": "Vitality", "description": "+20 max HP and heal 20"},
	&"speed": {"title": "Fleet Foot", "description": "+12% movement speed"},
	&"magnet": {"title": "Magnet", "description": "+40 pickup range"},
	&"area": {"title": "Growth", "description": "+18% projectile size"},
}

static func choices(count: int = 3) -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in UPGRADES:
		ids.append(id)
	ids.shuffle()
	return ids.slice(0, mini(count, ids.size()))

static func get_data(id: StringName) -> Dictionary:
	return UPGRADES.get(id, {})
