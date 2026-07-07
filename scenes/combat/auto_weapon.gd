class_name AutoWeapon
extends Node2D

@export var projectile_scene: PackedScene
@export var attack_range := 900.0
@export var projectile_speed := 720.0

@onready var attack_timer: Timer = $AttackTimer

var damage := 10.0
var cooldown := 0.8
var projectile_scale := 1.0
var skill_config: Dictionary = {}

func _ready() -> void:
	attack_timer.timeout.connect(_attack)
	attack_timer.start()

func configure(new_damage: float, new_cooldown: float) -> void:
	damage = new_damage
	cooldown = maxf(new_cooldown, 0.05)
	if is_node_ready():
		attack_timer.wait_time = cooldown

func configure_skill(new_config: Dictionary) -> void:
	skill_config = new_config.duplicate(true)

func _attack() -> void:
	var projectile_count := maxi(1, roundi(float(skill_config.get(&"projectile_count", 1.0))))
	var targets := _find_nearest_enemies(projectile_count)
	if targets.is_empty() or not projectile_scene:
		return
	var spread := deg_to_rad(float(skill_config.get(&"spread_degrees", 0.0)))
	for index in projectile_count:
		var target: Node2D = targets[index % targets.size()]
		var base_direction := global_position.direction_to(target.global_position)
		var angle_offset := 0.0
		if targets.size() == 1 and projectile_count > 1:
			angle_offset = lerpf(-spread * 0.5, spread * 0.5, float(index) / float(projectile_count - 1))
		var projectile := projectile_scene.instantiate() as Projectile
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = global_position
		projectile.setup(
			base_direction.rotated(angle_offset),
			damage * float(skill_config.get(&"damage_multiplier", 1.0)),
			projectile_speed * float(skill_config.get(&"projectile_speed_multiplier", 1.0)),
			projectile_scale * float(skill_config.get(&"projectile_scale", 1.0)),
			2.0 * float(skill_config.get(&"duration_multiplier", 1.0)),
			roundi(float(skill_config.get(&"pierce", 0.0))),
			float(skill_config.get(&"explosion_radius", 0.0)),
			StringName(skill_config.get(&"skill_id", &"default_attack")),
			target,
			float(skill_config.get(&"homing_strength", 0.0))
		)

func _find_nearest_enemies(limit: int) -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if not enemy or enemy.is_queued_for_deletion():
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance <= attack_range * attack_range:
			candidates.append(enemy)
	candidates.sort_custom(func(first: Node2D, second: Node2D) -> bool:
		return global_position.distance_squared_to(first.global_position) < global_position.distance_squared_to(second.global_position)
	)
	var selected: Array[Node2D] = []
	for index in mini(limit, candidates.size()):
		selected.append(candidates[index])
	return selected
