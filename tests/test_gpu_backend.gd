extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var renderer := EnemyRenderManager.new()
	add_child(renderer)

	var manager := GPUCombatManager.new()
	add_child(manager)

	for _frame in range(300):
		await get_tree().process_frame
		if manager.backend_announced:
			if not manager.is_gpu_enabled():
				push_error("GPU_BACKEND_TEST_FAILED: %s" % manager.render_init_error)
				get_tree().quit(1)
				return

			var enemy_scene: PackedScene = load("res://scenes/actors/enemy/enemy.tscn")
			for index in range(128):
				var enemy := enemy_scene.instantiate() as Enemy
				var angle := TAU * float(index) / 128.0
				var radius := 260.0 + float(index % 8) * 16.0
				enemy.global_position = Vector2.from_angle(angle) * radius
				add_child(enemy)

			for _dispatch_frame in range(120):
				await get_tree().process_frame

			if manager.get_enemy_count() != 128:
				push_error("GPU_BACKEND_TEST_FAILED: expected 128 GPU enemies, got %d" % manager.get_enemy_count())
				get_tree().quit(1)
				return
			if not renderer.gpu_state_bound:
				push_error("GPU_BACKEND_TEST_FAILED: enemy renderer never bound GPU state")
				get_tree().quit(1)
				return

			# Regression: bosses keep CPU AI/visuals but must remain in the GPU
			# collision buffer so GPU projectiles can acquire and damage them.
			var boss := enemy_scene.instantiate() as Enemy
			boss.global_position = Vector2(56.0, 0.0)
			add_child(boss)
			boss.configure_boss()
			await get_tree().process_frame
			if not boss.gpu_external_mirror or boss.gpu_slot < 0:
				push_error("GPU_BACKEND_TEST_FAILED: boss left GPU collision mirror")
				get_tree().quit(1)
				return
			if manager.get_enemy_count() != 129:
				push_error("GPU_BACKEND_TEST_FAILED: mirrored boss missing from GPU count")
				get_tree().quit(1)
				return

			var boss_start_health := boss.health.current
			var fired := manager.fire_skill(
				Vector2.ZERO,
				{"skill_id": &"default_attack", "damage_multiplier": 1.0},
				25.0,
				720.0,
				1.0,
				1400.0
			)
			if not fired:
				push_error("GPU_BACKEND_TEST_FAILED: projectile did not fire at mirrored boss")
				get_tree().quit(1)
				return

			for _boss_hit_frame in range(90):
				await get_tree().process_frame
				if boss.health.current < boss_start_health:
					break
			if boss.health.current >= boss_start_health:
				push_error("GPU_BACKEND_TEST_FAILED: GPU projectile did not detect/damage boss")
				get_tree().quit(1)
				return

			print("GPU_BACKEND_TEST_OK backend=%s enemies=%d boss_hit=true" % [manager.get_backend_text(), manager.get_enemy_count()])
			get_tree().quit(0)
			return

	push_error("GPU_BACKEND_TEST_FAILED: initialization timed out")
	get_tree().quit(1)
