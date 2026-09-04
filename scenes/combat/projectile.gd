class_name Projectile
extends Area2D

const FIRE_EXPLOSION_FX := preload("res://scenes/combat/fire_explosion_fx.gd")
const PROJECTILE_IMPACT_FX := preload("res://scenes/combat/projectile_impact_fx.gd")
const LIGHTNING_ARC_FX := preload("res://scenes/combat/lightning_arc_fx.gd")
const HIT_TARGET_REACQUIRE_DELAY := 0.02
const HIT_TARGET_DAMAGE_COOLDOWN := 0.5

var direction := Vector2.RIGHT
var speed := 720.0
var damage := 10.0
var lifetime := 2.0
var remaining_pierces := 0
var explosion_radius := 0.0
var skill_id := &"default_attack"
var homing_target_ref: WeakRef
var homing_strength := 0.0
var burn_duration := 0.0
var burn_damage_per_second := 0.0
var chill_duration := 0.0
var freeze_buildup_multiplier := 0.0
var chain_count := 0
var chain_radius := 0.0
var chain_damage_multiplier := 1.0
var recent_hit_target_ref: WeakRef
var recent_hit_reacquire_delay := 0.0
var flight_time := 0.0
var target_last_hit_time: Dictionary[int, float] = {}
var affliction_target_expiry: Dictionary[String, float] = {}
var exploded := false

@onready var shape_cast: ShapeCast2D = $ShapeCast2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(new_direction: Vector2, new_damage: float, new_speed: float, size_scale: float, new_lifetime := 2.0, pierce_count := 0, new_explosion_radius := 0.0, new_skill_id := &"default_attack", new_homing_target: Node2D = null, new_homing_strength := 0.0, new_burn_duration := 0.0, new_burn_damage_per_second := 0.0, new_chill_duration := 0.0, new_freeze_buildup_multiplier := 0.0, new_chain_count := 0, new_chain_radius := 0.0, new_chain_damage_multiplier := 1.0) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	speed = new_speed
	scale = Vector2.ONE * size_scale
	lifetime = new_lifetime
	remaining_pierces = pierce_count
	explosion_radius = new_explosion_radius
	skill_id = new_skill_id
	homing_target_ref = weakref(new_homing_target) if is_instance_valid(new_homing_target) else null
	homing_strength = new_homing_strength
	burn_duration = new_burn_duration
	burn_damage_per_second = new_burn_damage_per_second
	chill_duration = new_chill_duration
	freeze_buildup_multiplier = new_freeze_buildup_multiplier
	chain_count = maxi(new_chain_count, 0)
	chain_radius = maxf(new_chain_radius, 0.0)
	chain_damage_multiplier = maxf(new_chain_damage_multiplier, 0.0)
	rotation = direction.angle()
	$Visual.configure(skill_id)

func _physics_process(delta: float) -> void:
	flight_time += delta
	if homing_strength > 0.0:
		_update_recent_hit_reacquire(delta)
		var homing_target := _get_homing_target()
		if not homing_target:
			homing_target = _find_homing_target()
			homing_target_ref = weakref(homing_target) if homing_target else null
		if homing_target:
			var desired_direction := global_position.direction_to(homing_target.global_position)
			direction = direction.lerp(desired_direction, clampf(homing_strength * delta, 0.0, 1.0)).normalized()
			rotation = direction.angle()
	var movement := direction * speed * delta
	shape_cast.target_position = Vector2(movement.length(), 0.0)
	shape_cast.force_shapecast_update()
	if shape_cast.is_colliding():
		for index in shape_cast.get_collision_count():
			if _damage_collider(shape_cast.get_collider(index), shape_cast.get_collision_point(index)):
				return
	global_position += movement
	lifetime -= delta
	if lifetime <= 0.0:
		_explode(null)
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	_damage_collider(body, _estimate_impact_position(body, direction))

func _damage_collider(collider: Object, contact_position: Vector2 = Vector2.INF) -> bool:
	if not collider is Node:
		return false
	var target_id := collider.get_instance_id()
	if not _can_damage_target(target_id):
		return false
	var health := collider.get_node_or_null("HealthComponent") as HealthComponent
	if not health:
		return false
	_record_target_hit(target_id)
	var damage_dealt := health.take_damage(damage)
	GameEvents.damage_dealt.emit(damage_dealt, String(skill_id))
	var hit_node := collider as Node2D
	_spawn_hit_feedback(hit_node, contact_position, damage_dealt)
	if chain_count > 0 and hit_node and _element_for_skill() == &"shocked":
		_chain_lightning_from(hit_node)
	if remaining_pierces > 0:
		remaining_pierces -= 1
		var hit_enemy := collider as Node2D
		recent_hit_target_ref = weakref(hit_enemy) if hit_enemy else null
		recent_hit_reacquire_delay = HIT_TARGET_REACQUIRE_DELAY
		# Move on to a different available enemy first; the pierced enemy becomes
		# the delayed return target once its per-projectile hit cooldown expires.
		var next_target := _find_homing_target()
		homing_target_ref = weakref(next_target) if next_target else null
		return false
	_explode(collider)
	queue_free()
	return true

