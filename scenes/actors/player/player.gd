class_name Player
extends CharacterBody2D

@export var base_stats: ActorStats
@export var acceleration := 1800.0
@export var deceleration := 2200.0

@onready var health: HealthComponent = $HealthComponent
@onready var weapon: AutoWeapon = $AutoWeapon

var stats: ActorStats
var equipment_modifiers: Dictionary[StringName, float] = {}

func _ready() -> void:
	stats = base_stats.duplicate(true)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	health.configure(stats.max_health)
	weapon.configure(stats.damage, stats.cooldown)

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var desired_velocity := input * stats.move_speed
	var response := acceleration if input != Vector2.ZERO else deceleration
	velocity = velocity.move_toward(desired_velocity, response * delta)
	move_and_slide()
	if stats.health_regen > 0.0:
		health.heal(stats.health_regen * delta)

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
