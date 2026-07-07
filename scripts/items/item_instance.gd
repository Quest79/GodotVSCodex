class_name ItemInstance
extends Resource

const RARITY_NAMES := ["NORMAL", "MAGIC", "RARE", "UNIQUE"]
const RARITY_COLORS := [
	Color(0.76, 0.8, 0.82),
	Color(0.3, 0.55, 1.0),
	Color(1.0, 0.82, 0.2),
	Color(1.0, 0.45, 0.12),
]

var definition: Resource
var rarity := 0
var rolled_modifiers: Dictionary[StringName, float] = {}
var sockets: Array[Resource] = []
var inventory_index := -1
var equipped_slot: StringName

func initialize(item_definition: Resource, item_rarity: int = -1) -> void:
	definition = item_definition
	rarity = definition.default_rarity if item_rarity < 0 else item_rarity
	sockets.resize(definition.socket_count)

func can_equip_to(slot: StringName) -> bool:
	return definition != null and definition.allowed_slots.has(slot)

func get_modifiers() -> Dictionary[StringName, float]:
	var combined: Dictionary[StringName, float] = definition.base_modifiers.duplicate()
	for stat in rolled_modifiers:
		combined[stat] = combined.get(stat, 0.0) + rolled_modifiers[stat]
	return combined

func get_skill_configs() -> Array[Dictionary]:
	var configs: Array[Dictionary] = []
	for socketed_gem in sockets:
		if not _is_gem_kind(socketed_gem, GemDefinition.GemKind.SKILL):
			continue
		var skill: GemDefinition = socketed_gem.definition
		var config: Dictionary = {}
		for effect in skill.effects:
			config[effect] = skill.effects[effect]
		config[&"skill_id"] = skill.skill_id
		config[&"skill_name"] = skill.display_name
		config[&"affinities"] = skill.affinities.duplicate()
		config[&"supports"] = PackedStringArray()
		for support_gem in sockets:
			if not _is_gem_kind(support_gem, GemDefinition.GemKind.SUPPORT):
				continue
			var support: GemDefinition = support_gem.definition
			if not support.supports_skill(skill):
				continue
			_apply_support_effects(config, support.effects)
			config[&"supports"].append(support.display_name)
		configs.append(config)
	return configs

func _apply_support_effects(config: Dictionary, effects: Dictionary[StringName, float]) -> void:
	for effect in effects:
		if String(effect).ends_with("_multiplier"):
			config[effect] = float(config.get(effect, 1.0)) * effects[effect]
		else:
			config[effect] = float(config.get(effect, 0.0)) + effects[effect]

func _is_gem_kind(candidate: Resource, kind: int) -> bool:
	return candidate != null and candidate.definition is GemDefinition and candidate.definition.gem_kind == kind

func get_rarity_color() -> Color:
	return RARITY_COLORS[clampi(rarity, 0, RARITY_COLORS.size() - 1)]

func get_tooltip() -> String:
	if definition is GemDefinition:
		var gem: GemDefinition = definition
		var gem_type := "SKILL GEM" if gem.gem_kind == GemDefinition.GemKind.SKILL else "SUPPORT GEM"
		var lines := [gem.display_name, gem_type, "AFFINITIES: " + gem.affinity_text()]
		if gem.gem_kind == GemDefinition.GemKind.SUPPORT:
			var requirements: PackedStringArray = []
			for affinity in gem.required_affinities:
				requirements.append(String(affinity))
			lines.append("SUPPORTS: " + ", ".join(requirements))
		if not gem.flavor_text.is_empty():
			lines.append(gem.flavor_text)
		return "\n".join(lines)
	var lines := [definition.display_name, RARITY_NAMES[clampi(rarity, 0, RARITY_NAMES.size() - 1)]]
	for stat in get_modifiers():
		lines.append("%+.2f %s" % [get_modifiers()[stat], String(stat).replace("_", " ").to_upper()])
	if not sockets.is_empty():
		lines.append("SOCKETS  %d" % sockets.size())
	return "\n".join(lines)
