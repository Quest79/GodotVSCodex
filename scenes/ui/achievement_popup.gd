extends Control

const SLIDE_DISTANCE := 520.0

@onready var panel: PanelContainer = %PopupPanel
@onready var heading: Label = %Heading
@onready var title_label: Label = %AchievementTitle
@onready var description_label: Label = %Description
@onready var effect_layer: Control = %ElementEffect
@onready var audio_player: AudioStreamPlayer = %AlertSound

var notification_queue: Array[Dictionary] = []
var displaying := false
var rest_position := Vector2.ZERO
var sound_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ChallengeSystem.achievement_unlocked.connect(_queue_achievement)
	panel.modulate.a = 0.0
	call_deferred("_capture_rest_position")

func _capture_rest_position() -> void:
	rest_position = panel.position
	panel.position.x = rest_position.x + SLIDE_DISTANCE

func _queue_achievement(achievement_id: StringName, title: String, description: String, element: int) -> void:
	notification_queue.append({
		"id": achievement_id,
		"title": title,
		"description": description,
		"element": element,
	})
	if not displaying:
		_show_next()

func _show_next() -> void:
	if notification_queue.is_empty():
		displaying = false
		return
	displaying = true
	var notification: Dictionary = notification_queue.pop_front()
	var element: int = notification["element"]
	title_label.text = String(notification["title"])
	description_label.text = String(notification["description"])
	_apply_element_theme(element)
	effect_layer.call("configure", element)
	audio_player.stream = _get_unlock_sound(element)
	var alert_volume := clampf(GameEvents.achievement_alert_volume_percent / 100.0, 0.0, 1.0)
	audio_player.volume_db = linear_to_db(alert_volume) if alert_volume > 0.0 else -80.0
	audio_player.play()
	panel.position = rest_position + Vector2(SLIDE_DISTANCE, 0.0)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.97, 0.97)
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "position", rest_position - Vector2(13.0, 0.0), 0.38).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position", rest_position, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(4.0)
	tween.tween_property(panel, "position", rest_position + Vector2(SLIDE_DISTANCE, 0.0), 0.42).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.28)
	tween.finished.connect(_on_notification_finished)

func _on_notification_finished() -> void:
	effect_layer.call("stop")
	_show_next()

func _apply_element_theme(element: int) -> void:
	match element:
		ChallengeSystem.ElementStyle.FREEZING:
			heading.add_theme_color_override("font_color", Color("89dfff"))
			title_label.add_theme_color_override("font_color", Color("d8f7ff"))
			title_label.add_theme_color_override("font_shadow_color", Color(0.18, 0.72, 1.0, 0.7))
		ChallengeSystem.ElementStyle.LIGHTNING:
			heading.add_theme_color_override("font_color", Color("b89cff"))
			title_label.add_theme_color_override("font_color", Color("f0e9ff"))
			title_label.add_theme_color_override("font_shadow_color", Color(0.55, 0.3, 1.0, 0.75))
		_:
			heading.add_theme_color_override("font_color", Color("ff8b45"))
			title_label.add_theme_color_override("font_color", Color("fff0ba"))
			title_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.18, 0.02, 0.72))

func _get_unlock_sound(element: int) -> AudioStreamWAV:
	if sound_cache.has(element):
		return sound_cache[element] as AudioStreamWAV
	var stream := _build_unlock_sound(element)
	sound_cache[element] = stream
	return stream

func _build_unlock_sound(element: int) -> AudioStreamWAV:
	const MIX_RATE := 44100
	const DURATION := 1.05
	var sample_count := roundi(MIX_RATE * DURATION)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var frequencies := [523.25, 659.25, 783.99]
	var accent_frequency := 392.0
	match element:
		ChallengeSystem.ElementStyle.FREEZING:
			accent_frequency = 1046.5
		ChallengeSystem.ElementStyle.LIGHTNING:
			accent_frequency = 739.99
	for index in sample_count:
		var time := float(index) / MIX_RATE
		var sample := 0.0
		for note_index in frequencies.size():
			var delay := note_index * 0.105
			var note_time := time - delay
			if note_time >= 0.0:
				var envelope := exp(-note_time * 4.8) * (1.0 - exp(-note_time * 55.0))
				sample += sin(TAU * frequencies[note_index] * note_time) * envelope * 0.19
		var accent_time := time - 0.24
		if accent_time >= 0.0:
			var accent_envelope := exp(-accent_time * 6.2) * (1.0 - exp(-accent_time * 70.0))
			sample += sin(TAU * accent_frequency * accent_time) * accent_envelope * 0.08
		var encoded_sample := roundi(clampf(sample, -0.9, 0.9) * 32767.0)
		data.encode_s16(index * 2, encoded_sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
