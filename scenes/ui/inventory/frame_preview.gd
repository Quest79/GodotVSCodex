extends Control

func _draw() -> void:
	var center := size * Vector2(0.5, 0.48)
	draw_circle(center, 76.0, Color(0.02, 0.15, 0.2, 0.28), true, -1.0, true)
	draw_arc(center, 78.0, -2.7, 0.15, 42, Color(0.08, 0.85, 1, 0.85), 3.0, true)
	draw_arc(center, 78.0, 0.45, 2.2, 28, Color(1, 0.1, 0.62, 0.75), 3.0, true)
	draw_circle(center + Vector2(0, -40), 25.0, Color(0.025, 0.08, 0.12, 1), true, -1.0, true)
	draw_arc(center + Vector2(0, -40), 25.0, 0.0, TAU, 32, Color(0.1, 0.75, 0.9, 0.9), 2.0, true)
	var torso := PackedVector2Array([center + Vector2(-42, -10), center + Vector2(42, -10), center + Vector2(56, 72), center + Vector2(-56, 72)])
	draw_colored_polygon(torso, Color(0.018, 0.06, 0.09, 1))
	draw_polyline(PackedVector2Array([torso[0], torso[1], torso[2], torso[3], torso[0]]), Color(0.12, 0.62, 0.72, 0.75), 2.0, true)
	draw_line(center + Vector2(-25, 15), center + Vector2(25, 15), Color(1, 0.12, 0.62, 0.7), 2.0, true)
	draw_circle(center + Vector2(0, 34), 8.0, Color(0.08, 0.9, 1, 0.9), true, -1.0, true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

