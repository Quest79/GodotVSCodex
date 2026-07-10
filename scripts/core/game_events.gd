extends Node

enum EnemyDeathEffect { RADIAL_SHATTER, SPIRAL_SHATTER, IMPLOSION_SHATTER }

const BASE_RENDER_SIZE := Vector2i(1920, 1080)
const KEYBINDS_PATH := "user://keybinds.cfg"
const KEYBINDS_SECTION := "keyboard"
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "settings"
const CAMERA_ZOOM_STEPS := [0.5, 0.7, 1.0, 1.5, 2.0]

var enemy_death_effect := EnemyDeathEffect.RADIAL_SHATTER
var game_speed_percent := 200.0
var game_speed_active := false
var rendering_scale_percent := 100.0
var rendering_target_size := BASE_RENDER_SIZE
var rendering_canvas_scale := 1.0
var camera_zoom := 0.7

func _ready() -> void:
	_load_settings()
	_load_keybinds()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("RENDERER: %s | GPU: %s" % [
		RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(),
	])
	get_tree().root.size_changed.connect(apply_rendering_scale)
	apply_rendering_scale()

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SETTINGS_SECTION, "enemy_death_effect", enemy_death_effect)
	config.set_value(SETTINGS_SECTION, "game_speed_percent", game_speed_percent)
	config.set_value(SETTINGS_SECTION, "rendering_scale_percent", rendering_scale_percent)
	config.set_value(SETTINGS_SECTION, "camera_zoom", camera_zoom)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save settings: %s" % error)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	enemy_death_effect = clampi(
		int(config.get_value(SETTINGS_SECTION, "enemy_death_effect", enemy_death_effect)),
		EnemyDeathEffect.RADIAL_SHATTER,
		EnemyDeathEffect.IMPLOSION_SHATTER
	)
	game_speed_percent = clampf(float(config.get_value(SETTINGS_SECTION, "game_speed_percent", game_speed_percent)), 25.0, 500.0)
	rendering_scale_percent = clampf(float(config.get_value(SETTINGS_SECTION, "rendering_scale_percent", rendering_scale_percent)), 25.0, 200.0)
	camera_zoom = clampf(float(config.get_value(SETTINGS_SECTION, "camera_zoom", camera_zoom)), 0.5, 2.0)

func set_keyboard_binding(action: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action) or physical_keycode == KEY_NONE:
		return
	# Replace keyboard events only. Existing controller bindings remain intact.
	for input_event in InputMap.action_get_events(action):
		if input_event is InputEventKey:
			InputMap.action_erase_event(action, input_event)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, key_event)
	var config := ConfigFile.new()
	config.load(KEYBINDS_PATH)
	config.set_value(KEYBINDS_SECTION, String(action), int(physical_keycode))
	var error := config.save(KEYBINDS_PATH)
	if error != OK:
		push_warning("Could not save keybinds: %s" % error)

func get_keyboard_binding_text(action: StringName) -> String:
	for input_event in InputMap.action_get_events(action):
		if input_event is InputEventKey:
			var key_event := input_event as InputEventKey
			return OS.get_keycode_string(key_event.physical_keycode)
	return "UNBOUND"

func _load_keybinds() -> void:
	var config := ConfigFile.new()
	if config.load(KEYBINDS_PATH) != OK:
		return
	for action_name in config.get_section_keys(KEYBINDS_SECTION):
		var action := StringName(action_name)
		if action != &"cycle_camera_zoom":
			continue
		var physical_keycode := int(config.get_value(KEYBINDS_SECTION, action_name, KEY_NONE)) as Key
		set_keyboard_binding(action, physical_keycode)

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

func apply_camera_zoom() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.zoom = Vector2.ONE * clampf(camera_zoom, 0.5, 2.0)

func cycle_camera_zoom() -> void:
	var next_index := 0
	for index in CAMERA_ZOOM_STEPS.size():
		if CAMERA_ZOOM_STEPS[index] > camera_zoom + 0.001:
			next_index = index
			break
	camera_zoom = CAMERA_ZOOM_STEPS[next_index]
	save_settings()
	apply_camera_zoom()

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
