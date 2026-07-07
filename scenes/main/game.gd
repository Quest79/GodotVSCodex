extends Node2D

@onready var player: Player = $Player

var level := 1
var xp := 0
var xp_required := 5
var pending_level_ups := 0
var score := 0
var wave := 1
var choosing_upgrade := false
var run_ended := false

func _ready() -> void:
	GameEvents.game_speed_active = false
	Engine.time_scale = 1.0
	GameEvents.xp_collected.connect(_add_xp)
	GameEvents.enemy_defeated.connect(_on_enemy_defeated)
	GameEvents.upgrade_selected.connect(_apply_upgrade)
	GameEvents.upgrade_cancelled.connect(_cancel_upgrade)
	GameEvents.player_died.connect(_end_run)
	$EnemySpawner.wave_changed.connect(_on_wave_changed)
	$ItemInventory.connect("equipment_changed", _on_equipment_changed)
	$ItemInventory.connect("skill_loadout_changed", _on_skill_loadout_changed)
	call_deferred("_broadcast_progression")
	call_deferred("_broadcast_run_stats")
	call_deferred("_sync_equipment")
	call_deferred("_update_speed_status")

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("toggle_game_speed") or run_ended or choosing_upgrade:
		return
	GameEvents.game_speed_active = not GameEvents.game_speed_active
	_apply_game_speed()
	get_viewport().set_input_as_handled()

func _apply_game_speed() -> void:
	Engine.time_scale = GameEvents.game_speed_percent / 100.0 if GameEvents.game_speed_active else 1.0
	_update_speed_status()

func _update_speed_status() -> void:
	var label := $GameUI/SpeedStatus as Label
	if GameEvents.game_speed_active:
		label.text = "SPEED x%.2f  [ACTIVE]" % (GameEvents.game_speed_percent / 100.0)
		label.add_theme_color_override("font_color", Color(0.22, 1.0, 0.78))
	else:
		label.text = "SPACE  SPEED x%.2f" % (GameEvents.game_speed_percent / 100.0)
		label.add_theme_color_override("font_color", Color(0.45, 0.62, 0.66))

func _on_enemy_defeated() -> void:
	score += 10
	_broadcast_run_stats()

func _on_wave_changed(new_wave: int) -> void:
	wave = new_wave
	_broadcast_run_stats()

func _on_equipment_changed(modifiers: Dictionary) -> void:
	player.apply_equipment_modifiers(modifiers)
	_broadcast_run_stats()

func _on_skill_loadout_changed(loadout: Dictionary) -> void:
	player.apply_skill_loadout(loadout)

func _sync_equipment() -> void:
	_on_equipment_changed($ItemInventory.get_total_modifiers())
	_on_skill_loadout_changed($ItemInventory.get_skill_loadout())

func _add_xp(amount: int) -> void:
	if run_ended:
		return
	xp += amount
	while xp >= xp_required:
		xp -= xp_required
		level += 1
		xp_required = ceili(xp_required * 1.35 + 2.0)
		pending_level_ups += 1
	_broadcast_progression()
	if pending_level_ups > 0 and not choosing_upgrade:
		_show_level_up()

func _show_level_up() -> void:
	choosing_upgrade = true
	get_tree().paused = true
	GameEvents.level_up_requested.emit(level)

func _apply_upgrade(upgrade_id: StringName) -> void:
	if run_ended or not choosing_upgrade:
		return
	player.apply_upgrade(upgrade_id)
	_broadcast_run_stats()
	pending_level_ups = maxi(pending_level_ups - 1, 0)
	choosing_upgrade = false
	if pending_level_ups > 0:
		call_deferred("_show_level_up")
	else:
		get_tree().paused = false

func _cancel_upgrade() -> void:
	if run_ended or not choosing_upgrade:
		return
	choosing_upgrade = false
	get_tree().paused = false

func _end_run() -> void:
	run_ended = true
	GameEvents.game_speed_active = false
	Engine.time_scale = 1.0
	_update_speed_status()
	get_tree().paused = true

func _broadcast_progression() -> void:
	GameEvents.progression_changed.emit(xp, xp_required, level)

func _broadcast_run_stats() -> void:
	GameEvents.run_stats_changed.emit(score, wave, 1.0 / player.stats.cooldown, player.stats.move_speed, player.stats.health_regen)
