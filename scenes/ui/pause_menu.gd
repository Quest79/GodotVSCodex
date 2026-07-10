class_name PauseMenu
extends Control

@onready var panel: PanelContainer = %PausePanel
@onready var resume_button: Button = %ResumeButton

var is_open := false
var rebinding_action: StringName

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	resume_button.pressed.connect(_close)
	%PauseRestartButton.pressed.connect(_restart)
	%QuitButton.pressed.connect(_quit)
	%CameraZoomKeybindButton.pressed.connect(_begin_camera_zoom_rebind)
	_update_camera_zoom_keybind_button()
	%DeathEffectOption.clear()
	%DeathEffectOption.add_item("Radial Shatter", GameEvents.EnemyDeathEffect.RADIAL_SHATTER)
	%DeathEffectOption.add_item("Spiral Shatter", GameEvents.EnemyDeathEffect.SPIRAL_SHATTER)
	%DeathEffectOption.add_item("Implosion Shatter", GameEvents.EnemyDeathEffect.IMPLOSION_SHATTER)
	%DeathEffectOption.select(GameEvents.enemy_death_effect)
	%DeathEffectOption.item_selected.connect(_on_death_effect_selected)
	%GameSpeedSlider.value = GameEvents.game_speed_percent
	%GameSpeedSlider.value_changed.connect(_on_game_speed_changed)
	_update_game_speed_label(GameEvents.game_speed_percent)
	%RenderingScaleSlider.value = GameEvents.rendering_scale_percent
	%RenderingScaleSlider.value_changed.connect(_on_rendering_scale_changed)
	_update_rendering_scale_label(GameEvents.rendering_scale_percent)
	%CameraZoomSlider.value = GameEvents.camera_zoom
	%CameraZoomSlider.value_changed.connect(_on_camera_zoom_changed)
	_update_camera_zoom_label(GameEvents.camera_zoom)

func _unhandled_input(event: InputEvent) -> void:
	if not rebinding_action.is_empty():
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_open:
		_close()
	elif _can_open():
		_open()
	else:
		return
	get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if rebinding_action.is_empty() or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode != KEY_ESCAPE:
		GameEvents.set_keyboard_binding(rebinding_action, key_event.physical_keycode)
	rebinding_action = &""
	_update_camera_zoom_keybind_button()
	get_viewport().set_input_as_handled()

func _begin_camera_zoom_rebind() -> void:
	rebinding_action = &"cycle_camera_zoom"
	%CameraZoomKeybindButton.text = "PRESS A KEY   •   ESC TO CANCEL"

func _update_camera_zoom_keybind_button() -> void:
	%CameraZoomKeybindButton.text = "CYCLE CAMERA ZOOM   [ %s ]" % GameEvents.get_keyboard_binding_text(&"cycle_camera_zoom").to_upper()

func _can_open() -> bool:
	var ui := get_parent()
	return not ui.get_node("UpgradeScreen").visible \
		and not ui.get_node("DeathPanel").visible \
		and not ui.get_node("InventoryScreen").visible

func _open() -> void:
	is_open = true
	get_tree().paused = true
	show()
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.96, 0.96)
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "modulate:a", 1.0, 0.14)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	resume_button.grab_focus()

func _close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	get_tree().paused = false

func _restart() -> void:
	is_open = false
	get_tree().paused = false
	_clear_saved_run()
	get_tree().reload_current_scene()

func _clear_saved_run() -> void:
	var inventory := get_tree().get_first_node_in_group("item_inventory")
	if inventory and inventory.has_method("clear_saved_run"):
		inventory.call("clear_saved_run")

func _quit() -> void:
	get_tree().quit()

func _on_death_effect_selected(index: int) -> void:
	GameEvents.enemy_death_effect = %DeathEffectOption.get_item_id(index)
	GameEvents.save_settings()

func _on_game_speed_changed(value: float) -> void:
	GameEvents.game_speed_percent = value
	GameEvents.save_settings()
	_update_game_speed_label(value)
	if GameEvents.game_speed_active:
		Engine.time_scale = value / 100.0
	var game := get_tree().current_scene
	if game and game.has_method("_update_speed_status"):
		game.call("_update_speed_status")

func _update_game_speed_label(value: float) -> void:
	%GameSpeedValue.text = "%d%%" % roundi(value)

func _on_rendering_scale_changed(value: float) -> void:
	GameEvents.rendering_scale_percent = value
	GameEvents.save_settings()
	GameEvents.apply_rendering_scale()
	_update_rendering_scale_label(value)

func _update_rendering_scale_label(value: float) -> void:
	%RenderingScaleValue.text = "%d%%" % roundi(value)

func _on_camera_zoom_changed(value: float) -> void:
	GameEvents.camera_zoom = value
	GameEvents.save_settings()
	GameEvents.apply_camera_zoom()
	_update_camera_zoom_label(value)

func _update_camera_zoom_label(value: float) -> void:
	%CameraZoomValue.text = "%.2fx" % value
