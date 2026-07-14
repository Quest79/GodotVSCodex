class_name EnemyAfflictionFX
extends Node2D

const BURNING := &"burning"
const CHILLED := &"chilled"
const SHOCKED := &"shocked"
const FULL_PARTICLE_BUDGET_BURNING_ENEMIES := 3
const MIN_PARTICLE_BUDGET_SCALE := 0.16

static var active_burning_effects := 0

var afflictions: Dictionary = {}
var active := false
var elapsed := 0.0
var redraw_elapsed := 0.0
var burning_budget_registered := false

func configure(new_afflictions: Dictionary) -> void:
	afflictions = new_afflictions.duplicate(true)
	_set_burning_budget_registration(afflictions.has(BURNING))
	active = not afflictions.is_empty()
	visible = active
	queue_redraw()

func clear() -> void:
	afflictions.clear()
	_set_burning_budget_registration(false)
	active = false
	visible = false
	queue_redraw()

func _exit_tree() -> void:
	_set_burning_budget_registration(false)

func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	redraw_elapsed += delta
	if redraw_elapsed >= 1.0 / 30.0:
		redraw_elapsed = 0.0
		queue_redraw()

func _draw() -> void:
	if not active:
		return
	if afflictions.has(BURNING):
		_draw_burning()
	if afflictions.has(CHILLED):
		_draw_chilled()
	if afflictions.has(SHOCKED):
		_draw_shocked()

func _draw_burning() -> void:
	match GameEvents.burning_effect_style:
		GameEvents.BurningEffectStyle.CINDER_BURST:
			_draw_cinder_burst()
		GameEvents.BurningEffectStyle.CINDER_RING:
			_draw_cinder_ring()
		GameEvents.BurningEffectStyle.CINDER_CROWN:
			_draw_cinder_crown()
		GameEvents.BurningEffectStyle.CINDER_COIL:
			_draw_cinder_coil()
		GameEvents.BurningEffectStyle.CINDER_SCATTER:
			_draw_cinder_scatter()
		GameEvents.BurningEffectStyle.CINDER_HEARTH:
			_draw_cinder_hearth()
		_:
			_draw_cinder_burst()

