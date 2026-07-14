extends Node2D

const LEVEL_UP_NOVA_FX := preload("res://scenes/combat/level_up_nova_fx.gd")

@onready var player: Player = $Player

var level := 1
var xp := 0
var xp_required := 5
var score := 0
var wave := 1
var run_ended := false

func _ready() -> void:
	GameEvents.game_speed_active = false
	Engine.time_scale = 1.0
	_reset_player_start()
	GameEvents.xp_collected.connect(_add_xp)
	GameEvents.enemy_defeated.connect(_on_enemy_defeated)
	GameEvents.player_died.connect(_end_run)
	$EnemySpawner.wave_changed.connect(_on_wave_changed)
	$ItemInventory.connect("equipment_changed", _on_equipment_changed)
	$ItemInventory.connect("skill_loadout_changed", _on_skill_loadout_changed)
	call_deferred("_broadcast_progression")
	call_deferred("_broadcast_run_stats")
	call_deferred("_sync_equipment")
	call_deferred("_update_speed_status")

func _reset_player_start() -> void:
	# Initialize position and camera before the first rendered frame. Applying
	# saved camera settings later caused a visible startup jump.
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.zoom = Vector2.ONE * clampf(GameEvents.camera_zoom, 0.5, 2.0)
		camera.reset_smoothing()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_camera_zoom"):
		GameEvents.cycle_camera_zoom()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("toggle_game_speed") or run_ended:
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
	_broadcast_run_stats()

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
		var upgrades := UpgradeCatalog.choices()
		if not upgrades.is_empty():
			var upgrade_id: StringName = upgrades.pick_random()
			player.apply_upgrade(upgrade_id)
			GameEvents.upgrade_applied.emit(upgrade_id)
		_spawn_level_up_nova()
	_broadcast_progression()
	_broadcast_run_stats()

func _spawn_level_up_nova() -> void:
	var nova := LEVEL_UP_NOVA_FX.new() as LevelUpNovaFX
	get_tree().current_scene.add_child(nova)
	nova.global_position = player.global_position

func _end_run() -> void:
	run_ended = true
	GameEvents.game_speed_active = false
	Engine.time_scale = 1.0
	_update_speed_status()
	get_tree().paused = true

func _broadcast_progression() -> void:
	GameEvents.progression_changed.emit(xp, xp_required, level)

func _broadcast_run_stats() -> void:
	var config := player.weapon.skill_config
	var attack_rate := 1.0 / player.stats.cooldown
	var projectile_count := maxi(1, roundi(float(config.get(&"projectile_count", 1.0))))
	var penetration := maxi(0, roundi(float(config.get(&"pierce", 0.0))))
	var damage_per_projectile := player.stats.damage * float(config.get(&"damage_multiplier", 1.0))
	var attack_name := String(config.get(&"skill_name", "Default Attack"))
	var main_attack_dps := damage_per_projectile * projectile_count * attack_rate
	GameEvents.run_stats_changed.emit(
		score,
		wave,
		attack_rate,
		player.stats.move_speed,
		player.stats.health_regen,
		attack_name,
		penetration,
		projectile_count,
		main_attack_dps
	)
