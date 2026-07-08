class_name GameHUD
extends CanvasLayer

@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_label: Label = %HPLabel
@onready var xp_bar: ProgressBar = %XPBar
@onready var xp_label: Label = %XPLabel
@onready var level_label: Label = %LevelLabel
@onready var score_label: Label = %ScoreLabel
@onready var wave_label: Label = %WaveLabel
@onready var attack_label: Label = %AttackLabel
@onready var movement_speed_label: Label = %MovementSpeedLabel
@onready var health_regen_label: Label = %HealthRegenLabel
@onready var main_attack_label: Label = %MainAttackLabel
@onready var penetration_label: Label = %PenetrationLabel
@onready var projectile_count_label: Label = %ProjectileCountLabel
@onready var main_attack_dps_label: Label = %MainAttackDPSLabel
@onready var fps_label: Label = %FPSLabel
@onready var death_panel: Control = %DeathPanel

var fps_refresh_elapsed := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameEvents.player_health_changed.connect(_on_health_changed)
	GameEvents.progression_changed.connect(_on_progression_changed)
	GameEvents.run_stats_changed.connect(_on_run_stats_changed)
	GameEvents.player_died.connect(_on_player_died)
	%RestartButton.pressed.connect(_restart)
	call_deferred("_sync_health")

func _process(delta: float) -> void:
	fps_refresh_elapsed += delta
	if fps_refresh_elapsed < 0.25:
		return
	fps_refresh_elapsed = 0.0
	fps_label.text = str(Engine.get_frames_per_second())

func _sync_health() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		_on_health_changed(player.health.current, player.health.maximum)

func _on_health_changed(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "%d / %d  VITALITY" % [ceili(current), ceili(maximum)]

func _on_progression_changed(xp: int, required: int, level: int) -> void:
	xp_bar.max_value = required
	xp_bar.value = xp
	xp_label.text = "%d / %d  ESSENCE" % [xp, required]
	level_label.text = str(level)

func _on_run_stats_changed(score: int, wave: int, attack_rate: float, movement_speed: float, health_regen: float, attack_name: String, projectile_penetration: int, projectile_count: int, main_attack_dps: float) -> void:
	score_label.text = str(score)
	wave_label.text = str(wave)
	attack_label.text = "%.2f/s" % attack_rate
	movement_speed_label.text = "%.0f" % movement_speed
	health_regen_label.text = "%.2f/s" % health_regen
	main_attack_label.text = attack_name.to_upper()
	penetration_label.text = str(projectile_penetration)
	projectile_count_label.text = str(projectile_count)
	main_attack_dps_label.text = "%.1f" % main_attack_dps

func _on_player_died() -> void:
	death_panel.show()

func _restart() -> void:
	get_tree().paused = false
	var inventory := get_tree().get_first_node_in_group("item_inventory")
	if inventory and inventory.has_method("clear_saved_run"):
		inventory.call("clear_saved_run")
	get_tree().reload_current_scene()