func _draw_cinder_burst() -> void:
	var pulse := 1.0 + sin(elapsed * 11.0) * 0.12
	draw_circle(Vector2(0, 7), 26.0 * pulse, Color(1.0, 0.08, 0.0, 0.1))
	draw_circle(Vector2(0, 7), 14.0, Color(1.0, 0.48, 0.01, 0.22))
	for flame_index in 9:
		var angle := TAU * float(flame_index) / 9.0 + sin(elapsed * 3.0 + flame_index) * 0.16
		var direction := Vector2.from_angle(angle)
		var point := direction * (11.0 + float(flame_index % 3) * 3.0) + Vector2(0, 4)
		draw_rect(Rect2(point - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(1.0, 0.18, 0.01, 0.8))
		draw_rect(Rect2(point - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), Color(1.0, 0.75, 0.05, 0.9))
	_draw_ember_particles(38, 62.0, 27.0, 1.35)

func _draw_cinder_ring() -> void:
	var pulse := 1.0 + sin(elapsed * 9.0) * 0.1
	draw_circle(Vector2(0, 7), 27.0 * pulse, Color(1.0, 0.08, 0.0, 0.08))
	draw_circle(Vector2(0, 7), 17.0, Color(1.0, 0.3, 0.01, 0.16))
	for block in 16:
		var angle := TAU * float(block) / 16.0 + elapsed * 0.8
		var point := Vector2.from_angle(angle) * (14.0 + sin(elapsed * 7.0 + block) * 2.0) + Vector2(0, 5)
		draw_rect(Rect2(point - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(1.0, 0.14, 0.005, 0.74))
		draw_rect(Rect2(point - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), Color(1.0, 0.7, 0.04, 0.88))
	_draw_ember_particles(30, 50.0, 23.0, 1.0)

func _draw_cinder_crown() -> void:
	draw_circle(Vector2(0, 8), 25.0, Color(1.0, 0.08, 0.0, 0.08))
	for column in 9:
		var x := -18.0 + float(column) * 4.5
		var height := 16.0 + float((column * 7) % 5) * 5.0
		for block in ceili(height / 5.0):
			var t := float(block) / maxf(1.0, ceili(height / 5.0))
			var sway := roundf(sin(elapsed * 5.0 + column * 0.9 + block) * (1.0 + t * 3.0))
			var color := Color(1.0, 0.09 + t * 0.3, 0.005, 0.72)
			draw_rect(Rect2(x + sway - 2.5, 10.0 - block * 5.0 - 2.5, 5.0, 5.0), color)
			if block > 1:
				draw_rect(Rect2(x + sway - 1.2, 10.0 - block * 5.0 - 1.2, 2.4, 2.4), Color(1.0, 0.72, 0.04, 0.86))
	_draw_ember_particles(24, 58.0, 20.0, 0.9)

func _draw_cinder_coil() -> void:
	draw_circle(Vector2(0, 7), 26.0, Color(1.0, 0.08, 0.0, 0.08))
	for block in 24:
		var t := float(block) / 23.0
		var angle := t * TAU * 1.55 + elapsed * 2.2
		var radius := lerpf(4.0, 22.0, t)
		var point := Vector2.from_angle(angle) * radius + Vector2(0, 7 - t * 29.0)
		var size := 6.0 - t * 2.5
		draw_rect(Rect2(point - Vector2(size * 0.5, size * 0.5), Vector2(size, size)), Color(1.0, 0.1 + t * 0.26, 0.005, 0.8))
		if block % 2 == 0:
			draw_rect(Rect2(point - Vector2(1.2, 1.2), Vector2(2.4, 2.4)), Color(1.0, 0.78, 0.08, 0.9))
	_draw_ember_particles(26, 52.0, 22.0, 0.95)

func _draw_cinder_scatter() -> void:
	var pulse := 1.0 + sin(elapsed * 12.0) * 0.12
	# The glow can breathe outside the body; the particles below cannot.
	draw_circle(Vector2(0, 7), 26.0 * pulse, Color(1.0, 0.06, 0.0, 0.09))
	draw_circle(Vector2(0, 7), 12.0, Color(1.0, 0.5, 0.01, 0.24))
	for block in 24:
		var angle := float(block) * 2.399963 + elapsed * (0.6 if block % 2 == 0 else -0.8)
		var distance := 5.0 + float((block * 13) % 13)
		var point := Vector2.from_angle(angle) * distance + Vector2(0, 6)
		var size := 1.0 + float(block % 3) * 0.45
		draw_rect(Rect2(point - Vector2(size, size), Vector2(size * 2.0, size * 2.0)), Color(1.0, 0.12 + float(block % 3) * 0.2, 0.005, 0.72))

	# Enemy body is roughly an 18px radius. Keep sides/bottom 5% inside;
	# the top is intentionally allowed to rise above the body.
	for particle_index in _scaled_particle_count(264):
		var phase := float(particle_index) * 2.399963
		var drift := sin(elapsed * (1.4 + float(particle_index % 5) * 0.18) + phase) * 1.5
		var x := clampf(sin(phase * 1.7 + elapsed * 0.65) * 15.6 + drift, -17.1, 17.1)
		var rise_height := 45.0 + float(particle_index % 9) * 2.0
		var rise := fmod(elapsed * (7.0 + float(particle_index % 7) * 1.2) + phase * 9.0, rise_height)
		var y := clampf(14.0 - rise, -27.0, 17.1)
		var size := 0.45 + float(particle_index % 4) * 0.22
		var rise_progress := clampf(rise / rise_height, 0.0, 1.0)
		var fade := pow(1.0 - rise_progress, 1.35)
		var flicker_wave := 0.5 + 0.5 * sin(elapsed * (10.0 + float(particle_index % 6) * 1.7) + phase * 5.0)
		var flicker := lerpf(0.42, 1.0, flicker_wave)
		var alpha := (0.52 + float(particle_index % 5) * 0.12) * fade * flicker
		var color := Color(1.0, 0.14 + float(particle_index % 4) * 0.17, 0.005, alpha)
		if particle_index % 11 == 0:
			var spark_size := size * 1.5
			draw_rect(Rect2(x - spark_size, y - spark_size, spark_size * 2.0, spark_size * 2.0), Color(1.0, 0.7, 0.04, alpha * 1.2))
		else:
			draw_rect(Rect2(x - size, y - size, size * 2.0, size * 2.0), color)

func _draw_cinder_hearth() -> void:
	draw_circle(Vector2(0, 9), 30.0, Color(1.0, 0.08, 0.0, 0.07))
	draw_circle(Vector2(0, 10), 18.0, Color(1.0, 0.38, 0.01, 0.2))
	for block in 18:
		var x := -24.0 + float(block % 9) * 6.0
		var row := float(block / 9)
		var y := 10.0 - row * 5.0 + sin(elapsed * 5.0 + block) * 1.5
		var size := 5.0 + float(block % 3)
		draw_rect(Rect2(x - size * 0.5, y - size * 0.5, size, size), Color(1.0, 0.1 + row * 0.2, 0.005, 0.78))
		if block % 2 == 0:
			draw_rect(Rect2(x - 1.2, y - 1.2, 2.4, 2.4), Color(1.0, 0.76, 0.04, 0.9))
	_draw_ember_particles(28, 43.0, 25.0, 1.0)

func _draw_ember_particles(count: int, rise_height: float, spread: float, size_scale: float) -> void:
	for particle_index in _scaled_particle_count(count):
		var phase := float(particle_index) * 2.399963
		var rise := fmod(elapsed * (12.0 + float(particle_index % 5) * 3.0) + phase * 8.0, rise_height)
		var x := sin(phase + elapsed * 2.0) * spread * (0.55 + float(particle_index % 4) * 0.13)
		var point := Vector2(x, 12.0 - rise)
		var alpha := clampf(1.0 - rise / rise_height, 0.0, 1.0) * (0.42 + float(particle_index % 4) * 0.13)
		var size := (1.0 + float(particle_index % 3) * 0.7) * size_scale
		var color := Color(1.0, 0.18 + float(particle_index % 3) * 0.22, 0.01, alpha)
		if particle_index % 7 == 0:
			draw_rect(Rect2(point - Vector2(size, size), Vector2(size * 2.0, size * 2.0)), Color(1.0, 0.72, 0.05, alpha))
		else:
			draw_circle(point, size, color, true, -1.0, true)

func _set_burning_budget_registration(has_burning: bool) -> void:
	if burning_budget_registered == has_burning:
		return
	burning_budget_registered = has_burning
	active_burning_effects += 1 if has_burning else -1
	active_burning_effects = maxi(active_burning_effects, 0)

func _scaled_particle_count(full_count: int) -> int:
	if active_burning_effects <= FULL_PARTICLE_BUDGET_BURNING_ENEMIES:
		return full_count
	var scale := maxf(MIN_PARTICLE_BUDGET_SCALE, float(FULL_PARTICLE_BUDGET_BURNING_ENEMIES) / float(active_burning_effects))
	return maxi(4, roundi(float(full_count) * scale))

func _draw_chilled() -> void:
	var pulse := sin(elapsed * 4.0) * 2.0
	draw_circle(Vector2.ZERO, 23.0 + pulse, Color(0.1, 0.65, 1.0, 0.1))
	draw_arc(Vector2.ZERO, 22.0 + pulse, elapsed * 0.6, elapsed * 0.6 + TAU * 0.78, 24, Color(0.35, 0.88, 1.0, 0.82), 2.0, true)
	for crystal_index in 6:
		var angle := TAU * float(crystal_index) / 6.0 - elapsed * 0.35
		var direction := Vector2.from_angle(angle)
		var center := direction * 16.0
		var tangent := Vector2(-direction.y, direction.x)
		var size := 7.0 + float(crystal_index % 2) * 2.0
		var points := PackedVector2Array([
			center + direction * size,
			center + tangent * 3.0,
			center - direction * size,
			center - tangent * 3.0,
		])
		draw_colored_polygon(points, Color(0.16, 0.66, 1.0, 0.78))
		draw_line(center - direction * size, center + direction * size, Color(0.86, 1.0, 1.0, 0.9), 1.2, true)
	for flake_index in 8:
		var angle := TAU * float(flake_index) / 8.0 + elapsed * 0.45
		var point := Vector2.from_angle(angle) * (25.0 + sin(elapsed * 3.0 + flake_index) * 3.0)
		draw_line(point - Vector2(2.5, 0), point + Vector2(2.5, 0), Color(0.7, 0.95, 1.0, 0.72), 1.0, true)
		draw_line(point - Vector2(0, 2.5), point + Vector2(0, 2.5), Color(0.7, 0.95, 1.0, 0.72), 1.0, true)

func _draw_shocked() -> void:
	draw_circle(Vector2.ZERO, 23.0 + sin(elapsed * 16.0) * 2.0, Color(0.66, 0.26, 1.0, 0.1))
	for arc_index in 5:
		var start_angle := TAU * float(arc_index) / 5.0 + elapsed * (1.4 if arc_index % 2 == 0 else -1.1)
		var direction := Vector2.from_angle(start_angle)
		var tangent := Vector2(-direction.y, direction.x)
		var points := PackedVector2Array([direction * 8.0])
		for step in 4:
			var distance := 12.0 + float(step) * 5.0
			var offset := tangent * (4.0 if step % 2 == 0 else -4.0)
			points.append(direction * distance + offset)
		draw_polyline(points, Color(0.82, 0.55, 1.0, 0.9), 2.0, true)
		draw_polyline(points, Color(0.95, 0.9, 1.0, 0.8), 0.8, true)
	for spark_index in 10:
		var angle := float(spark_index) * 2.399963 - elapsed * 1.5
		var point := Vector2.from_angle(angle) * (20.0 + float(spark_index % 3) * 4.0)
		draw_circle(point, 1.5 + float(spark_index % 2), Color(0.95, 0.88, 1.0, 0.85), true, -1.0, true)
