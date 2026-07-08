class_name MeadowGrassChunk
extends Node2D

const CELL_SIZE := 160.0
const HALF_SIZE := 5000.0
const DIRT_EDGE := Color("#596044")
const GRASS_DARK := Color("#355631")
const STONE := Color("#77786a")

var world_rect: Rect2

func configure(rect: Rect2) -> void:
	world_rect = rect
	position = rect.position
	queue_redraw()

func _draw() -> void:
	# Each chunk owns only nearby blades, allowing Godot to discard almost all
	# meadow geometry before submitting canvas commands for an onscreen frame.
	_draw_ground_variation()
	_draw_stones()
	for gx in range(-31, 32):
		for gy in range(-31, 32):
			var index := (gx + 31) * 67 + gy + 31
			if _rand(index, 201) < 0.38:
				continue
			var base := Vector2(gx, gy) * CELL_SIZE
			base += Vector2((_rand(index, 202) - 0.5) * 125.0, (_rand(index, 203) - 0.5) * 125.0)
			if not world_rect.has_point(base) or _near_path(base):
				continue
			var local_base := base - world_rect.position
			var lean := (_rand(index, 204) - 0.5) * 3.0
			var blade_color := Color("#6f8b4b") if index % 4 else Color("#829653")
			for blade in range(3):
				var root := local_base + Vector2(blade * 4.0 - 4.0, 0)
				var height := 8.0 + _rand(index, 210 + blade) * 9.0
				draw_line(root, root + Vector2(lean + blade - 1.0, -height), Color(blade_color, 0.72), 1.25, true)
			if index % 43 == 0:
				var flower := Color("#ddd48a") if index % 86 else Color("#b6c9e8")
				draw_circle(local_base + Vector2(lean, -12), 2.2, flower)

func _draw_ground_variation() -> void:
	for index in range(72):
		var center := _point(index, 41, HALF_SIZE - 220.0)
		if not world_rect.has_point(center):
			continue
		var radius := 150.0 + _rand(index, 9) * 310.0
		var is_dirt := _rand(index, 18) > 0.62
		var color := DIRT_EDGE if is_dirt else GRASS_DARK
		color.a = 0.13 if is_dirt else 0.16
		var local_center := center - world_rect.position
		for ring in range(5, 0, -1):
			var ring_color := color
			ring_color.a *= (6.0 - ring) / 7.0
			draw_circle(local_center, radius * ring / 5.0, ring_color)

func _draw_stones() -> void:
	for index in range(95):
		var point := _point(index, 113, HALF_SIZE - 100.0)
		if not world_rect.has_point(point) or _near_path(point):
			continue
		_draw_stone(point - world_rect.position, 5.0 + _rand(index, 114) * 12.0)

func _draw_stone(point: Vector2, radius: float) -> void:
	draw_circle(point + Vector2(2, 4), radius, Color(0.12, 0.16, 0.11, 0.24))
	draw_circle(point, radius, Color(STONE, 0.82))
	draw_circle(point + Vector2(-radius * 0.25, -radius * 0.28), radius * 0.48, Color(0.62, 0.62, 0.53, 0.7))

func _near_path(point: Vector2) -> bool:
	var horizontal_y := 760.0 + sin(point.x * 0.0013) * 260.0 + sin(point.x * 0.0031) * 70.0
	var vertical_x := -1750.0 + sin(point.y * 0.0011) * 330.0
	return abs(point.y - horizontal_y) < 105.0 or abs(point.x - vertical_x) < 80.0

func _rand(index: int, salt: int) -> float:
	var value := sin(float(index * 92821 + salt * 68917)) * 43758.5453
	return value - floor(value)

func _point(index: int, salt: int, extent: float) -> Vector2:
	return Vector2((_rand(index, salt) * 2.0 - 1.0) * extent, (_rand(index, salt + 1) * 2.0 - 1.0) * extent)
