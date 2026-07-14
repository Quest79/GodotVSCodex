extends Node2D

const MAX_TRAIL_PARTICLES := 150

var skill_id := &"default_attack"
var elapsed := 0.0
var emission_accumulator := 0.0
var trail_particles: Array[Dictionary] = []

func _ready() -> void:
	top_level = true
	_sync_world_transform()

func configure(new_skill_id: StringName) -> void:
	skill_id = new_skill_id
	trail_particles.clear()
	emission_accumulator = 0.0
	set_process(skill_id == &"fireball" or skill_id == &"ice_shard")
	_sync_world_transform()
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if skill_id == &"fireball" and GameEvents.fireball_visual_style != GameEvents.FireballVisualStyle.ORIGINAL:
		_update_world_trail(delta)
	_sync_world_transform()
	queue_redraw()

func _sync_world_transform() -> void:
	var projectile := get_parent() as Node2D
	if projectile:
		global_position = projectile.global_position
		global_rotation = 0.0
		global_scale = projectile.global_scale

func _draw() -> void:
	if skill_id == &"fireball":
		_draw_fireball()
	elif skill_id == &"ice_shard":
		_draw_ice_shard()
	else:
		_draw_default_projectile()

func _draw_ice_shard() -> void:
	var projectile := get_parent()
	var direction_angle := 0.0
	if projectile and "direction" in projectile:
		direction_angle = Vector2(projectile.direction).angle()
	draw_set_transform(Vector2.ZERO, direction_angle, Vector2.ONE)
	var pulse := 1.0 + sin(elapsed * 10.0) * 0.06
	var outer := PackedVector2Array([
		Vector2(14.0 * pulse, 0.0), Vector2(1.0, -7.5), Vector2(-11.0, -4.0),
		Vector2(-16.0, 0.0), Vector2(-11.0, 4.0), Vector2(1.0, 7.5),
	])
	draw_colored_polygon(outer, Color("279ee8"))
	draw_polyline(PackedVector2Array([outer[0], outer[1], outer[2], outer[3], outer[4], outer[5], outer[0]]), Color("d9fbff"), 1.4, true)
	draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(0, -5.5), Vector2(-4, 0), Vector2(0, 2.0)]), Color("a8efff"))
	draw_line(Vector2(-12, 0), Vector2(11, 0), Color(0.9, 1.0, 1.0, 0.8), 1.0, true)
	for index in 7:
		var phase := fposmod(elapsed * (2.2 + index * 0.07) + index * 0.19, 1.0)
		var point := Vector2(-8.0 - phase * 22.0, sin(elapsed * 6.0 + index * 1.4) * (2.0 + phase * 5.0))
		var size := lerpf(2.2, 0.7, phase)
		draw_rect(Rect2(point - Vector2.ONE * size * 0.5, Vector2.ONE * size), Color(0.55, 0.92, 1.0, 1.0 - phase))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_fireball() -> void:
	var style := GameEvents.fireball_visual_style
	if style == GameEvents.FireballVisualStyle.ORIGINAL:
		_draw_original_fireball()
		_draw_interior_flame_detail(style)
		return
	_draw_world_trail()
	match style:
		GameEvents.FireballVisualStyle.WHITE_HOT_COMET:
			_draw_white_hot_comet()
		GameEvents.FireballVisualStyle.PIXEL_INFERNO:
			_draw_pixel_inferno()
		GameEvents.FireballVisualStyle.SOLAR_FLARE:
			_draw_solar_flare()
		GameEvents.FireballVisualStyle.SOULFIRE:
			_draw_soulfire()
		GameEvents.FireballVisualStyle.WILDFIRE:
			_draw_wildfire()
		GameEvents.FireballVisualStyle.VOLCANIC_BLAZE:
			_draw_volcanic_blaze()
		GameEvents.FireballVisualStyle.DRAGON_FIRE:
			_draw_dragon_fire()
		GameEvents.FireballVisualStyle.PHOENIX_FLAME:
			_draw_phoenix_flame()
		GameEvents.FireballVisualStyle.ASHEN_INFERNO:
			_draw_ashen_inferno()
		_:
			_draw_ember_comet()
	_draw_interior_flame_detail(style)

