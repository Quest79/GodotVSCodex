extends Node2D

var skill_id := &"default_attack"
var elapsed := 0.0
var redraw_elapsed := 0.0

func configure(new_skill_id: StringName) -> void:
	skill_id = new_skill_id
	set_process(skill_id == &"fireball")
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	redraw_elapsed += delta
	if redraw_elapsed >= 1.0 / 30.0:
		redraw_elapsed = 0.0
		queue_redraw()

func _draw() -> void:
	if skill_id == &"fireball":
		_draw_fireball()
	else:
		_draw_default_projectile()

func _draw_fireball() -> void:
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

func _draw_default_projectile() -> void:
	draw_line(Vector2(-10, 0), Vector2(5, 0), Color(0.08, 0.72, 1.0, 0.5), 5.0, true)
	draw_circle(Vector2(5, 0), 5.0, Color(0.12, 0.82, 1.0, 1.0), true, -1.0, true)
	draw_circle(Vector2(4, -1), 2.0, Color(0.82, 1.0, 1.0, 1.0), true, -1.0, true)
