extends Node2D

var animation_time := 0.0
var merged_xp := 0
var total_xp := 1

func set_crystal_state(new_merged_xp: int, new_total_xp: int) -> void:
	merged_xp = new_merged_xp
	total_xp = new_total_xp
	queue_redraw()

func _process(delta: float) -> void:
	animation_time += delta
	rotation += delta * 0.7
	position.y = sin(animation_time * 3.0) * 2.0

func _draw() -> void:
	var awakened := total_xp >= 20
	var purple_progress := clampf(merged_xp / 20.0, 0.0, 1.0)
	var body := Color("#24d97d").lerp(Color("#8250b6"), purple_progress)
	var light := Color("#6effaa").lerp(Color("#c29be7"), purple_progress)
	var dark := Color("#0c8b51").lerp(Color("#50306f"), purple_progress)
	if awakened:
		body = Color("#72cff2")
		light = Color("#d4f5ff")
		dark = Color("#367da8")
	var crystal := PackedVector2Array([Vector2(0, -12), Vector2(8, -3), Vector2(6, 8), Vector2(0, 13), Vector2(-6, 8), Vector2(-8, -3)])
	draw_colored_polygon(crystal, body)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(8, -3), Vector2(0, 3), Vector2(-8, -3)]), light)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 3), Vector2(6, 8), Vector2(0, 13)]), dark)
	draw_polyline(PackedVector2Array([Vector2(0, -12), Vector2(8, -3), Vector2(6, 8), Vector2(0, 13), Vector2(-6, 8), Vector2(-8, -3), Vector2(0, -12)]), Color(0.0, 0.0, 0.0, 0.55), 1.4, true)
	draw_line(Vector2(-3, -7), Vector2(1, -3), Color(light, 0.95), 1.5, true)
