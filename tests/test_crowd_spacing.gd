extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_target := Node2D.new()
	player_target.add_to_group("player")
	player_target.position = Vector2(0.0, 100.0)
	add_child(player_target)

	var enemy_scene: PackedScene = load("res://scenes/actors/enemy/enemy.tscn")
	var left := enemy_scene.instantiate() as Enemy
	var center := enemy_scene.instantiate() as Enemy
	var right := enemy_scene.instantiate() as Enemy
	left.position = Vector2(-40.0, 0.0)
	center.position = Vector2.ZERO
	right.position = Vector2(40.0, 0.0)
	add_child(left)
	add_child(center)
	add_child(right)
	await get_tree().process_frame
	EnemyRegistry.update_enemy(left)
	EnemyRegistry.update_enemy(center)
	EnemyRegistry.update_enemy(right)

	var left_separation := EnemyRegistry.get_crowd_separation(left, player_target.global_position)
	var center_separation := EnemyRegistry.get_crowd_separation(center, player_target.global_position)
	assert(left_separation.length() > 0.0)
	# Radial forces on the middle enemy cancel. A non-zero result verifies that
	# the circulation lane breaks a perfectly symmetric crowd pile.
	assert(center_separation.length() > 0.0)
	assert(center.get_body_radius() >= 28.0)
	print("CROWD_SPACING_TEST_OK edge_force=", snappedf(left_separation.length(), 0.1), " center_flow=", snappedf(center_separation.length(), 0.1))
	get_tree().quit(0)
