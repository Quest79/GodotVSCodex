class_name ContactDamage
extends Area2D

@export var damage := 1.0
@export var cooldown := 1.0

@onready var check_timer: Timer = $Timer

var last_hit_times: Dictionary[int, float] = {}

func _ready() -> void:
	body_entered.connect(_try_damage)
	check_timer.timeout.connect(_damage_overlapping_bodies)
	check_timer.start()

func configure(new_damage: float, new_cooldown: float) -> void:
	damage = new_damage
	cooldown = maxf(new_cooldown, 0.05)

func _damage_overlapping_bodies() -> void:
	for body in get_overlapping_bodies():
		_try_damage(body)

func _try_damage(body: Node2D) -> void:
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if not health:
		return
	var target_id := body.get_instance_id()
	var now := Time.get_ticks_msec() / 1000.0
	var last_hit: float = last_hit_times.get(target_id, -INF)
	if now - last_hit < cooldown:
		return
	last_hit_times[target_id] = now
	health.take_damage(damage)
