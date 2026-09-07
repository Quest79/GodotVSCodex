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

			print("GPU_BACKEND_TEST_OK backend=%s enemies=%d" % [manager.get_backend_text(), manager.get_enemy_count()])
			get_tree().quit(0)
			return

	push_error("GPU_BACKEND_TEST_FAILED: initialization timed out")
	get_tree().quit(1)
