extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var ice_gem: GemDefinition = load("res://resources/gems/ice_shard.tres")
	assert(ice_gem != null)
	assert(ice_gem.skill_id == &"ice_shard")
	assert(is_equal_approx(float(ice_gem.effects[&"damage_min"]), 1.0))
	assert(is_equal_approx(float(ice_gem.effects[&"damage_max"]), 3.0))
	assert(float(ice_gem.effects[&"freeze_buildup_multiplier"]) > 0.0)

	var enemy := load("res://scenes/actors/enemy/enemy.tscn").instantiate() as Enemy
	add_child(enemy)
	await get_tree().process_frame

	enemy.apply_cold_ailments(2.0, 2.0, float(ice_gem.effects[&"freeze_buildup_multiplier"]))
	assert(enemy.afflictions.has(&"chilled"))
	var chill: Dictionary = enemy.afflictions[&"chilled"]
	assert(float(chill["magnitude"]) >= Enemy.CHILL_MIN_EFFECT)
	assert(float(chill["magnitude"]) <= Enemy.CHILL_MAX_EFFECT)
	assert(enemy.freeze_buildup > 0.0)
	assert(enemy._cold_action_speed_multiplier() < 1.0)

	var hits := 1
	while not enemy.is_frozen() and hits < 30:
		enemy.apply_cold_ailments(2.0, 2.0, float(ice_gem.effects[&"freeze_buildup_multiplier"]))
		hits += 1
	assert(enemy.is_frozen())
	assert(hits < 30)
	assert(is_zero_approx(enemy.freeze_buildup))

	var decay_enemy := load("res://scenes/actors/enemy/enemy.tscn").instantiate() as Enemy
	add_child(decay_enemy)
	await get_tree().process_frame
	decay_enemy.freeze_buildup = 50.0
	decay_enemy.freeze_decay_delay = 0.0
	decay_enemy._process_afflictions(0.5)
	assert(decay_enemy.freeze_buildup < 50.0)

	print("ICE_SHARD_TEST_OK hits_to_freeze=", hits, " chill=", snappedf(float(chill["magnitude"]) * 100.0, 0.1), "%")
	enemy.queue_free()
	decay_enemy.queue_free()
	get_tree().quit(0)
