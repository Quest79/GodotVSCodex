class_name Hurtbox
extends Area2D

@export var health_component: HealthComponent

func take_damage(amount: float) -> void:
	if health_component:
		health_component.take_damage(amount)
