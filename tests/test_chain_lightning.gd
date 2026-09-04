extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var lightning_gem: GemDefinition = load("res://resources/gems/chain_lightning.tres")
	assert(lightning_gem != null)
	assert(lightning_gem.skill_id == &"chain_lightning")
	assert(int(lightning_gem.effects[&"chain_count"]) == 4)
	assert(float(lightning_gem.effects[&"chain_radius"]) >= 200.0)

	var enemy_scene: PackedScene = load("res://scenes/actors/enemy/enemy.tscn")
	var first := enemy_scene.instantiate() as Enemy
	var second := enemy_scene.instantiate() as Enemy
	first.position = Vector2.ZERO
	second.position = Vector2(100.0, 0.0)
	add_child(first)
	add_child(second)
	await get_tree().process_frame
	first.set_physics_process(false)
	second.set_physics_process(false)
	EnemyRegistry.update_enemy(first)
	EnemyRegistry.update_enemy(second)

	var projectile := load("res://scenes/combat/projectile.tscn").instantiate() as Projectile
	add_child(projectile)
	projectile.global_position = Vector2(-20.0, 0.0)
	projectile.setup(
		Vector2.RIGHT,
		5.0,
		720.0,
		1.0,
		2.0,
		0,
		0.0,
		&"chain_lightning",
		first,
		0.0,
		4.0,
		0.0,
		0.0,
		0.0,
		4,
		220.0,
		0.82
	)

	var second_before := second.health.current
	projectile._damage_collider(first, first.global_position)
	assert(first.afflictions.has(&"shocked"))
	assert(second.afflictions.has(&"shocked"))
	assert(second.health.current < second_before)

	var raw_damage := 5.0
	var amplified_damage := second.health.take_damage(raw_damage)
	assert(amplified_damage > raw_damage)
	assert(second.health.incoming_damage_multiplier > 1.0)

	for _index in 10:
		second.apply_elemental_affliction(&"shocked", 4.0)
	assert(int(second.afflictions[&"shocked"]["stacks"]) == Enemy.SHOCK_MAX_STACKS)
	assert(is_equal_approx(second.health.incoming_damage_multiplier, 1.4))

	print("CHAIN_LIGHTNING_TEST_OK multiplier=", second.health.incoming_damage_multiplier)
	get_tree().quit(0)
