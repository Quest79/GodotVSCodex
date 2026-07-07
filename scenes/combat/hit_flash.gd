class_name HitFlash
extends Node

@export var health_component: HealthComponent
@export var target: CanvasItem
@export var duration := 0.12
@export var pop_scale := 1.18

var active_tween: Tween
var base_modulate := Color.WHITE
var base_scale := Vector2.ONE

func _ready() -> void:
	if not health_component or not target:
		return
	base_modulate = target.modulate
	base_scale = target.scale
	health_component.damaged.connect(_play)

func _play(_amount: float) -> void:
	if active_tween:
		active_tween.kill()
	target.modulate = Color(2.2, 2.2, 2.2, 1.0)
	target.scale = base_scale * pop_scale
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(target, "modulate", base_modulate, duration)
	active_tween.tween_property(target, "scale", base_scale, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

