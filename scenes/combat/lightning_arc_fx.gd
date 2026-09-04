class_name LightningArcFX
extends Node2D

const DURATION := 0.18
const SEGMENTS := 10

var endpoint := Vector2.ZERO
var age := 0.0


func configure(start: Vector2, finish: Vector2) -> void:
	global_position = start
	endpoint = finish - start
	z_index = 7
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	if age >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if endpoint == Vector2.ZERO:
		return
	var progress := clampf(age / DURATION, 0.0, 1.0)
	var fade := 1.0 - progress
	var normal := endpoint.normalized().orthogonal()
	var points := PackedVector2Array()
	for index in range(SEGMENTS + 1):
		var t := float(index) / float(SEGMENTS)
		var point := endpoint * t
		if index > 0 and index < SEGMENTS:
			var envelope := sin(t * PI)
			var jitter := sin(float(index) * 8.73 + age * 93.0) * 9.0 * envelope
			point += normal * jitter
		points.append(point)
	draw_polyline(points, Color(0.38, 0.12, 1.0, 0.28 * fade), 8.0, true)
	draw_polyline(points, Color(0.68, 0.38, 1.0, 0.92 * fade), 3.5, true)
	draw_polyline(points, Color(1.0, 0.96, 1.0, fade), 1.2, true)
	draw_circle(Vector2.ZERO, 5.0 + progress * 5.0, Color(0.75, 0.5, 1.0, 0.32 * fade))
	draw_circle(endpoint, 6.0 + progress * 8.0, Color(0.9, 0.72, 1.0, 0.38 * fade))
