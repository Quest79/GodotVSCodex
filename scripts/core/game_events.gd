extends Node

enum EnemyDeathEffect { RADIAL_SHATTER, SPIRAL_SHATTER, IMPLOSION_SHATTER }

var enemy_death_effect := EnemyDeathEffect.RADIAL_SHATTER
var game_speed_percent := 200.0
var game_speed_active := false

signal player_health_changed(current: float, maximum: float)
signal progression_changed(xp: int, required: int, level: int)
signal xp_collected(amount: int)
signal enemy_defeated
signal run_stats_changed(score: int, wave: int, attack_rate: float, movement_speed: float, health_regen: float)
signal level_up_requested(level: int)
signal upgrade_cancelled
signal player_died
signal upgrade_selected(upgrade_id: StringName)
