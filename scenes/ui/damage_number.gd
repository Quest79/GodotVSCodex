class_name DamageNumber
extends Node2D

var amount := 0.0

@onready var label: Label = $Label

func setup(new_amount: float, spawn_position: Vector2) -> void:
	amount = new_amount
	global_position = spawn_position

func _ready() -> void:
	label.text = "%d" % roundi(amount)
	scale = Vector2.ONE * 0.85
	rotation = randf_range(-0.025, 0.025)

	var motion_tween := create_tween().set_parallel(true)
	motion_tween.tween_property(self, "position", position + Vector2(randf_range(-3.0, 3.0), -18.0), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	motion_tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.25)
	motion_tween.chain().tween_callback(queue_free)

	var pop_tween := create_tween()
	pop_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
