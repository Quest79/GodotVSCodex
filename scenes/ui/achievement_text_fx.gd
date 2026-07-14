extends Control

var element := 0
var elapsed := 0.0
var active := false

func configure(new_element: int) -> void:
	element = new_element
	elapsed = 0.0
	active = true
	queue_redraw()

func stop() -> void:
	active = false
	queue_redraw()

func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	match element:
		ChallengeSystem.ElementStyle.FREEZING:
			_draw_freezing()
		ChallengeSystem.ElementStyle.LIGHTNING:
			_draw_lightning()
		_:
			_draw_burning()

func _draw_burning() -> void:
	for index in 18:
		var phase := fposmod(elapsed * (0.7 + index % 3 * 0.08) + index * 0.173, 1.0)
		var x := 28.0 + fposmod(index * 53.0, maxf(size.x - 56.0, 1.0))
		var y := 84.0 - phase * 48.0 + sin(elapsed * 5.0 + index) * 3.0
		var ember_size := lerpf(3.0, 0.8, phase)
		var color := Color("ffd05a").lerp(Color("ee3510"), phase)
		color.a = (1.0 - phase) * 0.82
		draw_rect(Rect2(Vector2(x, y) - Vector2.ONE * ember_size * 0.5, Vector2.ONE * ember_size), color)
	draw_line(Vector2(24, 87), Vector2(size.x - 24, 87), Color(1.0, 0.22, 0.04, 0.42 + sin(elapsed * 7.0) * 0.08), 2.0, true)

func _draw_freezing() -> void:
	for index in 13:
		var phase := fposmod(elapsed * 0.28 + index * 0.239, 1.0)
		var x := 24.0 + fposmod(index * 67.0, maxf(size.x - 48.0, 1.0))
		var y := 38.0 + phase * 52.0
		var crystal_size := 1.5 + float(index % 3)
		var points := PackedVector2Array([
			Vector2(x, y - crystal_size * 1.8), Vector2(x + crystal_size, y),
			Vector2(x, y + crystal_size * 1.8), Vector2(x - crystal_size, y),
		])
		draw_colored_polygon(points, Color(0.55, 0.9, 1.0, (1.0 - phase) * 0.72))
	var glint_x := fposmod(elapsed * 115.0, maxf(size.x - 60.0, 1.0)) + 30.0
	draw_line(Vector2(glint_x, 41), Vector2(glint_x + 18, 80), Color(0.9, 1.0, 1.0, 0.5), 1.2, true)

func _draw_lightning() -> void:
	var pulse := 0.45 + 0.35 * absf(sin(elapsed * 11.0))
	for index in 5:
		var x := 38.0 + fposmod(index * 91.0, maxf(size.x - 76.0, 1.0))
		var y := 39.0 + sin(elapsed * 8.0 + index) * 5.0
		var points := PackedVector2Array([
			Vector2(x, y), Vector2(x + 8, y + 11), Vector2(x + 3, y + 20), Vector2(x + 14, y + 32),
		])
		draw_polyline(points, Color(0.83, 0.7, 1.0, pulse), 1.5, true)
	draw_line(Vector2(24, 87), Vector2(size.x - 24, 87), Color(0.62, 0.38, 1.0, pulse * 0.6), 1.5, true)
