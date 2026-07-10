class_name FireExplosionFX
extends Node2D

const DURATION := 0.52
const SEGMENT_COUNT := 16

var maximum_radius := 80.0
var elapsed := 0.0
var redraw_elapsed := 0.0

func configure(radius: float) -> void:
	maximum_radius = maxf(radius, 12.0)
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
	var expansion := 1.0 - pow(1.0 - progress, 3.0)
	var fade := pow(1.0 - progress, 1.35)
	var radius := maximum_radius * expansion
	var rotation_offset := elapsed * 2.6

	# Fast white-hot ignition followed by a molten core.
	var flash := maxf(0.0, 1.0 - progress * 4.5)
	draw_circle(Vector2.ZERO, maximum_radius * 0.3 * flash, Color(1.0, 0.95, 0.62, flash * 0.72), true, -1.0, true)
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.12, 0.015, fade * 0.055), true, -1.0, true)
	draw_circle(Vector2.ZERO, radius * 0.42, Color(1.0, 0.34, 0.025, fade * 0.12), true, -1.0, true)

	# Broken rotating rings give the explosion its cyberpunk pulse.
	for index in SEGMENT_COUNT:
		if index % 3 == 2:
			continue
		var segment := TAU / float(SEGMENT_COUNT)
		var start_angle := rotation_offset + index * segment
		var end_angle := start_angle + segment * 0.62
		var ring_color := Color(1.0, 0.24 + 0.025 * (index % 4), 0.015, fade * 0.92)
		draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 6, ring_color, 3.2, true)

	# A second counter-rotating circuit ring marks the damage boundary.
	var inner_radius := radius * 0.72
	for index in 8:
		var segment := TAU / 8.0
		var start_angle := -rotation_offset * 1.35 + index * segment
		draw_arc(Vector2.ZERO, inner_radius, start_angle, start_angle + segment * 0.48, 5, Color(1.0, 0.68, 0.08, fade * 0.72), 1.8, true)

	# Angular spokes and nodes read as a projected combat glyph.
	for index in 12:
		var angle := index * TAU / 12.0 + rotation_offset * 0.18
		var direction := Vector2.from_angle(angle)
		var spoke_start := direction * radius * 0.5
		var spoke_end := direction * radius * (0.86 + 0.06 * sin(index * 2.1))
		draw_line(spoke_start, spoke_end, Color(1.0, 0.38, 0.025, fade * 0.52), 1.4, true)
		draw_circle(spoke_end, 2.2 + 1.2 * fade, Color(1.0, 0.82, 0.2, fade), true, -1.0, true)

	# Outward-drifting embers linger after the ring reaches full size.
	for index in 18:
		var angle := index * 2.399 + sin(index * 3.7) * 0.22
		var travel := maximum_radius * (0.18 + 0.9 * expansion * (0.55 + 0.03 * (index % 7)))
		var ember_position := Vector2.from_angle(angle) * travel
		var ember_size := 1.2 + float(index % 3) * 0.7
		draw_circle(ember_position, ember_size, Color(1.0, 0.5 + 0.08 * (index % 3), 0.025, fade * 0.9), true, -1.0, true)
