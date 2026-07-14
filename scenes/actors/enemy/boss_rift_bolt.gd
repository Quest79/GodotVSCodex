extends Node2D

const SPEED := 540.0
const DAMAGE := 18.0
const LIFETIME := 2.2
const HIT_RADIUS := 28.0

var direction := Vector2.RIGHT
var remaining := LIFETIME
var elapsed := 0.0

func _ready() -> void:
	add_to_group("boss_rift_bolts")

func configure(new_direction: Vector2) -> void:
	direction = new_direction.normalized() if new_direction != Vector2.ZERO else Vector2.RIGHT
	rotation = direction.angle()

func _process(delta: float) -> void:
	elapsed += delta
	remaining -= delta
	global_position += direction * SPEED * delta
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and global_position.distance_squared_to(player.global_position) <= HIT_RADIUS * HIT_RADIUS:
		player.health.take_damage(DAMAGE)
		queue_free()
		return
	if remaining <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var pulse := 0.55 + 0.45 * sin(elapsed * 15.0)
	draw_circle(Vector2.ZERO, 19.0 + pulse * 4.0, Color(1.0, 0.04, 0.42, 0.1), true, -1.0, true)
	draw_circle(Vector2.ZERO, 11.0 + pulse * 1.6, Color(0.92, 0.04, 0.36, 0.86), true, -1.0, true)
	draw_circle(Vector2(4.0, 0.0), 5.0, Color(0.65, 0.95, 1.0, 0.98), true, -1.0, true)
	for index in range(4):
		var angle := elapsed * 9.0 + index * TAU / 4.0
		var point := Vector2.from_angle(angle) * 13.0
		draw_line(point, point + Vector2.from_angle(angle) * 8.0, Color(1.0, 0.3, 0.62, 0.8), 1.8, true)