func _update_world_trail(delta: float) -> void:
	var projectile := get_parent()
	if not projectile or not "direction" in projectile:
		return
	var projectile_position: Vector2 = projectile.global_position
	var travel_direction: Vector2 = projectile.direction.normalized()
	var perpendicular := travel_direction.orthogonal()
	var profile := _trail_profile()
	emission_accumulator += delta * float(profile["rate"])
	while emission_accumulator >= 1.0 and trail_particles.size() < MAX_TRAIL_PARTICLES:
		emission_accumulator -= 1.0
		_spawn_trail_particle(projectile_position, travel_direction, perpendicular, profile)
	for index in range(trail_particles.size() - 1, -1, -1):
		var particle: Dictionary = trail_particles[index]
		particle["age"] = float(particle["age"]) + delta
		if float(particle["age"]) >= float(particle["life"]):
			trail_particles.remove_at(index)
			continue
		var velocity: Vector2 = particle["velocity"]
		if bool(particle["smoke"]):
			velocity += Vector2(0.0, -13.0) * delta
			velocity *= pow(0.9, delta)
		else:
			velocity += Vector2(0.0, -7.0) * delta
			velocity *= pow(0.72, delta)
		particle["velocity"] = velocity
		particle["position"] = Vector2(particle["position"]) + velocity * delta
		trail_particles[index] = particle

func _spawn_trail_particle(origin: Vector2, direction: Vector2, perpendicular: Vector2, profile: Dictionary) -> void:
	var smoke_chance: float = profile["smoke_chance"]
	var is_smoke := randf() < smoke_chance
	var spread: float = profile["spread"]
	var position := origin - direction * randf_range(5.0, 12.0) + perpendicular * randf_range(-spread, spread)
	var backward_speed := randf_range(18.0, 62.0) if not is_smoke else randf_range(5.0, 24.0)
	var velocity := -direction * backward_speed + perpendicular * randf_range(-28.0, 28.0)
	if is_smoke:
		velocity += Vector2(randf_range(-9.0, 9.0), randf_range(-26.0, -9.0))
	var minimum_size: float = profile["smoke_size_min"] if is_smoke else profile["fire_size_min"]
	var maximum_size: float = profile["smoke_size_max"] if is_smoke else profile["fire_size_max"]
	trail_particles.append({
		"position": position,
		"velocity": velocity,
		"age": 0.0,
		"life": randf_range(0.42, 0.82) if is_smoke else randf_range(0.18, 0.48),
		"size": randf_range(minimum_size, maximum_size),
		"smoke": is_smoke,
		"hot": randf(),
		"wobble": randf_range(0.0, TAU),
	})

func _trail_profile() -> Dictionary:
	match GameEvents.fireball_visual_style:
		GameEvents.FireballVisualStyle.WHITE_HOT_COMET:
			return _make_profile(145.0, 5.0, 0.04, 1.0, 4.4, 1.4, 4.2, Color("fffbdc"), Color("ff8b13"), Color("3b2927"))
		GameEvents.FireballVisualStyle.PIXEL_INFERNO:
			return _make_profile(165.0, 7.0, 0.05, 1.0, 5.4, 1.3, 4.0, Color("ffd33d"), Color("d71316"), Color("351e24"))
		GameEvents.FireballVisualStyle.SOLAR_FLARE:
			return _make_profile(135.0, 8.0, 0.03, 1.2, 5.0, 1.2, 3.7, Color("fff9a8"), Color("ff6908"), Color("4a3020"))
		GameEvents.FireballVisualStyle.SOULFIRE:
			return _make_profile(150.0, 7.0, 0.05, 1.0, 4.7, 1.3, 4.5, Color("fff0d2"), Color("b80b24"), Color("3b2025"))
		GameEvents.FireballVisualStyle.WILDFIRE:
			return _make_profile(185.0, 9.0, 0.06, 0.9, 6.0, 1.6, 5.0, Color("fff2a1"), Color("e92d08"), Color("3b302d"))
		GameEvents.FireballVisualStyle.VOLCANIC_BLAZE:
			return _make_profile(160.0, 8.0, 0.08, 1.3, 6.6, 1.8, 5.8, Color("ffd24b"), Color("a90d09"), Color("281f22"))
		GameEvents.FireballVisualStyle.DRAGON_FIRE:
			return _make_profile(195.0, 6.0, 0.04, 0.8, 5.0, 1.4, 4.5, Color("fffbd0"), Color("f04408"), Color("40332b"))
		GameEvents.FireballVisualStyle.PHOENIX_FLAME:
			return _make_profile(180.0, 11.0, 0.04, 0.9, 5.3, 1.3, 4.2, Color("ffffd5"), Color("ff6b08"), Color("4b3028"))
		GameEvents.FireballVisualStyle.ASHEN_INFERNO:
			return _make_profile(170.0, 10.0, 0.10, 1.0, 5.7, 1.7, 6.0, Color("ffe09a"), Color("d83612"), Color("302d30"))
	return _make_profile(150.0, 7.0, 0.05, 1.0, 4.8, 1.4, 4.5, Color("fff08a"), Color("f13b08"), Color("3b2928"))

