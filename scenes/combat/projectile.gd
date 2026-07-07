class_name Projectile
extends Area2D

const FIRE_EXPLOSION_FX := preload("res://scenes/combat/fire_explosion_fx.gd")

var direction := Vector2.RIGHT
var speed := 720.0
var damage := 10.0
var lifetime := 2.0
var remaining_pierces := 0
var explosion_radius := 0.0
var skill_id := &"default_attack"
var homing_target: Node2D
var homing_strength := 0.0
var hit_targets: Dictionary[int, bool] = {}
var exploded := false

@onready var shape_cast: ShapeCast2D = $ShapeCast2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(new_direction: Vector2, new_damage: float, new_speed: float, size_scale: float, new_lifetime := 2.0, pierce_count := 0, new_explosion_radius := 0.0, new_skill_id := &"default_attack", new_homing_target: Node2D = null, new_homing_strength := 0.0) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	speed = new_speed
	scale = Vector2.ONE * size_scale
	lifetime = new_lifetime
	remaining_pierces = pierce_count
	explosion_radius = new_explosion_radius
	skill_id = new_skill_id
	homing_target = new_homing_target
	homing_strength = new_homing_strength
	rotation = direction.angle()
	$Visual.configure(skill_id)

func _physics_process(delta: float) -> void:
	if homing_strength > 0.0 and is_instance_valid(homing_target) and not homing_target.is_queued_for_deletion():
		var desired_direction := global_position.direction_to(homing_target.global_position)
		direction = direction.lerp(desired_direction, clampf(homing_strength * delta, 0.0, 1.0)).normalized()
		rotation = direction.angle()
	var movement := direction * speed * delta
	shape_cast.target_position = Vector2(movement.length(), 0.0)
	shape_cast.force_shapecast_update()
	if shape_cast.is_colliding():
		for index in shape_cast.get_collision_count():
			if _damage_collider(shape_cast.get_collider(index)):
				return
	global_position += movement
	lifetime -= delta
	if lifetime <= 0.0:
		_explode(null)
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	_damage_collider(body)

func _damage_collider(collider: Object) -> bool:
	if not collider is Node:
		return false
	var target_id := collider.get_instance_id()
	if hit_targets.has(target_id):
		return false
	var health := collider.get_node_or_null("HealthComponent") as HealthComponent
	if not health:
		return false
	hit_targets[target_id] = true
	health.take_damage(damage)
	if remaining_pierces > 0:
		remaining_pierces -= 1
		return false
	_explode(collider)
	queue_free()
	return true

func _explode(primary_target: Object) -> void:
	if exploded or explosion_radius <= 0.0:
		return
	exploded = true
	var effect := FIRE_EXPLOSION_FX.new() as FireExplosionFX
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position
	effect.configure(explosion_radius)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == primary_target or not enemy is Node2D:
			continue
		if global_position.distance_to(enemy.global_position) > explosion_radius:
			continue
		var target_id := enemy.get_instance_id()
		if hit_targets.has(target_id):
			continue
		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			hit_targets[target_id] = true
			health.take_damage(damage)
