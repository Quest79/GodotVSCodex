class_name ActorStatusIcon
extends Node2D

var status_id := &""
var stacks := 0
var active := false

@onready var graphic: Sprite2D = $Graphic
@onready var stack_label: Label = $StackLabel

func configure(new_status_id: StringName, new_stacks: int, new_texture: Texture2D = null) -> void:
	status_id = new_status_id
	stacks = new_stacks
	if new_texture:
		graphic.texture = new_texture
	graphic.visible = status_id == &"burning"
	active = stacks > 0
	if status_id == &"frozen":
		stack_label.text = "ICE"
	elif status_id == &"chilled":
		stack_label.text = "%d%%" % stacks
	else:
		stack_label.text = str(stacks)
	visible = active
	queue_redraw()

func clear() -> void:
	status_id = &""
	stacks = 0
	active = false
	visible = false
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.06
	var is_cold := status_id == &"chilled" or status_id == &"frozen"
	var border_color := Color(0.28, 0.82, 1.0, 0.82 * pulse) if is_cold else Color(1.0, 0.18, 0.02, 0.72 * pulse)
	var inner_color := Color(0.015, 0.12, 0.2, 0.98) if is_cold else Color(0.075, 0.018, 0.01, 0.98)
	# Reusable square status-icon frame; the child Sprite2D supplies the graphic.
	draw_rect(Rect2(-18, -18, 36, 36), Color(0.005, 0.008, 0.015, 0.92))
	draw_rect(Rect2(-17, -17, 34, 34), Color(0.17, 0.19, 0.22, 1.0), false, 2.0)
	draw_rect(Rect2(-14, -14, 28, 28), inner_color)
	draw_rect(Rect2(-14, -14, 28, 28), border_color, false, 1.0)
	if is_cold:
		for spoke_index in 6:
			var direction := Vector2.from_angle(TAU * float(spoke_index) / 6.0)
			draw_line(Vector2.ZERO, direction * 10.0, Color(0.75, 0.96, 1.0, 0.9), 1.5, true)
		draw_circle(Vector2.ZERO, 2.5, Color(0.92, 1.0, 1.0, 0.95))
	else:
		draw_line(Vector2(-14, -13), Vector2(13, -13), Color(1.0, 0.58, 0.12, 0.72), 1.0, true)
		draw_line(Vector2(-13, 13), Vector2(13, 13), Color(0.35, 0.025, 0.01, 0.9), 1.0, true)
