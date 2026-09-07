class_name GPUProjectileVisualProxy
extends Node2D

const PROJECTILE_VISUAL_SCRIPT := preload("res://scenes/combat/projectile_visual.gd")

var direction := Vector2.RIGHT
var speed := 0.0
var skill_id := &"default_attack"
var visual: Node2D


func _ready() -> void:
	visual = Node2D.new()
	visual.set_script(PROJECTILE_VISUAL_SCRIPT)
	add_child(visual)
	set_process(false)
	visible = false


func activate(new_skill_id: StringName, position: Vector2, new_direction: Vector2, new_speed: float, new_scale: float) -> void:
	skill_id = new_skill_id
	global_position = position
	direction = new_direction.normalized() if new_direction != Vector2.ZERO else Vector2.RIGHT
	speed = new_speed
	scale = Vector2.ONE * maxf(new_scale, 0.01)
	visible = true
	visual.visible = true
	visual.call("configure", skill_id)
	set_process(true)


func apply_snapshot(position: Vector2, new_direction: Vector2, new_speed: float, new_scale: float) -> void:
	global_position = position
	if new_direction != Vector2.ZERO:
		direction = new_direction.normalized()
	speed = new_speed
	scale = Vector2.ONE * maxf(new_scale, 0.01)


func deactivate() -> void:
	visible = false
	if is_instance_valid(visual):
		visual.visible = false
		visual.set_process(false)
	set_process(false)


func _process(delta: float) -> void:
	global_position += direction * speed * delta
