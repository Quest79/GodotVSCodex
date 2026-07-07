class_name DamageArea
extends Area2D

@export var damage := 5.0
@export var cooldown := 0.75

@onready var timer: Timer = $Timer

func _ready() -> void:
	timer.wait_time = cooldown
	timer.timeout.connect(_deal_damage)
	timer.start()

func configure(new_damage: float, new_cooldown: float) -> void:
	damage = new_damage
	cooldown = maxf(new_cooldown, 0.05)
	if is_node_ready():
		timer.wait_time = cooldown

func _deal_damage() -> void:
	for area in get_overlapping_areas():
		if area.has_method("take_damage"):
			area.take_damage(damage)

