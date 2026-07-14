class_name Enemy
extends CharacterBody2D

const DEATH_FX := preload("res://scenes/actors/enemy/enemy_death_fx.gd")
const BOSS_DEATH_FX := preload("res://scenes/actors/enemy/boss_death_fx.gd")
const BOSS_PRESENCE_FX := preload("res://scenes/actors/enemy/boss_presence_fx.gd")
const BOSS_RIFT_BOLT := preload("res://scenes/actors/enemy/boss_rift_bolt.gd")
const FIRE_EXPLOSION_FX := preload("res://scenes/combat/fire_explosion_fx.gd")
const BURNING_STACK_THRESHOLD := 10
const BURNING_EXPLOSION_MULTIPLIER := 3.0
const BURNING_EXPLOSION_RADIUS := 180.0
const PLAYER_PUSH_SPEED_MULTIPLIER := 2.5
const PLAYER_PUSH_RESPONSE := 2400.0
const PROJECTILE_KNOCKBACK_MIN_SPEED := 35.0
const PROJECTILE_KNOCKBACK_MAX_SPEED := 640.0
const PROJECTILE_KNOCKBACK_DRAG := 7.0
const PROJECTILE_KNOCKBACK_STOP_SPEED := 6.0
const BOSS_ORBIT_MINION_COUNT := 12
const BOSS_ORBIT_DURATION := 7.0
const BOSS_ORBIT_RELEASE_INTERVAL := 0.5
const BOSS_ORBIT_RECOVERY_TIME := 15.0
const BOSS_ORBITING := 1
const BOSS_RELEASING := 2
const BOSS_WAITING_FOR_GROUP_DEATH := 3
const BOSS_RECOVERING := 4

@export var base_stats: ActorStats
@export var xp_gem_scene: PackedScene
@export var damage_number_scene: PackedScene
@export var loot_drop_scene: PackedScene
@export var loot_definitions: Array[Resource] = []

@onready var health: HealthComponent = $HealthComponent
@onready var contact_damage: ContactDamage = $ContactDamage
@onready var health_label: Label = $HealthLabel
@onready var affliction_icon: ActorStatusIcon = $AfflictionIcon
@onready var affliction_fx: EnemyAfflictionFX = $AfflictionFX
@onready var boss_health_bar: ActorHealthBar = $BossHealthBar

var stats: ActorStats
var target: Node2D
var dying := false
var is_boss := false
var impact_velocity := Vector2.ZERO
var afflictions: Dictionary = {}
var affliction_tick_elapsed := 0.0
var boss_attack_elapsed := 0.0
var boss_attack_delay := 1.1
var boss_charge_elapsed := 0.0
var boss_charge_cooldown := 2.8
var boss_charge_direction := Vector2.RIGHT
var boss_orbit_state := 0
var boss_orbit_elapsed := 0.0
var boss_orbit_release_elapsed := 0.0
var boss_orbit_release_index := 0
var boss_orbit_group: Array[WeakRef] = []
var orbit_boss_ref: WeakRef
var orbit_angle := 0.0
var orbit_radius := 0.0
var orbit_elapsed := 0.0
var launch_elapsed := 0.0
var launch_velocity := Vector2.ZERO

func _ready() -> void:
	stats = base_stats.duplicate(true)
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	health.health_changed.connect(_on_health_changed)
	health.configure(stats.max_health)
	contact_damage.configure(stats.damage, stats.cooldown)
	target = get_tree().get_first_node_in_group("player") as Node2D
	affliction_icon.hide()
	boss_health_bar.hide()
	EnemyRegistry.register(self)

func _exit_tree() -> void:
	EnemyRegistry.unregister(self)

func _on_health_changed(current: float, _maximum: float) -> void:
	if is_boss:
		boss_health_bar.set_health(current, health.maximum)
	else:
		health_label.text = "%d HP" % ceili(current)

func _on_damaged(amount: float) -> void:
	if not damage_number_scene:
		return
	var number := damage_number_scene.instantiate() as Node2D
	number.call("setup", amount, global_position + Vector2(0.0, -24.0))
	get_tree().current_scene.add_child(number)

