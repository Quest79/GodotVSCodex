class_name EnemySpawner
extends Node2D

signal wave_changed(wave: int)

const VIEW_SPAWN_MARGIN := 110.0

@export var enemy_scene: PackedScene
@export var minimum_spawn_radius := 520.0
@export var maximum_spawn_radius := 700.0
@export var starting_interval := 0.9
@export var minimum_interval := 0.18
@export var max_alive := 180
@export var wave_duration := 30.0
@export var boss_reinforcement_min_delay := 5.0
@export var boss_reinforcement_max_delay := 8.0

@onready var spawn_timer: Timer = $SpawnTimer

var elapsed := 0.0
var current_wave := 1
var target: Node2D
var boss_wave_active := false
var boss_reinforcement_elapsed := 0.0
var boss_reinforcement_delay := 6.0

func _ready() -> void:
	add_to_group("enemy_spawner")
	target = get_tree().get_first_node_in_group("player") as Node2D
	spawn_timer.wait_time = starting_interval
	spawn_timer.timeout.connect(_spawn_enemy)
	spawn_timer.start()

func _process(delta: float) -> void:
	if boss_wave_active:
		_process_boss_reinforcements(delta)
		return
	elapsed += delta
	var next_wave := floori(elapsed / wave_duration) + 1
	if next_wave != current_wave:
		current_wave = next_wave
		wave_changed.emit(current_wave)
		if current_wave == 2 or current_wave % 5 == 0:
			_spawn_boss()
			return
	spawn_timer.wait_time = maxf(starting_interval - elapsed * 0.006, minimum_interval)

func _spawn_enemy() -> void:
	if not enemy_scene or not is_instance_valid(target):
		return
	if EnemyRegistry.get_enemy_count() >= max_alive:
		return
	var enemy := enemy_scene.instantiate() as Node2D
	# Give the body its final transform before it enters the physics world.
	# Adding it at (0, 0) for even one physics tick can displace the player.
	enemy.global_position = _get_offscreen_spawn_position()
	get_tree().current_scene.add_child(enemy)
	EnemyRegistry.update_enemy(enemy as Enemy)

func _spawn_boss() -> void:
	if not enemy_scene or not is_instance_valid(target):
		return
	boss_wave_active = true
	boss_reinforcement_elapsed = 0.0
	boss_reinforcement_delay = randf_range(boss_reinforcement_min_delay, boss_reinforcement_max_delay)
	spawn_timer.stop()
	var boss := enemy_scene.instantiate() as Enemy
	boss.global_position = _get_offscreen_spawn_position()
	get_tree().current_scene.add_child(boss)
	EnemyRegistry.update_enemy(boss)
	boss.configure_boss()
	boss.health.died.connect(_on_boss_died, CONNECT_ONE_SHOT)
	boss.health.died.connect(_spawn_boss_minions.bind(boss), CONNECT_ONE_SHOT)

func _process_boss_reinforcements(delta: float) -> void:
	boss_reinforcement_elapsed += delta
	if boss_reinforcement_elapsed < boss_reinforcement_delay:
		return
	boss_reinforcement_elapsed = 0.0
	boss_reinforcement_delay = randf_range(boss_reinforcement_min_delay, boss_reinforcement_max_delay)
	var count := randi_range(2, 4)
	for index in range(count):
		if EnemyRegistry.get_enemy_count() >= max_alive:
			return
		var minion := enemy_scene.instantiate() as Node2D
		minion.global_position = _get_offscreen_spawn_position()
		get_tree().current_scene.add_child(minion)
		EnemyRegistry.update_enemy(minion as Enemy)

func _on_boss_died() -> void:
	boss_wave_active = false
	# A boss wave ends the moment its boss dies; the next wave starts immediately.
	elapsed = float(current_wave) * wave_duration
	current_wave += 1
	wave_changed.emit(current_wave)
	spawn_timer.start()

func _spawn_boss_minions(boss: Enemy) -> void:
	if not enemy_scene or not is_instance_valid(boss):
		return
	for index in 2:
		var minion := enemy_scene.instantiate() as Node2D
		var offset := Vector2.from_angle(index * PI + randf_range(-0.45, 0.45)) * randf_range(24.0, 48.0)
		minion.position = boss.global_position + offset
		get_tree().current_scene.add_child(minion)
		EnemyRegistry.update_enemy(minion as Enemy)

func _get_offscreen_spawn_position() -> Vector2:
	var camera := target.get_node_or_null("Camera2D") as Camera2D
	if not is_instance_valid(camera):
		var angle := randf_range(0.0, TAU)
		var distance := randf_range(minimum_spawn_radius, maximum_spawn_radius)
		return target.global_position + Vector2.from_angle(angle) * distance

	var half_view := camera.get_viewport_rect().size * 0.5 / camera.zoom
	var screen_center := camera.get_screen_center_position()
	match randi_range(0, 3):
		0:
			return screen_center + Vector2(randf_range(-half_view.x, half_view.x), -half_view.y - VIEW_SPAWN_MARGIN)
		1:
			return screen_center + Vector2(half_view.x + VIEW_SPAWN_MARGIN, randf_range(-half_view.y, half_view.y))
		2:
			return screen_center + Vector2(randf_range(-half_view.x, half_view.x), half_view.y + VIEW_SPAWN_MARGIN)
		_:
			return screen_center + Vector2(-half_view.x - VIEW_SPAWN_MARGIN, randf_range(-half_view.y, half_view.y))
