class_name KeybindScreen
extends Control

signal closed

@onready var pause_button: Button = %PauseKeybindButton
@onready var camera_button: Button = %CameraZoomKeybindButton
@onready var dash_button: Button = %DashKeybindButton
@onready var accelerate_button: Button = %AccelerateKeybindButton
@onready var back_button: Button = %BackButton

var rebinding_action: StringName

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.pressed.connect(_begin_rebind.bind(&"pause_game"))
	camera_button.pressed.connect(_begin_rebind.bind(&"cycle_camera_zoom"))
	dash_button.pressed.connect(_begin_rebind.bind(&"dash"))
	accelerate_button.pressed.connect(_begin_rebind.bind(&"toggle_game_speed"))
	back_button.pressed.connect(close)
	_update_buttons()
	hide()

func open() -> void:
	rebinding_action = &""
	_update_buttons()
	show()
	pause_button.grab_focus()

func close() -> void:
	rebinding_action = &""
	hide()
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not rebinding_action.is_empty():
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.pressed and not key_event.echo:
				if key_event.physical_keycode == KEY_ESCAPE:
					rebinding_action = &""
					_update_buttons()
				else:
					GameEvents.set_keyboard_binding(rebinding_action, key_event.physical_keycode)
					rebinding_action = &""
					_update_buttons()
				get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _begin_rebind(action: StringName) -> void:
	rebinding_action = action
	_update_buttons()

func _update_buttons() -> void:
	if not rebinding_action.is_empty():
		pause_button.text = "PRESS A KEY   [ ESC CANCEL ]" if rebinding_action == &"pause_game" else pause_button.text
		camera_button.text = "PRESS A KEY   [ ESC CANCEL ]" if rebinding_action == &"cycle_camera_zoom" else camera_button.text
		dash_button.text = "PRESS A KEY   [ ESC CANCEL ]" if rebinding_action == &"dash" else dash_button.text
		accelerate_button.text = "PRESS A KEY   [ ESC CANCEL ]" if rebinding_action == &"toggle_game_speed" else accelerate_button.text
		return
	pause_button.text = "PAUSE GAME   [ %s ]" % GameEvents.get_keyboard_binding_text(&"pause_game").to_upper()
	camera_button.text = "CYCLE CAMERA ZOOM   [ %s ]" % GameEvents.get_keyboard_binding_text(&"cycle_camera_zoom").to_upper()
	dash_button.text = "DASH   [ %s ]" % GameEvents.get_keyboard_binding_text(&"dash").to_upper()
	accelerate_button.text = "ACCELERATE GAME   [ %s ]" % GameEvents.get_keyboard_binding_text(&"toggle_game_speed").to_upper()
