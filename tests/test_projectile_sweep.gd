extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var enemy_scene: PackedScene = load("res://scenes/actors/enemy/enemy.tscn")
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.position = Vector2(60.0, 0.0)
	add_child(enemy)
	await get_tree().process_frame
	enemy.set_physics_process(false)
	EnemyRegistry.update_enemy(enemy)

	var projectile := load("res://scenes/combat/projectile.tscn").instantiate() as Projectile
	add_child(projectile)
	projectile.global_position = Vector2.ZERO
	projectile.setup(Vector2.RIGHT, 5.0, 720.0, 1.0)

	var hits := projectile._find_swept_hits(Vector2.ZERO, Vector2(120.0, 0.0))
	assert(hits.has(enemy))
	assert(enemy.get_projectile_collision_radius() > 0.0)
	assert(enemy is Node2D)
	assert(not enemy is PhysicsBody2D)

	print("PROJECTILE_SWEEP_TEST_OK")
	get_tree().quit(0)