func _physics_process(delta: float) -> void:
	_process_afflictions(delta)
	if not is_instance_valid(target):
		velocity = impact_velocity
		_decay_impact_velocity(delta)
		EnemyRegistry.update_enemy(self)
		return
	if _process_boss_orbit(delta):
		EnemyRegistry.update_enemy(self)
		return
	if launch_elapsed > 0.0:
		launch_elapsed = maxf(launch_elapsed - delta, 0.0)
		velocity = launch_velocity + impact_velocity
		_decay_impact_velocity(delta)
		move_and_slide()
		EnemyRegistry.update_enemy(self)
		return
	var chase_velocity := global_position.direction_to(target.global_position) * stats.move_speed
	if is_boss:
		_process_boss_charge(delta)
		if boss_charge_elapsed > 0.0:
			chase_velocity = boss_charge_direction * stats.move_speed * 5.0
	velocity = chase_velocity + impact_velocity
	_decay_impact_velocity(delta)
	move_and_slide()
	if is_boss:
		_process_boss_attack(delta)
		_process_boss_orbit_barrage(delta)
	EnemyRegistry.update_enemy(self)

func _process_boss_attack(delta: float) -> void:
	boss_attack_elapsed += delta * _boss_action_speed()
	if boss_attack_elapsed < boss_attack_delay or not is_instance_valid(target):
		return
	boss_attack_elapsed = 0.0
	boss_attack_delay = randf_range(1.35, 2.25)
	var bolt: Node2D = BOSS_RIFT_BOLT.new()
	bolt.call("configure", global_position.direction_to(target.global_position))
	bolt.global_position = global_position + global_position.direction_to(target.global_position) * 118.0
	get_tree().current_scene.add_child(bolt)

func _process_boss_charge(delta: float) -> void:
	if health.current / health.maximum > 0.5:
		return
	var action_delta := delta * _boss_action_speed()
	if boss_charge_elapsed > 0.0:
		boss_charge_elapsed = maxf(boss_charge_elapsed - action_delta, 0.0)
		return
	boss_charge_cooldown -= action_delta
	if boss_charge_cooldown > 0.0:
		return
	boss_charge_direction = global_position.direction_to(target.global_position)
	if boss_charge_direction == Vector2.ZERO:
		boss_charge_direction = Vector2.RIGHT
	boss_charge_elapsed = 0.72
	boss_charge_cooldown = randf_range(3.0, 4.2)

func _boss_action_speed() -> float:
	return 1.25 if health.current / health.maximum <= 0.25 else 1.0

func begin_boss_orbit(boss: Enemy, new_angle: float) -> void:
	orbit_boss_ref = weakref(boss)
	orbit_angle = new_angle
	orbit_radius = randf_range(150.0, 205.0)
	orbit_elapsed = 0.0
	velocity = Vector2.ZERO

func launch_from_boss_orbit(player: Node2D) -> void:
	orbit_boss_ref = null
	launch_velocity = global_position.direction_to(player.global_position) * 900.0
	launch_elapsed = 1.15

func _process_boss_orbit(delta: float) -> bool:
	if orbit_boss_ref == null:
		return false
	var boss := orbit_boss_ref.get_ref() as Enemy
	if not is_instance_valid(boss) or boss.dying:
		orbit_boss_ref = null
		return false
	orbit_elapsed += delta
	global_position = boss.global_position + Vector2.from_angle(orbit_angle + orbit_elapsed * 2.3) * orbit_radius
	velocity = Vector2.ZERO
	return true

func _process_boss_orbit_barrage(delta: float) -> void:
	if health.current / health.maximum > 0.75:
		return
	var action_delta := delta * _boss_action_speed()
	match boss_orbit_state:
		0:
			_start_boss_orbit_barrage()
		BOSS_ORBITING:
			boss_orbit_elapsed += action_delta
			if boss_orbit_elapsed >= BOSS_ORBIT_DURATION:
				boss_orbit_state = BOSS_RELEASING
				boss_orbit_release_elapsed = 0.0
		BOSS_RELEASING:
			boss_orbit_release_elapsed += action_delta
			while boss_orbit_release_elapsed >= BOSS_ORBIT_RELEASE_INTERVAL and boss_orbit_release_index < boss_orbit_group.size():
				boss_orbit_release_elapsed -= BOSS_ORBIT_RELEASE_INTERVAL
				var minion := boss_orbit_group[boss_orbit_release_index].get_ref() as Enemy
				boss_orbit_release_index += 1
				if is_instance_valid(minion) and is_instance_valid(target):
					minion.launch_from_boss_orbit(target)
			if boss_orbit_release_index >= boss_orbit_group.size():
				boss_orbit_state = BOSS_WAITING_FOR_GROUP_DEATH
		BOSS_WAITING_FOR_GROUP_DEATH:
			if _boss_orbit_group_is_defeated():
				boss_orbit_state = BOSS_RECOVERING
				boss_orbit_elapsed = BOSS_ORBIT_RECOVERY_TIME
		BOSS_RECOVERING:
			boss_orbit_elapsed -= action_delta
			if boss_orbit_elapsed <= 0.0:
				boss_orbit_state = 0