func _chain_lightning_from(first_target: Node2D) -> void:
	if chain_count <= 0 or chain_radius <= 0.0:
		return
	var current_target := first_target as Enemy
	if not is_instance_valid(current_target):
		return
	var visited: Dictionary[int, bool] = {current_target.get_instance_id(): true}
	var jump_damage := damage * chain_damage_multiplier
	for _jump_index in range(chain_count):
		var current_position := current_target.global_position
		var next_target := _find_chain_target(current_position, visited)
		if not is_instance_valid(next_target):
			break
		var next_position := next_target.global_position
		_spawn_lightning_arc(current_position, next_position)
		_record_target_hit(next_target.get_instance_id())
		var damage_dealt := next_target.health.take_damage(jump_damage)
		GameEvents.damage_dealt.emit(damage_dealt, String(skill_id))
		var jump_direction := current_position.direction_to(next_position)
		_spawn_hit_feedback(next_target, next_position, damage_dealt, jump_direction)
		visited[next_target.get_instance_id()] = true
		current_target = next_target
		jump_damage *= chain_damage_multiplier


func _find_chain_target(origin: Vector2, visited: Dictionary[int, bool]) -> Enemy:
	var nearest: Enemy
	var nearest_distance_squared := INF
	for candidate in EnemyRegistry.get_in_radius(origin, chain_radius):
		var candidate_id := candidate.get_instance_id()
		if visited.has(candidate_id) or not _can_damage_target(candidate_id):
			continue
		var distance_squared := origin.distance_squared_to(candidate.global_position)
		if distance_squared < nearest_distance_squared:
			nearest = candidate
			nearest_distance_squared = distance_squared
	return nearest


func _spawn_lightning_arc(start: Vector2, finish: Vector2) -> void:
	var arc := LIGHTNING_ARC_FX.new() as LightningArcFX
	get_tree().current_scene.add_child(arc)
	arc.configure(start, finish)


func _get_homing_target() -> Node2D:
	if not homing_target_ref:
		return null
	var candidate := homing_target_ref.get_ref() as Node2D
	if not candidate or candidate.is_queued_for_deletion():
		return null
	return candidate

func _update_recent_hit_reacquire(delta: float) -> void:
	if not recent_hit_target_ref:
		return
	recent_hit_reacquire_delay -= delta
	if recent_hit_reacquire_delay > 0.0:
		return
	var recent_target := recent_hit_target_ref.get_ref() as Node2D
	recent_hit_target_ref = null
	if recent_target and not recent_target.is_queued_for_deletion():
		homing_target_ref = weakref(recent_target)

func _find_homing_target() -> Node2D:
	var excluded_enemy_id := -1
	if recent_hit_target_ref:
		var recent_target := recent_hit_target_ref.get_ref() as Node2D
		if recent_target and not _can_damage_target(recent_target.get_instance_id()):
			excluded_enemy_id = recent_target.get_instance_id()
	return EnemyRegistry.get_nearest(global_position, INF, excluded_enemy_id)

func _can_damage_target(target_id: int) -> bool:
	return flight_time - target_last_hit_time.get(target_id, -INF) >= HIT_TARGET_DAMAGE_COOLDOWN

func _record_target_hit(target_id: int) -> void:
	target_last_hit_time[target_id] = flight_time

func _explode(primary_target: Object) -> void:
	if exploded or explosion_radius <= 0.0:
		return
	exploded = true
	var effect := FIRE_EXPLOSION_FX.new() as FireExplosionFX
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position
	effect.configure(explosion_radius)
	for enemy in EnemyRegistry.get_in_radius(global_position, explosion_radius, primary_target as Enemy):
		var target_id := enemy.get_instance_id()
		if not _can_damage_target(target_id):
			continue
		_record_target_hit(target_id)
		var damage_dealt := enemy.health.take_damage(damage)
		GameEvents.damage_dealt.emit(damage_dealt, String(skill_id))
		var explosion_direction := global_position.direction_to(enemy.global_position)
		_spawn_hit_feedback(enemy, _estimate_impact_position(enemy, explosion_direction), damage_dealt, explosion_direction)

func _spawn_hit_feedback(target: Node2D, impact_position: Vector2 = Vector2.INF, damage_dealt: float = 0.0, impact_direction: Vector2 = direction) -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("apply_projectile_impact"):
		target.apply_projectile_impact(impact_direction, damage_dealt)
	var element := _element_for_skill()
	if element == &"chilled" and chill_duration > 0.0 and target.has_method("apply_cold_ailments"):
		target.call("apply_cold_ailments", damage_dealt, chill_duration, freeze_buildup_multiplier)
	elif not element.is_empty() and burn_duration > 0.0 and target.has_method("apply_elemental_affliction"):
		var affliction_key := "%s:%s" % [target.get_instance_id(), element]
		var next_allowed_time := float(affliction_target_expiry.get(affliction_key, -INF))
		if flight_time >= next_allowed_time:
			target.apply_elemental_affliction(element, burn_duration, burn_damage_per_second)
			affliction_target_expiry[affliction_key] = flight_time + burn_duration
	var effect := PROJECTILE_IMPACT_FX.new() as Node2D
	get_tree().current_scene.add_child(effect)
	effect.global_position = impact_position if impact_position.is_finite() else _estimate_impact_position(target, direction)
	effect.call("configure", skill_id, impact_direction, scale.x)

func _estimate_impact_position(target: Node2D, incoming_direction: Vector2) -> Vector2:
	var radius := 18.0
	var collision_shape := target.get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D
	if collision_shape and collision_shape.shape is CircleShape2D:
		radius = (collision_shape.shape as CircleShape2D).radius
	var target_scale := maxf(absf(target.global_scale.x), absf(target.global_scale.y))
	return target.global_position - incoming_direction.normalized() * radius * target_scale

func _element_for_skill() -> StringName:
	match skill_id:
		&"fireball", &"fire":
			return &"burning"
		&"ice", &"frost", &"blizzard", &"ice_shard":
			return &"chilled"
		&"lightning", &"storm", &"shock", &"chain_lightning":
			return &"shocked"
	return &""