func _make_profile(rate: float, spread: float, smoke_chance: float, fire_min: float, fire_max: float, smoke_min: float, smoke_max: float, hot: Color, cool: Color, smoke: Color) -> Dictionary:
	return {
		"rate": rate,
		"spread": spread,
		"smoke_chance": smoke_chance,
		"fire_size_min": fire_min,
		"fire_size_max": fire_max,
		"smoke_size_min": smoke_min,
		"smoke_size_max": smoke_max,
		"hot_color": hot,
		"cool_color": cool,
		"smoke_color": smoke,
	}

func _draw_world_trail() -> void:
	var profile := _trail_profile()
	for particle in trail_particles:
		var progress := float(particle["age"]) / float(particle["life"])
		var world_offset := Vector2(particle["position"]) - global_position
		var safe_scale := Vector2(maxf(absf(global_scale.x), 0.001), maxf(absf(global_scale.y), 0.001))
		var position := world_offset / safe_scale
		var smooth_wobble := sin(float(particle["wobble"]) + float(particle["age"]) * 5.5)
		if bool(particle["smoke"]):
			position.x += smooth_wobble * progress * 0.8
		var base_size: float = particle["size"]
		if bool(particle["smoke"]):
			var smoke_color: Color = profile["smoke_color"]
			smoke_color.a = sin(progress * PI) * 0.15
			var smoke_size := base_size * lerpf(0.6, 1.25, progress)
			draw_circle(position, smoke_size, smoke_color)
			_draw_pixel(position + Vector2(base_size * 0.25, -base_size * 0.15), maxf(0.8, smoke_size * 0.3), Color(smoke_color, smoke_color.a * 0.35))
		else:
			var hot_color: Color = profile["hot_color"]
			var cool_color: Color = profile["cool_color"]
			var color := hot_color.lerp(cool_color, clampf(progress * 1.25, 0.0, 1.0))
			color.a = (1.0 - progress) * 0.96
			var fire_size := base_size * (1.0 - progress * 0.62)
			_draw_pixel(position, maxf(1.0, fire_size), color)
			if base_size > 3.0:
				_draw_pixel(position - Vector2.ONE, maxf(1.0, fire_size * 0.42), Color(hot_color, color.a))

