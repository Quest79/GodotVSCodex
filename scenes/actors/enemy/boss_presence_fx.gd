extends Node2D

var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(elapsed * 2.4)
	for ring_index in range(3):
		var radius := 27.0 + ring_index * 8.0 + pulse * 3.0
		var spin := elapsed * (0.7 + ring_index * 0.24) * (-1.0 if ring_index % 2 == 0 else 1.0)
		for segment_index in range(7):
			var start := spin + segment_index * TAU / 7.0
			draw_arc(Vector2.ZERO, radius, start, start + 0.46, 8, Color(0.96, 0.08, 0.48, 0.38), 1.25, true)
	for index in range(12):
		var angle := elapsed * 1.8 + index * TAU / 12.0
		var point := Vector2.from_angle(angle) * (31.0 + sin(elapsed * 3.0 + index) * 4.0)
		draw_circle(point, 1.6 + pulse * 0.8, Color(0.2, 0.95, 1.0, 0.72), true, -1.0, true)
