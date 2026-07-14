extends Node2D

var animation_time := 0.0
var merged_xp := 0
var total_xp := 1
var shimmer_delay := randf_range(4.0, 30.0)
var shimmer_time := 0.0
var max_charge_time := 0.0
var max_charge_flash := 0.0
var energy_particles: Array[Dictionary] = []

const SHIMMER_DURATION := 0.42
const MAX_XP := 1000
const PARTICLE_COUNT := 18

func set_crystal_state(new_merged_xp: int, new_total_xp: int) -> void:
	var reached_max := new_total_xp >= MAX_XP and total_xp < MAX_XP
	merged_xp = new_merged_xp
	total_xp = new_total_xp
	if reached_max:
		max_charge_time = 0.0
		max_charge_flash = 1.0
		energy_particles.clear()
		for index in range(PARTICLE_COUNT):
			var angle := index * TAU / PARTICLE_COUNT + randf_range(-0.08, 0.08)
			energy_particles.append({
				"angle": angle,
				"distance": randf_range(7.0, 13.0),
				"speed": randf_range(24.0, 52.0),
				"size": randf_range(1.2, 2.8),
				"phase": randf_range(0.0, TAU)
			})
	queue_redraw()

func _process(delta: float) -> void:
	animation_time += delta
	rotation += delta * 0.7
	position.y = sin(animation_time * 3.0) * 2.0
	if total_xp >= MAX_XP:
		max_charge_time += delta
		max_charge_flash = maxf(0.0, max_charge_flash - delta * 2.4)
		queue_redraw()
	if shimmer_time > 0.0:
		shimmer_time = maxf(0.0, shimmer_time - delta)
		queue_redraw()
		return
	shimmer_delay -= delta
	if shimmer_delay <= 0.0:
		shimmer_time = SHIMMER_DURATION
		shimmer_delay = randf_range(4.0, 30.0)
		queue_redraw()

func _draw() -> void:
	var maxed := total_xp >= MAX_XP
	var purple_progress := clampf(float(total_xp) / MAX_XP, 0.0, 1.0)
	var body := Color("#24d97d").lerp(Color("#8250b6"), purple_progress)
	var light := Color("#6effaa").lerp(Color("#c29be7"), purple_progress)
	var dark := Color("#0c8b51").lerp(Color("#50306f"), purple_progress)
	if maxed:
		var pulse := 0.5 + 0.5 * sin(max_charge_time * 4.2)
		var radiance := 0.22 + pulse * 0.18 + max_charge_flash * 0.35
		draw_circle(Vector2.ZERO, 22.0 + pulse * 5.0, Color(0.34, 0.08, 0.62, radiance * 0.25))
		draw_arc(Vector2.ZERO, 18.0 + pulse * 4.0, 0.0, TAU, 40, Color(0.76, 0.48, 1.0, radiance), 1.5 + pulse, true)
		body = Color("#72cff2")
		light = Color("#f2ddff")
		dark = Color("#4e247e")
	var crystal := PackedVector2Array([Vector2(0, -12), Vector2(8, -3), Vector2(6, 8), Vector2(0, 13), Vector2(-6, 8), Vector2(-8, -3)])
	draw_colored_polygon(crystal, body)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(8, -3), Vector2(0, 3), Vector2(-8, -3)]), light)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 3), Vector2(6, 8), Vector2(0, 13)]), dark)
	draw_polyline(PackedVector2Array([Vector2(0, -12), Vector2(8, -3), Vector2(6, 8), Vector2(0, 13), Vector2(-6, 8), Vector2(-8, -3), Vector2(0, -12)]), Color(0.0, 0.0, 0.0, 0.55), 1.4, true)
	if shimmer_time > 0.0:
		var progress := 1.0 - shimmer_time / SHIMMER_DURATION
		var sweep_x := lerpf(-7.0, 7.0, progress)
		var shimmer_alpha := sin(progress * PI) * 0.9
		draw_line(Vector2(sweep_x - 2.6, -6.5), Vector2(sweep_x + 2.6, 5.5), Color(0.94, 1.0, 1.0, shimmer_alpha), 2.1, true)
	draw_line(Vector2(-3, -7), Vector2(1, -3), Color(light, 0.95), 1.5, true)
	if maxed:
		for particle in energy_particles:
			var particle_angle: float = particle["angle"] + sin(animation_time * 1.4 + particle["phase"]) * 0.16
			var distance: float = particle["distance"] + fmod(max_charge_time * particle["speed"], 38.0)
			var point := Vector2.from_angle(particle_angle) * distance
			var alpha := 0.35 + 0.45 * (0.5 + 0.5 * sin(animation_time * 5.0 + particle["phase"]))
			draw_circle(point, particle["size"], Color(0.78, 0.46, 1.0, alpha))
			draw_line(point, point - Vector2.from_angle(particle_angle) * 5.0, Color(0.55, 0.25, 0.9, alpha * 0.45), 1.0, true)
