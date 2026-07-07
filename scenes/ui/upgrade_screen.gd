class_name UpgradeScreen
extends Control

@onready var choice_container: VBoxContainer = %Choices

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameEvents.level_up_requested.connect(_show_choices)
	hide()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		GameEvents.upgrade_cancelled.emit()
		get_viewport().set_input_as_handled()

func _show_choices(level: int) -> void:
	for child in choice_container.get_children():
		child.queue_free()
	%Title.text = "LEVEL %d" % level
	for id in UpgradeCatalog.choices():
		var data := UpgradeCatalog.get_data(id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(420, 76)
		button.text = "%s\n%s" % [data.title, data.description]
		button.pressed.connect(_choose.bind(id))
		choice_container.add_child(button)
	show()

func _choose(id: StringName) -> void:
	hide()
	GameEvents.upgrade_selected.emit(id)
