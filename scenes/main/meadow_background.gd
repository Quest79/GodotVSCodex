extends Node2D

const HALF_SIZE := 5000.0
const CELL_SIZE := 160.0
const GRASS := Color("#42643b")
const GRASS_DARK := Color("#355631")
const DIRT := Color("#715d3f")
const DIRT_EDGE := Color("#596044")
const STONE := Color("#77786a")

var wind_time := 0.0
var redraw_accumulator := 0.0

func _ready() -> void:
	z_index = -100
	queue_redraw()

func _process(delta: float) -> void:
	wind_time += delta
	redraw_accumulator += delta
	# A low redraw rate makes the wind feel gentle and avoids spending a full
	# render pass on background decoration every gameplay frame.
	if redraw_accumulator >= 0.08:
		redraw_accumulator = 0.0
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-HALF_SIZE, -HALF_SIZE, HALF_SIZE * 2.0, HALF_SIZE * 2.0), GRASS)
	_draw_ground_variation()
	_draw_paths()
	_draw_stones()
	_draw_meadow_details()

func _draw_ground_variation() -> void:
	# Large overlapping translucent shapes keep the terrain transitions soft.
	for index in range(72):
		var center := _point(index, 41, HALF_SIZE - 220.0)
		var radius := 150.0 + _rand(index, 9) * 310.0
		var is_dirt := _rand(index, 18) > 0.62
		var color := DIRT_EDGE if is_dirt else GRASS_DARK
		color.a = 0.13 if is_dirt else 0.16
		for ring in range(5, 0, -1):
			var ring_color := color
			ring_color.a *= (6.0 - ring) / 7.0
			draw_circle(center, radius * ring / 5.0, ring_color)

func _draw_paths() -> void:
	# Two old, broken tracks crossing the field rather than a perfect road.
	var horizontal := PackedVector2Array()
	var vertical := PackedVector2Array()
	for step in range(65):
		var x := -HALF_SIZE + step * (HALF_SIZE * 2.0 / 64.0)
		horizontal.append(Vector2(x, 760.0 + sin(x * 0.0013) * 260.0 + sin(x * 0.0031) * 70.0))
		var y := -HALF_SIZE + step * (HALF_SIZE * 2.0 / 64.0)
		vertical.append(Vector2(-1750.0 + sin(y * 0.0011) * 330.0, y))
	draw_polyline(horizontal, Color(DIRT, 0.22), 128.0, true)
	draw_polyline(horizontal, Color(DIRT, 0.38), 72.0, true)
	draw_polyline(vertical, Color(DIRT, 0.17), 104.0, true)
	# Sparse inset stones sell the main path without making it feel paved.
	for index in range(46):
		if index % 5 == 0:
			continue
		var x := -4700.0 + index * 208.0
		var y := 760.0 + sin(x * 0.0013) * 260.0 + sin(x * 0.0031) * 70.0
		var p := Vector2(x, y) + Vector2(0.0, (_rand(index, 77) - 0.5) * 52.0)
		_draw_stone(p, 12.0 + _rand(index, 78) * 17.0)

func _draw_stones() -> void:
	for index in range(95):
		var p := _point(index, 113, HALF_SIZE - 100.0)
		if _near_path(p):
			continue
		_draw_stone(p, 5.0 + _rand(index, 114) * 12.0)

func _draw_stone(position: Vector2, radius: float) -> void:
	draw_circle(position + Vector2(2, 4), radius, Color(0.12, 0.16, 0.11, 0.24))
	draw_circle(position, radius, Color(STONE, 0.82))
	draw_circle(position + Vector2(-radius * 0.25, -radius * 0.28), radius * 0.48, Color(0.62, 0.62, 0.53, 0.7))

func _draw_meadow_details() -> void:
	for gx in range(-31, 32):
		for gy in range(-31, 32):
			var index := (gx + 31) * 67 + gy + 31
			if _rand(index, 201) < 0.38:
				continue
			var base := Vector2(gx, gy) * CELL_SIZE
			base += Vector2((_rand(index, 202) - 0.5) * 125.0, (_rand(index, 203) - 0.5) * 125.0)
			if _near_path(base):
				continue
			var sway := sin(wind_time * 1.15 + base.x * 0.013 + base.y * 0.009) * 2.2
			var blade_color := Color("#6f8b4b") if index % 4 else Color("#829653")
			for blade in range(3):
				var root := base + Vector2(blade * 4.0 - 4.0, 0)
				var height := 8.0 + _rand(index, 210 + blade) * 9.0
				draw_line(root, root + Vector2(sway + blade - 1.0, -height), Color(blade_color, 0.72), 1.25, true)
			if index % 43 == 0:
				var flower := Color("#ddd48a") if index % 86 else Color("#b6c9e8")
				draw_circle(base + Vector2(sway, -12), 2.2, flower)

func _near_path(p: Vector2) -> bool:
	var horizontal_y := 760.0 + sin(p.x * 0.0013) * 260.0 + sin(p.x * 0.0031) * 70.0
	var vertical_x := -1750.0 + sin(p.y * 0.0011) * 330.0
	return abs(p.y - horizontal_y) < 105.0 or abs(p.x - vertical_x) < 80.0

func _point(index: int, salt: int, extent: float) -> Vector2:
	return Vector2((_rand(index, salt) * 2.0 - 1.0) * extent, (_rand(index, salt + 1) * 2.0 - 1.0) * extent)

func _rand(index: int, salt: int) -> float:
	var value := sin(float(index * 92821 + salt * 68917)) * 43758.5453
	return value - floor(value)
