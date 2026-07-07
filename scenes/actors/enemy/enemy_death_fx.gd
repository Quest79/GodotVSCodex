class_name EnemyDeathFX
extends Node2D

const DURATION := 0.62
const OUTER_COLOR := Color(0.35, 0.035, 0.07, 1.0)
const BODY_COLOR := Color(0.95, 0.16, 0.28, 1.0)
const HIGHLIGHT_COLOR := Color(1.0, 0.55, 0.62, 0.95)

var mode := 0
var elapsed := 0.0
var enemy_radius := 19.0

func configure(effect_mode: int, radius := 19.0) -> void:
	mode = clampi(effect_mode, 0, 2)
	enemy_radius = maxf(radius, 5.0)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / DURATION, 0.0, 1.0)
	match mode:
		0:
			_draw_radial_shatter(progress)
		1:
			_draw_spiral_shatter(progress)
		2:
			_draw_implosion_shatter(progress)

func _draw_enemy_silhouette(scale_amount: float, alpha: float) -> void:
	draw_circle(Vector2.ZERO, enemy_radius * scale_amount, Color(OUTER_COLOR, alpha), true, -1.0, true)
	draw_circle(Vector2.ZERO, enemy_radius * 0.84 * scale_amount, Color(BODY_COLOR, alpha), true, -1.0, true)
	draw_circle(Vector2(-enemy_radius * 0.26, -enemy_radius * 0.26) * scale_amount, enemy_radius * 0.24 * scale_amount, Color(HIGHLIGHT_COLOR, alpha * 0.9), true, -1.0, true)

func _draw_radial_shatter(progress: float) -> void:
	var burst := _burst_progress(progress, 0.1)
	var fade := pow(1.0 - progress, 1.15)
	if progress < 0.22:
		_draw_enemy_silhouette(1.0 + progress * 0.12, 1.0 - progress / 0.22)
	_draw_shards(burst, fade, 0.0, false, 18, 2.35)
	_draw_burst_ring(burst, fade, 2.45, Color(1.0, 0.2, 0.3, 0.82))

func _draw_spiral_shatter(progress: float) -> void:
	var burst := _burst_progress(progress, 0.06)
	var fade := pow(1.0 - progress, 1.25)
	if progress < 0.2:
		_draw_enemy_silhouette(1.0, 1.0 - progress / 0.2)
	_draw_shards(burst, fade, burst * 2.4, true, 22, 2.15)
	_draw_burst_ring(burst, fade, 2.2, Color(0.15, 0.92, 1.0, 0.72))
	for index in 3:
		var radius := enemy_radius * (0.75 + burst * (0.8 + index * 0.3))
		draw_arc(Vector2.ZERO, radius, burst * 3.0 + index * 2.0, burst * 3.0 + index * 2.0 + PI * 0.9, 18, Color(1.0, 0.12, 0.55, fade * 0.5), 1.2, true)

func _draw_implosion_shatter(progress: float) -> void:
	var collapse := clampf(progress / 0.34, 0.0, 1.0)
	var burst := clampf((progress - 0.28) / 0.72, 0.0, 1.0)
	var fade := 1.0 - burst
	if progress < 0.34:
		_draw_enemy_silhouette(1.0 - collapse * 0.65, 1.0)
		draw_arc(Vector2.ZERO, enemy_radius * (1.2 - collapse * 0.85), 0.0, TAU, 32, Color(1.0, 0.42, 0.08, collapse), 2.0, true)
	if burst > 0.0:
		_draw_shards(burst, fade, 0.0, false, 26, 2.7)
		_draw_burst_ring(burst, fade, 2.8, Color(1.0, 0.52, 0.08, 0.9))
		draw_circle(Vector2.ZERO, enemy_radius * 0.36 * (1.0 - burst), Color(1.0, 0.88, 0.48, fade), true, -1.0, true)

func _draw_shards(progress: float, fade: float, spin: float, tangent_motion: bool, count: int, range_multiplier: float) -> void:
	var eased := 1.0 - pow(1.0 - progress, 2.4)
	for index in count:
		var base_angle := index * TAU / float(count) + sin(index * 4.17) * 0.16
		var direction := Vector2.from_angle(base_angle)
		var tangent := direction.rotated(PI * 0.5)
		var source_radius := enemy_radius * (0.18 + 0.7 * float(index % 7) / 6.0)
		var distance := enemy_radius * range_multiplier * eased * (0.72 + 0.055 * float(index % 6))
		var center := direction * (source_radius + distance)
		if tangent_motion:
			center += tangent * sin(index * 2.3) * enemy_radius * progress * 0.85
		var shard_direction := direction.rotated(spin + sin(index) * 0.16)
		var shard_tangent := shard_direction.rotated(PI * 0.5)
		var shard_length := enemy_radius * (0.23 + 0.035 * float(index % 4))
		var shard_width := enemy_radius * (0.08 + 0.018 * float(index % 3))
		var points := PackedVector2Array([
			center + shard_direction * shard_length,
			center - shard_direction * shard_length * 0.58 + shard_tangent * shard_width,
			center - shard_direction * shard_length * 0.38 - shard_tangent * shard_width,
		])
		var shard_color := BODY_COLOR
		if index % 5 == 0:
			shard_color = HIGHLIGHT_COLOR
		elif index % 3 == 0:
			shard_color = OUTER_COLOR.lightened(0.16)
		shard_color.a = fade
		draw_colored_polygon(points, shard_color)
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color(1.0, 0.48, 0.58, fade * 0.62), maxf(0.8, enemy_radius * 0.045), true)

func _draw_burst_ring(progress: float, fade: float, range_multiplier: float, color: Color) -> void:
	var ring_radius := enemy_radius * (0.45 + progress * range_multiplier)
	for index in 12:
		if index % 3 == 2:
			continue
		var segment := TAU / 12.0
		var start := index * segment - progress * 1.4
		var ring_color := color
		ring_color.a *= fade
		draw_arc(Vector2.ZERO, ring_radius, start, start + segment * 0.58, 5, ring_color, maxf(1.0, enemy_radius * 0.09), true)

func _burst_progress(progress: float, delay: float) -> float:
	return clampf((progress - delay) / maxf(1.0 - delay, 0.001), 0.0, 1.0)
