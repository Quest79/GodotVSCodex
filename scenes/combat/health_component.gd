class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal died

var maximum := 1.0
var current := 1.0

func configure(max_health: float) -> void:
	maximum = maxf(max_health, 1.0)
	current = maximum
	health_changed.emit(current, maximum)

func take_damage(amount: float) -> void:
	if amount <= 0.0 or current <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	damaged.emit(amount)
	health_changed.emit(current, maximum)
	if current <= 0.0:
		died.emit()

func increase_max_health(amount: float, heal_amount: float = 0.0) -> void:
	maximum = maxf(maximum + amount, 1.0)
	current = minf(current + heal_amount, maximum)
	health_changed.emit(current, maximum)

func heal(amount: float) -> void:
	if amount <= 0.0 or current <= 0.0 or current >= maximum:
		return
	current = minf(current + amount, maximum)
	health_changed.emit(current, maximum)
