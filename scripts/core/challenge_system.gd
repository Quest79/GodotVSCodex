extends Node

enum ElementStyle { BURNING, FREEZING, LIGHTNING }

const DEFAULT_SAVE_PATH := "user://achievements.cfg"
const ACHIEVEMENT_DEFINITIONS := {
	&"century_bronze": {"title": "Century Initiate", "description": "Defeat 100 monsters in under 2 minutes."},
	&"century_silver": {"title": "Horde Breaker", "description": "Defeat 100 monsters in under 90 seconds."},
	&"century_gold": {"title": "One-Person Cataclysm", "description": "Defeat 100 monsters in under 60 seconds."},
	&"boss_bronze": {"title": "Deadline Met", "description": "Defeat the first boss within 5 minutes."},
	&"boss_silver": {"title": "Rift Hunter", "description": "Defeat the first boss within 4 minutes."},
	&"boss_gold": {"title": "Boss Executioner", "description": "Defeat the first boss within 3 minutes."},
	&"untouchable_bronze": {"title": "Untouchable", "description": "Defeat 100 monsters without taking damage."},
	&"untouchable_silver": {"title": "Untouchable Rush", "description": "Do it without damage in under 90 seconds."},
	&"untouchable_gold": {"title": "Flawless Cataclysm", "description": "Do it without damage in under 60 seconds."},
}

signal achievement_unlocked(achievement_id: StringName, title: String, description: String, element: int)
signal challenge_state_changed

var unlocked: Dictionary = {}
var unlock_elements: Dictionary = {}
var best_times: Dictionary = {}
var save_path := DEFAULT_SAVE_PATH

var run_active := false
var run_elapsed := 0.0
var regular_kills := 0
var run_untouched := true
var first_boss_defeated := false
var century_completed := false
var untouchable_completed := false

func _ready() -> void:
	_load_progress()
	GameEvents.enemy_defeated_details.connect(_on_enemy_defeated)
	GameEvents.player_damaged.connect(_on_player_damaged)
	GameEvents.player_died.connect(end_run)

func _process(delta: float) -> void:
	if run_active:
		run_elapsed += delta

func start_run() -> void:
	run_active = true
	run_elapsed = 0.0
	regular_kills = 0
	run_untouched = true
	first_boss_defeated = false
	century_completed = false
	untouchable_completed = false
	challenge_state_changed.emit()

func end_run() -> void:
	run_active = false
	challenge_state_changed.emit()

func _on_enemy_defeated(is_boss: bool) -> void:
	if not run_active:
		return
	if is_boss:
		if not first_boss_defeated:
			first_boss_defeated = true
			_record_time(&"boss_deadline", run_elapsed)
			_unlock_timed_tiers(&"boss", run_elapsed, [300.0, 240.0, 180.0])
	else:
		regular_kills += 1
		if regular_kills >= 100 and not century_completed:
			century_completed = true
			_record_time(&"century_sweep", run_elapsed)
			_unlock_timed_tiers(&"century", run_elapsed, [120.0, 90.0, 60.0])
			if run_untouched:
				untouchable_completed = true
				_record_time(&"untouchable", run_elapsed)
				_unlock_achievement(&"untouchable_bronze")
				if run_elapsed <= 90.0:
					_unlock_achievement(&"untouchable_silver")
				if run_elapsed <= 60.0:
					_unlock_achievement(&"untouchable_gold")
	challenge_state_changed.emit()

func _on_player_damaged(amount: float) -> void:
	if run_active and amount > 0.0 and run_untouched:
		run_untouched = false
		challenge_state_changed.emit()

func _unlock_timed_tiers(prefix: StringName, time: float, thresholds: Array) -> void:
	var tier_names := [&"bronze", &"silver", &"gold"]
	for index in thresholds.size():
		if time <= float(thresholds[index]):
			_unlock_achievement(StringName("%s_%s" % [prefix, tier_names[index]]))

func _record_time(challenge_id: StringName, time: float) -> void:
	var previous_best := float(best_times.get(challenge_id, INF))
	if time < previous_best:
		best_times[challenge_id] = time
		_save_progress()

func _unlock_achievement(achievement_id: StringName) -> void:
	if unlocked.get(achievement_id, false):
		return
	var definition: Dictionary = ACHIEVEMENT_DEFINITIONS.get(achievement_id, {})
	if definition.is_empty():
		return
	var element := randi_range(ElementStyle.BURNING, ElementStyle.LIGHTNING)
	unlocked[achievement_id] = true
	unlock_elements[achievement_id] = element
	_save_progress()
	achievement_unlocked.emit(
		achievement_id,
		String(definition["title"]),
		String(definition["description"]),
		element
	)

func get_best_time(challenge_id: StringName) -> float:
	return float(best_times.get(challenge_id, -1.0))

func get_run_status() -> Dictionary:
	return {
		"active": run_active,
		"elapsed": run_elapsed,
		"kills": regular_kills,
		"untouched": run_untouched,
		"boss_defeated": first_boss_defeated,
		"century_completed": century_completed,
	}

func get_achievement_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for achievement_id in ACHIEVEMENT_DEFINITIONS:
		var definition: Dictionary = ACHIEVEMENT_DEFINITIONS[achievement_id]
		entries.append({
			"id": achievement_id,
			"title": String(definition["title"]),
			"description": String(definition["description"]),
			"unlocked": bool(unlocked.get(achievement_id, false)),
			"element": int(unlock_elements.get(achievement_id, -1)),
		})
	return entries

func format_time(seconds: float) -> String:
	if seconds < 0.0 or is_inf(seconds):
		return "--:--.-"
	var minutes := floori(seconds / 60.0)
	var remaining := fmod(seconds, 60.0)
	return "%02d:%04.1f" % [minutes, remaining]

func _save_progress() -> void:
	var config := ConfigFile.new()
	for achievement_id in unlocked:
		config.set_value("achievements", String(achievement_id), bool(unlocked[achievement_id]))
	for achievement_id in unlock_elements:
		config.set_value("elements", String(achievement_id), int(unlock_elements[achievement_id]))
	for challenge_id in best_times:
		config.set_value("records", String(challenge_id), float(best_times[challenge_id]))
	var error := config.save(save_path)
	if error != OK:
		push_warning("Could not save achievement progress: %s" % error)

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	for key in config.get_section_keys("achievements"):
		unlocked[StringName(key)] = bool(config.get_value("achievements", key, false))
	for key in config.get_section_keys("elements"):
		unlock_elements[StringName(key)] = int(config.get_value("elements", key, ElementStyle.BURNING))
	for key in config.get_section_keys("records"):
		best_times[StringName(key)] = float(config.get_value("records", key, -1.0))
