class_name BossDeathFX
extends Node2D

const DURATION := 1.55
const PARTICLE_COUNT := 108

var radius := 95.0
var elapsed := 0.0
var redraw_elapsed := 0.0

func configure(new_radius: float) -> void:
	radius = maxf(new_radius, 45.0)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	redraw_elapsed += delta
	if redraw_elapsed >= 1.0 / 30.0:
		redraw_elapsed = 0.0
		queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / DURATION, 0.0, 1.0)
	var burst := 1.0 - pow(1.0 - progress, 3.2)
	var fade := pow(1.0 - progress, 1.4)
	var flash := maxf(0.0, 1.0 - progress * 5.0)
	var outer_radius := radius * (0.3 + burst * 2.5)

	draw_circle(Vector2.ZERO, radius * 1.25 * flash, Color(0.96, 0.2, 1.0, flash * 0.72), true, -1.0, true)
	draw_circle(Vector2.ZERO, radius * 0.58 * flash, Color(0.8, 1.0, 1.0, flash * 0.9), true, -1.0, true)
	draw_circle(Vector2.ZERO, outer_radius, Color(0.04, 0.9, 1.0, fade * 0.075), true, -1.0, true)
	draw_circle(Vector2.ZERO, outer_radius * 0.7, Color(0.35, 0.06, 1.0, fade * 0.08), true, -1.0, true)
	draw_circle(Vector2.ZERO, outer_radius * 0.42, Color(1.0, 0.06, 0.58, fade * 0.13), true, -1.0, true)

	for ring_index in 5:
		var ring_radius := outer_radius * (0.32 + ring_index * 0.18)
		for segment_index in 18:
			if (segment_index + ring_index * 2) % 4 == 0:
				continue
			var segment := TAU / 18.0
			var spin := elapsed * (2.1 + ring_index * 0.95) * (-1.0 if ring_index % 2 == 0 else 1.0)
			var start := segment_index * segment + spin
			var color := Color(0.08, 0.96, 1.0, fade * (0.98 - ring_index * 0.12))
			if ring_index % 3 == 1:
				color = Color(1.0, 0.08, 0.64, fade * 0.84)
			elif ring_index % 3 == 2:
				color = Color(0.55, 0.22, 1.0, fade * 0.72)
			draw_arc(Vector2.ZERO, ring_radius, start, start + segment * 0.64, 7, color, 4.2 - ring_index * 0.45, true)

	for index in 16:
		var angle := index * TAU / 16.0 - elapsed * 1.7
		var direction := Vector2.from_angle(angle)
		var inner := direction * outer_radius * (0.12 + 0.22 * sin(elapsed * 6.0 + index) * sin(elapsed * 6.0 + index))
		var outer := direction * outer_radius * (0.82 + 0.12 * sin(elapsed * 4.0 + index * 1.7))
		draw_line(inner, outer, Color(0.22, 0.96, 1.0, fade * 0.38), 1.8, true)
		draw_circle(outer, 3.5 + 2.0 * fade, Color(1.0, 0.2, 0.72, fade), true, -1.0, true)

	for index in PARTICLE_COUNT:
		var angle := index * 2.399963 + sin(index * 4.13) * 0.18
		var direction := Vector2.from_angle(angle)
		var travel := radius * burst * (0.65 + 2.65 * (0.48 + 0.04 * float(index % 9)))
		var position := direction * travel
		var color := Color(0.1, 0.96, 1.0, fade)
		if index % 3 == 0:
			color = Color(1.0, 0.12, 0.66, fade)
		elif index % 7 == 0:
			color = Color(0.96, 0.9, 1.0, fade)
		var length := radius * (0.16 + 0.03 * float(index % 4)) * (1.0 - progress * 0.3)
		draw_line(position - direction * length, position + direction * length * 0.55, color, 1.8 + float(index % 3) * 0.55, true)
		if index % 2 == 0:
			draw_circle(position, 1.5 + float(index % 3), color, true, -1.0, true)
