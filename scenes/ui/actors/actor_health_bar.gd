class_name ActorHealthBar
extends Node2D

const WIDTH := 320.0
const HEIGHT := 16.0
const HEALTH_SMOOTH_TIME := 0.3

var title := "BOSS"
var maximum := 1.0
var target_current := 1.0
var displayed_current := 1.0
var fill_color := Color(0.95, 0.08, 0.16, 1.0)
var active := false

func configure(new_title: String, new_maximum: float, new_fill_color := Color(0.95, 0.08, 0.16, 1.0)) -> void:
	title = new_title
	maximum = maxf(new_maximum, 1.0)
	target_current = maximum
	displayed_current = maximum
	fill_color = new_fill_color
	active = true
	visible = true
	queue_redraw()

func set_health(new_current: float, new_maximum: float) -> void:
	maximum = maxf(new_maximum, 1.0)
	target_current = clampf(new_current, 0.0, maximum)
	queue_redraw()

func _process(delta: float) -> void:
	if not active:
		return
	var actor := get_parent() as Node2D
	if actor:
		global_position = actor.global_position + Vector2(0.0, -96.0)
	var rate := maximum / HEALTH_SMOOTH_TIME
	displayed_current = move_toward(displayed_current, target_current, rate * delta)
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	var ratio := clampf(displayed_current / maximum, 0.0, 1.0)
	var left := -WIDTH * 0.5
	# Deliberately integer-aligned geometry keeps this UI crisp at every scale.
	draw_rect(Rect2(left, 0.0, WIDTH, HEIGHT), Color("#070a12"), true)
	draw_rect(Rect2(left + 1.0, 1.0, WIDTH - 2.0, HEIGHT - 2.0), Color("#e8c573"), false, 1.0, true)
	draw_rect(Rect2(left + 4.0, 4.0, WIDTH - 8.0, HEIGHT - 8.0), Color("#1d111d"), true)
	var fill_width: float = floorf((WIDTH - 8.0) * ratio)
	if fill_width > 0.0:
		draw_rect(Rect2(left + 4.0, 4.0, fill_width, HEIGHT - 8.0), fill_color, true)
		draw_line(Vector2(left + 4.0, 4.0), Vector2(left + 4.0 + fill_width, 4.0), Color.WHITE.lightened(0.35), 1.0, true)
	draw_rect(Rect2(left, 0.0, WIDTH, HEIGHT), Color("#08090d"), false, 2.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(left, -7.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color("#ffdf9a"))
	draw_string(ThemeDB.fallback_font, Vector2(left, -7.0), "%d / %d" % [ceili(displayed_current), ceili(maximum)], HORIZONTAL_ALIGNMENT_RIGHT, WIDTH, 11, Color("#f5f0e8"))