func _start_boss_orbit_barrage() -> void:
	var spawner := get_tree().get_first_node_in_group("enemy_spawner") as EnemySpawner
	if not is_instance_valid(spawner) or not spawner.enemy_scene:
		return
	boss_orbit_group.clear()
	boss_orbit_elapsed = 0.0
	boss_orbit_release_elapsed = 0.0
	boss_orbit_release_index = 0
	for index in range(BOSS_ORBIT_MINION_COUNT):
		var minion := spawner.enemy_scene.instantiate() as Enemy
		minion.global_position = global_position
		get_tree().current_scene.add_child(minion)
		EnemyRegistry.update_enemy(minion)
		minion.begin_boss_orbit(self, TAU * float(index) / BOSS_ORBIT_MINION_COUNT)
		boss_orbit_group.append(weakref(minion))
	boss_orbit_state = BOSS_ORBITING

func _boss_orbit_group_is_defeated() -> bool:
	for minion_ref in boss_orbit_group:
		if is_instance_valid(minion_ref.get_ref()):
			return false
	return true

func apply_elemental_affliction(element: StringName, duration: float, damage_per_second: float = 0.0) -> void:
	if dying or duration <= 0.0 or element.is_empty():
		return
	var entry: Dictionary = afflictions.get(element, {})
	entry["stacks"] = int(entry.get("stacks", 0)) + 1
	entry["remaining"] = maxf(float(entry.get("remaining", 0.0)), duration)
	if damage_per_second > 0.0:
		entry["damage_per_second"] = maxf(float(entry.get("damage_per_second", 0.0)), damage_per_second)
		entry["total_burn_damage"] = float(entry.get("total_burn_damage", 0.0)) + duration * damage_per_second
	if element == &"burning" and int(entry["stacks"]) >= BURNING_STACK_THRESHOLD:
		var full_stack_damage := float(entry.get("total_burn_damage", 0.0))
		afflictions.erase(element)
		affliction_fx.configure(afflictions)
		_update_affliction_label()
		_trigger_burning_stack_explosion(full_stack_damage * BURNING_EXPLOSION_MULTIPLIER)
		return
	afflictions[element] = entry
	affliction_fx.configure(afflictions)
	_update_affliction_label()

func _process_afflictions(delta: float) -> void:
	if afflictions.is_empty():
		return
	affliction_tick_elapsed += delta
	while affliction_tick_elapsed >= 1.0 and not dying:
		affliction_tick_elapsed -= 1.0
		var burning: Dictionary = afflictions.get(&"burning", {})
		if not burning.is_empty():
			var burn_damage := float(burning.get("damage_per_second", 0.0)) * float(burning.get("stacks", 0))
			if burn_damage > 0.0:
				GameEvents.damage_dealt.emit(burn_damage, "burning")
				health.take_damage(burn_damage)
	var expired: Array[StringName] = []
	for element in afflictions:
		var entry: Dictionary = afflictions[element]
		entry["remaining"] = float(entry.get("remaining", 0.0)) - delta
		if entry["remaining"] <= 0.0:
			expired.append(element)
		else:
			afflictions[element] = entry
	for element in expired:
		afflictions.erase(element)
	if not expired.is_empty():
		affliction_fx.configure(afflictions)
		_update_affliction_label()

func _trigger_burning_stack_explosion(damage: float) -> void:
	if dying or damage <= 0.0:
		return
	var effect := FIRE_EXPLOSION_FX.new() as FireExplosionFX
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position
	effect.configure(BURNING_EXPLOSION_RADIUS)
	for enemy in EnemyRegistry.get_in_radius(global_position, BURNING_EXPLOSION_RADIUS):
		GameEvents.damage_dealt.emit(damage, "burning_stack")
		enemy.health.take_damage(damage)

func _update_affliction_label() -> void:
	var burning: Dictionary = afflictions.get(&"burning", {})
	if burning.is_empty():
		affliction_icon.clear()
		return
	affliction_icon.configure(&"burning", int(burning.get("stacks", 0)))

