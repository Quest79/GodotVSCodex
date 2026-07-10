extends Node2D

var age := 0.0
var duration := 0.55
var awakened := false
var strength := 1.0
var redraw_elapsed := 0.0

func configure(is_awakened: bool, amount: int) -> void:
	awakened = is_awakened
	strength = clampf(1.0 + amount * 0.035, 1.0, 1.8)
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	redraw_elapsed += delta
	if redraw_elapsed >= 1.0 / 30.0:
		redraw_elapsed = 0.0
		queue_redraw()

func _draw() -> void:
	var progress := age / duration
	var fade := 1.0 - progress
	var color := Color("#aeeaff") if awakened else Color("#ad78db")
	for index in range(9):
		var angle := index * TAU / 9.0 + progress * 0.65
		var distance := lerpf(5.0, 34.0 * strength, progress)
		var point := Vector2.from_angle(angle) * distance
		var tangent := Vector2.from_angle(angle + PI * 0.5) * 3.0
		draw_colored_polygon(PackedVector2Array([point - tangent, point + tangent, point + Vector2.from_angle(angle) * 7.0 * fade]), Color(color, fade))
	var ring_color := Color(color, fade * 0.65)
	draw_arc(Vector2.ZERO, lerpf(7.0, 31.0 * strength, progress), 0.0, TAU, 32, ring_color, 2.0 * fade, true)
