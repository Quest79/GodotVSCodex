extends Node2D

func _draw() -> void:
	draw_circle(Vector2.ZERO, 19.0, Color(0.35, 0.035, 0.07, 1.0), true, -1.0, true)
	draw_circle(Vector2.ZERO, 16.0, Color(0.95, 0.16, 0.28, 1.0), true, -1.0, true)
	draw_circle(Vector2(-5.0, -5.0), 4.5, Color(1.0, 0.55, 0.62, 0.9), true, -1.0, true)

