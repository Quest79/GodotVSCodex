extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := GPUCombatManager.new()
	add_child(manager)

	for _frame in range(300):
		await get_tree().process_frame
		if manager.backend_announced:
			if not manager.is_gpu_enabled():
				push_error("GPU_BACKEND_TEST_FAILED: %s" % manager.render_init_error)
				get_tree().quit(1)
				return

			# Let the live render-thread compute loop execute multiple dispatches.
			for _dispatch_frame in range(30):
				await get_tree().process_frame

			print("GPU_BACKEND_TEST_OK backend=%s" % manager.get_backend_text())
			get_tree().quit(0)
			return

	push_error("GPU_BACKEND_TEST_FAILED: initialization timed out")
	get_tree().quit(1)
