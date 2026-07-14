class_name LevelUpNovaFX
extends Node2D

const DURATION := 1.25
const CYAN := Color(0.08, 0.78, 1.0, 1.0)
const BLUE := Color(0.12, 0.32, 1.0, 1.0)
const VIOLET := Color(0.52, 0.12, 1.0, 1.0)
const MAGENTA := Color(0.95, 0.16, 1.0, 1.0)
const WHITE := Color(0.92, 0.98, 1.0, 1.0)

var elapsed := 0.0
var redraw_elapsed := 0.0

func _ready() -> void:
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
	var burst := 1.0 - pow(1.0 - progress, 3.0)
	var fade := pow(1.0 - progress, 1.15)
	var flash := maxf(0.0, 1.0 - progress * 5.5)
	var rotation_offset := elapsed * 0.75

	# Deep violet/cyan bloom behind the seal.
	draw_circle(Vector2.ZERO, 56.0 + burst * 155.0, Color(0.18, 0.02, 0.65, fade * 0.10))
	draw_circle(Vector2.ZERO, 34.0 + burst * 70.0, Color(0.04, 0.24, 1.0, fade * 0.13))
	draw_circle(Vector2.ZERO, 22.0 + flash * 48.0, Color(0.62, 0.05, 1.0, fade * 0.22))

	# Layered rotating spell seal, with alternating cyan and magenta arcs.
	for ring_index in 5:
		var ring_radius := 28.0 + float(ring_index) * 23.0 + burst * (18.0 + float(ring_index) * 32.0)
		var segment_count := 16 + ring_index * 4
		var segment_angle := TAU / float(segment_count)
		var direction := -1.0 if ring_index % 2 == 0 else 1.0
		for segment_index in segment_count:
			if (segment_index + ring_index) % 3 == 1:
				continue
			var start := segment_index * segment_angle + rotation_offset * direction
			var length := segment_angle * (0.42 + 0.1 * float((segment_index + ring_index) % 3))
			var color := CYAN if (segment_index + ring_index) % 2 == 0 else MAGENTA
			draw_arc(Vector2.ZERO, ring_radius, start, start + length, 5, Color(color, fade * (0.62 - ring_index * 0.055)), 2.0 + float(ring_index % 2), true)

	# Fine radial geometry gives the effect the rune/clockwork density from the reference.
	for spoke_index in 24:
		var angle := TAU * float(spoke_index) / 24.0 + rotation_offset * 0.35
		var direction := Vector2.from_angle(angle)
		var inner := direction * (22.0 + burst * 16.0)
		var outer := direction * (78.0 + burst * 122.0)
		var color := Color(MAGENTA, fade * 0.56) if spoke_index % 2 == 0 else Color(CYAN, fade * 0.42)
		draw_line(inner, outer, color, 1.2, true)
		if spoke_index % 3 == 0:
			draw_diamond(outer, direction, 8.0 + burst * 5.0, color)

	# Large outward-flying crystals are the main visual replacement for the old smooth nova.
	for shard_index in 18:
		var angle := TAU * float(shard_index) / 18.0 + 0.12 * sin(float(shard_index) * 4.7) + rotation_offset * (-0.55 if shard_index % 2 == 0 else 0.55)
		var direction := Vector2.from_angle(angle)
		var distance := 34.0 + burst * (65.0 + float(shard_index % 5) * 19.0)
		var length := 22.0 + float(shard_index % 4) * 7.0
		var width := 6.0 + float(shard_index % 3) * 2.0
		var color := CYAN if shard_index % 3 != 1 else MAGENTA
		draw_crystal(direction * distance, direction, length, width, color, fade * 0.94)

	# Small square-like motes break up the silhouette as it fades.
	for mote_index in 64:
		var angle := float(mote_index) * 2.399963 + elapsed * (0.35 if mote_index % 2 == 0 else -0.5)
		var direction := Vector2.from_angle(angle)
		var distance := 52.0 + burst * (50.0 + float((mote_index * 17) % 100))
		var point := direction * distance
		var size := 1.5 + float(mote_index % 3)
		var color := Color(CYAN, fade * 0.7) if mote_index % 3 == 0 else Color(MAGENTA, fade * 0.76)
		draw_rect(Rect2(point - Vector2(size, size), Vector2(size * 2.0, size * 2.0)), color)

	# Central star and concentric core seal.
	draw_arc(Vector2.ZERO, 16.0 + burst * 18.0, rotation_offset, rotation_offset + TAU * 0.72, 24, Color(WHITE, fade * 0.9), 2.0, true)
	draw_arc(Vector2.ZERO, 25.0 + burst * 25.0, -rotation_offset, -rotation_offset + TAU * 0.55, 24, Color(MAGENTA, fade * 0.9), 2.4, true)
	for ray_index in 8:
		var ray_direction := Vector2.from_angle(TAU * float(ray_index) / 8.0 + rotation_offset)
		draw_line(ray_direction * 4.0, ray_direction * (18.0 + flash * 28.0), Color(WHITE, fade * 0.9), 2.0, true)
	draw_circle(Vector2.ZERO, 15.0 + flash * 18.0, Color(0.7, 0.12, 1.0, fade * 0.24))
	draw_circle(Vector2.ZERO, 8.0 + flash * 8.0, Color(WHITE, fade * 0.96), true, -1.0, true)
	draw_circle(Vector2.ZERO, 3.0 + flash * 3.0, Color(1.0, 1.0, 1.0, fade), true, -1.0, true)

func draw_crystal(center: Vector2, direction: Vector2, length: float, width: float, color: Color, alpha: float) -> void:
	var tangent := Vector2(-direction.y, direction.x)
	var tip := center + direction * length * 0.65
	var tail := center - direction * length * 0.55
	var points := PackedVector2Array([
		tail,
		center - direction * length * 0.12 + tangent * width,
		tip,
		center + direction * length * 0.08 - tangent * width * 0.72,
	])
	draw_colored_polygon(points, Color(color, alpha * 0.2))
	draw_colored_polygon(points, Color(color, alpha))
	draw_line(tail, tip, Color(WHITE, alpha * 0.88), 1.4, true)
	draw_line(center - tangent * width * 0.72, tip, Color(WHITE, alpha * 0.45), 1.0, true)

func draw_diamond(center: Vector2, direction: Vector2, size: float, color: Color) -> void:
	var tangent := Vector2(-direction.y, direction.x)
	var points := PackedVector2Array([
		center + direction * size,
		center + tangent * size * 0.48,
		center - direction * size,
		center - tangent * size * 0.48,
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(WHITE, color.a * 0.82), 1.0, true)