func _draw_original_fireball() -> void:
	var projectile := get_parent()
	var direction_angle := 0.0
	if projectile and "direction" in projectile:
		direction_angle = Vector2(projectile.direction).angle()
	draw_set_transform(Vector2.ZERO, direction_angle, Vector2.ONE)
	var pulse := 1.0 + sin(elapsed * 13.0) * 0.08
	for index in 4:
		var tail_position := Vector2(-9.0 - index * 6.0, sin(elapsed * 18.0 + index * 1.7) * (2.0 + index))
		var tail_radius := maxf(2.0, 7.0 - index * 1.25)
		draw_circle(tail_position, tail_radius, Color(1.0, 0.18 + index * 0.05, 0.01, 0.42 - index * 0.07), true, -1.0, true)
	draw_circle(Vector2.ZERO, 17.0 * pulse, Color(1.0, 0.12, 0.01, 0.12), true, -1.0, true)
	draw_circle(Vector2.ZERO, 12.5 * pulse, Color(1.0, 0.28, 0.015, 0.34), true, -1.0, true)
	draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.48, 0.025, 1.0), true, -1.0, true)
	draw_circle(Vector2(-2.5, -2.5), 5.0, Color(1.0, 0.9, 0.22, 1.0), true, -1.0, true)
	draw_circle(Vector2(-3.5, -3.5), 2.2, Color(1.0, 1.0, 0.82, 1.0), true, -1.0, true)
	for index in 3:
		var angle := elapsed * (3.8 + index) + index * 2.1
		var ember := Vector2(cos(angle), sin(angle)) * (12.0 + index * 2.0)
		draw_circle(ember, 1.3, Color(1.0, 0.68, 0.08, 0.9), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_ember_comet() -> void:
	_draw_layered_core(Color("f43b08"), Color("ff8b13"), Color("fff07a"), 10.5, 0.06)
	_draw_core_pixels(Color("ff5a0a"), Color("ffe14a"), 7)

func _draw_white_hot_comet() -> void:
	_draw_layered_core(Color("ff5710"), Color("ffc638"), Color("fffdf1"), 10.0, 0.04)
	_draw_core_pixels(Color("ff991f"), Color("ffffff"), 10)

func _draw_pixel_inferno() -> void:
	for index in 20:
		var angle := index * TAU / 20.0 + elapsed * (0.7 if index % 2 == 0 else -0.55)
		var radius := 8.0 + fposmod(float(index) * 4.7, 7.0)
		_draw_pixel(Vector2.from_angle(angle) * radius, 2.0 + float(index % 4), Color("ff3511") if index % 3 else Color("ffae19"))
	_draw_pixel(Vector2(-5, -4), 9.0, Color("ff9f20"))
	_draw_pixel(Vector2(2, 2), 9.0, Color("fff08a"))
	_draw_pixel(Vector2(-1, -1), 6.0, Color("fffbe0"))

func _draw_solar_flare() -> void:
	for index in 12:
		var angle := index * TAU / 12.0 + sin(elapsed * 3.0 + index) * 0.08
		draw_line(Vector2.from_angle(angle) * 9.0, Vector2.from_angle(angle) * (17.0 + 3.0 * sin(elapsed * 15.0 + index * 2.0)), Color("ff8a13"), 2.0, true)
	_draw_layered_core(Color("ff8a0b"), Color("ffd532"), Color("fffbd1"), 10.0, 0.09)

func _draw_soulfire() -> void:
	_draw_layered_core(Color("8f071c"), Color("e51d32"), Color("fff0d2"), 10.0, 0.07)
	_draw_core_pixels(Color("bd0b25"), Color("ffb25b"), 9)

func _draw_wildfire() -> void:
	var flicker := sin(elapsed * 19.0)
	draw_circle(Vector2(1.5, 1.0), 12.5, Color(1.0, 0.12, 0.0, 0.18))
	draw_circle(Vector2(flicker * 1.5, 1.0), 10.0, Color("df2507"))
	draw_circle(Vector2(-2.0, -2.0 - flicker), 7.2, Color("ff7b0b"))
	draw_circle(Vector2(-3.5, -4.0), 4.1, Color("ffe66b"))
	draw_circle(Vector2(-4.5, -5.0), 2.0, Color("fffbd5"))
	_draw_core_pixels(Color("ff4b08"), Color("ffd94a"), 12)

func _draw_volcanic_blaze() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color(0.2, 0.03, 0.025, 0.42))
	draw_circle(Vector2.ZERO, 9.7, Color("77100c"))
	for index in 7:
		var angle := index * TAU / 7.0 + elapsed * 0.7
		var start := Vector2.from_angle(angle) * 2.0
		var end := Vector2.from_angle(angle + sin(index * 2.0) * 0.2) * 8.0
		draw_line(start, end, Color("ff7a10"), 1.7, true)
	draw_circle(Vector2(-2.0, -2.0), 3.2, Color("ffd14a"))
	_draw_core_pixels(Color("a9140c"), Color("ff9a1c"), 10)

func _draw_dragon_fire() -> void:
	var pulse := 1.0 + sin(elapsed * 16.0) * 0.05
	draw_circle(Vector2.ZERO, 13.5 * pulse, Color(1.0, 0.18, 0.0, 0.13))
	draw_circle(Vector2(1.0, 0.0), 10.5 * pulse, Color("e93407"))
	draw_circle(Vector2(-2.5, 0.0), 7.5, Color("ff9414"))
	draw_circle(Vector2(-4.0, -1.5), 4.4, Color("fff17a"))
	draw_circle(Vector2(-5.0, -2.0), 2.0, Color("ffffff"))
	for index in 8:
		var angle := elapsed * 5.0 + index * TAU / 8.0
		_draw_pixel(Vector2.from_angle(angle) * 11.0, 1.0 + index % 3, Color("ffb629"))

func _draw_phoenix_flame() -> void:
	var wing := 12.0 + sin(elapsed * 13.0) * 3.0
	draw_arc(Vector2.ZERO, wing, -2.7, -0.35, 12, Color("ff6a08"), 3.0, true)
	draw_arc(Vector2.ZERO, wing, 0.35, 2.7, 12, Color("ff9f12"), 3.0, true)
	_draw_layered_core(Color("f14c06"), Color("ffb51b"), Color("ffffcf"), 9.5, 0.08)
	_draw_core_pixels(Color("ff7b08"), Color("fff06a"), 14)

