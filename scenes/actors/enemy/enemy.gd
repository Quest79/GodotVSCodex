class_name Enemy
extends CharacterBody2D

const DEATH_FX := preload("res://scenes/actors/enemy/enemy_death_fx.gd")

@export var base_stats: ActorStats
@export var xp_gem_scene: PackedScene
@export var damage_number_scene: PackedScene
@export var loot_drop_scene: PackedScene
@export var loot_definitions: Array[Resource] = []

@onready var health: HealthComponent = $HealthComponent
@onready var contact_damage: ContactDamage = $ContactDamage
@onready var health_label: Label = $HealthLabel

var stats: ActorStats
var target: Node2D
var dying := false

func _ready() -> void:
	stats = base_stats.duplicate(true)
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	health.health_changed.connect(_on_health_changed)
	health.configure(stats.max_health)
	contact_damage.configure(stats.damage, stats.cooldown)
	target = get_tree().get_first_node_in_group("player") as Node2D

func _on_health_changed(current: float, _maximum: float) -> void:
	health_label.text = "%d HP" % ceili(current)

func _on_damaged(amount: float) -> void:
	if not damage_number_scene:
		return
	var number := damage_number_scene.instantiate() as Node2D
	number.call("setup", amount, global_position + Vector2(0.0, -24.0))
	get_tree().current_scene.add_child(number)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		return
	velocity = global_position.direction_to(target.global_position) * stats.move_speed
	move_and_slide()

func _on_died() -> void:
	if dying:
		return
	dying = true
	GameEvents.enemy_defeated.emit()
	_try_drop_loot()
	if xp_gem_scene:
		var gem := xp_gem_scene.instantiate() as XPGem
		gem.global_position = global_position
		gem.set_xp_value(stats.xp_reward)
		get_tree().current_scene.call_deferred("add_child", gem)
	var effect := DEATH_FX.new() as EnemyDeathFX
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position
	var visual_scale := maxf(absf($Visual.global_scale.x), absf($Visual.global_scale.y))
	effect.configure(GameEvents.enemy_death_effect, 19.0 * visual_scale)
	queue_free()

func _try_drop_loot() -> void:
	if not loot_drop_scene or loot_definitions.is_empty():
		return
	var roll := randf() * 100.0
	var rarity := -1
	# Absolute per-kill chances: 0.1% mythic, 0.5% epic, 1% rare,
	# 3% uncommon, and 5% common. The remaining 90.4% drops nothing.
	if roll < 0.1:
		rarity = ItemDefinition.Rarity.MYTHIC
	elif roll < 0.6:
		rarity = ItemDefinition.Rarity.EPIC
	elif roll < 1.6:
		rarity = ItemDefinition.Rarity.RARE
	elif roll < 4.6:
		rarity = ItemDefinition.Rarity.UNCOMMON
	elif roll < 9.6:
		rarity = ItemDefinition.Rarity.COMMON
	if rarity < 0:
		return
	var drop := loot_drop_scene.instantiate() as Area2D
	drop.call("configure", loot_definitions.pick_random(), rarity)
	drop.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", drop)
