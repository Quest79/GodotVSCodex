class_name ChallengeScreen
extends Control

signal closed

@onready var run_status_label: Label = %RunStatus
@onready var century_best_label: Label = %CenturyBest
@onready var boss_best_label: Label = %BossBest
@onready var untouchable_best_label: Label = %UntouchableBest
@onready var achievement_list: RichTextLabel = %AchievementList
@onready var back_button: Button = %BackButton

var refresh_elapsed := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	back_button.pressed.connect(close)
	ChallengeSystem.challenge_state_changed.connect(_refresh)
	hide()

func _process(delta: float) -> void:
	if not visible:
		return
	refresh_elapsed += delta
	if refresh_elapsed >= 0.1:
		refresh_elapsed = 0.0
		_refresh_run_status()

func open() -> void:
	refresh_elapsed = 0.0
	_refresh()
	show()
	back_button.grab_focus()

func close() -> void:
	hide()
	closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	_refresh_run_status()
	century_best_label.text = _best_text(&"century_sweep")
	boss_best_label.text = _best_text(&"boss_deadline")
	untouchable_best_label.text = _best_text(&"untouchable")
	var lines: Array[String] = []
	for entry in ChallengeSystem.get_achievement_entries():
		var unlocked: bool = entry["unlocked"]
		var marker := "[color=#58f0bd]UNLOCKED[/color]" if unlocked else "[color=#52636b]LOCKED[/color]"
		var title: String = entry["title"] if unlocked else "???"
		var description: String = entry["description"]
		lines.append("%s  [b]%s[/b]\n[color=#82969e]%s[/color]" % [marker, title, description])
	achievement_list.text = "\n\n".join(lines)

func _refresh_run_status() -> void:
	var status := ChallengeSystem.get_run_status()
	if not bool(status["active"]):
		run_status_label.text = "NO ACTIVE RUN"
		return
	var untouched_text := "FLAWLESS" if bool(status["untouched"]) else "DAMAGE TAKEN"
	run_status_label.text = "RUN %s   •   100 KILLS %d/100   •   %s" % [
		ChallengeSystem.format_time(float(status["elapsed"])),
		mini(int(status["kills"]), 100),
		untouched_text,
	]

func _best_text(challenge_id: StringName) -> String:
	var best := ChallengeSystem.get_best_time(challenge_id)
	return "BEST  %s" % ChallengeSystem.format_time(best)