func _draw_ashen_inferno() -> void:
	var wobble := sin(elapsed * 17.0)
	draw_circle(Vector2.ZERO, 13.0, Color(0.35, 0.08, 0.03, 0.22))
	draw_circle(Vector2(wobble, 1.0), 10.5, Color("ba260d"))
	draw_circle(Vector2(-2.0, -2.0), 7.0, Color("f27319"))
	draw_circle(Vector2(-3.0, -3.5), 3.8, Color("ffe0a0"))
	for index in 9:
		var angle := elapsed * (2.0 + index * 0.13) + index * TAU / 9.0
		_draw_pixel(Vector2.from_angle(angle) * (10.0 + index % 3), 1.0 + index % 3, Color("432d2a") if index % 2 else Color("ff9a26"))

func _draw_layered_core(outer: Color, middle: Color, hot: Color, radius: float, pulse_amount: float) -> void:
	var pulse := 1.0 + sin(elapsed * 14.0) * pulse_amount
	draw_circle(Vector2.ZERO, radius * 1.55 * pulse, Color(outer, 0.16))
	draw_circle(Vector2.ZERO, radius * pulse, outer)
	draw_circle(Vector2(-2.0, -1.5), radius * 0.68, middle)
	draw_circle(Vector2(-3.3, -2.7), radius * 0.36, hot)

func _draw_interior_flame_detail(style: int) -> void:
	var deep_color := Color("b20b12")
	var middle_color := Color("ff6611")
	var hot_color := Color("fff2a1")
	match style:
		GameEvents.FireballVisualStyle.WHITE_HOT_COMET:
			deep_color = Color("d92308")
			middle_color = Color("ff9b20")
			hot_color = Color("ffffff")
		GameEvents.FireballVisualStyle.SOULFIRE:
			deep_color = Color("7d0619")
			middle_color = Color("e51d32")
			hot_color = Color("ffd5a3")
		GameEvents.FireballVisualStyle.VOLCANIC_BLAZE:
			deep_color = Color("5c0807")
			middle_color = Color("dc3510")
			hot_color = Color("ffd04a")
		GameEvents.FireballVisualStyle.ASHEN_INFERNO:
			deep_color = Color("6b1710")
			middle_color = Color("e95b18")
			hot_color = Color("ffe0a0")
	for index in 10:
		var phase := fposmod(elapsed * (1.7 + float(index % 3) * 0.24) + float(index) / 10.0, 1.0)
		var rise := lerpf(5.5, -5.5, phase)
		var swirl := sin(elapsed * (4.0 + float(index % 2)) + index * 1.73) * (4.3 - phase * 1.4)
		var particle_size := lerpf(2.1 + float(index % 2) * 0.45, 0.65, phase)
		var detail_color := deep_color.lerp(middle_color, sin(phase * PI))
		if index % 4 == 0:
			detail_color = detail_color.lerp(hot_color, 0.72)
		detail_color.a = 0.82
		draw_circle(Vector2(swirl, rise), particle_size, detail_color)
	for index in 3:
		var arc_rotation := elapsed * (1.8 + index * 0.35) + index * TAU / 3.0
		draw_arc(Vector2.ZERO, 3.0 + index * 1.5, arc_rotation, arc_rotation + 0.9, 7, Color(hot_color, 0.38), 0.8, true)

func _draw_core_pixels(outer: Color, hot: Color, count: int) -> void:
	for index in count:
		var angle := elapsed * (4.0 + float(index % 3)) + index * 2.399
		var radius := 7.0 + float(index % 4) * 1.5
		_draw_pixel(Vector2.from_angle(angle) * radius, 1.0 + float(index % 3), hot if index % 3 == 0 else outer)

func _draw_pixel(position: Vector2, size: float, color: Color) -> void:
	draw_rect(Rect2(position - Vector2.ONE * size * 0.5, Vector2.ONE * size), color)

func _draw_default_projectile() -> void:
	var projectile := get_parent()
	var direction_angle := 0.0
	if projectile and "direction" in projectile:
		direction_angle = Vector2(projectile.direction).angle()
	draw_set_transform(Vector2.ZERO, direction_angle, Vector2.ONE)
	draw_line(Vector2(-10, 0), Vector2(5, 0), Color(0.08, 0.72, 1.0, 0.5), 5.0, true)
	draw_circle(Vector2(5, 0), 5.0, Color(0.12, 0.82, 1.0, 1.0), true, -1.0, true)
	draw_circle(Vector2(4, -1), 2.0, Color(0.82, 1.0, 1.0, 1.0), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
