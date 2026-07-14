class_name Player
extends CharacterBody2D

@export var base_stats: ActorStats
@export var acceleration := 1800.0
@export var deceleration := 2200.0

const DASH_DURATION := 0.7
const DASH_RECHARGE_TIME := 2.5
const DASH_MAX_CHARGES := 3
const DASH_INITIAL_SPEED := 1500.0

@onready var health: HealthComponent = $HealthComponent
@onready var weapon: AutoWeapon = $AutoWeapon

var stats: ActorStats
var equipment_modifiers: Dictionary[StringName, float] = {}
var dash_cooldowns: Array[float] = [0.0, 0.0, 0.0]
var dash_elapsed := 0.0
var dash_direction := Vector2.RIGHT

func _ready() -> void:
	stats = base_stats.duplicate(true)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	health.configure(stats.max_health)
	weapon.configure(stats.damage, stats.cooldown)
	GameEvents.dash_cooldowns_changed.emit(dash_cooldowns.duplicate())

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var desired_velocity := input * stats.move_speed
	_update_dash_cooldowns(delta)
	var dash_index := _get_available_dash_index()
	if Input.is_action_just_pressed("dash") and dash_elapsed <= 0.0 and dash_index >= 0:
		_start_dash(input, dash_index)
	if dash_elapsed > 0.0:
		# Cubic ease-out gives the dash a sharp launch and a naturally soft stop.
		var progress := 1.0 - clampf(dash_elapsed / DASH_DURATION, 0.0, 1.0)
		var dash_speed := DASH_INITIAL_SPEED * pow(1.0 - progress, 2.6)
		if input != Vector2.ZERO:
			dash_speed = maxf(dash_speed, desired_velocity.length())
		velocity = dash_direction * dash_speed
		dash_elapsed = maxf(dash_elapsed - delta, 0.0)
	else:
		var response := acceleration if input != Vector2.ZERO else deceleration
		velocity = velocity.move_toward(desired_velocity, response * delta)
	# Keep body pushes responsive even when collision has stopped visible motion.
	var push_speed := maxf(velocity.length(), desired_velocity.length() * 0.72) if input != Vector2.ZERO else 0.0
	move_and_slide()
	_push_collided_enemies(push_speed, delta)
	if stats.health_regen > 0.0:
		health.heal(stats.health_regen * delta)

func _start_dash(input: Vector2, dash_index: int) -> void:
	dash_direction = input.normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = velocity.normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2.RIGHT
	dash_cooldowns[dash_index] = DASH_RECHARGE_TIME
	dash_elapsed = DASH_DURATION
	GameEvents.dash_cooldowns_changed.emit(dash_cooldowns.duplicate())

func _get_available_dash_index() -> int:
	for index in range(DASH_MAX_CHARGES):
		if dash_cooldowns[index] <= 0.0:
			return index
	return -1

func _update_dash_cooldowns(delta: float) -> void:
	var changed := false
	for index in range(DASH_MAX_CHARGES):
		if dash_cooldowns[index] > 0.0:
			dash_cooldowns[index] = maxf(dash_cooldowns[index] - delta, 0.0)
			changed = true
	if changed:
		GameEvents.dash_cooldowns_changed.emit(dash_cooldowns.duplicate())

func _push_collided_enemies(push_speed: float, delta: float) -> void:
	if push_speed <= 1.0:
		return
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		var enemy := collision.get_collider() as Enemy
		if enemy:
			enemy.apply_player_body_push(global_position, get_body_mass(), push_speed, delta)

func get_body_mass() -> float:
	var body_scale := maxf(absf(global_scale.x), absf(global_scale.y))
	# A softened size curve keeps enemies twice the player's size pushable,
	# while still making larger bodies feel meaningfully heavier.
	return maxf(pow(body_scale, 1.6), 0.05)

func collect_xp(amount: int) -> void:
	GameEvents.xp_collected.emit(amount)

func get_pickup_range() -> float:
	return stats.pickup_range

func apply_upgrade(upgrade_id: StringName) -> void:
	match upgrade_id:
		&"might":
			stats.damage *= 1.25
		&"haste":
			stats.cooldown *= 0.85
		&"vitality":
			stats.max_health += 20.0
			health.increase_max_health(20.0, 20.0)
		&"speed":
			stats.move_speed *= 1.12
		&"magnet":
			stats.pickup_range += 40.0
		&"area":
			weapon.projectile_scale *= 1.18
	weapon.configure(stats.damage, stats.cooldown)

func apply_equipment_modifiers(new_modifiers: Dictionary) -> void:
	for stat_name: StringName in [&"damage", &"cooldown", &"move_speed", &"pickup_range", &"max_health", &"health_regen"]:
		var change: float = new_modifiers.get(stat_name, 0.0) - equipment_modifiers.get(stat_name, 0.0)
		match stat_name:
			&"damage":
				stats.damage += change
			&"cooldown":
				stats.cooldown = maxf(stats.cooldown + change, 0.05)
			&"move_speed":
				stats.move_speed += change
			&"pickup_range":
				stats.pickup_range += change
			&"max_health":
				stats.max_health += change
				health.increase_max_health(change, maxf(change, 0.0))
			&"health_regen":
				stats.health_regen += change
	equipment_modifiers = new_modifiers.duplicate()
	weapon.configure(stats.damage, stats.cooldown)

func apply_skill_loadout(loadout: Dictionary) -> void:
	weapon.configure_skill(loadout)

func _on_health_changed(current: float, maximum: float) -> void:
	GameEvents.player_health_changed.emit(current, maximum)

func _on_died() -> void:
	set_physics_process(false)
	GameEvents.player_died.emit()
