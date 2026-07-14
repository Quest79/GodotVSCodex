class_name ProjectileImpactFX
extends Node2D

var age := 0.0
var duration := 0.34
var element := &"arcane"
var incoming_direction := Vector2.RIGHT
var radius := 32.0
var particles: Array[Dictionary] = []
var fireball_style := 0

func configure(new_skill_id: StringName, new_direction: Vector2, projectile_scale := 1.0) -> void:
	element = new_skill_id
	if element == &"fireball" or element == &"fire":
		fireball_style = GameEvents.fireball_visual_style
	incoming_direction = new_direction.normalized()
	radius = maxf(30.0, 27.0 * projectile_scale)
	var particle_count := 24 if element == &"fireball" or element == &"fire" else (20 if element == &"ice_shard" else 16)
	for index in particle_count:
		var angle := index * TAU / particle_count + randf_range(-0.12, 0.12)
		particles.append({
			"angle": angle,
			"speed": randf_range(42.0, 92.0),
			"size": randf_range(1.0, 2.7),
			"phase": randf_range(0.0, TAU)
		})
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	queue_redraw()

func _palette() -> Array[Color]:
	if element == &"fireball" or element == &"fire":
		match fireball_style:
			GameEvents.FireballVisualStyle.ORIGINAL:
				return [Color("#ff3b12"), Color("#ff9d24"), Color("#fff2a6")]
			GameEvents.FireballVisualStyle.WHITE_HOT_COMET:
				return [Color("#ff4a0b"), Color("#ffd75a"), Color("#ffffff")]
			GameEvents.FireballVisualStyle.PIXEL_INFERNO:
				return [Color("#8f0712"), Color("#ff4817"), Color("#ffd34d")]
			GameEvents.FireballVisualStyle.SOLAR_FLARE:
				return [Color("#ff7608"), Color("#ffd72d"), Color("#fffbd0")]
			GameEvents.FireballVisualStyle.SOULFIRE:
				return [Color("#8f071c"), Color("#e51d32"), Color("#fff0d2")]
			GameEvents.FireballVisualStyle.WILDFIRE:
				return [Color("#d92506"), Color("#ff7b0b"), Color("#fff2a1")]
			GameEvents.FireballVisualStyle.VOLCANIC_BLAZE:
				return [Color("#61100d"), Color("#d52c0c"), Color("#ffd24b")]
			GameEvents.FireballVisualStyle.DRAGON_FIRE:
				return [Color("#e93407"), Color("#ff9414"), Color("#fffbd0")]
			GameEvents.FireballVisualStyle.PHOENIX_FLAME:
				return [Color("#f14c06"), Color("#ffb51b"), Color("#ffffcf")]
			GameEvents.FireballVisualStyle.ASHEN_INFERNO:
				return [Color("#6b2d21"), Color("#e85d16"), Color("#ffe0a0")]
		return [Color("#ff3b12"), Color("#ff9d24"), Color("#fff2a6")]
	if element == &"ice" or element == &"frost" or element == &"ice_shard":
		return [Color("#3da9ff"), Color("#a8e8ff"), Color("#f2ffff")]
	if element == &"lightning" or element == &"storm":
		return [Color("#9e6cff"), Color("#e3c8ff"), Color("#ffffff")]
	return [Color("#7136c7"), Color("#bd86ff"), Color("#e8d7ff")]

func _draw() -> void:
	var progress := age / duration
	var fade := 1.0 - progress
	var colors := _palette()
	var impact_axis := incoming_direction * radius * 0.42

	# The flash is deliberately wider than the projectile's visual body.
	draw_circle(Vector2.ZERO, lerpf(radius * 0.32, radius, progress), Color(colors[0], fade * 0.16))
	draw_arc(Vector2.ZERO, lerpf(7.0, radius, progress), 0.0, TAU, 32, Color(colors[1], fade * 0.9), 2.4 * fade, true)
	draw_line(-impact_axis, impact_axis, Color(colors[2], fade * 0.8), 2.2 * fade, true)

	for particle in particles:
		var angle: float = particle["angle"]
		var distance: float = lerpf(5.0, radius * 1.35, progress) * (float(particle["speed"]) / 68.0)
		var point: Vector2 = Vector2.from_angle(angle) * distance
		var particle_fade := fade * (0.5 + 0.5 * sin(progress * PI + particle["phase"]))
		var particle_size: float = particle["size"] * (1.0 - progress * 0.35)
		if element == &"fireball" or element == &"fire":
			var pixel_position := Vector2(roundf(point.x), roundf(point.y))
			draw_rect(Rect2(pixel_position - Vector2.ONE * particle_size * 0.5, Vector2.ONE * particle_size), Color(colors[1], particle_fade))
		else:
			draw_circle(point, particle_size, Color(colors[1], particle_fade))
		draw_line(point, point - Vector2.from_angle(angle) * 6.0, Color(colors[0], particle_fade * 0.65), 1.0, true)
