extends Node2D

const NEON_CYAN := Color(0.08, 0.9, 1.0, 1.0)
const NEON_MAGENTA := Color(1.0, 0.12, 0.65, 1.0)

var animation_time := 0.0
var motion_amount := 0.0
var redraw_elapsed := 0.0

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody2D
	var target_motion := clampf(body.velocity.length() / 280.0, 0.0, 1.0)
	motion_amount = lerpf(motion_amount, target_motion, 1.0 - exp(-10.0 * delta))
	animation_time = fmod(animation_time + delta * (1.5 + motion_amount * 3.0), TAU)
	var target_tilt := clampf(body.velocity.x / 280.0, -1.0, 1.0) * 0.1
	rotation = lerp_angle(rotation, target_tilt, 1.0 - exp(-8.0 * delta))
	var pulse := sin(animation_time * 2.0) * 0.015 * motion_amount
	scale = Vector2(1.0 + pulse, 1.0 - pulse)
	redraw_elapsed += delta
	if redraw_elapsed >= 1.0 / 30.0:
		redraw_elapsed = 0.0
		queue_redraw()

func _draw() -> void:
	var stride := sin(animation_time * 2.0) * motion_amount

	# A compact top-down cyber hunter silhouette, with a strong shadow for grounding.
	draw_shadow_ellipse(Vector2(0, 20), Vector2(25, 10), Color(0.0, 0.02, 0.04, 0.42))
	draw_circle(Vector2.ZERO, 29.0, Color(0.01, 0.45, 0.58, 0.12), true, -1.0, true)

	# Split boots and lower coat make movement readable at game scale.
	var left_leg := PackedVector2Array([Vector2(-13, 9 + stride), Vector2(-2, 10 - stride), Vector2(-4, 27 - stride), Vector2(-16, 27 + stride)])
	var right_leg := PackedVector2Array([Vector2(2, 10 - stride), Vector2(13, 9 + stride), Vector2(16, 27 + stride), Vector2(4, 27 - stride)])
	draw_colored_polygon(left_leg, Color(0.015, 0.05, 0.08, 1.0))
	draw_colored_polygon(right_leg, Color(0.02, 0.065, 0.1, 1.0))
	draw_polyline(PackedVector2Array([left_leg[0], left_leg[1], left_leg[2], left_leg[3], left_leg[0]]), Color(0.08, 0.55, 0.65, 0.9), 1.6, true)
	draw_polyline(PackedVector2Array([right_leg[0], right_leg[1], right_leg[2], right_leg[3], right_leg[0]]), Color(0.08, 0.55, 0.65, 0.9), 1.6, true)
	draw_line(Vector2(-14, 26 + stride), Vector2(-4, 26 + stride), NEON_MAGENTA, 2.4, true)
	draw_line(Vector2(4, 26 - stride), Vector2(15, 26 - stride), NEON_CYAN, 2.4, true)

	# Asymmetric coat/shoulder silhouette: this is the visual identity, not a circle.
	var coat := PackedVector2Array([Vector2(-16, -7), Vector2(16, -7), Vector2(20, 12), Vector2(11, 22), Vector2(-11, 22), Vector2(-20, 12)])
	draw_colored_polygon(coat, Color(0.012, 0.035, 0.06, 1.0))
	draw_polyline(PackedVector2Array([coat[0], coat[1], coat[2], coat[3], coat[4], coat[5], coat[0]]), Color(0.08, 0.72, 0.82, 0.95), 2.0, true)
	draw_line(Vector2(-17, 0), Vector2(-24, 8), NEON_MAGENTA, 3.0, true)
	draw_line(Vector2(17, 0), Vector2(24, -8), NEON_CYAN, 3.0, true)
	draw_line(Vector2(-9, 13), Vector2(9, 13), Color(1.0, 0.12, 0.65, 0.85), 2.0, true)

	# Chest plate and reactor.
	var chest := PackedVector2Array([Vector2(-10, -5), Vector2(10, -5), Vector2(7, 12), Vector2(0, 17), Vector2(-7, 12)])
	draw_colored_polygon(chest, Color(0.025, 0.12, 0.17, 1.0))
	draw_polyline(PackedVector2Array([chest[0], chest[1], chest[2], chest[3], chest[4], chest[0]]), Color(0.16, 0.52, 0.62, 0.9), 1.2, true)
	draw_circle(Vector2(0, 5), 7.0, Color(0.01, 0.25, 0.34, 1.0), true, -1.0, true)
	draw_circle(Vector2(0, 5), 4.0, NEON_CYAN, true, -1.0, true)
	draw_circle(Vector2(-1.2, 3.8), 1.5, Color(0.85, 1.0, 1.0, 1.0), true, -1.0, true)

	# Helmet, fins, and one unmistakable horizontal visor.
	var helmet := PackedVector2Array([Vector2(-13, -20), Vector2(-7, -30), Vector2(7, -30), Vector2(14, -20), Vector2(10, -8), Vector2(-10, -8)])
	draw_colored_polygon(helmet, Color(0.02, 0.07, 0.11, 1.0))
	draw_polyline(PackedVector2Array([helmet[0], helmet[1], helmet[2], helmet[3], helmet[4], helmet[5], helmet[0]]), Color(0.1, 0.8, 0.9, 1.0), 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -19), Vector2(10, -19), Vector2(8, -12), Vector2(-8, -12)]), Color(0.32, 0.95, 1.0, 0.95))
	draw_line(Vector2(-8, -16), Vector2(8, -16), Color(0.9, 1.0, 1.0, 0.95), 1.5, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -22), Vector2(-20, -28), Vector2(-13, -14)]), Color(0.08, 0.42, 0.55, 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(12, -22), Vector2(19, -18), Vector2(13, -11)]), Color(0.75, 0.08, 0.42, 1.0))

	# Animated energy traces replace the old featureless orbit rings.
	draw_arc(Vector2.ZERO, 27.0, animation_time, animation_time + 0.9, 10, Color(0.08, 0.9, 1.0, 0.65), 1.8, true)
	draw_arc(Vector2.ZERO, 27.0, animation_time + PI, animation_time + PI + 0.55, 8, Color(1.0, 0.12, 0.65, 0.7), 1.8, true)

func draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 24:
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
