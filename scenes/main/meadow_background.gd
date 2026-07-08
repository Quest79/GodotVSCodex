extends Node2D

const HALF_SIZE := 5000.0
const CELL_SIZE := 160.0
const GRASS := Color("#42643b")
const GRASS_DARK := Color("#355631")
const DIRT := Color("#715d3f")
const DIRT_EDGE := Color("#596044")
const STONE := Color("#77786a")
const GRASS_CHUNK_SCRIPT := preload("res://scenes/main/meadow_grass_chunk.gd")
const GRASS_CHUNK_SIZE := 800.0

func _ready() -> void:
	z_index = -100
	_build_grass_chunks()
	queue_redraw()

func _build_grass_chunks() -> void:
	for chunk_x in range(-7, 7):
		for chunk_y in range(-7, 7):
			var chunk := GRASS_CHUNK_SCRIPT.new() as MeadowGrassChunk
			add_child(chunk)
			chunk.configure(Rect2(
				Vector2(chunk_x, chunk_y) * GRASS_CHUNK_SIZE,
				Vector2.ONE * GRASS_CHUNK_SIZE
			))

func _draw() -> void:
	draw_rect(Rect2(-HALF_SIZE, -HALF_SIZE, HALF_SIZE * 2.0, HALF_SIZE * 2.0), GRASS)
	_draw_paths()

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

func _near_path(p: Vector2) -> bool:
	var horizontal_y := 760.0 + sin(p.x * 0.0013) * 260.0 + sin(p.x * 0.0031) * 70.0
	var vertical_x := -1750.0 + sin(p.y * 0.0011) * 330.0
	return abs(p.y - horizontal_y) < 105.0 or abs(p.x - vertical_x) < 80.0

func _point(index: int, salt: int, extent: float) -> Vector2:
	return Vector2((_rand(index, salt) * 2.0 - 1.0) * extent, (_rand(index, salt + 1) * 2.0 - 1.0) * extent)

func _rand(index: int, salt: int) -> float:
	var value := sin(float(index * 92821 + salt * 68917)) * 43758.5453
	return value - floor(value)
