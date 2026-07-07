extends Node2D

const NEON_CYAN := Color(0.08, 0.9, 1.0, 1.0)
const NEON_MAGENTA := Color(1.0, 0.12, 0.65, 1.0)

var animation_time := 0.0
var motion_amount := 0.0

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody2D
	var target_motion := clampf(body.velocity.length() / 280.0, 0.0, 1.0)
	motion_amount = lerpf(motion_amount, target_motion, 1.0 - exp(-10.0 * delta))
	animation_time = fmod(animation_time + delta * (1.5 + motion_amount * 3.0), TAU)
	var target_tilt := clampf(body.velocity.x / 280.0, -1.0, 1.0) * 0.1
	rotation = lerp_angle(rotation, target_tilt, 1.0 - exp(-8.0 * delta))
	var pulse := sin(animation_time * 2.0) * 0.015 * motion_amount
	scale = Vector2(1.0 + pulse, 1.0 - pulse)
	queue_redraw()

func _draw() -> void:
	# Soft outer silhouette and armored shell.
	draw_circle(Vector2.ZERO, 25.0, Color(0.01, 0.45, 0.58, 0.16), true, -1.0, true)
	draw_circle(Vector2.ZERO, 21.0, Color(0.015, 0.04, 0.09, 1.0), true, -1.0, true)
	draw_circle(Vector2.ZERO, 17.5, Color(0.035, 0.12, 0.18, 1.0), true, -1.0, true)

	# Counter-rotating neon circuit bands keep the round silhouette readable.
	draw_arc(Vector2.ZERO, 20.5, animation_time, animation_time + 1.75, 18, NEON_CYAN, 3.0, true)
	draw_arc(Vector2.ZERO, 20.5, animation_time + PI, animation_time + PI + 0.85, 10, NEON_MAGENTA, 3.0, true)
	draw_arc(Vector2.ZERO, 14.0, -animation_time * 0.7, -animation_time * 0.7 + 2.2, 20, Color(0.12, 0.55, 0.75, 0.9), 1.5, true)

	# Central reactor and asymmetric cybernetic details.
	draw_circle(Vector2.ZERO, 8.0, Color(0.01, 0.3, 0.42, 1.0), true, -1.0, true)
	draw_circle(Vector2.ZERO, 4.5, NEON_CYAN, true, -1.0, true)
	draw_circle(Vector2(-1.5, -1.5), 1.7, Color(0.8, 1.0, 1.0, 1.0), true, -1.0, true)
	draw_line(Vector2(-14, 5), Vector2(-8, 3), NEON_MAGENTA, 2.0, true)
	draw_line(Vector2(10, -7), Vector2(15, -10), NEON_CYAN, 2.0, true)

