extends Node2D

const OUTER_FLESH := Color("#230814")
const SHELL_DARK := Color("#4b0d24")
const SHELL_MID := Color("#861636")
const SHELL_HOT := Color("#d52b4a")
const CORE_GLOW := Color("#ff4b62")
const EYE_GLOW := Color("#ffe2a8")

var animation_time := 0.0
var redraw_elapsed := 0.0
var procedural_enabled := false

func _ready() -> void:
	visible = false
	set_process(false)

func set_procedural_enabled(enabled: bool) -> void:
	procedural_enabled = enabled
	visible = enabled
	set_process(enabled)
	if enabled:
		queue_redraw()

func _process(delta: float) -> void:
	if not procedural_enabled:
		return
	var enemy := get_parent() as Enemy
	var hunt_speed := 0.0
	var hunt_direction := Vector2.RIGHT
	if enemy:
		hunt_speed = enemy.velocity.length()
		if is_instance_valid(enemy.target):
			hunt_direction = enemy.global_position.direction_to(enemy.target.global_position)
		if hunt_direction != Vector2.ZERO:
			rotation = lerp_angle(rotation, hunt_direction.angle(), 1.0 - exp(-9.0 * delta))
	var urgency := clampf(hunt_speed / 95.0, 0.25, 1.0)
	animation_time = fmod(animation_time + delta * lerpf(2.3, 6.2, urgency), TAU)
	var lunge := maxf(0.0, sin(animation_time)) * lerpf(1.0, 4.2, urgency)
	position = Vector2(lunge, 0.0)
	var breathing := sin(animation_time * 2.0) * 0.055
	scale = Vector2(1.0 + breathing * 0.45, 1.0 - breathing)
	redraw_elapsed += delta
	if redraw_elapsed >= 1.0 / 30.0:
		redraw_elapsed = 0.0
		queue_redraw()

func _draw() -> void:
	if not procedural_enabled:
		return
	var pulse := 0.55 + 0.45 * sin(animation_time * 2.0)
	# This visual node turns to face its target and lunges forward. Counter both
	# transforms for the shadow so it remains a fixed, world-aligned oval below
	# the enemy instead of rotating and orbiting with the body.
	var ground_shadow_position := (Vector2(0, 17) - position).rotated(-rotation) / scale
	draw_set_transform(ground_shadow_position, -rotation, Vector2.ONE / scale)
	draw_shadow_ellipse(Vector2.ZERO, Vector2(28, 8), Color(0.0, 0.0, 0.42))
	draw_set_transform(Vector2.ZERO)

	# Diffuse threat glow makes the silhouette read at a glance.
	draw_circle(Vector2(2, 0), 28.0 + pulse * 2.0, Color(CORE_GLOW, 0.055 + pulse * 0.025), true, -1.0, true)

	# Jagged rear spines break up the perfect circle while keeping the enemy round.
	for index in range(7):
		var angle := lerpf(PI * 0.62, PI * 1.38, float(index) / 6.0)
		var base := Vector2.from_angle(angle) * 14.0
		var tip := Vector2.from_angle(angle) * (25.0 + sin(animation_time * 2.0 + index) * 1.8)
		var side := Vector2.from_angle(angle + PI * 0.5) * 3.2
		draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), SHELL_DARK)
		draw_polyline(PackedVector2Array([base - side, tip, base + side]), Color("#a32141"), 1.0, true)

	# Layered carapace: dark rim, irregular muscle shell, and a hot front-facing core.
	draw_circle(Vector2.ZERO, 22.0, OUTER_FLESH, true, -1.0, true)
	draw_circle(Vector2(1.0, -1.0), 19.5, SHELL_DARK, true, -1.0, true)
	draw_circle(Vector2(3.0, -1.5), 16.5, SHELL_MID, true, -1.0, true)
	draw_circle(Vector2(7.5, -1.0), 10.5, Color("#b71f3c"), true, -1.0, true)
	draw_circle(Vector2(9.5, -1.0), 7.2 + pulse * 0.8, Color(SHELL_HOT, 0.9), true, -1.0, true)
	draw_circle(Vector2(10.5, -1.0), 3.6 + pulse * 0.65, Color(CORE_GLOW, 0.98), true, -1.0, true)

	# Scar-like channels make the creature feel organic instead of like a flat orb.
	for index in range(4):
		var y := -10.0 + index * 6.6
		var start := Vector2(-11.0 + absf(y) * 0.15, y)
		var end := Vector2(3.0 + sin(animation_time + index) * 1.5, y * 0.68)
		draw_line(start, end, Color("#2b0715"), 2.2, true)
		draw_line(start + Vector2(0, -0.45), end + Vector2(0, -0.45), Color("#d52b4a", 0.52), 0.7, true)

	# Three eyes lock toward the player. Their tiny jitter makes the approach unnerving.
	_draw_eye(Vector2(8.5, -8.0), 3.8, pulse, 0.0)
	_draw_eye(Vector2(14.0, 0.0), 4.6, pulse, 1.7)
	_draw_eye(Vector2(8.5, 8.0), 3.8, pulse, 3.4)
	# Wet highlight gives the shell a convincing curved surface.
	draw_circle(Vector2(-5.0, -9.0), 4.6, Color(1.0, 0.55, 0.64, 0.22), true, -1.0, true)
	draw_arc(Vector2(1.0, -1.0), 17.0, PI * 1.1, PI * 1.75, 14, Color(1.0, 0.45, 0.56, 0.48), 1.3, true)
	var enemy := get_parent() as Enemy
	if enemy and enemy.is_boss:
		_draw_boss_regalia(pulse)

func _draw_eye(center: Vector2, radius: float, pulse: float, phase: float) -> void:
	var twitch := Vector2(sin(animation_time * 5.0 + phase), cos(animation_time * 4.0 + phase)) * 0.55
	draw_circle(center, radius + 1.2 + pulse * 0.45, Color(CORE_GLOW, 0.16), true, -1.0, true)
	draw_circle(center, radius, Color("#210510"), true, -1.0, true)
	draw_circle(center + twitch, radius * 0.56, EYE_GLOW, true, -1.0, true)
	draw_circle(center + twitch * 1.35, radius * 0.25, Color("#ff3855"), true, -1.0, true)

func _draw_boss_regalia(pulse: float) -> void:
	# Boss1 gets a visible crown of rift horns and an oversized central eye.
	for index in range(5):
		var angle := lerpf(PI * 1.12, PI * 1.88, float(index) / 4.0)
		var base := Vector2.from_angle(angle) * 17.0
		var tip := Vector2.from_angle(angle) * (34.0 + pulse * 4.0)
		var side := Vector2.from_angle(angle + PI * 0.5) * 4.4
		draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), Color("#4f0b58"))
		draw_line(base, tip, Color(0.22, 0.95, 1.0, 0.9), 1.3, true)
	draw_circle(Vector2(13.0, 0.0), 9.5 + pulse * 1.5, Color(0.2, 0.95, 1.0, 0.2), true, -1.0, true)
	draw_circle(Vector2(13.0, 0.0), 6.4, Color("#18051f"), true, -1.0, true)
	draw_circle(Vector2(15.0, 0.0), 3.8 + pulse * 0.7, Color(0.85, 0.98, 1.0, 1.0), true, -1.0, true)

func draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	color.a = 0.10
	var points := PackedVector2Array()
	for index in range(28):
		var angle := TAU * float(index) / 28.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
