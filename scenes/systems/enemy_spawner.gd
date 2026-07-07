class_name EnemySpawner
extends Node2D

signal wave_changed(wave: int)

@export var enemy_scene: PackedScene
@export var minimum_spawn_radius := 520.0
@export var maximum_spawn_radius := 700.0
@export var starting_interval := 0.9
@export var minimum_interval := 0.18
@export var max_alive := 180
@export var wave_duration := 30.0

@onready var spawn_timer: Timer = $SpawnTimer

var elapsed := 0.0
var current_wave := 1
var target: Node2D

func _ready() -> void:
	target = get_tree().get_first_node_in_group("player") as Node2D
	spawn_timer.wait_time = starting_interval
	spawn_timer.timeout.connect(_spawn_enemy)
	spawn_timer.start()

func _process(delta: float) -> void:
	elapsed += delta
	var next_wave := floori(elapsed / wave_duration) + 1
	if next_wave != current_wave:
		current_wave = next_wave
		wave_changed.emit(current_wave)
	spawn_timer.wait_time = maxf(starting_interval - elapsed * 0.006, minimum_interval)

func _spawn_enemy() -> void:
	if not enemy_scene or not is_instance_valid(target):
		return
	if get_tree().get_nodes_in_group("enemies").size() >= max_alive:
		return
	var angle := randf_range(0.0, TAU)
	var distance := randf_range(minimum_spawn_radius, maximum_spawn_radius)
	var enemy := enemy_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = target.global_position + Vector2.from_angle(angle) * distance
