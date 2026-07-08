class_name GemSocketTarget
extends Control

const ITEM_TOOLTIP_SCENE := preload("res://scenes/ui/inventory/item_tooltip.tscn")

signal drop_requested(data: Dictionary, socket_index: int)
signal socket_clicked(socket_index: int)

var gear_item: Resource
var gem: Resource
var socket_index := -1

func setup(source_item: Resource, index: int, socketed_gem: Resource) -> void:
	gear_item = source_item
	socket_index = index
	gem = socketed_gem
	tooltip_text = gem.get_tooltip() if gem else "Empty socket"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _make_custom_tooltip(_for_text: String) -> Object:
	if not gem:
		return null
	var tooltip := ITEM_TOOLTIP_SCENE.instantiate()
	tooltip.call("setup", gem)
	return tooltip

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if gem:
			socket_clicked.emit(socket_index)
		accept_event()

func _get_drag_data(_position: Vector2) -> Variant:
	if not gem:
		return null
	var preview := Control.new()
	var preview_art := TextureRect.new()
	preview.add_child(preview_art)
	preview_art.size = Vector2(76, 76)
	preview_art.position = Vector2(-38, -38)
	preview_art.texture = gem.definition.tooltip_art if gem.definition.tooltip_art else gem.definition.inventory_icon
	preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)
	return {
		"source_kind": &"socket",
		"source_key": {"item": gear_item, "index": socket_index},
	}

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("source_kind") and data.has("source_key")

func _drop_data(_position: Vector2, data: Variant) -> void:
	drop_requested.emit(data, socket_index)
