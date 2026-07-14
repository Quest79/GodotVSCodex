extends PanelContainer

var refresh_elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ChallengeSystem.challenge_state_changed.connect(_refresh)
	_refresh()

func _process(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed >= 0.1:
		refresh_elapsed = 0.0
		_refresh()

func _refresh() -> void:
	var status := ChallengeSystem.get_run_status()
	if not bool(status["active"]):
		hide()
		return
	show()
	%Timer.text = ChallengeSystem.format_time(float(status["elapsed"]))
	%Century.text = "CENTURY SWEEP   %d / 100" % mini(int(status["kills"]), 100)
	%Boss.text = "BOSS DEADLINE   %s" % ("COMPLETE" if bool(status["boss_defeated"]) else "RUNNING")
	if bool(status["century_completed"]):
		%Untouchable.text = "UNTOUCHABLE   COMPLETE" if bool(status["untouched"]) else "UNTOUCHABLE   FAILED"
	else:
		%Untouchable.text = "UNTOUCHABLE   ACTIVE" if bool(status["untouched"]) else "UNTOUCHABLE   FAILED"
	%Untouchable.add_theme_color_override(
		"font_color",
		Color("77efc3") if bool(status["untouched"]) else Color("b5646c")
	)