func apply_projectile_impact(projectile_direction: Vector2, damage_amount: float = 0.0) -> void:
	if dying:
		return
	var health_fraction := clampf(damage_amount / maxf(health.maximum, 1.0), 0.0, 1.0)
	# Actual health removed controls the hit. The curve is readable for light
	# shots, forceful for big hits, and size-resisted for large bodies.
	var shaped_fraction := pow(health_fraction, 0.82)
	var knockback_strength := lerpf(PROJECTILE_KNOCKBACK_MIN_SPEED, PROJECTILE_KNOCKBACK_MAX_SPEED, shaped_fraction) / get_body_mass()
	impact_velocity += projectile_direction.normalized() * knockback_strength
	impact_velocity = impact_velocity.limit_length(PROJECTILE_KNOCKBACK_MAX_SPEED)

func _decay_impact_velocity(delta: float) -> void:
	impact_velocity *= exp(-PROJECTILE_KNOCKBACK_DRAG * delta)
	if impact_velocity.length() < PROJECTILE_KNOCKBACK_STOP_SPEED:
		impact_velocity = Vector2.ZERO

func apply_player_body_push(player_position: Vector2, player_mass: float, player_speed: float, delta: float) -> void:
	if dying:
		return
	var push_direction := player_position.direction_to(global_position)
	if push_direction == Vector2.ZERO:
		return
	var resistance := get_body_mass()
	var player_share := player_mass / (player_mass + resistance)
	var target_push_velocity := push_direction * player_speed * PLAYER_PUSH_SPEED_MULTIPLIER * player_share
	impact_velocity = impact_velocity.move_toward(target_push_velocity, PLAYER_PUSH_RESPONSE * delta)

func get_body_mass() -> float:
	var body_scale := maxf(absf(global_scale.x), absf(global_scale.y))
	# Use the same softened curve as Player: size matters without turning
	# a merely 2x-sized enemy into an immovable wall.
	return maxf(pow(body_scale, 1.6), 0.05)

func configure_boss() -> void:
	if is_boss:
		return
	is_boss = true
	stats.max_health *= 100.0
	# The original boss was 5x scale and 0.2x speed. Keep the imposing feel,
	# but make it 30% smaller and three times quicker.
	stats.move_speed *= 0.6
	stats.damage = 0.0
	scale = Vector2.ONE * 3.5
	health_label.hide()
	affliction_icon.scale = Vector2.ONE * (0.65 / 3.5)
	affliction_icon.position = Vector2(-150.0, -72.0) / 3.5
	health.configure(stats.max_health)
	contact_damage.configure(0.0, stats.cooldown)
	boss_health_bar.configure("BOSS 1  //  RIFT MAW", stats.max_health, Color(1.0, 0.08, 0.46, 0.98))
	var presence: Node2D = BOSS_PRESENCE_FX.new()
	presence.z_index = -1
	add_child(presence)

func _on_died() -> void:
	if dying:
		return
	dying = true
	GameEvents.enemy_defeated.emit()
	GameEvents.enemy_defeated_details.emit(is_boss)
	_try_drop_loot()
	if xp_gem_scene:
		var gem := xp_gem_scene.instantiate() as XPGem
		gem.global_position = global_position
		gem.set_xp_value(stats.xp_reward)
		get_tree().current_scene.call_deferred("add_child", gem)
	var visual_scale := maxf(absf($Visual.global_scale.x), absf($Visual.global_scale.y))
	if is_boss:
		var boss_effect := BOSS_DEATH_FX.new() as BossDeathFX
		get_tree().current_scene.add_child(boss_effect)
		boss_effect.global_position = global_position
		boss_effect.configure(19.0 * visual_scale * 3.0)
	else:
		var effect := DEATH_FX.new() as EnemyDeathFX
		get_tree().current_scene.add_child(effect)
		effect.global_position = global_position
		effect.configure(GameEvents.enemy_death_effect, 19.0 * visual_scale)
	queue_free()

func _try_drop_loot() -> void:
	if not loot_drop_scene or loot_definitions.is_empty():
		return
	var roll := randf() * 100.0
	var rarity := -1
	# Original absolute chances reduced by exactly 50x: 0.002% mythic,
	# 0.01% epic, 0.02% rare, 0.06% uncommon, and 0.1% common.
	if roll < 0.002:
		rarity = ItemDefinition.Rarity.MYTHIC
	elif roll < 0.012:
		rarity = ItemDefinition.Rarity.EPIC
	elif roll < 0.032:
		rarity = ItemDefinition.Rarity.RARE
	elif roll < 0.092:
		rarity = ItemDefinition.Rarity.UNCOMMON
	elif roll < 0.192:
		rarity = ItemDefinition.Rarity.COMMON
	if rarity < 0:
		return
	var drop := loot_drop_scene.instantiate() as Area2D
	drop.call("configure", loot_definitions.pick_random(), rarity)
	drop.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", drop)
