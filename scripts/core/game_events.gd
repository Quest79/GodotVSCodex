extends Node

enum EnemyDeathEffect { RADIAL_SHATTER, SPIRAL_SHATTER, IMPLOSION_SHATTER }

const BASE_RENDER_SIZE := Vector2i(1920, 1080)

var enemy_death_effect := EnemyDeathEffect.RADIAL_SHATTER
var game_speed_percent := 200.0
var game_speed_active := false
var rendering_scale_percent := 100.0
var rendering_target_size := BASE_RENDER_SIZE
var rendering_canvas_scale := 1.0

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("RENDERER: %s | GPU: %s" % [
		RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(),
	])
	get_tree().root.size_changed.connect(apply_rendering_scale)
	apply_rendering_scale()

func apply_rendering_scale() -> void:
	var scale := clampf(rendering_scale_percent / 100.0, 0.25, 2.0)
	var window := get_tree().root
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_size = BASE_RENDER_SIZE
	window.content_scale_factor = 1.0
	rendering_canvas_scale = scale
	rendering_target_size = Vector2i(
		roundi(BASE_RENDER_SIZE.x * scale),
		roundi(BASE_RENDER_SIZE.y * scale)
	)
	_set_render_target_size()

func _set_render_target_size() -> void:
	var window := get_tree().root
	var viewport_rid := window.get_viewport_rid()
	RenderingServer.viewport_set_render_direct_to_screen(viewport_rid, false)
	RenderingServer.viewport_set_size(
		viewport_rid,
		rendering_target_size.x,
		rendering_target_size.y
	)
	# The RenderingServer framebuffer size otherwise becomes the logical 2D
	# canvas size as well. Scale every canvas by the same factor so 1920x1080
	# remains the coordinate system for the camera, HUD, menus, and input.
	RenderingServer.viewport_set_global_canvas_transform(
		viewport_rid,
		Transform2D().scaled(Vector2.ONE * rendering_canvas_scale)
	)
	# Resizing a root viewport through RenderingServer also requires explicitly
	# mapping that framebuffer back onto the complete client area. Without this,
	# a supersampled target is shown at 1:1 size in the upper-left corner.
	RenderingServer.viewport_attach_to_screen(
		viewport_rid,
		Rect2(Vector2.ZERO, Vector2(window.size)),
		window.current_screen
	)

signal player_health_changed(current: float, maximum: float)
signal progression_changed(xp: int, required: int, level: int)
signal xp_collected(amount: int)
signal enemy_defeated
signal run_stats_changed(score: int, wave: int, attack_rate: float, movement_speed: float, health_regen: float, attack_name: String, projectile_penetration: int, projectile_count: int, main_attack_dps: float)
signal level_up_requested(level: int)
signal upgrade_cancelled
signal player_died
signal upgrade_selected(upgrade_id: StringName)
