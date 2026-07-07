class_name GemDefinition
extends ItemDefinition

enum GemKind { SKILL, SUPPORT }

@export var gem_kind := GemKind.SKILL
@export var affinities: Array[StringName] = []
@export var required_affinities: Array[StringName] = []
@export var skill_id: StringName
@export var effects: Dictionary[StringName, float] = {}

func supports_skill(skill: GemDefinition) -> bool:
	if gem_kind != GemKind.SUPPORT or skill.gem_kind != GemKind.SKILL:
		return false
	for affinity in required_affinities:
		if not skill.affinities.has(affinity):
			return false
	return not required_affinities.is_empty()

func affinity_text() -> String:
	var names: PackedStringArray = []
	for affinity in affinities:
		names.append(String(affinity))
	return ", ".join(names)
